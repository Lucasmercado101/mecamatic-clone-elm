port module Main exposing (..)

import Browser
import Html exposing (Html, button, datalist, div, form, input, option, text)
import Html.Attributes exposing (class, classList, disabled, id, list, value)
import Html.Events exposing (onInput, onSubmit)
import Json.Decode as JD
import Process
import Task



--* ANCHOR PORTS


port sendRequestUserData : String -> Cmd msg


port sendRequestProfilesNames : () -> Cmd msg



-- * PORT userDataReceiver = userData | undefined


port userDataReceiver : (JD.Value -> msg) -> Sub msg



-- * PORT userProfilesReceiver = string[] | undefined


port userProfilesReceiver : (JD.Value -> msg) -> Sub msg



-- * ANCHOR DECODERS


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



-- * ANCHOR SUBSCRIPTIONS


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



--* ANCHOR INIT


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



--* ANCHOR MODEL


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



--* ANCHOR UPDATE


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
                    ( MainView { userSettings = data, exercise = ExerciseNotSelected }, sendOnMainView () )

        ( GotMainViewMsg mainViewMsg, MainView mainViewModel ) ->
            mainViewUpdate mainViewMsg mainViewModel
                |> (\( mainModel, mainMsg ) -> ( MainView mainModel, Cmd.map GotMainViewMsg mainMsg ))

        _ ->
            ( model, Cmd.none )



--* ANCHOR VIEW


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
-- NOTE on entering the main view, we need to inform electron to show different menu messages


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
mainViewsubscriptions _ =
    receiveExerciseData
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



-- * MODEL


type ExerciseStatus
    = NotStarted
    | Ongoing
    | Paused
    | FinishedSuccessfully


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


type alias MainViewModel =
    { userSettings : UserSettings
    , exercise : Exercise
    }



-- * UPDATE


type MainViewMsg
    = ReceivedExerciseData ExerciseData
    | FailedToLoadExerciseData


mainViewUpdate : MainViewMsg -> MainViewModel -> ( MainViewModel, Cmd MainViewMsg )
mainViewUpdate msg model =
    case msg of
        ReceivedExerciseData exerciseData ->
            ( { model | exercise = ExerciseSelected exerciseData NotStarted }, Cmd.none )

        FailedToLoadExerciseData ->
            -- TODO handle happens when an exercise is already selected and we try to load another one and fail
            ( { model | exercise = FailedToLoadEData }, Cmd.none )



-- * VIEW


mainViewView : MainViewModel -> Html MainViewMsg
mainViewView model =
    div [ class "main-view" ] [ textBox model, text (Debug.toString model) ]


textBox : MainViewModel -> Html MainViewMsg
textBox model =
    div [ class "text-box-container" ]
        [ case model.exercise of
            ExerciseNotSelected ->
                div [ class "text-box__welcome-text" ] [ text "Bienvenido a MecaMatic 3.0" ]

            _ ->
                -- TODO
                div [] []
        ]



--            <div
--               ref={textContainerDiv}
--               style={{
--                 backgroundColor: "#008282",
--                 color: "white",
--                 overflow: "auto",
--                 height: 210,
--                 width: 570,
--                 border: "thin solid",
--                 borderStyle: "inset"
--               }}
--             >
--               {selectedLessonText ? (
--                 <div
--                   style={{
--                     fontSize: "1.3rem",
--                     padding: 4
--                   }}
--                 >
--                   {Array.from(selectedLessonText).map((letter, i) => (
--                     <span
--                       key={i}
--                       style={{
--                         color: exerciseCursorPosition > i ? "black" : "",
--                         backgroundColor:
--                           exerciseCursorPosition === i
--                             ? "#ff8a7e"
--                             : "transparent",
--                         whiteSpace: "break-spaces",
--                         fontFamily: `monospace`
--                       }}
--                       ref={exerciseCursorPosition === i ? myRef : null}
--                     >
--                       {letter}
--                     </span>
--                   ))}
--                 </div>
--               ) : (
--                 <div
--                   style={{
--                     fontSize: "1.5rem",
--                     width: "100%",
--                     height: "100%",
--                     display: "grid",
--                     placeItems: "center"
--                   }}
--                 >
--                   Bienvenido a MecaMatic 3.0
--                 </div>
--               )}
--             </div>
