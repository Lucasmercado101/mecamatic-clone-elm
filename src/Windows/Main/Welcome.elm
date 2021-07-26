port module Windows.Main.Welcome exposing (Model, Msg, UserData(..), init, sendRequestProfilesNames, subscriptions, update, view)

import Html exposing (Html, button, datalist, div, form, input, option, text)
import Html.Attributes exposing (class, classList, disabled, id, list, value)
import Html.Events exposing (onInput, onSubmit)
import Json.Decode as JD
import Process
import Task



--* ANCHOR PORTS


port sendRequestUserData : String -> Cmd msg


port sendRequestProfilesNames : () -> Cmd msg



-- * port userProfilesReceiver = string[] | undefined


port userProfilesReceiver : (JD.Value -> msg) -> Sub msg



-- * port userData = UserData | undefined


port userDataReceiver : (JD.Value -> msg) -> Sub msg



-- * ANCHOR DECODERS


userProfileNamesDecoder : JD.Decoder (List String)
userProfileNamesDecoder =
    JD.list JD.string


type alias UserSettings =
    { errorsCoefficient : Maybe Float
    , timeLimitInSeconds : Int
    , isTutorGloballyActive : Maybe Bool
    , isKeyboardGloballyVisible : Maybe Bool
    , minimumWPM : Maybe Int
    }


userDataDecoder : JD.Decoder UserSettings
userDataDecoder =
    JD.map5 UserSettings
        (JD.maybe (JD.field "errorsCoefficient" JD.float))
        (JD.field "timeLimitInSeconds" JD.int)
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
        ]



--* ANCHOR INIT


init : () -> ( Model, Cmd Msg )
init _ =
    ( { selectedUser = ""
      , userProfiles = IsLoading
      , userData = NotRequestedUserData
      }
    , Cmd.batch
        [ sendRequestProfilesNames ()
        , Process.sleep 200
            |> Task.perform (\_ -> ShowIsLoadingText)
        ]
    )



--* ANCHOR MODEL


type UserData
    = NotRequestedUserData
    | RequestedUserData
    | ErrorRequestingUserData
    | SuccessfullyGotUserData UserSettings


type UserProfiles
    = IsLoading
    | IsLoadingSlowly
    | FailedToLoad
    | UsersLoaded (List String)


type alias Model =
    { selectedUser : String
    , userProfiles : UserProfiles
    , userData : UserData
    }



--* ANCHOR UPDATE


type Msg
    = ConfirmedUserProfile
    | ReceivedUserProfiles (List String)
    | ChangeSelectedUser String
    | ShowIsLoadingText
    | FailedToLoadUsers
    | ReceivedUserData UserSettings
    | FailedToLoadUserData


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        ConfirmedUserProfile ->
            if model.selectedUser == "" then
                ( model, Cmd.none )

            else
                ( { model | userData = RequestedUserData }, sendRequestUserData model.selectedUser )

        ReceivedUserProfiles profiles ->
            ( { model | userProfiles = UsersLoaded profiles }, Cmd.none )

        ChangeSelectedUser userName ->
            ( { model | selectedUser = userName }, Cmd.none )

        ShowIsLoadingText ->
            case model.userProfiles of
                IsLoading ->
                    ( { model | userProfiles = IsLoadingSlowly }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        FailedToLoadUsers ->
            ( { model | userProfiles = FailedToLoad }, Cmd.none )

        ReceivedUserData data ->
            ( { model | userData = SuccessfullyGotUserData data }, Cmd.none )

        FailedToLoadUserData ->
            ( { model | userData = ErrorRequestingUserData }, Cmd.none )



--* ANCHOR VIEW


view : Model -> Html Msg
view model =
    form
        [ class "welcome-container", onSubmit ConfirmedUserProfile ]
        [ div
            [ class "input-container" ]
            [ div
                [ classList
                    [ ( "home-input", True )
                    , ( "home-input--loading", model.userProfiles == IsLoadingSlowly )
                    , ( "home-input--failed-load", model.userProfiles == FailedToLoad )

                    -- TODO error message if failed to load userData
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
