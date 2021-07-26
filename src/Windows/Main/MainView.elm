module Windows.Main.MainView exposing (Exercise, Model, Msg, init, update, view)

import Html exposing (Html, div, text)
import Windows.Main.Welcome exposing (UserData(..), UserSettings)



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
--* ANCHOR MODEL


type ExerciseStatus
    = NotStarted
    | Ongoing
    | Paused


type Exercise
    = NoExerciseSelected
    | ExerciseSelected ExerciseStatus
    | ExerciseFinishedSuccessfully
    | ExerciseFinishedUnsuccessfully


type alias Model =
    { exercise : Exercise
    , userData : UserData
    }


init : UserSettings -> Model
init data =
    { exercise = NoExerciseSelected
    , userData = SuccessfullyGotUserData data
    }



--* ANCHOR UPDATE


type Msg
    = Noop


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    ( model, Cmd.none )



--* ANCHOR UPDATE


view : Model -> Html Msg
view model =
    div [] [ text "on main view", text (Debug.toString model) ]
