const {
  app,
  BrowserWindow,
  Menu,
  ipcMain,
  dialog,
  globalShortcut
} = require("electron");
const { observable } = require("mobx");
const fs = require("fs");
const path = require("path");
const isDev = require("electron-is-dev");

const learningLessonsPath = path.join(
  isDev ? __dirname : path.dirname(__dirname),
  "..",
  "data",
  "lessons",
  "learning"
);

const practiceLessonsPath = path.join(
  isDev ? __dirname : path.dirname(__dirname),
  "..",
  "data",
  "lessons",
  "practice"
);
const perfectionLessonsPath = path.join(
  isDev ? __dirname : path.dirname(__dirname),
  "..",
  "data",
  "lessons",
  "perfecting"
);
const userProfilesPath = path.join(app.getPath("userData"), "profiles");

let currentUser = observable("");
let settingsWindow = observable();

ipcMain.handle("get-user-profiles", (e) => {
  if (fs.existsSync(userProfilesPath)) {
    const users = fs.readdirSync(userProfilesPath) || [];
    return users;
  } else {
    fs.mkdirSync(userProfilesPath);
    return [];
  }
});

ipcMain.handle("create-user-profile-and-load-said-user", (event, userName) => {
  const userProfileDir = path.join(userProfilesPath, userName);

  fs.mkdirSync(userProfileDir);

  const userSettings = {
    timeLimitInSeconds: 600
  };

  fs.writeFileSync(
    path.join(userProfileDir, "settings.json"),
    JSON.stringify(userSettings),
    "utf8"
  );

  return { userName, ...userSettings };
});

ipcMain.handle("load-user-profile", (event, userName) => {
  const userProfileDir = path.join(userProfilesPath, userName);

  const userSettings = fs.readFileSync(
    path.join(userProfileDir, "settings.json"),
    { encoding: "utf8" }
  );

  return { userName, ...JSON.parse(userSettings) };
});

ipcMain.handle(
  "send-selected-user-name-to-confirm-deletion",
  (event, userName) => {
    const userProfileDir = path.join(userProfilesPath, userName);
    if (fs.existsSync(userProfileDir) && userName.length > 0) {
      const selectedOption = dialog.showMessageBoxSync({
        type: "warning",
        buttons: ["Si", "No"],
        title: "Eliminar usuario",
        message: `¿Desea continuar?`,
        detail: `Esta acción es irreversible y eliminará los datos, la configuracion y los ejercicios que haya creado el usuario: ${userName}`,
        noLink: true
      });

      const YES = selectedOption === 0;
      if (YES) {
        fs.rmSync(userProfileDir, { recursive: true, force: true });
        return true;
      } else {
        return false;
      }
    } else {
      dialog.showErrorBox("Error", `El usuario ${userName} no existe.`);
    }
  }
);

ipcMain.on("is-on-main-view", () => {
  const win = BrowserWindow.getFocusedWindow();
  const menu = Menu.buildFromTemplate([
    {
      label: "Aprendizaje",
      submenu: fs
        .readdirSync(learningLessonsPath)
        .sort((a, b) => +a.split("lesson")[1] - +b.split("lesson")[1])
        .map((lessonsFolder) => {
          const lessonNumber = +lessonsFolder.split("lesson")[1];
          return {
            label: "LECCION " + lessonNumber,
            submenu: fs
              .readdirSync(path.join(learningLessonsPath, lessonsFolder))
              .sort((a, b) => +a.split(".json")[0] - +b.split(".json")[0])
              .map((exercise) => {
                const exerciseNumber = +exercise.split(".json")[0];
                return {
                  label: "Ejercicio " + exerciseNumber,
                  click() {
                    fs.readFile(
                      path.join(learningLessonsPath, lessonsFolder, exercise),
                      "utf8",
                      (err, data) => {
                        win.webContents.send("exercise", {
                          category: "Aprendizaje",
                          lesson: lessonNumber,
                          exercise: exerciseNumber,
                          ...JSON.parse(data)
                        });
                      }
                    );
                  }
                };
              })
          };
        })
    },
    {
      label: "Practica",
      submenu: fs
        .readdirSync(practiceLessonsPath)
        .sort((a, b) => +a.split("lesson")[1] - +b.split("lesson")[1])
        .map((lessonsFolder) => {
          const lessonNumber = +lessonsFolder.split("lesson")[1];
          return {
            label: "LECCION " + lessonNumber,
            submenu: fs
              .readdirSync(path.join(practiceLessonsPath, lessonsFolder))
              .sort((a, b) => +a.split(".json")[0] - +b.split(".json")[0])
              .map((exercise) => {
                const exerciseNumber = +exercise.split(".json")[0];
                return {
                  label: "Ejercicio " + exerciseNumber,
                  click() {
                    fs.readFile(
                      path.join(practiceLessonsPath, lessonsFolder, exercise),
                      "utf8",
                      (err, data) => {
                        win.webContents.send("exercise", {
                          category: "Practica",
                          lesson: lessonNumber,
                          exercise: exerciseNumber,
                          ...JSON.parse(data)
                        });
                      }
                    );
                  }
                };
              })
          };
        })
    },
    {
      label: "Perfeccionamiento",
      submenu: fs
        .readdirSync(perfectionLessonsPath)
        .sort((a, b) => +a.split("lesson")[1] - +b.split("lesson")[1])
        .map((lessonsFolder) => {
          const lessonNumber = +lessonsFolder.split("lesson")[1];
          return {
            label: "LECCION " + lessonNumber,
            submenu: fs
              .readdirSync(path.join(perfectionLessonsPath, lessonsFolder))
              .sort((a, b) => +a.split(".json")[0] - +b.split(".json")[0])
              .map((exercise) => {
                const exerciseNumber = +exercise.split(".json")[0];
                return {
                  label: "Ejercicio " + exerciseNumber,
                  click() {
                    fs.readFile(
                      path.join(perfectionLessonsPath, lessonsFolder, exercise),
                      "utf8",
                      (err, data) => {
                        win.webContents.send("exercise", {
                          category: "Perfeccionamiento",
                          lesson: lessonNumber,
                          exercise: exerciseNumber,
                          ...JSON.parse(data)
                        });
                      }
                    );
                  }
                };
              })
          };
        })
    },
    {
      label: "Terminar sesión",
      click() {
        win.webContents.send("log-out");
      }
    }
  ]);
  Menu.setApplicationMenu(menu);
});

ipcMain.on("open-global-settings-window", (e, userName) => {
  const win = new BrowserWindow({
    width: 655,
    height: 280,
    minWidth: 655,
    minHeight: 280,
    resizable: isDev ? true : false,
    fullscreen: false,
    skipTaskbar: true,
    title: "Opciones",
    modal: true,
    parent: BrowserWindow.getFocusedWindow(),
    autoHideMenuBar: true,
    webPreferences: {
      nodeIntegration: true,
      enableRemoteModule: true,
      contextIsolation: false
    }
  });

  win.setMenu(null);
  win.removeMenu();
  win.loadURL(`file://${__dirname}/settings/index.html`);

  if (isDev) win.webContents.openDevTools();

  currentUser = userName;
  settingsWindow = win;

  fs.readFile(
    path.resolve(userProfilesPath, userName, "settings.json"),
    { encoding: "utf8" },
    (err, data) => {
      win.webContents.on("did-finish-load", () => {
        win.webContents.send("settings-conf-json-sent", JSON.parse(data));
      });
    }
  );
});

ipcMain.on("new-global-settings-sent", (e, data) => {
  fs.writeFile(
    path.resolve(userProfilesPath, currentUser, "settings.json"),
    JSON.stringify(data),
    { encoding: "utf8" },
    () => {
      settingsWindow.close();
      const mainWindow = BrowserWindow.getFocusedWindow();
      mainWindow.send("reload-user-settings", {
        userName: currentUser,
        ...data
      });
    }
  );
});

ipcMain.on("close-settings-window", (e, data) => {
  BrowserWindow.getFocusedWindow().close();
});

function createWindow() {
  // Create the browser window.
  const win = new BrowserWindow({
    width: 800,
    height: 580,
    minWidth: 800,
    minHeight: 580,
    resizable: isDev ? true : false,
    title: "MecaMatic 3.0",
    webPreferences: {
      nodeIntegration: true,
      enableRemoteModule: true,
      contextIsolation: false
    }
  });
  win.loadURL(
    isDev
      ? "http://localhost:3000"
      : `file://${path.join(__dirname, "../build/index.html")}`
  );

  // win.loadURL("http://localhost:3000/");

  if (isDev) win.webContents.openDevTools();

  const menu = Menu.buildFromTemplate([
    {
      label: "Eliminar Usuario",
      click() {
        win.webContents.send("get-selected-user");
      }
    }
  ]);
  Menu.setApplicationMenu(menu);
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app
  .whenReady()
  .then(() => {
    if (isDev) {
      globalShortcut.register("CommandOrControl+Shift+C", () => {
        const win = BrowserWindow.getFocusedWindow();
        win.webContents.openDevTools();
      });
    }
  })
  .then(createWindow);

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("activate", () => {
  // On macOS it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.

  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
