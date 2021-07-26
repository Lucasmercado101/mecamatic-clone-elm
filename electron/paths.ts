import { app } from "electron";
import * as path from "path";

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
