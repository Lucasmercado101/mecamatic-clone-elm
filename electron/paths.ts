import { app } from "electron";
import * as path from "path";
import * as isDev from "electron-is-dev";

export const lessonsFolderPath = isDev
  ? path.join(__dirname, "..", "data", "lessons")
  : // TODO
    // path.dirname(__dirname)
    "";

export const learningLessonsFolderPath = path.join(
  lessonsFolderPath,
  "learning"
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
