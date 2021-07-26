module Main exposing (..)

import Browser
import Html exposing (Html)
import Json.Decode as JD
import Windows.Main.MainView as Main
import Windows.Main.Welcome as Welcome exposing (UserData(..))


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        WelcomeView welcomeModel ->
            Sub.map GotWelcomeMsg (Welcome.subscriptions welcomeModel)

        MainView _ ->
            Sub.none



-- * ANCHOR DECODERS


type alias UserSettings =
    { timeLimitInSeconds : Int
    }



-- userSettingsDecoder : JD.Decoder Int
-- userSettingsDecoder =
--     JD.field "data" JD.int


userProfileNamesDecoder : JD.Decoder (List String)
userProfileNamesDecoder =
    JD.list JD.string



--* ANCHOR MODEL


type Model
    = WelcomeView Welcome.Model
    | MainView Main.Model



-- | MainView
--* ANCHOR UPDATE


type Msg
    = GotWelcomeMsg Welcome.Msg
    | GotMainMsg Main.Msg


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        GotWelcomeMsg welcomeMsg ->
            case model of
                WelcomeView welcomeModel ->
                    Welcome.update welcomeMsg welcomeModel
                        |> (\( m, cmd ) ->
                                case m.userData of
                                    SuccessfullyGotUserData userData ->
                                        ( MainView (Main.init userData), cmd )

                                    _ ->
                                        ( WelcomeView m, cmd )
                           )

                _ ->
                    ( model, Cmd.none )

        GotMainMsg _ ->
            ( model, Cmd.none )



-- Debug.todo
-- ( model, Cmd.none )
--* ANCHOR VIEW


view : Model -> Html Msg
view model =
    case model of
        WelcomeView welcomeModel ->
            Html.map GotWelcomeMsg (Welcome.view welcomeModel)

        MainView mainModel ->
            Html.map GotMainMsg (Main.view mainModel)


main : Program () Model Msg
main =
    Browser.element
        { init = Welcome.init >> (\( model, cmd ) -> ( WelcomeView model, Cmd.map GotWelcomeMsg cmd ))
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
