const { app, BrowserWindow, Menu, globalShortcut } = require("electron");
// const { observable } = require("mobx");
// const fs = require("fs");
// const path = require("path");
const isDev = require("electron-is-dev");
try {
  isDev && require("electron-reloader")(module);
} catch (_) {}

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
    "http://127.0.0.1:1234/public/index.html"
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
