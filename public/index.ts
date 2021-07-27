// @ts-ignore
import { Elm } from "../src/Main.elm";
import { DefaultUserSettings } from "../electron/data.models";

const electron = window.require("electron");

const app = Elm.Main.init({
  node: document.getElementById("root")
});

/**
 * * Request users profiles names. LINK electron/electron.ts#load-user-profiles-names-listener
 *
 * * If successful sends an array of strings
 * * Else sends undefined
 */
app.ports.sendRequestProfilesNames.subscribe(function () {
  electron.ipcRenderer
    .invoke("load-user-profiles-names")
    .then((userProfilesArr: string[]) => {
      app.ports.userProfilesReceiver.send(userProfilesArr);
    })
    .catch(() => app.ports.userProfilesReceiver.send(undefined));
});

/**
 * * Request users' data. LINK electron/electron.ts#load-user-data
 */
app.ports.sendRequestUserData.subscribe(function (userName) {
  electron.ipcRenderer
    .invoke("load-user-data", userName)
    .then((userData: DefaultUserSettings) => {
      app.ports.userDataReceiver.send(userData);
    })
    .catch(() => {
      app.ports.userDataReceiver.send(undefined);
    });
});

// TODO handle "delete user" button
// electron.ipcRenderer.on("settings-conf-json-sent", (_, data) => {
//   app.ports.settingsReceiver.send(data);
// });
