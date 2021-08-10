import * as path from "path";
import { ipcMain } from "electron";
import { preMadeLesson } from "../../web-front/public";
import {
  learningLessonsFolderPath,
  perfectingLessonsFolderPath,
  practiceLessonsFolderPath
} from "../paths";
import { readFile } from "../helpers";
import { Ok } from "neverthrow";
import { LessonData, LessonDataDTO, lessonType } from "../data.models";

const getExerciseData = async (
  folderPath: string,
  lesson: number,
  exercise: number
): Promise<LessonData> => {
  //* it always exists ergo this won't fail, or shouldn't at least
  const res = (await readFile(
    path.join(folderPath, `lesson ${lesson}`, exercise + ".json")
  )) as Ok<string, any>;
  return JSON.parse(res.value);
};

const getExerciseDataDTO = async (
  folderPath: string,
  lesson: number,
  exercise: number,
  category: lessonType
) => {
  const { WPMNeededToPass, ...lessonData } = await getExerciseData(
    folderPath,
    lesson,
    exercise
  );

  return {
    exerciseCategory: category,
    lessonNumber: lesson,
    exerciseNumber: exercise,
    wordsPerMinuteNeededToPass: WPMNeededToPass,
    ...lessonData
  };
};

//!FIXME very much hacked together

ipcMain.handle(
  "request-next-exercise",
  async (_, data: preMadeLesson): Promise<LessonDataDTO | null> => {
    let thereIsANextExercise;
    let thereIsANextLesson;
    switch (data.lessonType) {
      case "Aprendizaje":
        thereIsANextExercise = data.exerciseNumber !== 10;
        thereIsANextLesson = data.lessonNumber !== 10;
        if (thereIsANextExercise) {
          const newExerciseNumber = data.exerciseNumber + 1;

          return await getExerciseDataDTO(
            learningLessonsFolderPath,
            //@ts-ignore
            data.lessonNumber === 0 ? 1 : data.lessonNumber,
            newExerciseNumber,
            "Aprendizaje"
          );
        } else if (!thereIsANextExercise && thereIsANextLesson) {
          const newExerciseNumber = 1;
          const newLessonNumber = data.lessonNumber + 1;

          return await getExerciseDataDTO(
            learningLessonsFolderPath,
            newLessonNumber,
            newExerciseNumber,
            "Aprendizaje"
          );
        }
        // there's neither a next exercise nor a next lesson
        //@ts-ignore
        data.exerciseNumber = 0;
        //@ts-ignore
        data.lessonNumber = 0;
      case "Practica":
        thereIsANextExercise = data.exerciseNumber !== 10;
        thereIsANextLesson = data.lessonNumber !== 10;
        if (thereIsANextExercise) {
          const newExerciseNumber = data.exerciseNumber + 1;

          return await getExerciseDataDTO(
            practiceLessonsFolderPath,
            //@ts-ignore
            data.lessonNumber === 0 ? 1 : data.lessonNumber,
            newExerciseNumber,
            "Practica"
          );
        } else if (!thereIsANextExercise && thereIsANextLesson) {
          const newExerciseNumber = 1;
          const newLessonNumber = data.lessonNumber + 1;

          return await getExerciseDataDTO(
            practiceLessonsFolderPath,
            newLessonNumber,
            newExerciseNumber,
            "Practica"
          );
        }
        // there's neither a next exercise nor a next lesson
        //@ts-ignore
        data.exerciseNumber = 0;
        //@ts-ignore
        data.lessonNumber = 0;
      case "Perfeccionamiento":
        thereIsANextExercise = data.exerciseNumber !== 10;
        thereIsANextLesson = data.lessonNumber !== 10;
        if (thereIsANextExercise) {
          const newExerciseNumber = data.exerciseNumber + 1;

          return await getExerciseDataDTO(
            perfectingLessonsFolderPath,
            //@ts-ignore
            data.lessonNumber === 0 ? 1 : data.lessonNumber,
            newExerciseNumber,
            "Perfeccionamiento"
          );
        } else if (!thereIsANextExercise && thereIsANextLesson) {
          const newExerciseNumber = 1;
          const newLessonNumber = data.lessonNumber + 1;

          return await getExerciseDataDTO(
            perfectingLessonsFolderPath,
            newLessonNumber,
            newExerciseNumber,
            "Perfeccionamiento"
          );
        }
        // there's neither a next exercise nor a next lesson
        //@ts-ignore
        data.exerciseNumber = 0;
        //@ts-ignore
        data.lessonNumber = 0;

      // TODO custom user lessons
      default:
        return null;
    }
  }
);
