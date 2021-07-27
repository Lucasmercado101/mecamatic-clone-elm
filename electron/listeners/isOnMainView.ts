import { ipcMain, Menu } from "electron";
import { MenuItem } from "electron/main";
import * as path from "path";
import { readDir } from "../helpers";
import { learningLessonsFolderPath } from "../paths";

// * Changes main window menu options
ipcMain.on("is-on-main-view", async () => {
  const learningSubmenus: Electron.MenuItemConstructorOptions[] = [];
  const learningLessonFolders = await readDir(learningLessonsFolderPath).then(
    (folders) =>
      folders.sort((a, b) => +a.split("lesson")[1] - +b.split("lesson")[1])
  );

  for (let i = 0; i < learningLessonFolders.length; i++) {
    const lessonFolder = learningLessonFolders[i];
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
          // TODO
        }
      });
    }

    learningSubmenus.push({
      label: `LECCION ${lessonFolder.split("lesson")[1]}`,
      submenu: lessonSubmenu
    });
    lessonSubmenu = [];
  }
  //               click() {
  //                 fs.readFile(
  //                   path.join(learningLessonsPath, lessonsFolder, exercise),
  //                   "utf8",
  //                   (err, data) => {
  //                     win.webContents.send("exercise", {
  //                       category: "Aprendizaje",
  //                       lesson: lessonNumber,
  //                       exercise: exerciseNumber,
  //                       ...JSON.parse(data)
  //                     });
  //                   }
  //                 );
  //               }
  //             };
  const menu = Menu.buildFromTemplate([
    { label: "a", submenu: learningSubmenus }
  ]);
  Menu.setApplicationMenu(menu);
});
