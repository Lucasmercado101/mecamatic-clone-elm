module Main exposing (..)

import Browser
import Html exposing (Html, text)
import Json.Decode as JD
import Windows.Main.Welcome as Welcome exposing (UserData(..))


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        WelcomeView welcomeModel ->
            Sub.map GotWelcomeMsg (Welcome.subscriptions welcomeModel)

        MainView ->
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



--* ANCHOR INIT
--* ANCHOR MODEL
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


type Model
    = WelcomeView Welcome.Model
    | MainView



-- | MainView
--* ANCHOR UPDATE


type Msg
    = GotWelcomeMsg Welcome.Msg


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
                                        ( MainView, cmd )

                                    _ ->
                                        ( WelcomeView m, cmd )
                           )

                _ ->
                    ( model, Cmd.none )



--* ANCHOR VIEW


view : Model -> Html Msg
view model =
    case model of
        WelcomeView welcomeModel ->
            Html.map GotWelcomeMsg (Welcome.view welcomeModel)

        MainView ->
            Html.div [] [ text "on main view" ]


main : Program () Model Msg
main =
    Browser.element
        { init = Welcome.init >> (\( model, cmd ) -> ( WelcomeView model, Cmd.map GotWelcomeMsg cmd ))
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
