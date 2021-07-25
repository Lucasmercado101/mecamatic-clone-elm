const {
  app,
  BrowserWindow,
  Menu,
  globalShortcut,
  ipcMain,
  dialog
} = require("electron");
// const { observable } = require("mobx");
const {
  createFile,
  dirOrFileExists,
  readFile,
  createFolderIfNotExists,
  readDir,
  createFolder
} = require("./helpers.js");
const path = require("path");
const fs = require("fs");
const userProfilesPath = path.join(app.getPath("userData"), "profiles");
const isDev = require("electron-is-dev");

try {
  isDev && require("electron-reloader")(module);
} catch (_) {}

/**
 * @typedef defaultUserData
 * @property {600} timeLimitInSeconds
 */

/**
 * @type {defaultUserData}
 */
const defaultUserSettings = { timeLimitInSeconds: 600 };

/**
 * TODO another listener to load saved records / history
 * TODO also load custom user lessons in this listener
 *
 * * ---- Loads user profile data (settings) ----
 *
 * * Creates user profile folder if it does not exist
 * * Creates user's settings.json if it does not exist
 * * Loads user's settings.json or the default if it doesn't exist
 *
 * NOTE It's assumed in this listener that the user profiles folder exists.
 *      user profiles folder is created at:
 * LINK ./electron.js#load-user-profiles-names-listener
 */
ipcMain.handle(
  "load-user-data",
  /**
   * @param {string} userName
   * @returns {Promise<any | undefined>}
   */
  async (_, userName) => {
    const userFolderPath = path.join(userProfilesPath, userName);
    const userSettingsPath = path.join(
      userProfilesPath,
      userName,
      "settings.json"
    );

    try {
      await createFolderIfNotExists(userFolderPath);
    } catch (err) {
      dialog.showErrorBox("Error", err.message);
      return undefined;
    }

    const userSettingsExists = await dirOrFileExists(userSettingsPath);

    if (!userSettingsExists) {
      return createFile(userSettingsPath, JSON.stringify(defaultUserSettings))
        .then(() => {
          return defaultUserSettings;
        })
        .catch(
          /**
           * @param {NodeJS.ErrnoException} err
           */
          (err) => {
            dialog.showErrorBox("Error", err.message);
            return undefined;
          }
        );
    } else {
      return readFile(userSettingsPath).catch(
        /**
         * @param {NodeJS.ErrnoException} err
         */
        (err) => {
          dialog.showErrorBox("Error", err.message);
          return undefined;
        }
      );
    }
  }
);

/**
 * ANCHOR[id=load-user-profiles-names-listener]
 *
 * * ---- Return user profile names as a string array ----
 *
 * * if an error occurs at any moment, it shows an error dialog box
 * * and returns "undefined"
 *
 */
ipcMain.handle("load-user-profiles-names", async () => {
  const userProfilesFolderExists = await dirOrFileExists(userProfilesPath);

  if (userProfilesFolderExists)
    return await readDir(userProfilesPath).catch(
      /**
       * @param {NodeJS.ErrnoException} err
       */
      (err) => {
        dialog.showErrorBox("Error", err.message);
        return undefined;
      }
    );
  else
    return createFolder(userProfilesPath)
      .then(() => [])
      .catch(
        /**
         * @param {NodeJS.ErrnoException} err
         */
        (err) => {
          dialog.showErrorBox("Error", err.message);
          return undefined;
        }
      );
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
    "http://localhost:1234"
    // TODO production files}
    // `file://${path.join(__dirname, "./index.html")}`
  );
  // isDev
  //   ? "http://localhost:3000"
  //   : `file://${path.join(__dirname, "../build/index.html")}`

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
        win && win.webContents.openDevTools();
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
