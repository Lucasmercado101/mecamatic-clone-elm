import { BrowserWindow, ipcMain, Menu } from "electron";
ipcMain.on("is-on-welcome-view", async () => {
  const currentWindow = BrowserWindow.getFocusedWindow()!;
  const menu = Menu.buildFromTemplate([
    {
      label: "Eliminar Usuario",
      click() {
        currentWindow.webContents.send("get-selected-user");
      }
    }
  ]);
  Menu.setApplicationMenu(menu);
});
