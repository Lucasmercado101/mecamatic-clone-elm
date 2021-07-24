port module Main exposing (..)

import Browser
import Html exposing (Html, button, datalist, div, input, option, text)
import Html.Attributes exposing (class, id, list, style, value)
import Html.Events exposing (onInput)



-- PORTS


port sendRequestUserData : String -> Cmd msg


port sendRequestProfilesNames : () -> Cmd msg



-- TODO handle when requesting users returns an error


port userProfilesReceiver : (List String -> msg) -> Sub msg



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    userProfilesReceiver ReceivedUserProfiles



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
            ( model, Cmd.none )

        ReceivedUserProfiles profiles ->
            ( { model | userProfiles = UsersLoaded profiles }, Cmd.none )

        ChangeSelectedUser userName ->
            ( { model | selectedUser = userName }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div
        [ style "height" "100vh"
        , style "width" "100vw"
        , style "display" "grid"
        , style "place-items" "center"
        ]
        [ div
            [ style "display" "flex"
            , style "gap" "8px"
            ]
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
                [ text "Aceptar"
                ]
            ]
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
