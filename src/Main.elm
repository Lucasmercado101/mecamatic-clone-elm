port module Main exposing (..)

import Browser
import Html exposing (Html, br, button, datalist, div, form, input, option, p, span, text)
import Html.Attributes exposing (class, classList, disabled, id, list, style, tabindex, value)
import Html.Attributes.Extra exposing (empty)
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
            case mainViewMsg of
                LogOut ->
                    init ()

                _ ->
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


port receiveLogOut : (() -> msg) -> Sub msg



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
        , receiveLogOut (\_ -> LogOut)
        ]



-- * MODEL


type ExerciseStatus
    = NotStarted
    | Ongoing Int Int -- Cursor, errors committed
    | Paused Int Int -- Cursor, errors committed
    | ExerciseFinishedSuccessfully Int Int -- Cursor, errors committed
    | ExerciseFailed Int Int String -- Cursor, errrors committed, error message


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



{- Enum

    {
        errorsCoefficient = 2
       , minimumSpeed = 20
   }
-}


userDefaults : { errorsCoefficient : Float, minimumSpeed : Int }
userDefaults =
    { errorsCoefficient = 2
    , minimumSpeed = 20
    }



{- Enum -}


keyFingerColors : { pinky : String, ringFinger : String, middleFinger : String, indexLeftHand : String, indexRightHand : String }
keyFingerColors =
    { pinky = "#ffffc0"
    , ringFinger = "#c0ffc0"
    , middleFinger = "#c0ffff"
    , indexLeftHand = "#ffc0ff"
    , indexRightHand = "#ff96ff"
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
    | LogOut


mainViewUpdate : MainViewMsg -> MainViewModel -> ( MainViewModel, Cmd MainViewMsg )
mainViewUpdate msg model =
    case msg of
        ReceivedExerciseData exerciseData ->
            ( { model | exercise = ExerciseSelected exerciseData NotStarted, elapsedSeconds = 0 }, Cmd.none )

        FailedToLoadExerciseData ->
            -- TODO handle happens when an exercise is already selected and we try to load another one and fail
            ( { model | exercise = FailedToLoadEData }, Cmd.none )

        -- TODO handle time has run out
        SecondHasElapsed ->
            let
                elapsedSeconds =
                    case model.exercise of
                        ExerciseSelected _ status ->
                            case status of
                                Ongoing _ _ ->
                                    model.elapsedSeconds + 1

                                _ ->
                                    model.elapsedSeconds

                        _ ->
                            model.elapsedSeconds
            in
            case model.exercise of
                ExerciseSelected data status ->
                    case status of
                        Ongoing cursor errors ->
                            if elapsedSeconds == model.userData.userSettings.timeLimitInSeconds then
                                ( { model
                                    | elapsedSeconds = elapsedSeconds
                                    , exercise = ExerciseSelected data (ExerciseFailed cursor errors "Ha superado el\nlimite de tiempo\nestablecido")
                                  }
                                , Cmd.none
                                )

                            else
                                ( { model | elapsedSeconds = elapsedSeconds }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        LogOut ->
            --* Never reaches here, gets picked up in LINK ./Main.elm:218
            ( model, Cmd.none )

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
                                            List.indexedMap Tuple.pair (String.toList exerciseData.text)

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
                                                let
                                                    pctErrorsCommited : Int
                                                    pctErrorsCommited =
                                                        round (calculatePercentageOfErrors errors cursor)
                                                in
                                                if pctErrorsCommited > round (Maybe.withDefault userDefaults.errorsCoefficient model.userData.userSettings.errorsCoefficient) then
                                                    ( { model | exercise = ExerciseSelected exerciseData (ExerciseFailed (cursor + 1) errors "Ha superado el % maximo de errores permitidos") }, Cmd.none )

                                                else if calcNetWPM cursor model.elapsedSeconds errors < userDefaults.minimumSpeed then
                                                    ( { model | exercise = ExerciseSelected exerciseData (ExerciseFailed (cursor + 1) errors "No ha superado la velocidad minima") }, Cmd.none )

                                                else
                                                    ( { model | exercise = ExerciseSelected exerciseData (ExerciseFinishedSuccessfully cursor errors) }, Cmd.none )

                                            else if keyPressed == String.fromChar char then
                                                ( { model | exercise = ExerciseSelected exerciseData (Ongoing (cursor + 1) errors) }, Cmd.none )

                                            else if isModifierKey keyPressed then
                                                ( { model | exercise = ExerciseSelected exerciseData (Ongoing cursor errors) }, Cmd.none )

                                            else
                                                ( { model | exercise = ExerciseSelected exerciseData (Ongoing cursor (errors + 1)) }, Cmd.none )

                                        Nothing ->
                                            ( { model | exercise = exercise }, Cmd.none )

                                _ ->
                                    ( { model | exercise = exercise }, Cmd.none )

                        Nothing ->
                            ( { model | exercise = exercise }, Cmd.none )



-- * VIEW


mainViewView : MainViewModel -> Html MainViewMsg
mainViewView model =
    div
        [ class "main-view"
        , tabindex 0
        , case model.exercise of
            ExerciseSelected _ status ->
                case status of
                    NotStarted ->
                        on "keydown" <|
                            JD.map KeyPressed decodeKeyboardEvent

                    Ongoing _ _ ->
                        on "keydown" <|
                            JD.map KeyPressed decodeKeyboardEvent

                    _ ->
                        empty

            _ ->
                empty
        ]
        [ div [ class "main-view-content" ] [ div [] [ textBox model, keyboard model ], infoPanel model ]
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

                                            ExerciseFailed cursor _ _ ->
                                                i == cursor

                                            _ ->
                                                False
                                      )
                                    , ( "text-box-chars__char--typed"
                                      , case status of
                                            NotStarted ->
                                                False

                                            Ongoing cursor _ ->
                                                i < cursor

                                            Paused cursor _ ->
                                                i < cursor

                                            ExerciseFailed cursor _ _ ->
                                                i < cursor

                                            ExerciseFinishedSuccessfully _ _ ->
                                                True
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


centerText : Html.Attribute msg
centerText =
    style "text-align" "center"



-- TODO add "title" property with descriptiosn to info boxes


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
        , div
            [ centerText, class "info-panel-box info-panel-incidences", style "min-height" "78px", style "max-height" "78px" ]
            [ p [ class "info-panel-box__title" ] [ text "Incidencias" ]
            , case model.exercise of
                ExerciseNotSelected ->
                    div [ class "info-panel-incidences__red-box" ] [ text "Seleccione un", br [] [], text "ejercicio" ]

                ExerciseSelected _ status ->
                    case status of
                        ExerciseFailed _ _ errorMessage ->
                            div [ class "info-panel-incidences__red-box" ] [ text errorMessage ]

                        _ ->
                            text ""

                _ ->
                    text ""
            ]
        , div [ class "info-panel-box info-panel-box--padded", style "min-height" "64px", style "max-height" "64px" ]
            [ p [ class "info-panel-box__title" ] [ text "Valores establecidos" ]
            , div [ class "info-panel-boxes-col" ]
                [ div [ class "info-panel-box-inner-boxes" ]
                    [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "Coefi M.e.p." ]
                    , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ] [ text (String.fromFloat (Maybe.withDefault userDefaults.errorsCoefficient userSettings.errorsCoefficient) ++ " %") ]
                    ]
                , div [ class "info-panel-box-inner-boxes" ]
                    [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "Velocidad" ]
                    , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ] [ text (String.fromInt (Maybe.withDefault userDefaults.minimumSpeed userSettings.minimumWPM)) ]
                    ]
                ]
            ]
        , div [ style "display" "flex", style "flex-direction" "column", style "gap" "13px" ]
            [ div
                [ class "info-panel-box info-panel-box--padded"
                , style "padding-top" "20px"
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

                                        ExerciseFailed cursor errors _ ->
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

                                        ExerciseFailed cursor errors _ ->
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

                                        ExerciseFailed _ errors _ ->
                                            text (String.fromInt errors)

                                _ ->
                                    text ""
                            ]
                        ]
                    , div [ class "info-panel-box-inner-boxes" ]
                        [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "% Errores" ]
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
                                            text
                                                (if cursor == 0 && errors > 0 then
                                                    "100.00"

                                                 else
                                                    getErrorPercentageString (calculatePercentageOfErrors errors cursor)
                                                )

                                        Paused cursor errors ->
                                            text
                                                (if cursor == 0 && errors > 0 then
                                                    "100.00"

                                                 else
                                                    getErrorPercentageString (calculatePercentageOfErrors errors cursor)
                                                )

                                        ExerciseFinishedSuccessfully cursor errors ->
                                            text
                                                (if cursor == 0 && errors > 0 then
                                                    "100.00"

                                                 else
                                                    getErrorPercentageString (calculatePercentageOfErrors errors cursor)
                                                )

                                        ExerciseFailed cursor errors _ ->
                                            text
                                                (if cursor == 0 && errors > 0 then
                                                    "100.00"

                                                 else
                                                    getErrorPercentageString (calculatePercentageOfErrors errors cursor)
                                                )

                                _ ->
                                    text ""
                            ]
                        ]
                    , div [ class "info-panel-box-inner-boxes" ]
                        [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "P. p. m." ]
                        , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ]
                            [ case model.exercise of
                                ExerciseSelected _ status ->
                                    if model.elapsedSeconds == 0 then
                                        text "0"

                                    else
                                        case status of
                                            NotStarted ->
                                                text "0"

                                            Ongoing cursor errors ->
                                                text (String.fromInt (max 0 (calcNetWPM cursor model.elapsedSeconds errors)))

                                            Paused cursor errors ->
                                                text (String.fromInt (max 0 (calcNetWPM cursor model.elapsedSeconds errors)))

                                            ExerciseFinishedSuccessfully cursor errors ->
                                                text (String.fromInt (max 0 (calcNetWPM cursor model.elapsedSeconds errors)))

                                            ExerciseFailed cursor errors _ ->
                                                text (String.fromInt (max 0 (calcNetWPM cursor model.elapsedSeconds errors)))

                                _ ->
                                    text ""
                            ]
                        ]
                    ]
                ]
            , div [ class "info-panel-time" ]
                [ div [ class "info-panel-time__box info-panel-time__box--big-box" ] [ text "Tiempo dis." ]
                , div [ class "info-panel-time__box info-panel-time__box--small-box" ]
                    [ let
                        minutesRemaining =
                            let
                                minutes =
                                    (model.userData.userSettings.timeLimitInSeconds - model.elapsedSeconds) // 60
                            in
                            if minutes < 10 then
                                "0" ++ String.fromInt minutes

                            else
                                String.fromInt minutes

                        secondsRemaining =
                            let
                                seconds =
                                    (model.userData.userSettings.timeLimitInSeconds - model.elapsedSeconds) |> modBy 60
                            in
                            if seconds < 10 then
                                "0" ++ String.fromInt seconds

                            else
                                String.fromInt seconds
                      in
                      text (minutesRemaining ++ ":" ++ secondsRemaining)
                    ]
                ]
            ]
        ]


keyboard : MainViewModel -> Html MainViewMsg
keyboard model =
    let
        exerciseHasntStarted =
            case model.exercise of
                ExerciseSelected _ status ->
                    if status == NotStarted then
                        True

                    else
                        False

                _ ->
                    False

        currentChar : Char
        currentChar =
            case model.exercise of
                ExerciseSelected data status ->
                    case status of
                        Ongoing cursor _ ->
                            String.toList data.text
                                |> List.indexedMap Tuple.pair
                                |> List.Extra.find (\( i, _ ) -> cursor == i)
                                |> Maybe.withDefault ( 0, '←' )
                                |> Tuple.second

                        _ ->
                            '←'

                _ ->
                    '←'
    in
    div [ class "keyboard-container" ]
        [ div [ class "keyboard-row" ]
            [ div [ class "key", style "background-color" keyFingerColors.pinky ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "fontSize" "0.8rem"
                        , style "left" "4px"
                        , style "top" "-4px"
                        ]
                        [ text "a" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "4px"
                        , style "top" "11px"
                        ]
                        [ text "°" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "16px"
                        , style "top" "7px"
                        , style "fontSize" "0.9rem"
                        ]
                        [ text "\\" ]
                    ]
                ]
            , div [ class "key", style "background-color" keyFingerColors.pinky ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "-3px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "!" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "4px"
                        , style "top" "10px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text "1" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "18px"
                        , style "top" "6px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "|" ]
                    ]
                ]
            , div [ class "key", style "background-color" keyFingerColors.ringFinger ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "-2px"
                        ]
                        [ text "\"" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "4px"
                        , style "top" "8px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "2" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "14px"
                        , style "top" "8px"
                        , style "fontSize" "0.6rem"
                        ]
                        [ text "@" ]
                    ]
                ]
            , div [ class "key", style "background-color" keyFingerColors.middleFinger ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "-10px"
                        ]
                        [ text "." ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "4px"
                        , style "top" "7px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "3" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "16px"
                        , style "top" "8px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text "#" ]
                    ]
                ]
            , div [ class "key", style "background-color" keyFingerColors.indexLeftHand ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "6px"
                        , style "top" "-3px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "$" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "9px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "4" ]
                    ]
                ]
            , div [ class "key", style "background-color" keyFingerColors.indexLeftHand ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "-3px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text "%" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "9px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "5" ]
                    ]
                ]
            , div [ class "key", style "background-color" keyFingerColors.indexRightHand ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "-4px"
                        , style "fontSize" "1.3rem"
                        ]
                        [ text "°" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "6px"
                        , style "top" "9px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "6" ]
                    ]
                ]
            , div [ class "key", style "background-color" keyFingerColors.indexRightHand ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "6px"
                        , style "top" "-3px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "/" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "9px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "7" ]
                    ]
                ]
            , div [ class "key", style "background-color" keyFingerColors.middleFinger ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "-3px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text "(" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "9px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "8" ]
                    ]
                ]
            , div [ class "key", style "background-color" keyFingerColors.ringFinger ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "-3px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text ")" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "9px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "9" ]
                    ]
                ]
            , div [ class "key" ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "-3px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text "=" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "9px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "0" ]
                    ]
                ]
            , div [ class "key" ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "-2px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "?" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "14px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "'" ]
                    ]
                ]
            , div [ class "key" ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "-6px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "¿" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "8px"
                        , style "top" "8px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text "¡" ]
                    ]
                ]
            , div [ class "key key--return" ] [ div [ style "margin-top" "-5px" ] [ text "←" ] ]
            ]
        , div [ class "keyboard-row" ]
            [ div [ class "key key--tab", style "background-color" keyFingerColors.pinky ] [ text "⭾" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'q' || currentChar == 'Q' )
                    ]
                , style "background-color" keyFingerColors.pinky
                ]
                [ text "Q" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'w' || currentChar == 'W' )
                    ]
                , style "background-color" keyFingerColors.ringFinger
                ]
                [ text "W" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'e' || currentChar == 'E' )
                    ]
                , style "background-color" keyFingerColors.middleFinger
                ]
                [ text "E" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'r' || currentChar == 'R' )
                    ]
                , style "background-color" keyFingerColors.indexLeftHand
                ]
                [ text "R" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 't' || currentChar == 'T' )
                    ]
                , style "background-color" keyFingerColors.indexLeftHand
                ]
                [ text "T" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'y' || currentChar == 'Y' )
                    ]
                , style "background-color" keyFingerColors.indexRightHand
                ]
                [ text "Y" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'u' || currentChar == 'U' )
                    ]
                , style "background-color" keyFingerColors.indexRightHand
                ]
                [ text "U" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'i' || currentChar == 'I' )
                    ]
                , style "background-color" keyFingerColors.middleFinger
                ]
                [ text "I" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'o' || currentChar == 'O' )
                    ]
                , style "background-color" keyFingerColors.ringFinger
                ]
                [ text "O" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'p' || currentChar == 'P' )
                    ]
                ]
                [ text "P" ]
            , div [ class "key" ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "1px"
                        ]
                        [ text "^" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "6px"
                        , style "top" "13px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text "`" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "16px"
                        , style "top" "8px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text "[" ]
                    ]
                ]
            , div [ class "key" ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "0"
                        ]
                        [ text "*" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "4px"
                        , style "top" "7px"
                        ]
                        [ text "+" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "18px"
                        , style "top" "8px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text "]" ]
                    ]
                ]
            , div
                [ classList
                    [ ( "key key--enter-top", True )
                    , ( "key--highlighted", exerciseHasntStarted )
                    ]
                ]
                [ text "Enter" ]
            ]
        , div [ class "keyboard-row" ]
            [ div [ class "key key--caps-lock", style "background-color" keyFingerColors.pinky ] [ text "Mayús" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'a' || currentChar == 'A' )
                    ]
                , style "background-color" keyFingerColors.pinky
                ]
                [ text "A" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 's' || currentChar == 'S' )
                    ]
                , style "background-color" keyFingerColors.ringFinger
                ]
                [ text "S" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'd' || currentChar == 'D' )
                    ]
                , style "background-color" keyFingerColors.middleFinger
                ]
                [ text "D" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'f' || currentChar == 'F' )
                    ]
                , style "background-color" keyFingerColors.indexLeftHand
                ]
                [ text "F" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'g' || currentChar == 'G' )
                    ]
                , style "background-color" keyFingerColors.indexLeftHand
                ]
                [ text "G" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'h' || currentChar == 'H' )
                    ]
                , style "background-color" keyFingerColors.indexRightHand
                ]
                [ text "H" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'j' || currentChar == 'J' )
                    ]
                , style "background-color" keyFingerColors.indexRightHand
                ]
                [ text "J" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'k' || currentChar == 'K' )
                    ]
                , style "background-color" keyFingerColors.middleFinger
                ]
                [ text "K" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'l' || currentChar == 'L' )
                    ]
                , style "background-color" keyFingerColors.ringFinger
                ]
                [ text "L" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'ñ' || currentChar == 'Ñ' )
                    ]
                ]
                [ text "Ñ" ]
            , div [ class "key" ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "6px"
                        , style "top" "2px"
                        ]
                        [ text "¨" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "4px"
                        , style "top" "13px"
                        ]
                        [ text "´" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "16px"
                        , style "top" "8px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text "{" ]
                    ]
                ]
            , div [ class "key" ]
                [ div [ class "custom-row-key" ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "5px"
                        , style "top" "-3px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "ç" ]
                    , p
                        [ style "position" "absolute"
                        , style "left" "16px"
                        , style "top" "4px"
                        , style "fontSize" "0.8rem"
                        ]
                        [ text "}" ]
                    ]
                ]
            , div
                [ classList
                    [ ( "key key--enter-bottom", True )
                    , ( "key--enter-bottom--highlighted", exerciseHasntStarted )
                    , ( "key--highlighted", exerciseHasntStarted )
                    ]
                ]
                []
            ]
        , div [ class "keyboard-row" ]
            [ div [ class "key key--lshift", style "background-color" keyFingerColors.pinky ] [ text "⇧" ]
            , div [ class "key", style "background-color" keyFingerColors.pinky ]
                [ div
                    [ style "line-height" "0.7"
                    , style "fontSize" "0.9rem"
                    ]
                    [ text ">"
                    , br [] []
                    , text "<"
                    ]
                ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'z' || currentChar == 'Z' )
                    ]
                , style "background-color" keyFingerColors.pinky
                ]
                [ text "Z" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'x' || currentChar == 'X' )
                    ]
                , style "background-color" keyFingerColors.ringFinger
                ]
                [ text "X" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'c' || currentChar == 'C' )
                    ]
                , style "background-color" keyFingerColors.middleFinger
                ]
                [ text "C" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'v' || currentChar == 'V' )
                    ]
                , style "background-color" keyFingerColors.indexLeftHand
                ]
                [ text "V" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'b' || currentChar == 'B' )
                    ]
                , style "background-color" keyFingerColors.indexLeftHand
                ]
                [ text "B" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'n' || currentChar == 'N' )
                    ]
                , style "background-color" keyFingerColors.indexRightHand
                ]
                [ text "N" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == 'm' || currentChar == 'M' )
                    ]
                , style "background-color" keyFingerColors.indexRightHand
                ]
                [ text "M" ]
            , div [ class "key", style "background-color" keyFingerColors.middleFinger ]
                [ div
                    [ style "line-height" "0.65"
                    , style "padding-left" "6px"
                    , style "text-align" "left"
                    , style "font-size" "0.85rem"
                    ]
                    [ text ";"
                    , br [] []
                    , text ","
                    ]
                ]
            , div [ class "key", style "background-color" keyFingerColors.ringFinger ]
                [ div
                    [ style "line-height" "0.65"
                    , style "padding-left" "6px"
                    , style "text-align" "left"
                    , style "font-size" "0.85rem"
                    ]
                    [ text ":"
                    , br [] []
                    , text "."
                    ]
                ]
            , div [ class "key" ]
                [ div
                    [ style "line-height" "1.2"
                    , style "padding-left" "6px"
                    , style "text-align" "left"
                    , style "font-size" "0.9rem"
                    , style "margin-top" "-8px"
                    ]
                    [ text "_"
                    , br [] []
                    , text "-"
                    ]
                ]
            , div [ class "key key--rshift" ] [ text "⇧" ]
            ]
        , div [ class "keyboard-row" ]
            [ div [ class "key key--ctrl" ] [ text "Ctrl" ]
            , div [ class "key", style "width" "52px" ] [ text "" ]
            , div [ class "key key--lalt" ] [ text "Alt" ]
            , div
                [ classList
                    [ ( "key", True )
                    , ( "key--highlighted", currentChar == ' ' )
                    ]
                , style "width" "159px"
                ]
                [ text "" ]
            , div [ class "key key--alt-grl" ] [ text "AltGrl" ]
            , div [ class "key", style "width" "48px" ] [ text "" ]
            , div [ class "key", style "width" "48px" ] [ text "" ]
            , div [ class "key key--ctrl" ] [ text "Ctrl" ]
            ]
        ]
