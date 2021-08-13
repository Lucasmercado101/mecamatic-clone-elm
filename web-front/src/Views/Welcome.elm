port module Views.Welcome exposing (Model, Msg(..), init, subscriptions, update, view)

import Html exposing (Html, button, datalist, div, form, input, option, text)
import Html.Attributes exposing (class, classList, disabled, id, list, value)
import Html.Events exposing (onInput, onSubmit)
import Json.Decode as JD
import Process
import Task



-- * PORTS


port sendOnWelcomeView : () -> Cmd msg


port sendRequestProfilesNames : () -> Cmd msg


port userSelectedRequestReceiver : (() -> msg) -> Sub msg



-- * PORT userDataReceiver = userData | undefined


port userDataReceiver : (JD.Value -> msg) -> Sub msg



-- * PORT userProfilesReceiver = string[] | undefined


port userProfilesReceiver : (JD.Value -> msg) -> Sub msg



-- * SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ userProfilesReceiver
            (JD.decodeValue
                userProfileNamesDecoder
                >> (\l ->
                        case l of
                            Ok val ->
                                ReceivedUserProfiles val

                            Err _ ->
                                -- NOTE if it fails then it doesn't re-request again or anything (todo?)
                                FailedToLoadUsers
                   )
            )
        , userDataReceiver
            (JD.decodeValue
                userDataDecoder
                >> (\l ->
                        case l of
                            Ok val ->
                                ReceivedUserData val

                            Err _ ->
                                FailedToLoadUserData
                   )
            )
        , userSelectedRequestReceiver (\_ -> ReceivedRequestToSendSelectedUserName)
        ]


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



-- * INIT


init : () -> ( Model, Cmd Msg )
init _ =
    ( { selectedUser = ""
      , userProfiles = IsLoading
      , requestedUserData = ErrorRequestingUserData
      }
    , Cmd.batch
        [ sendRequestProfilesNames ()
        , sendOnWelcomeView ()
        , Process.sleep 200
            |> Task.perform (\_ -> ShowIsLoadingText)
        ]
    )



-- * PORTS


port sendSelectedUser : String -> Cmd msg


port sendRequestUserData : String -> Cmd msg



-- * MODEL


type UserProfiles
    = IsLoading
    | IsLoadingSlowly
    | FailedToLoad
    | UsersLoaded (List String)


type RequestedUserData
    = NotRequested
    | Requested
    | ErrorRequestingUserData


type alias Model =
    { selectedUser : String
    , userProfiles : UserProfiles
    , requestedUserData : RequestedUserData
    }



--* UPDATE


type alias UserSettings =
    { timeLimitInSeconds : Int
    , errorsCoefficient : Maybe Float
    , isTutorGloballyActive : Maybe Bool
    , isKeyboardGloballyVisible : Maybe Bool
    , minimumWPM : Maybe Int
    }


type Msg
    = ConfirmedUserProfile
    | ReceivedUserProfiles (List String)
    | ChangeSelectedUser String
    | ShowIsLoadingText
    | FailedToLoadUsers
    | ReceivedUserData UserSettings
    | FailedToLoadUserData
    | ReceivedRequestToSendSelectedUserName


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceivedRequestToSendSelectedUserName ->
            ( model, sendSelectedUser model.selectedUser )

        ConfirmedUserProfile ->
            ( model, sendRequestUserData model.selectedUser )

        ChangeSelectedUser userName ->
            ( { model | selectedUser = userName }, Cmd.none )

        ReceivedUserProfiles profiles ->
            ( { model | userProfiles = UsersLoaded profiles }, Cmd.none )

        FailedToLoadUsers ->
            ( { model | userProfiles = FailedToLoad }, Cmd.none )

        ShowIsLoadingText ->
            case model.userProfiles of
                IsLoading ->
                    ( { model | userProfiles = IsLoadingSlowly }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        FailedToLoadUserData ->
            ( { model | requestedUserData = ErrorRequestingUserData }, Cmd.none )

        ReceivedUserData _ ->
            -- * Never reaches here, main.elm reaches it
            ( model, Cmd.none )



--* VIEW


view : Model -> Html Msg
view model =
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
