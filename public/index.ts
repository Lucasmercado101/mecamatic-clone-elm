// @ts-ignore
import { Elm } from "../src/Main.elm";

const electron = window.require("electron");

const app = Elm.Main.init({
  node: document.getElementById("root")
});

// TODO
// app.ports.sendRequestUserData.subscribe(function (userName) {
//   electron.ipcRenderer.invoke("load-user-data", userName).then(
//     /**
//      * @param {import("./electron").defaultUserData | undefined} userData
//      */
//     (userData) => {
//       if (!userData) {
//         // TODO handle if undefined then something went wrong
//       } else {
//       }
//     }
//   );
// });

/**
 * * Request users profiles names.
 *
 * * If successful sends an array of strings
 * * Else sends undefined
 */
app.ports.sendRequestProfilesNames.subscribe(function () {
  electron.ipcRenderer
    .invoke("load-user-profiles-names")
    .then((userProfilesArr: string[] | undefined) => {
      app.ports.userProfilesReceiver.send(userProfilesArr);
    })
    .catch(() => app.ports.userProfilesReceiver.send(undefined));
});

// app.ports.sendNewSettings.subscribe(function (data) {
//   electron.ipcRenderer.send("new-global-settings-sent", data);
// });

// app.ports.sendCloseWindow.subscribe(function () {
//   electron.ipcRenderer.send("close-settings-window");
// });

// electron.ipcRenderer.on("settings-conf-json-sent", (_, data) => {
//   app.ports.settingsReceiver.send(data);
// });
