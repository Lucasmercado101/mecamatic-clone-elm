import { ipcMain, dialog } from "electron";
import { getUserProfileFolderPath } from "../paths";
import * as fs from "fs";

ipcMain.on("selected-user-name", async (_, userName: string) => {
  console.log(userName);
  const userProfileDir = getUserProfileFolderPath(userName);
  if (userName.length === 0)
    return dialog.showErrorBox("Error", "No hay ningún usuario seleccionado");

  const selectedOption = dialog.showMessageBoxSync({
    type: "warning",
    buttons: ["Si", "No"],
    title: "Eliminar usuario",
    message: `¿Desea continuar?`,
    detail: `Esta acción es irreversible y eliminará los datos, la configuracion y los ejercicios que haya creado el usuario: ${userName}`,
    noLink: true
  });

  const YES = selectedOption === 0;
  if (YES) fs.rmdir(userProfileDir, { recursive: true }, () => {});
});
