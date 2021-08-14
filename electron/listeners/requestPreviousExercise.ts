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
    label({ label: "Request previous exercise" }),
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
  "request-previous-exercise",
  async (_, data: preMadeLesson): Promise<LessonDataDTO | null> => {
    logger.info(`@Start\n${JSON.stringify(data, null, 2)}`);

    if (data.lessonType === "Aprendizaje") {
      logger.info("On learning");

      // if on the first lesson
      if (data.exerciseNumber === 1) {
        if (data.lessonNumber === 1) {
          logger.info("On first lesson, first exercise, returning null");
          return null;
        } else {
          logger.info(
            `Returning exercise 10, previous lesson ${data.lessonNumber - 1}`
          );
          return getLearningExerciseDataDTO({
            exercise: 10,
            lesson: data.lessonNumber - 1
          });
        }
      } else {
        logger.info(`Returning previous exercise: ${data.exerciseNumber - 1}`);
        return getLearningExerciseDataDTO({
          exercise: data.exerciseNumber - 1,
          lesson: data.lessonNumber
        });
      }
    }

    if (data.lessonType === "Practica") {
      logger.info("On Practice");

      // if on the first lesson
      if (data.exerciseNumber === 1) {
        if (data.lessonNumber === 1) {
          logger.info(`Returning exercise 10, lesson 10 of Learning`);
          return getLearningExerciseDataDTO({
            exercise: 10,
            lesson: 10
          });
        } else {
          logger.info(
            `Returning exercise 10, previous lesson ${data.lessonNumber - 1}`
          );
          return getPracticeExerciseDataDTO({
            exercise: 10,
            lesson: data.lessonNumber - 1
          });
        }
      } else {
        logger.info(`Returning previous exercise: ${data.exerciseNumber - 1}`);
        return getPracticeExerciseDataDTO({
          exercise: data.exerciseNumber - 1,
          lesson: data.lessonNumber
        });
      }
    }

    if (data.lessonType === "Perfeccionamiento") {
      logger.info("On Perfecting");

      // if on the first lesson
      if (data.exerciseNumber === 1) {
        if (data.lessonNumber === 1) {
          logger.info(`Returning exercise 10, lesson 10 of Practice`);
          return getPracticeExerciseDataDTO({
            exercise: 10,
            lesson: 10
          });
        } else {
          logger.info(
            `Returning exercise 10, previous lesson ${data.lessonNumber - 1}`
          );
          return getPerfectingExerciseDataDTO({
            exercise: 10,
            lesson: data.lessonNumber - 1
          });
        }
      } else {
        logger.info(`Returning previous exercise: ${data.exerciseNumber - 1}`);
        return getPerfectingExerciseDataDTO({
          exercise: data.exerciseNumber - 1,
          lesson: data.lessonNumber
        });
      }
    }

    logger.error("Reached end, passed all ifs");
    return null;
  }
);
