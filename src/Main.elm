module Main exposing (..)

import Browser
import Html exposing (Html, div, text)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


type Model
    = Noop



-- INIT


init : () -> ( Model, Cmd msg )
init flags =
    ( Noop, Cmd.none )



-- UPDATE


type Msg
    = Noope


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        Noope ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Html msg
view model =
    div [] [ text "a" ]


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
