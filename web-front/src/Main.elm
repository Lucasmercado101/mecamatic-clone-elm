port module Main exposing (..)

import Browser
import Either exposing (Either(..))
import Html exposing (Html, button, datalist, div, form, input, option, text)
import Html.Attributes exposing (class, classList, disabled, id, list, value)
import Html.Events exposing (onInput, onSubmit)
import Json.Decode as JD
import Process
import Task
import Views.Main as MainView exposing (Exercise(..), Msg(..))



--* PORTS


port sendOnWelcomeView : () -> Cmd msg


port sendRequestUserData : String -> Cmd msg


port sendSelectedUser : String -> Cmd msg


port sendRequestProfilesNames : () -> Cmd msg



-- * PORT userDataReceiver = userData | undefined


port userDataReceiver : (JD.Value -> msg) -> Sub msg



-- * PORT userProfilesReceiver = string[] | undefined


port userProfilesReceiver : (JD.Value -> msg) -> Sub msg


port userSelectedRequestReceiver : (() -> msg) -> Sub msg



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
                , userSelectedRequestReceiver (\_ -> GotWelcomeMsg ReceivedRequestToSendSelectedUserName)
                ]

        MainView mainViewModel ->
            Sub.map GotMainViewMsg (MainView.subscriptions mainViewModel)



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
        , sendOnWelcomeView ()
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
    | MainView MainView.Model



--* UPDATE


type WelcomeMsg
    = ConfirmedUserProfile
    | ReceivedUserProfiles (List String)
    | ChangeSelectedUser String
    | ShowIsLoadingText
    | FailedToLoadUsers
    | ReceivedUserData UserSettings
    | FailedToLoadUserData
    | ReceivedRequestToSendSelectedUserName


type Msg
    = GotWelcomeMsg WelcomeMsg
    | GotMainViewMsg MainView.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( GotWelcomeMsg welcomeMsg, WelcomeView welcomeModel ) ->
            case welcomeMsg of
                ReceivedRequestToSendSelectedUserName ->
                    ( WelcomeView welcomeModel, sendSelectedUser welcomeModel.selectedUser )

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
                    , MainView.sendOnMainView ()
                    )

        ( GotMainViewMsg mainViewMsg, MainView mainViewModel ) ->
            case mainViewMsg of
                LogOut ->
                    init ()

                _ ->
                    MainView.update mainViewMsg mainViewModel
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
            Html.map GotMainViewMsg (MainView.view mainViewModel)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
