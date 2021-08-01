import { app } from "electron";
import * as path from "path";
import * as isDev from "electron-is-dev";

export const lessonsFolderPath = path.join(__dirname, "..", "data", "lessons");

export const learningLessonsFolderPath = path.join(
  lessonsFolderPath,
  "learning"
);

export const perfectingLessonsFolderPath = path.join(
  lessonsFolderPath,
  "perfecting"
);

export const practiceLessonsFolderPath = path.join(
  lessonsFolderPath,
  "practice"
);

/**
 * * Structure:
 *  Profiles
 *    |- {userName}
 *         |- settings.json
 *         TODO
 * todo    |- Custom Lessons
 * todo        |- {lessonName}
 */

export const userProfilesFolderPath = path.join(
  app.getPath("userData"),
  "profiles"
);

export const getUserProfileFolderPath = (userName: string) =>
  path.join(userProfilesFolderPath, userName);

export const getUserSettingsFilePath = (userName: string) =>
  path.join(getUserProfileFolderPath(userName), "settings.json");
