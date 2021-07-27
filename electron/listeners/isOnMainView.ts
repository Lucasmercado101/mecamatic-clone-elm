import { ipcMain, Menu } from "electron";
import { MenuItem } from "electron/main";

// * Changes main window menu options
ipcMain.on("is-on-main-view", async () => {
  const menu = Menu.buildFromTemplate([
    {
      label: "Aprendizaje",
      click() {
        console.log("a");
      }
    }
  ]);
  Menu.setApplicationMenu(menu);
});

// {
//   label: "Aprendizaje",
//   submenu: fs
//     .readdirSync(learningLessonsPath)
//     .sort((a, b) => +a.split("lesson")[1] - +b.split("lesson")[1])
//     .map((lessonsFolder) => {
//       const lessonNumber = +lessonsFolder.split("lesson")[1];
//       return {
//         label: "LECCION " + lessonNumber,
//         submenu: fs
//           .readdirSync(path.join(learningLessonsPath, lessonsFolder))
//           .sort((a, b) => +a.split(".json")[0] - +b.split(".json")[0])
//           .map((exercise) => {
//             const exerciseNumber = +exercise.split(".json")[0];
//             return {
//               label: "Ejercicio " + exerciseNumber,
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
//           })
//       };
//     })
// },
// {
//   label: "Practica",
//   submenu: fs
//     .readdirSync(practiceLessonsPath)
//     .sort((a, b) => +a.split("lesson")[1] - +b.split("lesson")[1])
//     .map((lessonsFolder) => {
//       const lessonNumber = +lessonsFolder.split("lesson")[1];
//       return {
//         label: "LECCION " + lessonNumber,
//         submenu: fs
//           .readdirSync(path.join(practiceLessonsPath, lessonsFolder))
//           .sort((a, b) => +a.split(".json")[0] - +b.split(".json")[0])
//           .map((exercise) => {
//             const exerciseNumber = +exercise.split(".json")[0];
//             return {
//               label: "Ejercicio " + exerciseNumber,
//               click() {
//                 fs.readFile(
//                   path.join(practiceLessonsPath, lessonsFolder, exercise),
//                   "utf8",
//                   (err, data) => {
//                     win.webContents.send("exercise", {
//                       category: "Practica",
//                       lesson: lessonNumber,
//                       exercise: exerciseNumber,
//                       ...JSON.parse(data)
//                     });
//                   }
//                 );
//               }
//             };
//           })
//       };
//     })
// },
// {
//   label: "Perfeccionamiento",
//   submenu: fs
//     .readdirSync(perfectionLessonsPath)
//     .sort((a, b) => +a.split("lesson")[1] - +b.split("lesson")[1])
//     .map((lessonsFolder) => {
//       const lessonNumber = +lessonsFolder.split("lesson")[1];
//       return {
//         label: "LECCION " + lessonNumber,
//         submenu: fs
//           .readdirSync(path.join(perfectionLessonsPath, lessonsFolder))
//           .sort((a, b) => +a.split(".json")[0] - +b.split(".json")[0])
//           .map((exercise) => {
//             const exerciseNumber = +exercise.split(".json")[0];
//             return {
//               label: "Ejercicio " + exerciseNumber,
//               click() {
//                 fs.readFile(
//                   path.join(perfectionLessonsPath, lessonsFolder, exercise),
//                   "utf8",
//                   (err, data) => {
//                     win.webContents.send("exercise", {
//                       category: "Perfeccionamiento",
//                       lesson: lessonNumber,
//                       exercise: exerciseNumber,
//                       ...JSON.parse(data)
//                     });
//                   }
//                 );
//               }
//             };
//           })
//       };
//     })
// },
// {
//   label: "Terminar sesión",
//   click() {
//     win.webContents.send("log-out");
//   }
// }
