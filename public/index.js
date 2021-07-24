/* global Elm:false electron:false */

const electron = window.require("electron");

const app = Elm.Main.init({
  node: document.getElementById("root")
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
