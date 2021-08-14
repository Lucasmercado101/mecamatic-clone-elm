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
import * as winston from "winston";
const { createLogger, format, transports } = winston;
const { combine, label, printf, colorize } = format;

const myFormat = printf(({ level, message, label }) => {
  return `[${label}] ${level}: ${message}`;
});

const logger = createLogger({
  format: combine(
    label({ label: "Request next exercise" }),
    colorize(),
    myFormat
  ),
  transports: [new transports.Console()]
});

const getExerciseData = async ({
  exercise,
  folderPath,
  lesson
}: {
  folderPath: string;
  lesson: number;
  exercise: number;
}): Promise<LessonData> => {
  //* it always exists ergo this won't fail, or shouldn't at least
  const res = (await readFile(
    path.join(folderPath, `lesson ${lesson}`, exercise + ".json")
  )) as Ok<string, any>;
  return JSON.parse(res.value);
};

const getExerciseDataDTO = async ({
  category,
  exercise,
  folderPath,
  lesson
}: {
  folderPath: string;
  lesson: number;
  exercise: number;
  category: lessonType;
}) => {
  const { WPMNeededToPass, ...lessonData } = await getExerciseData({
    folderPath,
    lesson,
    exercise
  });

  return {
    exerciseCategory: category,
    lessonNumber: lesson,
    exerciseNumber: exercise,
    wordsPerMinuteNeededToPass: WPMNeededToPass,
    ...lessonData
  };
};

const getLearningExerciseDataDTO = async ({
  exercise,
  lesson
}: {
  lesson: number;
  exercise: number;
}) =>
  getExerciseDataDTO({
    lesson,
    exercise,
    category: "Aprendizaje",
    folderPath: learningLessonsFolderPath
  });

const getPracticeExerciseDataDTO = async ({
  exercise,
  lesson
}: {
  lesson: number;
  exercise: number;
}) =>
  getExerciseDataDTO({
    lesson,
    exercise,
    category: "Practica",
    folderPath: practiceLessonsFolderPath
  });

const getPerfectingExerciseDataDTO = async ({
  exercise,
  lesson
}: {
  lesson: number;
  exercise: number;
}) =>
  getExerciseDataDTO({
    lesson,
    exercise,
    category: "Perfeccionamiento",
    folderPath: perfectingLessonsFolderPath
  });

ipcMain.handle(
  "request-next-exercise",
  async (_, data: preMadeLesson): Promise<LessonDataDTO | null> => {
    logger.info(`@Start\n${JSON.stringify(data, null, 2)}`);

    if (data.lessonType === "Aprendizaje") {
      logger.info("On learning");
      // If currently on last exercise of current lesson
      if (data.exerciseNumber === 10) {
        // If there is a next lesson
        if (data.lessonNumber < 10) {
          // Get the first exercise of the next lesson
          logger.info(
            `Returning next lesson (${data.lessonNumber + 1}), first exercise`
          );
          return getLearningExerciseDataDTO({
            exercise: 1,
            lesson: data.lessonNumber + 1
          });
        } else {
          // Else If there is no next lesson
          // Get the first exercise of the first lesson of the next category type
          logger.info(
            `Returning exercise ${1}, lesson ${1}, category: Practice`
          );
          return getPracticeExerciseDataDTO({
            exercise: 1,
            lesson: 1
          });
        }
      } else {
        // Else: there is a next exercise
        logger.info(
          `Returning next exercise: exercise ${
            data.exerciseNumber + 1
          }, lesson ${data.lessonNumber}`
        );
        return getLearningExerciseDataDTO({
          exercise: data.exerciseNumber + 1,
          lesson: data.lessonNumber
        });
      }
    }

    if (data.lessonType === "Practica") {
      // If currently on last exercise of current lesson
      if (data.exerciseNumber === 10) {
        // If there is a next lesson
        if (data.lessonNumber < 10) {
          // Get the first exercise of the next lesson
          logger.info(
            `Returning next lesson (${data.lessonNumber + 1}), first exercise`
          );
          return getPracticeExerciseDataDTO({
            exercise: 1,
            lesson: data.lessonNumber + 1
          });
        } else {
          // Else If there is no next lesson
          // Get the first exercise of the first lesson of the next category type
          logger.info(
            `Returning exercise ${1}, lesson ${1}, category: Perfecting`
          );
          return getPerfectingExerciseDataDTO({
            exercise: 1,
            lesson: 1
          });
        }
      } else {
        // Else: there is a next exercise
        logger.info(
          `Returning next exercise: exercise ${
            data.exerciseNumber + 1
          }, lesson ${data.lessonNumber}`
        );
        return getPracticeExerciseDataDTO({
          exercise: data.exerciseNumber + 1,
          lesson: data.lessonNumber
        });
      }
    }

    if (data.lessonType === "Perfeccionamiento") {
      // If currently on last exercise of current lesson
      if (data.exerciseNumber === 10) {
        // If there is a next lesson
        if (data.lessonNumber < 10) {
          // Get the first exercise of the next lesson
          logger.info(
            `Returning next lesson (${data.lessonNumber + 1}), first exercise`
          );
          return getPerfectingExerciseDataDTO({
            exercise: 1,
            lesson: data.lessonNumber + 1
          });
        } else {
          // Else If there is no next lesson
          // TODO custom user lessons
          logger.info("Returning null");
          return null;
        }
      } else {
        // Else: there is a next exercise
        logger.info(
          `Returning next exercise: exercise ${
            data.exerciseNumber + 1
          }, lesson ${data.lessonNumber}`
        );
        return getPerfectingExerciseDataDTO({
          exercise: data.exerciseNumber + 1,
          lesson: data.lessonNumber
        });
      }
    }

    return null;
  }
);
