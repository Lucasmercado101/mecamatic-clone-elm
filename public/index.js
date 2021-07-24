// @ts-ignore
import { Elm } from "../src/Main.elm";

const electron = window.require("electron");

const app = Elm.Main.init({
  node: document.getElementById("root")
});

app.ports.sendRequestUserData.subscribe(function (userName) {
  electron.ipcRenderer.invoke("load-user-data", userName).then(
    /**
     * @param {import("./electron").defaultUserData | undefined} userData
     */
    (userData) => {
      if (!userData) {
        // TODO handle if undefined then something went wrong
      } else {
      }
    }
  );
});

app.ports.sendRequestProfilesNames.subscribe(function () {
  electron.ipcRenderer.invoke("load-user-profiles-names").then(
    /**
     * @param {string[] | undefined} userProfilesArr
     */
    (userProfilesArr) => {
      if (!userProfilesArr) {
        // TODO handle if undefined then something went wrong
      } else app.ports.userProfilesReceiver.send(userProfilesArr);
    }
  );
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
