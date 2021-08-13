module Main exposing (..)

import Browser
import Either exposing (Either(..))
import Html exposing (Html)
import Views.Main as MainView exposing (Exercise(..), Msg(..))
import Views.Welcome as Welcome exposing (Msg(..))


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        WelcomeView welcomeViewModel ->
            Sub.map GotWelcomeMsg (Welcome.subscriptions welcomeViewModel)

        MainView mainViewModel ->
            Sub.map GotMainViewMsg (MainView.subscriptions mainViewModel)


type Model
    = WelcomeView Welcome.Model
    | MainView MainView.Model


type Msg
    = GotWelcomeMsg Welcome.Msg
    | GotMainViewMsg MainView.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( GotWelcomeMsg welcomeMsg, WelcomeView welcomeModel ) ->
            case welcomeMsg of
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

                _ ->
                    Welcome.update welcomeMsg welcomeModel
                        |> (\( mod, mesg ) -> ( WelcomeView mod, Cmd.map GotWelcomeMsg mesg ))

        ( GotMainViewMsg mainViewMsg, MainView mainViewModel ) ->
            case mainViewMsg of
                LogOut ->
                    Welcome.init ()
                        |> (\( welcomeModel, welcomeMsg ) -> ( WelcomeView welcomeModel, Cmd.map GotWelcomeMsg welcomeMsg ))

                _ ->
                    MainView.update mainViewMsg mainViewModel
                        |> (\( mainModel, mainMsg ) -> ( MainView mainModel, Cmd.map GotMainViewMsg mainMsg ))

        _ ->
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    case model of
        WelcomeView welcomeModel ->
            Html.map GotWelcomeMsg (Welcome.view welcomeModel)

        MainView mainViewModel ->
            Html.map GotMainViewMsg (MainView.view mainViewModel)


init : () -> ( Model, Cmd Msg )
init _ =
    Welcome.init ()
        |> (\( welcomeModel, welcomeMsg ) -> ( WelcomeView welcomeModel, Cmd.map GotWelcomeMsg welcomeMsg ))


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
