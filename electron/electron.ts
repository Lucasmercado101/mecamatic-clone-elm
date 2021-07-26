import {
  app,
  BrowserWindow,
  Menu,
  globalShortcut,
  ipcMain,
  dialog
} from "electron";
import * as path from "path";
import {
  createFile,
  dirOrFileExists,
  readFile,
  createFolderIfNotExists,
  readDir,
  createFolder
} from "./helpers";
import * as isDev from "electron-is-dev";
import { DefaultUserSettings } from "./data.models";
import {
  getUserProfileFolderPath,
  getUserSettingsFilePath,
  userProfilesFolderPath
} from "./paths";

try {
  isDev && require("electron-reloader")(module);
} catch (_) {}

const defaultUserSettings: DefaultUserSettings = { timeLimitInSeconds: 600 };

/**
 * ANCHOR[id=load-user-data]
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
 * LINK ./electron.ts#load-user-profiles-names-listener
 *
 * NOTE This creates user settings file if it doesn't exist
 */
ipcMain.handle("load-user-data", async (_, userName: string) => {
  const userFolderPath = getUserProfileFolderPath(userName);
  const userSettingsPath = getUserSettingsFilePath(userName);

  try {
    await createFolderIfNotExists(userFolderPath);
  } catch (err: any) {
    dialog.showErrorBox("Error", (err as NodeJS.ErrnoException).message);
    throw new Error();
  }

  const userSettingsExists = await dirOrFileExists(userSettingsPath);

  if (!userSettingsExists) {
    return createFile(userSettingsPath, JSON.stringify(defaultUserSettings))
      .then(() => defaultUserSettings)
      .catch((err: NodeJS.ErrnoException) => {
        dialog.showErrorBox("Error", err.message);
        throw new Error();
      });
  } else {
    return readFile(userSettingsPath).catch((err: NodeJS.ErrnoException) => {
      dialog.showErrorBox("Error", err.message);
      throw new Error();
    });
  }
});

/**
 * ANCHOR[id=load-user-profiles-names-listener]
 *
 * * ---- Return user profile names as a string array ----
 *
 * * if an error occurs at any moment, it shows an error dialog box
 * * and returns "undefined"
 *
 * NOTE creates userProfilesFolder if it does not exist
 *
 */
ipcMain.handle("load-user-profiles-names", async () => {
  const userProfilesFolderExists = await dirOrFileExists(
    userProfilesFolderPath
  );

  if (userProfilesFolderExists)
    return await readDir(userProfilesFolderPath).catch(
      (err: NodeJS.ErrnoException) => {
        dialog.showErrorBox("Error", err.message);
        throw new Error();
      }
    );
  else
    return createFolder(userProfilesFolderPath)
      .then(() => [])
      .catch((err: NodeJS.ErrnoException) => {
        dialog.showErrorBox("Error", err.message);
        throw new Error();
      });
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
