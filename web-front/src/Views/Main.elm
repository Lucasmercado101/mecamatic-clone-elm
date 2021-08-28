port module Views.Main exposing (Exercise(..), Model, Msg(..), sendOnMainView, subscriptions, update, view)

import Browser.Dom as Dom
import Char exposing (Char)
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
            ExerciseSelected _ state ->
                case state.status of
                    Ongoing ->
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


type ExerciseProgress
    = NotStarted
    | Ongoing
    | Paused
    | ExerciseFinishedSuccessfully
    | ExerciseFailed String


type alias HandTypingErrors =
    { leftPinky : Int
    , leftRing : Int
    , leftMiddle : Int
    , leftIndex : Int
    , thumbs : Int
    , rightPinky : Int
    , rightRing : Int
    , rightMiddle : Int
    , rightIndex : Int
    }


type alias ExerciseStatus =
    { status : ExerciseProgress
    , cursor : Int
    , errors : HandTypingErrors
    }


exerciseStatusNotStartedInit =
    { status = NotStarted
    , cursor = -1
    , errors =
        { leftPinky = 0
        , leftRing = 0
        , leftMiddle = 0
        , leftIndex = 0
        , thumbs = 0
        , rightPinky = 0
        , rightRing = 0
        , rightMiddle = 0
        , rightIndex = 0
        }
    }


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
    | FailedToLoadData
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
            ( { model
                | exercise =
                    ExerciseSelected exerciseData exerciseStatusNotStartedInit
                , elapsedSeconds = 0
              }
            , Cmd.none
            )

        FailedToLoadExerciseData ->
            -- TODO handle happens when an exercise is already selected and we try to load another one and fail
            case model.exercise of
                ExerciseSelected _ _ ->
                    ( model, Cmd.none )

                _ ->
                    ( { model | exercise = FailedToLoadData }, Cmd.none )

        -- TODO handle time has run out
        SecondHasElapsed ->
            let
                elapsedSeconds =
                    case model.exercise of
                        ExerciseSelected _ state ->
                            case state.status of
                                Ongoing ->
                                    model.elapsedSeconds + 1

                                _ ->
                                    model.elapsedSeconds

                        _ ->
                            model.elapsedSeconds
            in
            case model.exercise of
                ExerciseSelected data state ->
                    case state.status of
                        Ongoing ->
                            if elapsedSeconds == model.userData.userSettings.timeLimitInSeconds then
                                ( { model
                                    | elapsedSeconds = elapsedSeconds
                                    , exercise =
                                        ExerciseSelected data
                                            { state | status = ExerciseFailed "Ha superado el\nlimite de tiempo\nestablecido" }
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
                    ( { model | exercise = ExerciseSelected data exerciseStatusNotStartedInit, elapsedSeconds = 0 }
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
                        ExerciseSelected data state ->
                            case state.status of
                                Ongoing ->
                                    ExerciseSelected data { state | status = Paused }

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
                        ExerciseSelected data state ->
                            case state.status of
                                Paused ->
                                    ExerciseSelected data { state | status = Ongoing }

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

                FailedToLoadData ->
                    ( { model | exercise = exercise }, Cmd.none )

                ExerciseSelected exerciseData state ->
                    case event.key of
                        Just keyPressed ->
                            let
                                cursor =
                                    state.cursor

                                totalErrors =
                                    state.errors.leftPinky
                                        + state.errors.leftPinky
                                        + state.errors.leftRing
                                        + state.errors.leftMiddle
                                        + state.errors.leftIndex
                                        + state.errors.thumbs
                                        + state.errors.rightPinky
                                        + state.errors.rightRing
                                        + state.errors.rightMiddle
                                        + state.errors.rightIndex
                            in
                            case state.status of
                                NotStarted ->
                                    if keyPressed == "Enter" then
                                        ( { model
                                            | exercise =
                                                ExerciseSelected exerciseData
                                                    { state
                                                        | status = Ongoing
                                                        , cursor = 0
                                                        , errors = exerciseStatusNotStartedInit.errors
                                                    }
                                          }
                                        , Cmd.none
                                        )

                                    else
                                        ( { model | exercise = exercise }, Cmd.none )

                                Ongoing ->
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
                                                        round (calculatePercentageOfErrors totalErrors cursor)
                                                in
                                                if pctErrorsCommited > round (Maybe.withDefault userDefaults.errorsCoefficient model.userData.userSettings.errorsCoefficient) then
                                                    ( { model
                                                        | exercise =
                                                            ExerciseSelected exerciseData
                                                                { state | status = ExerciseFailed "Ha superado el % maximo de errores permitidos", cursor = cursor + 1 }
                                                      }
                                                    , Cmd.none
                                                    )

                                                else if calcNetWPM cursor model.elapsedSeconds totalErrors < userDefaults.minimumSpeed then
                                                    ( { model
                                                        | exercise =
                                                            ExerciseSelected exerciseData
                                                                { state | status = ExerciseFailed "No ha superado la velocidad minima", cursor = cursor + 1 }
                                                      }
                                                    , Cmd.none
                                                    )

                                                else
                                                    ( { model | exercise = ExerciseSelected exerciseData { state | status = ExerciseFinishedSuccessfully } }, Cmd.none )

                                            else if keyPressed == String.fromChar char then
                                                ( { model | exercise = ExerciseSelected exerciseData { state | status = Ongoing, cursor = cursor + 1 } }, sendScrollHighlightedKeyIntoView () )

                                            else if isModifierKey keyPressed then
                                                ( { model | exercise = ExerciseSelected exerciseData { state | status = Ongoing } }, Cmd.none )

                                            else
                                                ( { model
                                                    | exercise =
                                                        ExerciseSelected exerciseData
                                                            { state
                                                                | status = Ongoing
                                                                , errors =
                                                                    let
                                                                        errors =
                                                                            state.errors

                                                                        currentCharIn charsLists =
                                                                            case List.Extra.find (\l -> l == char) charsLists of
                                                                                Just _ ->
                                                                                    True

                                                                                Nothing ->
                                                                                    False

                                                                        bind fn bool =
                                                                            if bool == False then
                                                                                fn

                                                                            else
                                                                                True
                                                                    in
                                                                    { leftPinky =
                                                                        if
                                                                            -- currentCharIn aKeyChars
                                                                            currentCharIn degreeKeyChars
                                                                                |> bind (currentCharIn numberKey1Chars)
                                                                                |> bind (currentCharIn qKeyChars)
                                                                                |> bind (currentCharIn aKeyChars)
                                                                                |> bind (currentCharIn lgThenKeyChars)
                                                                                |> bind (currentCharIn zKeyChars)
                                                                        then
                                                                            errors.leftPinky + 1

                                                                        else
                                                                            errors.leftPinky
                                                                    , leftRing =
                                                                        if
                                                                            currentCharIn numberKey2Chars
                                                                                |> bind (currentCharIn wKeyChars)
                                                                                |> bind (currentCharIn sKeyChars)
                                                                                |> bind (currentCharIn xKeyChars)
                                                                        then
                                                                            errors.leftRing + 1

                                                                        else
                                                                            errors.leftRing
                                                                    , leftMiddle =
                                                                        if
                                                                            currentCharIn numberKey3Chars
                                                                                |> bind (currentCharIn eKeyChars)
                                                                                |> bind (currentCharIn dKeyChars)
                                                                                |> bind (currentCharIn cKeyChars)
                                                                        then
                                                                            errors.leftMiddle + 1

                                                                        else
                                                                            errors.leftMiddle
                                                                    , leftIndex =
                                                                        if
                                                                            currentCharIn numberKey4Chars
                                                                                |> bind (currentCharIn rKeyChars)
                                                                                |> bind (currentCharIn fKeyChars)
                                                                                |> bind (currentCharIn vKeyChars)
                                                                                |> bind (currentCharIn numberKey5Chars)
                                                                                |> bind (currentCharIn tKeyChars)
                                                                                |> bind (currentCharIn gKeyChars)
                                                                                |> bind (currentCharIn bKeyChars)
                                                                        then
                                                                            errors.leftIndex + 1

                                                                        else
                                                                            errors.leftIndex
                                                                    , rightIndex =
                                                                        if
                                                                            currentCharIn numberKey6Chars
                                                                                |> bind (currentCharIn yKeyChars)
                                                                                |> bind (currentCharIn hKeyChars)
                                                                                |> bind (currentCharIn nKeyChars)
                                                                                |> bind (currentCharIn numberKey7Chars)
                                                                                |> bind (currentCharIn uKeyChars)
                                                                                |> bind (currentCharIn jKeyChars)
                                                                                |> bind (currentCharIn mKeyChars)
                                                                        then
                                                                            errors.rightIndex + 1

                                                                        else
                                                                            errors.rightIndex
                                                                    , rightMiddle =
                                                                        if
                                                                            currentCharIn numberKey8Chars
                                                                                |> bind (currentCharIn iKeyChars)
                                                                                |> bind (currentCharIn kKeyChars)
                                                                                |> bind (currentCharIn semicolonKeyChars)
                                                                        then
                                                                            errors.rightMiddle + 1

                                                                        else
                                                                            errors.rightMiddle
                                                                    , rightRing =
                                                                        if
                                                                            currentCharIn numberKey9Chars
                                                                                |> bind (currentCharIn oKeyChars)
                                                                                |> bind (currentCharIn lKeyChars)
                                                                                |> bind (currentCharIn colonKeyChars)
                                                                        then
                                                                            errors.rightRing + 1

                                                                        else
                                                                            errors.rightRing
                                                                    , rightPinky =
                                                                        if
                                                                            currentCharIn numberKey0Chars
                                                                                |> bind (currentCharIn pKeyChars)
                                                                                |> bind (currentCharIn ñKeyChars)
                                                                                |> bind (currentCharIn underscoreKeyChars)
                                                                                |> bind (currentCharIn questionMarkKeyChars)
                                                                                |> bind (currentCharIn umlautKeyChars)
                                                                                |> bind (currentCharIn leftSquareBracketKeyChars)
                                                                                |> bind (currentCharIn startQuestionMarkKeyChars)
                                                                                |> bind (currentCharIn tildeKeyChars)
                                                                                |> bind (currentCharIn rightSquareBracketKeyChars)
                                                                        then
                                                                            errors.rightPinky + 1

                                                                        else
                                                                            errors.rightPinky
                                                                    , thumbs =
                                                                        if currentCharIn [ ' ' ] then
                                                                            errors.thumbs + 1

                                                                        else
                                                                            errors.thumbs
                                                                    }
                                                            }
                                                  }
                                                , Cmd.none
                                                )

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
            ExerciseSelected _ state ->
                case state.status of
                    NotStarted ->
                        on "keydown" <|
                            JD.map KeyPressed decodeKeyboardEvent

                    Ongoing ->
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
                        ExerciseSelected _ state ->
                            case state.status of
                                Ongoing ->
                                    onClick PauseTimer

                                Paused ->
                                    onClick ResumeTimer

                                _ ->
                                    onClick PauseTimer

                        _ ->
                            empty
                    ]
                    [ img [ src "./images/stop.png" ] []
                    , text
                        (case model.exercise of
                            ExerciseSelected _ state ->
                                case state.status of
                                    Ongoing ->
                                        "Pausa"

                                    Paused ->
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
            [ div []
                [ textBox model
                , div [ class "flex-col" ]
                    [ keyboard model
                    , case model.exercise of
                        ExerciseSelected _ state ->
                            fingerErrors state.errors

                        _ ->
                            fingerErrors exerciseStatusNotStartedInit.errors
                    ]
                ]
            , infoPanel model
            ]
        ]


fingerErrors : HandTypingErrors -> Html Msg
fingerErrors errors =
    div [ class "error-fingers-container", class "flex-row" ]
        [ div [ class "flex-col", style "text-align" "center" ]
            [ div [ class "error-finger-count-box" ] [ p [] [ text (String.fromInt errors.leftPinky) ] ]
            , p [ class "finger-errors-text" ] [ text "Meñique" ]
            ]
        , div [ class "flex-col", style "text-align" "center" ]
            [ div [ class "error-finger-count-box" ] [ p [] [ text (String.fromInt errors.leftRing) ] ]
            , p [ class "finger-errors-text" ] [ text "Anular" ]
            ]
        , div [ class "flex-col", style "text-align" "center" ]
            [ div [ class "error-finger-count-box" ] [ p [] [ text (String.fromInt errors.leftMiddle) ] ]
            , p [ class "finger-errors-text" ] [ text "Medio" ]
            ]
        , div [ class "flex-col", style "text-align" "center" ]
            [ div [ class "error-finger-count-box" ] [ p [] [ text (String.fromInt errors.leftIndex) ] ]
            , p [ class "finger-errors-text" ] [ text "Indice" ]
            ]
        , div [ class "flex-col", style "text-align" "center" ]
            [ div [ class "error-finger-count-box" ] [ p [] [ text (String.fromInt errors.thumbs) ] ]
            , p [ class "finger-errors-text" ] [ text "Pulgares" ]
            ]
        , div [ class "flex-col", style "text-align" "center" ]
            [ div [ class "error-finger-count-box" ] [ p [] [ text (String.fromInt errors.rightIndex) ] ]
            , p [ class "finger-errors-text" ] [ text "Indice" ]
            ]
        , div [ class "flex-col", style "text-align" "center" ]
            [ div [ class "error-finger-count-box" ] [ p [] [ text (String.fromInt errors.rightMiddle) ] ]
            , p [ class "finger-errors-text" ] [ text "Medio" ]
            ]
        , div [ class "flex-col", style "text-align" "center" ]
            [ div [ class "error-finger-count-box" ] [ p [] [ text (String.fromInt errors.rightRing) ] ]
            , p [ class "finger-errors-text" ] [ text "Anular" ]
            ]
        , div [ class "flex-col", style "text-align" "center" ]
            [ div [ class "error-finger-count-box" ] [ p [] [ text (String.fromInt errors.rightPinky) ] ]
            , p [ class "finger-errors-text" ] [ text "Meñique" ]
            ]
        ]


textBox : Model -> Html Msg
textBox model =
    div
        [ class "text-box-container", id "text-box-container-id" ]
        (case model.exercise of
            ExerciseNotSelected ->
                [ div [ class "text-box__welcome-text" ] [ text "Bienvenido a MecaMatic 3.0" ] ]

            ExerciseSelected data state ->
                [ div [ class "text-box-chars__container" ]
                    (List.indexedMap
                        (\i el ->
                            let
                                char =
                                    String.fromChar el

                                cursor =
                                    state.cursor
                            in
                            span
                                [ case state.status of
                                    Ongoing ->
                                        -- NOTE this is to make the cursor scroll into view using ports
                                        -- doesn't work with just i == cursor for some reason
                                        if i == cursor || i == cursor - 1 then
                                            id "key-highlighted"

                                        else
                                            empty

                                    Paused ->
                                        if i == cursor || i == cursor - 1 then
                                            id "key-highlighted"

                                        else
                                            empty

                                    ExerciseFailed _ ->
                                        if i == cursor || i == cursor - 1 then
                                            id "key-highlighted"

                                        else
                                            empty

                                    _ ->
                                        empty
                                , classList
                                    [ ( "text-box-chars__char", True )
                                    , ( "text-box-chars__char--highlighted"
                                      , case state.status of
                                            Ongoing ->
                                                i == cursor

                                            Paused ->
                                                i == cursor

                                            ExerciseFailed _ ->
                                                i == cursor

                                            _ ->
                                                False
                                      )
                                    , ( "text-box-chars__char--typed"
                                      , case state.status of
                                            NotStarted ->
                                                False

                                            Ongoing ->
                                                i < cursor

                                            Paused ->
                                                i < cursor

                                            ExerciseFailed _ ->
                                                i < cursor

                                            ExerciseFinishedSuccessfully ->
                                                True
                                      )
                                    ]
                                ]
                                [ text char ]
                        )
                        (String.toList data.text)
                    )
                ]

            FailedToLoadData ->
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



-- TODO add "title" property with descriptions to info boxes


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

                ExerciseSelected _ state ->
                    case state.status of
                        ExerciseFailed errorMessage ->
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
                                ExerciseSelected _ state ->
                                    let
                                        cursor =
                                            state.cursor

                                        errors =
                                            state.errors.leftPinky
                                                + state.errors.leftPinky
                                                + state.errors.leftRing
                                                + state.errors.leftMiddle
                                                + state.errors.leftIndex
                                                + state.errors.thumbs
                                                + state.errors.rightPinky
                                                + state.errors.rightRing
                                                + state.errors.rightMiddle
                                                + state.errors.rightIndex
                                    in
                                    case state.status of
                                        NotStarted ->
                                            text "0"

                                        Ongoing ->
                                            text (String.fromInt (totalGrossKeystrokesTyped cursor errors))

                                        Paused ->
                                            text (String.fromInt (totalGrossKeystrokesTyped cursor errors))

                                        ExerciseFinishedSuccessfully ->
                                            text (String.fromInt (totalGrossKeystrokesTyped cursor errors))

                                        ExerciseFailed _ ->
                                            text (String.fromInt (totalGrossKeystrokesTyped cursor errors))

                                _ ->
                                    text ""
                            ]
                        ]
                    , div [ class "info-panel-box-inner-boxes" ]
                        [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "P. Netas" ]
                        , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ]
                            [ case model.exercise of
                                ExerciseSelected _ state ->
                                    let
                                        cursor =
                                            state.cursor

                                        errors =
                                            state.errors.leftPinky
                                                + state.errors.leftPinky
                                                + state.errors.leftRing
                                                + state.errors.leftMiddle
                                                + state.errors.leftIndex
                                                + state.errors.thumbs
                                                + state.errors.rightPinky
                                                + state.errors.rightRing
                                                + state.errors.rightMiddle
                                                + state.errors.rightIndex
                                    in
                                    case state.status of
                                        NotStarted ->
                                            text "0"

                                        Ongoing ->
                                            text (String.fromInt (totalNetKeystrokesTyped cursor errors))

                                        Paused ->
                                            text (String.fromInt (totalNetKeystrokesTyped cursor errors))

                                        ExerciseFinishedSuccessfully ->
                                            text (String.fromInt (totalNetKeystrokesTyped cursor errors))

                                        ExerciseFailed _ ->
                                            text (String.fromInt (totalNetKeystrokesTyped cursor errors))

                                _ ->
                                    text ""
                            ]
                        ]
                    , div [ class "info-panel-box-inner-boxes" ]
                        [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "Errores" ]
                        , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ]
                            [ case model.exercise of
                                ExerciseSelected _ state ->
                                    let
                                        errors =
                                            state.errors.leftPinky
                                                + state.errors.leftPinky
                                                + state.errors.leftRing
                                                + state.errors.leftMiddle
                                                + state.errors.leftIndex
                                                + state.errors.thumbs
                                                + state.errors.rightPinky
                                                + state.errors.rightRing
                                                + state.errors.rightMiddle
                                                + state.errors.rightIndex
                                    in
                                    case state.status of
                                        NotStarted ->
                                            text "0"

                                        Ongoing ->
                                            text (String.fromInt errors)

                                        Paused ->
                                            text (String.fromInt errors)

                                        ExerciseFinishedSuccessfully ->
                                            text (String.fromInt errors)

                                        ExerciseFailed _ ->
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
                                ExerciseSelected _ state ->
                                    let
                                        cursor =
                                            state.cursor

                                        errors =
                                            state.errors.leftPinky
                                                + state.errors.leftPinky
                                                + state.errors.leftRing
                                                + state.errors.leftMiddle
                                                + state.errors.leftIndex
                                                + state.errors.thumbs
                                                + state.errors.rightPinky
                                                + state.errors.rightRing
                                                + state.errors.rightMiddle
                                                + state.errors.rightIndex

                                        errorPctText =
                                            if cursor == 0 && errors > 0 then
                                                "100.00"

                                            else
                                                getErrorPercentageString (calculatePercentageOfErrors errors cursor)
                                    in
                                    case state.status of
                                        NotStarted ->
                                            text "0"

                                        Ongoing ->
                                            text errorPctText

                                        Paused ->
                                            text errorPctText

                                        ExerciseFinishedSuccessfully ->
                                            text errorPctText

                                        ExerciseFailed _ ->
                                            text errorPctText

                                _ ->
                                    text ""
                            ]
                        ]
                    , div [ class "info-panel-box-inner-boxes" ]
                        [ div [ class "info-panel-box-inner-boxes__long-box info-panel-box-inner-boxes__box" ] [ text "P. p. m." ]
                        , div [ class "info-panel-box-inner-boxes__short-box info-panel-box-inner-boxes__box" ]
                            [ case model.exercise of
                                ExerciseSelected _ state ->
                                    let
                                        cursor =
                                            state.cursor

                                        errors =
                                            state.errors.leftPinky
                                                + state.errors.leftPinky
                                                + state.errors.leftRing
                                                + state.errors.leftMiddle
                                                + state.errors.leftIndex
                                                + state.errors.thumbs
                                                + state.errors.rightPinky
                                                + state.errors.rightRing
                                                + state.errors.rightMiddle
                                                + state.errors.rightIndex
                                    in
                                    if model.elapsedSeconds == 0 then
                                        text "0"

                                    else
                                        case state.status of
                                            NotStarted ->
                                                text "0"

                                            Ongoing ->
                                                text (String.fromInt (max 0 (calcNetWPM cursor model.elapsedSeconds errors)))

                                            Paused ->
                                                text (String.fromInt (max 0 (calcNetWPM cursor model.elapsedSeconds errors)))

                                            ExerciseFinishedSuccessfully ->
                                                text (String.fromInt (max 0 (calcNetWPM cursor model.elapsedSeconds errors)))

                                            ExerciseFailed _ ->
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



--* Keys highlight lists


degreeKeyChars : List Char
degreeKeyChars =
    [ '|', '°', '¬' ]


numberKey1Chars : List Char
numberKey1Chars =
    [ '1', '!' ]


numberKey2Chars : List Char
numberKey2Chars =
    [ '2', '"' ]


numberKey3Chars : List Char
numberKey3Chars =
    [ '3', '#' ]


numberKey4Chars : List Char
numberKey4Chars =
    [ '4', '$' ]


numberKey5Chars : List Char
numberKey5Chars =
    [ '5', '%' ]


numberKey6Chars : List Char
numberKey6Chars =
    [ '6', '&' ]


numberKey7Chars : List Char
numberKey7Chars =
    [ '7', '/' ]


numberKey8Chars : List Char
numberKey8Chars =
    [ '8', '(' ]


numberKey9Chars : List Char
numberKey9Chars =
    [ '9', ')' ]


numberKey0Chars : List Char
numberKey0Chars =
    [ '0', '=' ]


questionMarkKeyChars : List Char
questionMarkKeyChars =
    [ '?', '\'', '\\' ]


startQuestionMarkKeyChars : List Char
startQuestionMarkKeyChars =
    [ '¿', '¡' ]



--* Second keyboard row


qKeyChars : List Char
qKeyChars =
    [ 'q', 'Q', '@' ]


wKeyChars : List Char
wKeyChars =
    [ 'w', 'W' ]


eKeyChars : List Char
eKeyChars =
    [ 'e', 'E', 'é', 'É', 'ë', 'Ë' ]


rKeyChars : List Char
rKeyChars =
    [ 'r', 'R' ]


tKeyChars : List Char
tKeyChars =
    [ 't', 'T' ]


yKeyChars : List Char
yKeyChars =
    [ 'y', 'Y', 'ý', 'Ý', 'ÿ', 'Ÿ' ]


uKeyChars : List Char
uKeyChars =
    [ 'u', 'U', 'ú', 'Ú', 'ü', 'Ü' ]


iKeyChars : List Char
iKeyChars =
    [ 'i', 'I', 'í', 'Í', 'ï', 'Ï' ]


oKeyChars : List Char
oKeyChars =
    [ 'o', 'O', 'ó', 'Ó', 'ö', 'Ö' ]


pKeyChars : List Char
pKeyChars =
    [ 'p', 'P' ]


umlautKeyChars : List Char
umlautKeyChars =
    [ '´', '¨', 'á', 'é', 'í', 'ó', 'ú', 'ý', 'ä', 'ë', 'ï', 'ö', 'ü', 'ÿ', 'Á', 'É', 'Í', 'Ó', 'Ú', 'Ý', 'Ä', 'Ë', 'Ï', 'Ö', 'Ü', 'Ÿ' ]


tildeKeyChars : List Char
tildeKeyChars =
    [ '+', '*', '~' ]



--* Third keyboard row


aKeyChars : List Char
aKeyChars =
    [ 'a', 'A', 'á', 'Á', 'ä', 'Ä' ]


sKeyChars : List Char
sKeyChars =
    [ 's', 'S' ]


dKeyChars : List Char
dKeyChars =
    [ 'd', 'D' ]


fKeyChars : List Char
fKeyChars =
    [ 'f', 'F' ]


gKeyChars : List Char
gKeyChars =
    [ 'g', 'G' ]


hKeyChars : List Char
hKeyChars =
    [ 'h', 'H' ]


jKeyChars : List Char
jKeyChars =
    [ 'j', 'J' ]


kKeyChars : List Char
kKeyChars =
    [ 'k', 'K' ]


lKeyChars : List Char
lKeyChars =
    [ 'l', 'L' ]


ñKeyChars : List Char
ñKeyChars =
    [ 'ñ', 'Ñ' ]


leftSquareBracketKeyChars : List Char
leftSquareBracketKeyChars =
    [ '{', '[', '^' ]


rightSquareBracketKeyChars : List Char
rightSquareBracketKeyChars =
    [ '}', ']', '`' ]



--* Fourth keyboard row


lShiftKeyChars : List Char
lShiftKeyChars =
    [ '°', '!', '"', '#', '$', '%', '&', '/', '(', ')', '=', '?', '¡', '¨', '*', '[', ']', '_', ':', ';', '>', 'ä', 'ë', 'ï', 'ö', 'ü', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ñ', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ä', 'Ë', 'Ï', 'Ö', 'Ü', 'Á', 'É', 'Í', 'Ó', 'Ú' ]


lgThenKeyChars : List Char
lgThenKeyChars =
    [ '<', '>' ]


zKeyChars : List Char
zKeyChars =
    [ 'z', 'Z' ]


xKeyChars : List Char
xKeyChars =
    [ 'x', 'X' ]


cKeyChars : List Char
cKeyChars =
    [ 'c', 'C' ]


vKeyChars : List Char
vKeyChars =
    [ 'v', 'V' ]


bKeyChars : List Char
bKeyChars =
    [ 'b', 'B' ]


nKeyChars : List Char
nKeyChars =
    [ 'n', 'N' ]


mKeyChars : List Char
mKeyChars =
    [ 'm', 'M' ]


semicolonKeyChars : List Char
semicolonKeyChars =
    [ ';', ',' ]


colonKeyChars : List Char
colonKeyChars =
    [ ':', '.' ]


underscoreKeyChars : List Char
underscoreKeyChars =
    [ '_', '-' ]


altGrlChars : List Char
altGrlChars =
    [ '¬', '\\', '~', '^', '`' ]


keyboard : Model -> Html Msg
keyboard model =
    let
        exerciseHasntStarted =
            case model.exercise of
                ExerciseSelected _ state ->
                    if state.status == NotStarted then
                        True

                    else
                        False

                _ ->
                    False

        currentChar : Char
        currentChar =
            case model.exercise of
                ExerciseSelected data state ->
                    let
                        cursor =
                            state.cursor
                    in
                    case state.status of
                        Ongoing ->
                            String.toList data.text
                                |> List.indexedMap Tuple.pair
                                |> List.Extra.find (\( i, _ ) -> cursor == i)
                                |> Maybe.withDefault ( 0, '←' )
                                |> Tuple.second

                        Paused ->
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

        currentCharIs : List Char -> Bool
        currentCharIs chars =
            case List.Extra.find (\l -> l == currentChar) chars of
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
                    if currentCharIs degreeKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs degreeKeyChars then
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
                    if currentCharIs numberKey1Chars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs numberKey1Chars then
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
                    if currentCharIs numberKey2Chars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs numberKey2Chars then
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
                    if currentCharIs numberKey3Chars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs numberKey3Chars then
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
                    if currentCharIs numberKey4Chars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs numberKey4Chars then
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
                    if currentCharIs numberKey5Chars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs numberKey5Chars then
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
                    if currentCharIs numberKey6Chars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs numberKey6Chars then
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
                    if currentCharIs numberKey7Chars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs numberKey7Chars then
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
                    if currentCharIs numberKey8Chars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs numberKey8Chars then
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
                    if currentCharIs numberKey9Chars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs numberKey9Chars then
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
                    if currentCharIs numberKey0Chars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs numberKey0Chars then
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
                    if currentCharIs questionMarkKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs questionMarkKeyChars then
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
                    if currentCharIs startQuestionMarkKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs startQuestionMarkKeyChars then
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
                    if currentCharIs qKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs qKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "Q" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs wKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs wKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "W" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs eKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs eKeyChars then
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
                    if currentCharIs rKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs rKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "R" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs tKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs tKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "T" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs yKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs yKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "Y" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs uKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs uKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "U" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs iKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs iKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "I" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs oKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs oKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "O" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs pKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs pKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "P" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs umlautKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs umlautKeyChars then
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
                    if currentCharIs tildeKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs tildeKeyChars then
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
                    if currentCharIs aKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs aKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "A" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs sKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs sKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "S" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs dKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs dKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "D" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs fKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs fKeyChars then
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
                    if currentCharIs gKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs gKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "G" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs hKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs hKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "H" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs jKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs jKeyChars then
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
                    if currentCharIs kKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs kKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "K" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs lKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs lKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "L" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs ñKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs ñKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "Ñ" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs leftSquareBracketKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs leftSquareBracketKeyChars then
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
                    if currentCharIs rightSquareBracketKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs rightSquareBracketKeyChars then
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
                    if currentCharIs lShiftKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs lShiftKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "⇧" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs lgThenKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs lgThenKeyChars then
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
                    if currentCharIs zKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs zKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "Z" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs xKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs xKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "X" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs cKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs cKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "C" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs vKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs vKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "V" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs bKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexLeftHand

                  else if currentCharIs bKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "B" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs nKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs nKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "N" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs mKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.indexRightHand

                  else if currentCharIs mKeyChars then
                    class "key--highlighted"

                  else
                    empty
                ]
                [ text "M" ]
            , div
                [ class "key"
                , if isTutorActive then
                    if currentCharIs semicolonKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.middleFinger

                  else if currentCharIs semicolonKeyChars then
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
                    if currentCharIs colonKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.ringFinger

                  else if currentCharIs colonKeyChars then
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
                    if currentCharIs underscoreKeyChars then
                        class "key--highlighted"

                    else
                        style "background-color" keyFingerColors.pinky

                  else if currentCharIs underscoreKeyChars then
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
                    if currentCharIs altGrlChars then
                        class "key--highlighted"

                    else
                        empty

                  else if currentCharIs altGrlChars then
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
