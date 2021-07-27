port module Main exposing (..)

import Browser
import Html exposing (Html, button, datalist, div, form, input, option, text)
import Html.Attributes exposing (class, classList, disabled, id, list, style, value)
import Html.Events exposing (onInput, onSubmit)
import Json.Decode as JD
import Process
import Task



--* ANCHOR PORTS


port sendRequestUserData : String -> Cmd msg


port sendRequestProfilesNames : () -> Cmd msg



-- TODO
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
subscriptions _ =
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


update : Msg -> Model -> ( Model, Cmd msg )
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
                    ( MainView { userSettings = data }, Cmd.none )

        ( GotWelcomeMsg welcomeMsg, MainView mainViewModel ) ->
            ( MainView mainViewModel, Cmd.none )



--* ANCHOR VIEW


welcomeView : WelcomeModel -> Html WelcomeMsg
welcomeView model =
    form
        [ class "welcome-container", onSubmit ConfirmedUserProfile ]
        [ div
            [ class "input-container" ]
            [ div [ classList [ ( "home-input", True ), ( "home-input--loading", model.userProfiles == IsLoadingSlowly ), ( "home-input--failed-load", model.userProfiles == FailedToLoad ) ] ]
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
            mainViewView mainViewModel


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- TODO on welcome view
-- type alias Data = {
--     text: String
-- }
-- type ExerciseData
--     = NotSelected
--     | Selected (Data)
-- type ExerciseProgress
--     = NotStarted
--     | Started
--     | Paused
--     | FinishedSuccessfully
--     | FinishedUnsuccessfully
-- type Timer
--     = Started
--     | NotStarted
--     | Paused
-- TODO
-- type MainType
--     = MainApp MainView
--     | SettingsWindow
-- type MainView
--     = WelcomeView
--     | MainView
--  MAIN VIEW
-- * MODEL


type alias MainViewModel =
    { userSettings : UserSettings
    }



-- * VIEW


mainViewView : MainViewModel -> Html msg
mainViewView model =
    div [ class "main-container" ] [ text (Debug.toString model) ]
