port module Windows.Main.Welcome exposing (Model, Msg, init, initial, sendRequestProfilesNames, subscriptions, update, view)

import Html exposing (Html, button, datalist, div, form, input, option, text)
import Html.Attributes exposing (class, classList, id, list, value)
import Html.Events exposing (onInput, onSubmit)
import Json.Decode as JD
import Process
import Task


initial : Model
initial =
    { selectedUser = ""
    , userProfiles = IsLoading
    }



--* ANCHOR PORTS
-- TODO add this and
-- TODO handle when requesting returns undefined (error)
-- port sendRequestUserData : String -> Cmd msg
-- TODO handle when requesting returns undefined (error)


port sendRequestProfilesNames : () -> Cmd msg



-- * port userProfilesReceiver = string[] | undefined


port userProfilesReceiver : (JD.Value -> msg) -> Sub msg



-- * ANCHOR DECODERS


userProfileNamesDecoder : JD.Decoder (List String)
userProfileNamesDecoder =
    JD.list JD.string



-- * ANCHOR SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    userProfilesReceiver
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



--* ANCHOR INIT


init : () -> ( Model, Cmd Msg )
init _ =
    ( { selectedUser = ""
      , userProfiles = IsLoading
      }
    , Cmd.batch
        [ sendRequestProfilesNames ()
        , Process.sleep 200
            |> Task.perform (\_ -> ShowIsLoadingText)
        ]
    )



--* ANCHOR MODEL


type UserProfiles
    = IsLoading
    | IsLoadingSlowly
    | FailedToLoad
    | UsersLoaded (List String)


type alias Model =
    { selectedUser : String
    , userProfiles : UserProfiles
    }



--* ANCHOR UPDATE


type Msg
    = ConfirmedUserProfile
    | ReceivedUserProfiles (List String)
    | ChangeSelectedUser String
    | ShowIsLoadingText
    | FailedToLoadUsers


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        ConfirmedUserProfile ->
            Debug.todo "Request user data and load main view"

        -- ( model, sendRequestUserData model.selectedUser )
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



--* ANCHOR VIEW


view : Model -> Html Msg
view model =
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
            , button []
                [ text "Aceptar" ]
            ]
        ]
