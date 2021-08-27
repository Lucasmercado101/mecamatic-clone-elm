port module Views.Main exposing (Exercise(..), Model, Msg(..), sendOnMainView, subscriptions, update, view)

import Browser.Dom as Dom
import Either exposing (Either(..))
import Html exposing (Html, br, button, div, img, p, span, text)
import Html.Attributes exposing (class, classList, id, src, style, tabindex)
import Html.Attributes.Extra exposing (empty)
import Html.Events exposing (on, onClick)
import Json.Decode as JD
import Keyboard.Event exposing (KeyboardEvent, decodeKeyboardEvent)
import List.Extra
import Round
import Task
import Time


type alias UserSettings =
    { timeLimitInSeconds : Int
    , errorsCoefficient : Maybe Float
    , isTutorGloballyActive : Maybe Bool
    , isKeyboardGloballyVisible : Maybe Bool
    , minimumWPM : Maybe Int
    }



-- * SUBSCRIPTIONS
-- NOTE on entering the main view, we need to inform electron to show different menu messages, hence the port:
-- this way it actually changes the menu items and exercises can be loaded


port sendOnMainView : () -> Cmd msg


port sendScrollHighlightedKeyIntoView : () -> Cmd msg


type alias RequestExercise =
    { exerciseNumber : Int
    , lessonNumber : Int
    , lessonType : String
    }


port sendRequestNextExercise : RequestExercise -> Cmd msg


port sendRequestPreviousExercise : RequestExercise -> Cmd msg



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


subscriptions : Model -> Sub Msg
subscriptions model =
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



-- TODO map each key to it's error finger & hand, default to index
-- type KeyFingerErrors
--     = Pinky
--     | RingFinger
--     | MiddleFinger
--     | IndexLeftHand
--     | IndexRightHand
-- type KeyHandError
--     = LeftHand KeyFingerErrors
--     | RightHand KeyFingerErrors


type alias Model =
    { userData : UserData
    , exercise : Exercise
    , elapsedSeconds : Int
    }



-- * UPDATE


type Msg
    = ReceivedExerciseData ExerciseData
    | FailedToLoadExerciseData
    | KeyPressed KeyboardEvent
    | SecondHasElapsed
    | LogOut
    | PauseTimer
    | ResumeTimer
    | RestartExercise
    | NoOp
    | RequestPreviousExercise
    | RequestNextExercise


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ReceivedExerciseData exerciseData ->
            ( { model | exercise = ExerciseSelected exerciseData NotStarted, elapsedSeconds = 0 }, Cmd.none )

        FailedToLoadExerciseData ->
            -- TODO handle happens when an exercise is already selected and we try to load another one and fail
            case model.exercise of
                ExerciseSelected _ _ ->
                    ( model, Cmd.none )

                _ ->
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

        RestartExercise ->
            case model.exercise of
                ExerciseSelected data status ->
                    ( { model | exercise = ExerciseSelected data NotStarted, elapsedSeconds = 0 }
                    , Task.attempt (\_ -> NoOp) (Dom.setViewportOf "text-box-container-id" 0 0)
                    )

                _ ->
                    ( model, Cmd.none )

        LogOut ->
            --* Never reaches here, gets picked up in LINK ./Main.elm:218
            ( model, Cmd.none )

        PauseTimer ->
            let
                exercise =
                    model.exercise
            in
            ( { model
                | exercise =
                    case exercise of
                        ExerciseSelected data status ->
                            case status of
                                Ongoing cursor errors ->
                                    ExerciseSelected data (Paused cursor errors)

                                _ ->
                                    exercise

                        _ ->
                            exercise
              }
            , Cmd.none
            )

        ResumeTimer ->
            let
                exercise =
                    model.exercise
            in
            ( { model
                | exercise =
                    case exercise of
                        ExerciseSelected data status ->
                            case status of
                                Paused cursor errors ->
                                    ExerciseSelected data (Ongoing cursor errors)

                                _ ->
                                    exercise

                        _ ->
                            exercise
              }
            , Cmd.none
            )

        RequestPreviousExercise ->
            case model.exercise of
                ExerciseSelected data _ ->
                    ( model
                    , sendRequestPreviousExercise
                        { exerciseNumber = data.exerciseNumber
                        , lessonNumber = data.lessonNumber
                        , lessonType = data.exerciseCategory
                        }
                    )

                _ ->
                    ( model, Cmd.none )

        RequestNextExercise ->
            case model.exercise of
                ExerciseSelected data _ ->
                    ( model
                    , sendRequestNextExercise
                        { exerciseNumber = data.exerciseNumber
                        , lessonNumber = data.lessonNumber
                        , lessonType = data.exerciseCategory
                        }
                    )

                _ ->
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
                                                ( { model | exercise = ExerciseSelected exerciseData (Ongoing (cursor + 1) errors) }, sendScrollHighlightedKeyIntoView () )

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


view : Model -> Html Msg
view model =
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
        -- TODO Unblur on click
        [ div [ class "top-toolbar" ]
            [ div [ class "top-toolbar__menu-items" ]
                [ div [ class "toolbar-separator" ] []
                , button
                    [ class "top-toolbar__menu-item"
                    , case model.exercise of
                        ExerciseSelected _ status ->
                            case status of
                                Ongoing _ _ ->
                                    onClick PauseTimer

                                Paused _ _ ->
                                    onClick ResumeTimer

                                _ ->
                                    onClick PauseTimer

                        _ ->
                            empty
                    ]
                    [ img [ src "./images/stop.png" ] []
                    , text
                        (case model.exercise of
                            ExerciseSelected _ status ->
                                case status of
                                    Ongoing _ _ ->
                                        "Pausa"

                                    Paused _ _ ->
                                        "Reanudar"

                                    _ ->
                                        "Pausa"

                            _ ->
                                "Pausa"
                        )
                    ]
                , div [ class "toolbar-separator" ] []
                , button
                    [ class "top-toolbar__menu-item"
                    , onClick RestartExercise
                    ]
                    [ img [ src "./images/repeat.png" ] []
                    , text "Repetir"
                    ]
                , div [ class "toolbar-separator" ] []
                , button
                    [ class "top-toolbar__menu-item"
                    , onClick RequestPreviousExercise
                    ]
                    [ img [ src "./images/left_arr.png" ] []
                    , text "Anterior"
                    ]
                , div [ class "toolbar-separator" ] []
                , button
                    [ class "top-toolbar__menu-item"
                    , onClick RequestNextExercise
                    ]
                    [ img [ src "./images/right_arr.png" ] []
                    , text "Siguiente"
                    ]
                ]
            ]
        , div
            [ class "main-view-content" ]
            [ div [] [ textBox model, keyboard model ]
            , infoPanel model
            ]
        ]


textBox : Model -> Html Msg
textBox model =
    div
        [ class "text-box-container", id "text-box-container-id" ]
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
                                [ case status of
                                    Ongoing cursor _ ->
                                        -- NOTE this is to make the cursor scroll into view using ports
                                        -- doesn't work with just i == cursor for some reason
                                        if i == cursor || i == cursor - 1 then
                                            id "key-highlighted"

                                        else
                                            empty

                                    Paused cursor _ ->
                                        if i == cursor || i == cursor - 1 then
                                            id "key-highlighted"

                                        else
                                            empty

                                    ExerciseFailed cursor _ _ ->
                                        if i == cursor || i == cursor - 1 then
                                            id "key-highlighted"

                                        else
                                            empty

                                    _ ->
                                        empty
                                , classList
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


infoPanel : Model -> Html Msg
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


keyboard : Model -> Html Msg
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

                        Paused cursor _ ->
                            String.toList data.text
                                |> List.indexedMap Tuple.pair
                                |> List.Extra.find (\( i, _ ) -> cursor == i)
                                |> Maybe.withDefault ( 0, '←' )
                                |> Tuple.second

                        _ ->
                            '←'

                _ ->
                    '←'

        isTutorActive =
            case model.exercise of
                ExerciseNotSelected ->
                    True

                ExerciseSelected data _ ->
                    case model.userData.userSettings.isTutorGloballyActive of
                        Just bool ->
                            bool

                        Nothing ->
                            data.isTutorActive

                _ ->
                    False

        currentCharIs : Either Char (List Char) -> Bool
        currentCharIs val =
            case val of
                Left char ->
                    Char.toLower char == currentChar || char == currentChar

                Right chars ->
                    case List.Extra.find (\l -> Char.toLower l == currentChar || l == currentChar) chars of
                        Just _ ->
                            True

                        Nothing ->
                            False
    in
    div [ class "keyboard-container" ]
        [ div [ class "keyboard-row" ]
            [ div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '|', '°', '¬' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Right [ '|', '°', '¬' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '1', '!' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Right [ '1', '!' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '2', '"' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs (Right [ '2', '"' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '3', '#' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs (Right [ '3', '#' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '4', '$' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs (Right [ '4', '$' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '5', '%' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs (Right [ '5', '%' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '6', '&' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs (Right [ '6', '&' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '7', '/' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs (Right [ '7', '/' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '8', '(' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs (Right [ '8', '(' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '9', ')' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs (Right [ '9', ')' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '0', '=' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Right [ '0', '=' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '?', '\'', '\\' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Right [ '?', '\'', '\\' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '¿', '¡' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Right [ '¿', '¡' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            [ div
                [ class "key key--tab"
                , if isTutorActive then
                    style "background-color" keyFingerColors.pinky

                  else
                    empty
                ]
                [ text "⭾" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'Q') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Left 'Q') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "Q" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'W') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs (Left 'W') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "W" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ 'E', 'É', 'Ë', 'é', 'ë' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs (Right [ 'E', 'É', 'Ë', 'é', 'ë' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ div
                    [ style "display" "flex"
                    , style "flex-direction" "column"
                    , style "position" "relative"
                    , style "width" "100%"
                    , style "height" "100%"
                    ]
                    [ p
                        [ style "position" "absolute"
                        , style "left" "4px"
                        , style "top" "0"
                        , style "fontSize" "1rem"
                        ]
                        [ text "E" ]
                    , p
                        [ style "position" "absolute"
                        , style "bottom" "1px"
                        , style "right" "2px"
                        , style "fontSize" "0.7rem"
                        ]
                        [ text "€"
                        ]
                    ]
                ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'R') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs (Left 'R') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "R" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'T') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs (Left 'T') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "T" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'Y') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs (Left 'Y') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "Y" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ 'U', 'Ú', 'Ü', 'ú', 'ü' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs (Right [ 'U', 'Ú', 'Ü', 'ú', 'ü' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "U" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ 'I', 'Í', 'Ï', 'í', 'ï' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs (Right [ 'I', 'Í', 'Ï', 'í', 'ï' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "I" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ 'O', 'Ó', 'Ö', 'ó', 'ö' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs (Right [ 'O', 'Ó', 'Ö', 'ó', 'ö' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "O" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'P') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Left 'P') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "P" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if
                        currentCharIs (Right [ '´', '¨', 'á', 'é', 'í', 'ó', 'ú', 'ä', 'ë', 'ï', 'ö', 'ü' ])
                            || (case List.Extra.find (\l -> l == currentChar) [ 'Ä', 'Ë', 'Ï', 'Ö', 'Ü', 'Á', 'É', 'Í', 'Ó', 'Ú' ] of
                                    Just _ ->
                                        True

                                    Nothing ->
                                        False
                               )
                    then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if
                    currentCharIs (Right [ '´', '¨', 'á', 'é', 'í', 'ó', 'ú', 'ä', 'ë', 'ï', 'ö', 'ü' ])
                        || (case List.Extra.find (\l -> l == currentChar) [ 'Ä', 'Ë', 'Ï', 'Ö', 'Ü', 'Á', 'É', 'Í', 'Ó', 'Ú' ] of
                                Just _ ->
                                    True

                                Nothing ->
                                    False
                           )
                  then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '+', '*', '~' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Right [ '+', '*', '~' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
                [ class "key key--enter-top"
                , if isTutorActive then
                    if exerciseHasntStarted then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if exerciseHasntStarted then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "Enter" ]
            ]
        , div [ class "keyboard-row" ]
            [ div
                [ class "key key--caps-lock"
                , if isTutorActive then
                    style "background-color" keyFingerColors.pinky

                  else
                    empty
                ]
                [ text "Mayús" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ 'A', 'á', 'ä', 'Á', 'Ä' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Right [ 'A', 'á', 'ä', 'Á', 'Ä' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "A" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'S') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs (Left 'S') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "S" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'D') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs (Left 'D') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "D" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'F') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs (Left 'F') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ div
                    [ style "lineHeight" "0.3"
                    , style "paddingTop" "5px"
                    ]
                    [ text "F"
                    , br [] []
                    , text "_"
                    ]
                ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'G') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs (Left 'G') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "G" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'H') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs (Left 'H') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "H" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'J') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs (Left 'J') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ div
                    [ style "lineHeight" "0.3"
                    , style "paddingTop" "5px"
                    ]
                    [ text "J"
                    , br [] []
                    , text "_"
                    ]
                ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'K') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs (Left 'K') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "K" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'L') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs (Left 'L') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "L" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'Ñ') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Left 'Ñ') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "Ñ" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '{', '[', '^' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Right [ '{', '[', '^' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ div
                    [ class "custom-row-key"
                    ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '}', ']', '`' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Right [ '}', ']', '`' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ div
                    [ class "custom-row-key" ]
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
                    ]
                , if isTutorActive then
                    if exerciseHasntStarted then
                        classList
                            [ ( "key--enter-bottom--highlighted", exerciseHasntStarted )
                            , ( "key--highlighted", exerciseHasntStarted )
                            ]

                    else
                        class "key--enter-bottom--colored"

                  else if exerciseHasntStarted then
                    classList
                        [ ( "key--enter-bottom--highlighted", exerciseHasntStarted )
                        , ( "key--highlighted", exerciseHasntStarted )
                        ]

                  else
                    empty
                , if isTutorActive then
                    if exerciseHasntStarted then
                        empty

                    else
                        style "background-color" keyFingerColors.pinky

                  else
                    empty
                ]
                []
            ]
        , div [ class "keyboard-row" ]
            [ div
                --
                [ class "key key--lshift"
                , if isTutorActive then
                    if
                        currentCharIs (Right [ '°', '!', '"', '#', '$', '%', '&', '/', '(', ')', '=', '?', '¡', '¨', '*', '[', ']', '_', ':', ';', '>', 'ä', 'ë', 'ï', 'ö', 'ü' ])
                            || (case List.Extra.find (\l -> l == currentChar) [ 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ñ', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ä', 'Ë', 'Ï', 'Ö', 'Ü', 'Á', 'É', 'Í', 'Ó', 'Ú' ] of
                                    Just _ ->
                                        True

                                    Nothing ->
                                        False
                               )
                    then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if
                    currentCharIs (Right [ '°', '!', '"', '#', '$', '%', '&', '/', '(', ')', '=', '?', '¡', '¨', '*', '[', ']', '_', ':', ';', '>', 'ä', 'ë', 'ï', 'ö', 'ü' ])
                        || (case List.Extra.find (\l -> l == currentChar) [ 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ñ', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ä', 'Ë', 'Ï', 'Ö', 'Ü', 'Á', 'É', 'Í', 'Ó', 'Ú' ] of
                                Just _ ->
                                    True

                                Nothing ->
                                    False
                           )
                  then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "⇧" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '<', '>' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Right [ '<', '>' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'Z') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Left 'Z') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "Z" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'X') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs (Left 'X') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "X" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'C') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs (Left 'C') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "C" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'V') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs (Left 'V') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "V" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'B') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs (Left 'B') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "B" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'N') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs (Left 'N') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "N" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Left 'M') then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs (Left 'M') then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "M" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ ';', ',' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs (Right [ ';', ',' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ ':', '.' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs (Right [ ':', '.' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs (Right [ '_', '-' ]) then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs (Right [ '_', '-' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
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
            , div
                [ class "key key--rshift"
                , if isTutorActive then
                    style "background-color" keyFingerColors.pinky

                  else
                    empty
                ]
                [ text "⇧" ]
            ]
        , div [ class "keyboard-row" ]
            [ div [ class "key key--ctrl" ] [ text "Ctrl" ]
            , div [ class "key", style "width" "52px" ] [ text "" ]
            , div [ class "key key--lalt" ] [ text "Alt" ]
            , div
                [ class "key"
                , style "width" "159px"
                , if isTutorActive then
                    if currentChar == ' ' then
                        class "key--highlighted"

                    else
                        style "background-color" "#ffc0c0"

                  else if currentChar == ' ' then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "" ]
            , div
                [ class "key key--alt-grl"
                , if isTutorActive then
                    if currentCharIs (Right [ '¬', '\\', '~', '^', '`' ]) then
                        class "key--highlighted"

                    else
                        empty

                  else if currentCharIs (Right [ '¬', '\\', '~', '^', '`' ]) then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "AltGrl" ]
            , div [ class "key", style "width" "48px" ] [ text "" ]
            , div [ class "key", style "width" "48px" ] [ text "" ]
            , div [ class "key key--ctrl" ] [ text "Ctrl" ]
            ]
        ]
