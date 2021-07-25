"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const electron_1 = require("electron");
const path = require("path");
const helpers_1 = require("./helpers");
const isDev = require("electron-is-dev");
const userProfilesPath = path.join(electron_1.app.getPath("userData"), "profiles");
try {
    isDev && require("electron-reloader")(module);
}
catch (_) { }
const defaultUserSettings = { timeLimitInSeconds: 600 };
electron_1.ipcMain.handle("load-user-data", (_, userName) => __awaiter(void 0, void 0, void 0, function* () {
    const userFolderPath = path.join(userProfilesPath, userName);
    const userSettingsPath = path.join(userProfilesPath, userName, "settings.json");
    try {
        yield helpers_1.createFolderIfNotExists(userFolderPath);
    }
    catch (err) {
        electron_1.dialog.showErrorBox("Error", err.message);
        return undefined;
    }
    const userSettingsExists = yield helpers_1.dirOrFileExists(userSettingsPath);
    if (!userSettingsExists) {
        return helpers_1.createFile(userSettingsPath, JSON.stringify(defaultUserSettings))
            .then(() => {
            return defaultUserSettings;
        })
            .catch((err) => {
            electron_1.dialog.showErrorBox("Error", err.message);
            return undefined;
        });
    }
    else {
        return helpers_1.readFile(userSettingsPath).catch((err) => {
            electron_1.dialog.showErrorBox("Error", err.message);
            return undefined;
        });
    }
}));
electron_1.ipcMain.handle("load-user-profiles-names", () => __awaiter(void 0, void 0, void 0, function* () {
    const userProfilesFolderExists = yield helpers_1.dirOrFileExists(userProfilesPath);
    if (userProfilesFolderExists)
        return yield helpers_1.readDir(userProfilesPath).catch((err) => {
            electron_1.dialog.showErrorBox("Error", err.message);
            return undefined;
        });
    else
        return helpers_1.createFolder(userProfilesPath)
            .then(() => [])
            .catch((err) => {
            electron_1.dialog.showErrorBox("Error", err.message);
            return undefined;
        });
}));
function createWindow() {
    const win = new electron_1.BrowserWindow({
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
    win.loadURL("http://localhost:1234");
    if (isDev)
        win.webContents.openDevTools();
    const menu = electron_1.Menu.buildFromTemplate([
        {
            label: "Eliminar Usuario",
            click() {
                win.webContents.send("get-selected-user");
            }
        }
    ]);
    electron_1.Menu.setApplicationMenu(menu);
}
electron_1.app
    .whenReady()
    .then(() => {
    if (isDev) {
        electron_1.globalShortcut.register("CommandOrControl+Shift+C", () => {
            const win = electron_1.BrowserWindow.getFocusedWindow();
            win && win.webContents.openDevTools();
        });
    }
})
    .then(createWindow);
electron_1.app.on("window-all-closed", () => {
    if (process.platform !== "darwin") {
        electron_1.app.quit();
    }
});
electron_1.app.on("activate", () => {
    if (electron_1.BrowserWindow.getAllWindows().length === 0) {
        createWindow();
    }
});
