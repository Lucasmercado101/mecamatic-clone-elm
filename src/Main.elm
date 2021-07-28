port module Main exposing (..)

import Browser
import Html exposing (Html, br, button, datalist, div, form, input, option, p, span, text)
import Html.Attributes exposing (class, classList, disabled, id, list, style, tabindex, value)
import Html.Events exposing (on, onInput, onSubmit)
import Json.Decode as JD
import Keyboard.Event exposing (KeyboardEvent, decodeKeyboardEvent)
import List.Extra
import Process
import Round
import Task
import Time



--* PORTS


port sendRequestUserData : String -> Cmd msg


port sendRequestProfilesNames : () -> Cmd msg



-- * PORT userDataReceiver = userData | undefined


port userDataReceiver : (JD.Value -> msg) -> Sub msg



-- * PORT userProfilesReceiver = string[] | undefined


port userProfilesReceiver : (JD.Value -> msg) -> Sub msg



-- * DECODERS


type alias UserSettings =
    { timeLimitInSeconds : Int
    , errorsCoefficient : Maybe Float
    , isTutorGloballyActive : Maybe Bool
    , isKeyboardGloballyVisible : Maybe Bool
    , minimumWPM : Maybe Int
    }


userProfileNamesDecoder : JD.Decoder (List String)
userProfileNamesDecoder =
    JD.list JD.string


userDataDecoder : JD.Decoder UserSettings
userDataDecoder =
    JD.map5 UserSettings
        (JD.field "timeLimitInSeconds" JD.int)
        (JD.maybe (JD.field "errorsCoefficient" JD.float))
        (JD.maybe (JD.field "isTutorGloballyActive" JD.bool))
        (JD.maybe (JD.field "isKeyboardGloballyVisible" JD.bool))
        (JD.maybe (JD.field "minimumWPM" JD.int))



-- * SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        WelcomeView _ ->
            Sub.batch
                [ userProfilesReceiver
                    (JD.decodeValue
                        userProfileNamesDecoder
                        >> (\l ->
                                case l of
                                    Ok val ->
                                        GotWelcomeMsg (ReceivedUserProfiles val)

                                    Err _ ->
                                        -- NOTE if it fails then it doesn't re-request again or anything (todo?)
                                        GotWelcomeMsg FailedToLoadUsers
                           )
                    )
                , userDataReceiver
                    (JD.decodeValue
                        userDataDecoder
                        >> (\l ->
                                case l of
                                    Ok val ->
                                        GotWelcomeMsg (ReceivedUserData val)

                                    Err _ ->
                                        GotWelcomeMsg FailedToLoadUserData
                           )
                    )
                ]

        MainView mainViewModel ->
            Sub.map GotMainViewMsg (mainViewsubscriptions mainViewModel)



--* INIT


init : () -> ( Model, Cmd Msg )
init _ =
    ( WelcomeView
        { selectedUser = ""
        , userProfiles = IsLoading
        , requestedUserData = ErrorRequestingUserData
        }
    , Cmd.batch
        [ sendRequestProfilesNames ()
        , Process.sleep 200
            |> Task.perform (\_ -> GotWelcomeMsg ShowIsLoadingText)
        ]
    )



--* MODEL


type UserProfiles
    = IsLoading
    | IsLoadingSlowly
    | FailedToLoad
    | UsersLoaded (List String)


type RequestedUserData
    = NotRequested
    | Requested
    | ErrorRequestingUserData


type alias WelcomeModel =
    { selectedUser : String
    , userProfiles : UserProfiles
    , requestedUserData : RequestedUserData
    }


type Model
    = WelcomeView WelcomeModel
    | MainView MainViewModel



--* UPDATE


type WelcomeMsg
    = ConfirmedUserProfile
    | ReceivedUserProfiles (List String)
    | ChangeSelectedUser String
    | ShowIsLoadingText
    | FailedToLoadUsers
    | ReceivedUserData UserSettings
    | FailedToLoadUserData


type Msg
    = GotWelcomeMsg WelcomeMsg
    | GotMainViewMsg MainViewMsg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( GotWelcomeMsg welcomeMsg, WelcomeView welcomeModel ) ->
            case welcomeMsg of
                ConfirmedUserProfile ->
                    ( WelcomeView welcomeModel, sendRequestUserData welcomeModel.selectedUser )

                ChangeSelectedUser userName ->
                    ( WelcomeView { welcomeModel | selectedUser = userName }, Cmd.none )

                ReceivedUserProfiles profiles ->
                    ( WelcomeView { welcomeModel | userProfiles = UsersLoaded profiles }, Cmd.none )

                FailedToLoadUsers ->
                    ( WelcomeView { welcomeModel | userProfiles = FailedToLoad }, Cmd.none )

                ShowIsLoadingText ->
                    case welcomeModel.userProfiles of
                        IsLoading ->
                            ( WelcomeView { welcomeModel | userProfiles = IsLoadingSlowly }, Cmd.none )

                        _ ->
                            ( WelcomeView welcomeModel, Cmd.none )

                FailedToLoadUserData ->
                    ( WelcomeView { welcomeModel | requestedUserData = ErrorRequestingUserData }, Cmd.none )

                ReceivedUserData data ->
                    ( MainView
                        { userData =
                            { userSettings = data
                            , userName = welcomeModel.selectedUser
                            }
                        , exercise = ExerciseNotSelected
                        , elapsedSeconds = 0
                        }
                    , sendOnMainView ()
                    )

        ( GotMainViewMsg mainViewMsg, MainView mainViewModel ) ->
            mainViewUpdate mainViewMsg mainViewModel
                |> (\( mainModel, mainMsg ) -> ( MainView mainModel, Cmd.map GotMainViewMsg mainMsg ))

        _ ->
            ( model, Cmd.none )



--* VIEW


welcomeView : WelcomeModel -> Html WelcomeMsg
welcomeView model =
    form
        -- TODO handle what happens when this fails to load user data
        [ class "welcome-container", onSubmit ConfirmedUserProfile ]
        [ div
            [ class "input-container" ]
            [ div
                [ classList
                    [ ( "home-input", True )
                    , ( "home-input--loading", model.userProfiles == IsLoadingSlowly )
                    , ( "home-input--failed-load", model.userProfiles == FailedToLoad )
                    ]
                ]
                [ input
                    [ list "user-profiles"
                    , onInput ChangeSelectedUser
                    , value model.selectedUser
                    ]
                    []
                ]
            , datalist [ id "user-profiles" ]
                (case model.userProfiles of
                    UsersLoaded usersProfiles ->
                        List.map (\l -> option [ value l ] []) usersProfiles

                    _ ->
                        []
                )
            , button [ disabled (model.selectedUser == "") ]
                [ text "Aceptar" ]
            ]
        ]


view : Model -> Html Msg
view model =
    case model of
        WelcomeView welcomeModel ->
            welcomeView welcomeModel |> Html.map GotWelcomeMsg

        MainView mainViewModel ->
            Html.map GotMainViewMsg (mainViewView mainViewModel)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- *********** MAIN VIEW *************
-- * SUBSCRIPTIONS
-- NOTE on entering the main view, we need to inform electron to show different menu messages, hence:
-- this way it actually changes the menu items and exercises can be loaded


port sendOnMainView : () -> Cmd msg



-- * Receives LINK electron/data.models.ts:33


port receiveExerciseData : (JD.Value -> msg) -> Sub msg



-- * DECODERS


exerciseDataDecoder : JD.Decoder ExerciseData
exerciseDataDecoder =
    JD.map7 ExerciseData
        (JD.field "text" JD.string)
        (JD.field "isTutorActive" JD.bool)
        (JD.field "isKeyboardVisible" JD.bool)
        (JD.field "wordsPerMinuteNeededToPass" JD.int)
        (JD.field "exerciseCategory" JD.string)
        (JD.field "exerciseNumber" JD.int)
        (JD.field "lessonNumber" JD.int)



-- * SUBSCRIPTIONS


mainViewsubscriptions : MainViewModel -> Sub MainViewMsg
mainViewsubscriptions model =
    Sub.batch
        [ case model.exercise of
            ExerciseSelected _ status ->
                case status of
                    Ongoing _ _ ->
                        Time.every 1000 (always SecondHasElapsed)

                    _ ->
                        Sub.none

            _ ->
                Sub.none
        , receiveExerciseData
            (JD.decodeValue
                exerciseDataDecoder
                >> (\l ->
                        case l of
                            Ok val ->
                                ReceivedExerciseData val

                            Err _ ->
                                FailedToLoadExerciseData
                   )
            )
        ]



-- * MODEL


type ExerciseStatus
    = NotStarted
    | Ongoing Int Int -- Cursor, errors committed
    | Paused Int Int -- Cursor, errors committed
    | ExerciseFinishedSuccessfully Int Int -- Cursor, errors committed


type alias ExerciseData =
    { text : String
    , isTutorActive : Bool
    , isKeyboardVisible : Bool
    , wordsPerMinuteNeededToPass : Int
    , exerciseCategory : String
    , exerciseNumber : Int
    , lessonNumber : Int
    }


type Exercise
    = ExerciseNotSelected
    | FailedToLoadEData
    | ExerciseSelected ExerciseData ExerciseStatus


type alias UserData =
    { userName : String
    , userSettings : UserSettings
    }


type alias MainViewModel =
    { userData : UserData
    , exercise : Exercise
    , elapsedSeconds : Int
    }



-- * UPDATE


type MainViewMsg
    = ReceivedExerciseData ExerciseData
    | FailedToLoadExerciseData
    | KeyPressed KeyboardEvent
    | SecondHasElapsed


mainViewUpdate : MainViewMsg -> MainViewModel -> ( MainViewModel, Cmd MainViewMsg )
mainViewUpdate msg model =
    case msg of
        ReceivedExerciseData exerciseData ->
            ( { model | exercise = ExerciseSelected exerciseData NotStarted }, Cmd.none )

        FailedToLoadExerciseData ->
            -- TODO handle happens when an exercise is already selected and we try to load another one and fail
            ( { model | exercise = FailedToLoadEData }, Cmd.none )

        SecondHasElapsed ->
            let
                elapsedSeconds =
                    case model.exercise of
                        ExerciseSelected exerciseData status ->
                            case status of
                                Ongoing _ _ ->
                                    model.elapsedSeconds + 1

                                _ ->
                                    model.elapsedSeconds

                        _ ->
                            model.elapsedSeconds
            in
            ( { model | elapsedSeconds = elapsedSeconds }, Cmd.none )

        KeyPressed event ->
            let
                exercise =
                    model.exercise
            in
            case model.exercise of
                ExerciseNotSelected ->
                    ( { model | exercise = exercise }, Cmd.none )

                FailedToLoadEData ->
                    ( { model | exercise = exercise }, Cmd.none )

                ExerciseSelected exerciseData status ->
                    case event.key of
                        Just keyPressed ->
                            case status of
                                NotStarted ->
                                    if keyPressed == "Enter" then
                                        ( { model | exercise = ExerciseSelected exerciseData (Ongoing 0 0) }, Cmd.none )

                                    else
                                        ( { model | exercise = exercise }, Cmd.none )

                                Ongoing cursor errors ->
                                    let
                                        textCharsList : List ( Int, Char )
                                        textCharsList =
                                            List.indexedMap (\i c -> Tuple.pair i c) (String.toList exerciseData.text)

                                        currentChar : Maybe ( Int, Char )
                                        currentChar =
                                            List.Extra.find (\( i, _ ) -> cursor == i) textCharsList

                                        -- ------- Modifier keys --------
                                        -- https://www.w3.org/TR/uievents-key/#keys-modifier
                                        modifierKeys =
                                            [ "Alt"
                                            , "AltGraph"
                                            , "CapsLock"
                                            , "Control"
                                            , "Fn"
                                            , "FnLock"
                                            , "Meta"
                                            , "NumLock"
                                            , "ScrollLock"
                                            , "Shift"
                                            , "Symbol"
                                            , "SymbolLock"
                                            ]

                                        -- https://www.w3.org/TR/uievents-key/#keys-composition
                                        iMEAndCompositionKeys =
                                            [ "AllCandidates"
                                            , "Alphanumeric"
                                            , "CodeInput"
                                            , "Compose"
                                            , "Convert"
                                            , "Dead"
                                            , "FinalMode"
                                            , "GroupFirst"
                                            , "GroupLast"
                                            , "GroupNext"
                                            , "GroupPrevious"
                                            , "ModeChange"
                                            , "NextCandidate"
                                            , "NonConvert"
                                            , "PreviousCandidate"
                                            , "Process"
                                            , "SingleCandidate"
                                            ]

                                        -- NOTE this check is not exhaustive
                                        isModifierKey : String -> Bool
                                        isModifierKey key =
                                            List.member key modifierKeys
                                                || List.member key iMEAndCompositionKeys
                                                || event.altKey
                                                || event.ctrlKey
                                                || event.metaKey
                                                || event.shiftKey
                                    in
                                    -- NOTE this won't be "Enter" or something that isn't a single char, otherwise this doesn't work
                                    -- i KNOW it won't be enter as none of the lessons have \n or \r or \r\n in them
                                    case currentChar of
                                        Just ( _, char ) ->
                                            if cursor == (String.length exerciseData.text - 1) then
                                                -- TODO check if succeded or failed
                                                ( { model | exercise = ExerciseSelected exerciseData (ExerciseFinishedSuccessfully cursor errors) }, Cmd.none )

                                            else if keyPressed == String.fromChar char then
                                                ( { model | exercise = ExerciseSelected exerciseData (Ongoing (cursor + 1) errors) }, Cmd.none )
                                                -- TODO check if key is not modifier key

                                            else if isModifierKey keyPressed then
                                                ( { model | exercise = ExerciseSelected exerciseData (Ongoing cursor errors) }, Cmd.none )

                                            else
                                                ( { model | exercise = ExerciseSelected exerciseData (Ongoing cursor (errors + 1)) }, Cmd.none )

                                        Nothing ->
                                            ( { model | exercise = exercise }, Cmd.none )

                                -- TODO successfully and unsuccessfully finished cases
                                _ ->
                                    ( { model | exercise = exercise }, Cmd.none )

                        Nothing ->
                            ( { model | exercise = exercise }, Cmd.none )



-- model.exercise
-- ( { model | exercise = exercise }, Cmd.none )
-- * VIEW


mainViewView : MainViewModel -> Html MainViewMsg
mainViewView model =
    div
        [ class "main-view"
        , tabindex 0
        , on "keydown" <|
            JD.map KeyPressed decodeKeyboardEvent
        ]
        [ div [ class "main-view-content" ] [ textBox model, infoPanel model ]
        ]


textBox : MainViewModel -> Html MainViewMsg
textBox model =
    div
        [ class "text-box-container"
        ]
        (case model.exercise of
            ExerciseNotSelected ->
                [ div [ class "text-box__welcome-text" ] [ text "Bienvenido a MecaMatic 3.0" ] ]

            ExerciseSelected data status ->
                [ div [ class "text-box-chars__container" ]
                    (List.indexedMap
                        (\i el ->
                            let
                                char =
                                    String.fromChar el
                            in
                            span
                                [ classList
                                    [ ( "text-box-chars__char", True )
                                    , ( "text-box-chars__char--highlighted"
                                      , case status of
                                            Ongoing cursor _ ->
                                                i == cursor

                                            Paused cursor _ ->
                                                i == cursor

                                            NotStarted ->
                                                False

                                            ExerciseFinishedSuccessfully _ _ ->
                                                False
                                      )
                                    , ( "text-box-chars__char--typed"
                                      , case status of
                                            Ongoing cursor _ ->
                                                i < cursor

                                            Paused cursor _ ->
                                                i < cursor

                                            NotStarted ->
                                                False

                                            ExerciseFinishedSuccessfully _ _ ->
                                                False
                                      )
                                    ]
                                ]
                                [ text char ]
                        )
                        (String.toList data.text)
                    )
                ]

            FailedToLoadEData ->
                -- TODO if there is already an exercise selected and we try to load another one and fails
                [ div [] [] ]
        )


totalNetKeystrokesTyped : Int -> Int -> Int
totalNetKeystrokesTyped totalKeystrokes errors =
    totalKeystrokes - errors


totalGrossKeystrokesTyped : Int -> Int -> Int
totalGrossKeystrokesTyped totalKeystrokes errors =
    totalKeystrokes + errors


calculatePercentageOfErrors : Int -> Int -> Float
calculatePercentageOfErrors errors cursor =
    if errors == 0 then
        0.0

    else
        100.0 * (toFloat errors / toFloat cursor)


calcNetWPM : Int -> Int -> Int -> Int
calcNetWPM cursor seconds errors =
    if cursor == 0 then
        0

    else
        round ((toFloat cursor / 5 - toFloat errors) / (toFloat seconds / 60))


centerText =
    style "text-align" "center"


infoPanel : MainViewModel -> Html MainViewMsg
infoPanel model =
    let
        userSettings =
            model.userData.userSettings
    in
    div [ class "info-panel-container" ]
        [ div
            [ centerText, class "info-panel-box", style "min-height" "69px", style "max-height" "69px" ]
            ([ p [ class "info-panel-box__title" ] [ text "Alumno y nivel actual" ]
             , br [] []
             , text model.userData.userName
             ]
                ++ (case model.exercise of
                        ExerciseSelected exerciseData _ ->
                            [ br [] []
                            , div [ style "display" "inline-block", style "margin-top" "5px" ] [ text exerciseData.exerciseCategory ]
                            , br [] []
                            , text ("Lección " ++ String.fromInt exerciseData.lessonNumber ++ " - Ejercicio " ++ String.fromInt exerciseData.exerciseNumber)
                            ]

                        _ ->
                            []
                   )
            )
        , div [ class "info-panel-box info-panel-box--padded", style "min-height" "64px", style "max-height" "64px" ]
            [ p [ class "info-panel-box__title" ] [ text "Valores establecidos" ]
            , div [ class "info-panel-boxes-col" ]
                [ div [ class "info-panel-box-inner-boxes" ]
                    [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "Coefi M.e.p." ]
                    , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ] [ text (String.fromFloat (Maybe.withDefault 2 userSettings.errorsCoefficient) ++ " %") ]
                    ]
                , div [ class "info-panel-box-inner-boxes" ]
                    [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "Velocidad" ]
                    , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ] [ text (String.fromInt (Maybe.withDefault 20 userSettings.minimumWPM)) ]
                    ]
                ]
            ]
        , div
            [ class "info-panel-box info-panel-box--padded"
            , style "padding-top" "20px"

            -- TODO
            -- , style "min-height" "64px"
            -- , style "max-height" "64px"
            ]
            [ p [ class "info-panel-box__title" ] [ text "Resultados obtenidos" ]
            , div [ class "info-panel-boxes-col" ]
                [ div [ class "info-panel-box-inner-boxes" ]
                    [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "P. Brutas" ]
                    , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ]
                        [ case model.exercise of
                            ExerciseSelected _ status ->
                                case status of
                                    NotStarted ->
                                        text "0"

                                    Ongoing cursor errors ->
                                        text (String.fromInt (totalGrossKeystrokesTyped cursor errors))

                                    Paused cursor errors ->
                                        text (String.fromInt (totalGrossKeystrokesTyped cursor errors))

                                    ExerciseFinishedSuccessfully cursor errors ->
                                        text (String.fromInt (totalGrossKeystrokesTyped cursor errors))

                            _ ->
                                text ""
                        ]
                    ]
                , div [ class "info-panel-box-inner-boxes" ]
                    [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "P. Netas" ]
                    , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ]
                        [ case model.exercise of
                            ExerciseSelected _ status ->
                                case status of
                                    NotStarted ->
                                        text "0"

                                    Ongoing cursor errors ->
                                        text (String.fromInt (totalNetKeystrokesTyped cursor errors))

                                    Paused cursor errors ->
                                        text (String.fromInt (totalNetKeystrokesTyped cursor errors))

                                    ExerciseFinishedSuccessfully cursor errors ->
                                        text (String.fromInt (totalNetKeystrokesTyped cursor errors))

                            _ ->
                                text ""
                        ]
                    ]
                , div [ class "info-panel-box-inner-boxes" ]
                    [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "Errores" ]
                    , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ]
                        [ case model.exercise of
                            ExerciseSelected _ status ->
                                case status of
                                    NotStarted ->
                                        text "0"

                                    Ongoing _ errors ->
                                        text (String.fromInt errors)

                                    Paused _ errors ->
                                        text (String.fromInt errors)

                                    ExerciseFinishedSuccessfully _ errors ->
                                        text (String.fromInt errors)

                            _ ->
                                text ""
                        ]
                    ]
                , div [ class "info-panel-box-inner-boxes" ]
                    [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "% Errores" ]

                    --! FIXME can give infinity
                    , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ]
                        [ let
                            isWholeNumber : Float -> Bool
                            isWholeNumber num =
                                String.fromFloat num
                                    |> String.filter (\l -> l == '.')
                                    |> (\l -> String.length l == 1)

                            getErrorPercentageString : Float -> String
                            getErrorPercentageString num =
                                if isWholeNumber num then
                                    Round.round 2 num

                                else
                                    String.fromFloat num
                          in
                          case model.exercise of
                            ExerciseSelected _ status ->
                                case status of
                                    NotStarted ->
                                        text "0"

                                    Ongoing cursor errors ->
                                        text (getErrorPercentageString (calculatePercentageOfErrors errors cursor))

                                    Paused cursor errors ->
                                        text (getErrorPercentageString (calculatePercentageOfErrors errors cursor))

                                    ExerciseFinishedSuccessfully cursor errors ->
                                        text (getErrorPercentageString (calculatePercentageOfErrors errors cursor))

                            _ ->
                                text ""
                        ]
                    ]

                -- TODO
                , div [ class "info-panel-box-inner-boxes" ]
                    [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "P. p. m." ]

                    --! FIXME can give infinity
                    , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ]
                        [ case model.exercise of
                            ExerciseSelected _ status ->
                                case status of
                                    NotStarted ->
                                        text "0"

                                    Ongoing cursor errors ->
                                        text (String.fromInt (calcNetWPM cursor model.elapsedSeconds errors))

                                    Paused cursor errors ->
                                        text (String.fromInt (calcNetWPM cursor model.elapsedSeconds errors))

                                    ExerciseFinishedSuccessfully cursor errors ->
                                        text (String.fromInt (calcNetWPM cursor model.elapsedSeconds errors))

                            _ ->
                                text ""
                        ]
                    ]
                ]
            ]
        ]
