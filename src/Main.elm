port module Main exposing (..)

import Browser
import Html exposing (Html, button, datalist, div, form, input, option, text)
import Html.Attributes exposing (class, id, list, style, value)
import Html.Events exposing (onInput, onSubmit)
import Json.Decode as JD



-- PORTS
-- TODO handle when requesting returns undefined (error)


port sendRequestUserData : String -> Cmd msg



-- TODO handle when requesting returns undefined (error)


port sendRequestProfilesNames : () -> Cmd msg



-- TODO handle when requesting returns undefined (error)


port userProfilesReceiver : (JD.Value -> msg) -> Sub msg



-- port userProfilesReceiver : (Maybe (List String) -> msg) -> Sub msg
-- SUBSCRIPTIONS
-- subscriptions : Model -> Sub Msg
-- subscriptions _ =
--     userProfilesReceiver
--         (\l ->
--             case l of
--                 Just val ->
--                     ReceivedUserProfiles val
--                 Nothing ->
--                     -- TODO
--                     ReceivedUserProfiles [ "test" ]
--         )
-- * DECODERS


type alias UserSettings =
    { timeLimitInSeconds : Int
    }



-- userSettingsDecoder : JD.Decoder Int
-- userSettingsDecoder =
--     JD.field "data" JD.int


userProfileNamesDecoder : JD.Decoder (List String)
userProfileNamesDecoder =
    JD.list JD.string


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
                            -- TODO handle this error case
                            ReceivedUserProfiles [ "a" ]
               )
        )



-- INIT


init : () -> ( Model, Cmd msg )
init _ =
    ( { selectedUser = ""
      , userProfiles = IsLoading
      }
    , sendRequestProfilesNames ()
    )



-- MODEL


type UserProfiles
    = IsLoading
    | UsersLoaded (List String)


type alias Model =
    { selectedUser : String
    , userProfiles : UserProfiles
    }



-- UPDATE


type Msg
    = ConfirmedUserProfile
    | ReceivedUserProfiles (List String)
    | ChangeSelectedUser String


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        ConfirmedUserProfile ->
            ( model, sendRequestUserData model.selectedUser )

        ReceivedUserProfiles profiles ->
            ( { model | userProfiles = UsersLoaded profiles }, Cmd.none )

        ChangeSelectedUser userName ->
            ( { model | selectedUser = userName }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    form
        [ class "welcome-container", onSubmit ConfirmedUserProfile ]
        [ div
            [ class "input-container" ]
            [ input
                [ list "user-profiles"
                , onInput ChangeSelectedUser
                , value model.selectedUser
                ]
                []
            , datalist [ id "user-profiles" ]
                (case model.userProfiles of
                    IsLoading ->
                        []

                    UsersLoaded usersProfiles ->
                        List.map (\l -> option [ value l ] []) usersProfiles
                )
            , button []
                [ text "Aceptar" ]
            ]
        , div [] [ text (Debug.toString model) ]
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
