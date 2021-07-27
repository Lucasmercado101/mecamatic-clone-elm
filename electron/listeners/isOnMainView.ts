import { BrowserWindow, ipcMain, Menu } from "electron";
import * as path from "path";
import { LessonData, LessonDataDTO } from "../data.models";
import { readDir, readFile } from "../helpers";
import {
  learningLessonsFolderPath,
  lessonsFolderPath,
  perfectingLessonsFolderPath,
  practiceLessonsFolderPath
} from "../paths";

const getOptionMenuSubmenus = async (
  lessonsFolder: string,
  categoryNameFolder: string,
  category: LessonDataDTO["exerciseCategory"]
) => {
  const currentWindow = BrowserWindow.getFocusedWindow()!;
  const submenus: Electron.MenuItemConstructorOptions[] = [];
  const lessonFolders = await readDir(lessonsFolder).then((folders) =>
    folders.sort((a, b) => +a.split("lesson")[1] - +b.split("lesson")[1])
  );

  for (let i = 0; i < lessonFolders.length; i++) {
    const lessonFolder = lessonFolders[i];
    let lessonSubmenu: Electron.MenuItemConstructorOptions[] = [];
    const exerciseFiles = await readDir(
      path.join(learningLessonsFolderPath, lessonFolder)
    ).then((exercises) =>
      exercises.sort((a, b) => +a.split(".json")[0] - +b.split(".json")[0])
    );

    for (let j = 0; j < exerciseFiles.length; j++) {
      const exercise = exerciseFiles[j];
      lessonSubmenu.push({
        label: `EJERCICIO ${exercise.split(".json")[0]}`,
        click() {
          readFile(
            path.join(
              lessonsFolderPath,
              categoryNameFolder,
              lessonFolder,
              exercise
            )
          ).then((data) => {
            const { WPMNeededToPass, ...otherLessonData }: LessonData =
              JSON.parse(data);
            const lessonDataDTO: LessonDataDTO = {
              exerciseCategory: category,
              exerciseNumber: +exercise.split(".json")[0],
              lessonNumber: +lessonFolder.split("lesson")[1],
              wordsPerMinuteNeededToPass: WPMNeededToPass,
              ...otherLessonData
            };
            currentWindow.webContents.send(
              "exercise-picked-data",
              lessonDataDTO
            );
          });
        }
      });
    }

    submenus.push({
      label: `LECCION ${lessonFolder.split("lesson")[1]}`,
      submenu: lessonSubmenu
    });
    lessonSubmenu = [];
  }

  return submenus;
};

// * Changes main window menu options
ipcMain.on("is-on-main-view", async () => {
  const menu = Menu.buildFromTemplate([
    {
      label: "Aprendizaje",
      submenu: await getOptionMenuSubmenus(
        learningLessonsFolderPath,
        "learning",
        "Aprendizaje"
      )
    },
    {
      label: "Practica",
      submenu: await getOptionMenuSubmenus(
        practiceLessonsFolderPath,
        "practice",
        "Practica"
      )
    },
    {
      label: "Perfeccionamiento",
      submenu: await getOptionMenuSubmenus(
        perfectingLessonsFolderPath,
        "perfecting",
        "Perfeccionamiento"
      )
    }
  ]);
  Menu.setApplicationMenu(menu);
});
