// @ts-ignore
import { Elm } from "../src/Main.elm";
import {
  DefaultUserSettings,
  LessonDataDTO,
  lessonType
} from "../../electron/data.models";

const electron = window.require("electron");

const app = Elm.Main.init({
  node: document.getElementById("root")
});

/**
 *
 */

electron.ipcRenderer.on("get-selected-user", () =>
  app.ports.userSelectedRequestReceiver.send(null)
);

app.ports.sendSelectedUser.subscribe((userName: string) =>
  electron.ipcRenderer.send("selected-user-name", userName)
);

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
app.ports.sendRequestUserData.subscribe(function (userName: string) {
  electron.ipcRenderer
    .invoke("load-user-data", userName)
    .then((userData: DefaultUserSettings) => {
      app.ports.userDataReceiver.send(userData);
    })
    .catch(() => {
      app.ports.userDataReceiver.send(undefined);
    });
});

// * Inform electron that it's on main view LINK electron/listeners/isOnMainView.ts
app.ports.sendOnMainView.subscribe(() => {
  electron.ipcRenderer.send("is-on-main-view");
});

// * Inform electron that it's on welcome view LINK electron/listeners/isOnMainView.ts
app.ports.sendOnWelcomeView.subscribe(() => {
  electron.ipcRenderer.send("is-on-welcome-view");
});

electron.ipcRenderer.on("exercise-picked-data", (_, data: LessonDataDTO) =>
  app.ports.receiveExerciseData.send(data)
);

electron.ipcRenderer.on("log-out", () => app.ports.receiveLogOut.send(null));

app.ports.sendScrollHighlightedKeyIntoView.subscribe(() => {
  document
    .getElementById("key-highlighted")!
    .scrollIntoView({ behavior: "smooth" });
});

export interface preMadeLesson {
  exerciseNumber: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10;
  lessonNumber: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10;
  lessonType: lessonType;
}

// TODO
// interface userLesson {
//   exerciseNumber: number;
//   lessonNumber: number;
// }
// export type currentExercise = preMadeLesson | userLesson

app.ports.sendRequestNextExercise.subscribe((data: preMadeLesson) => {
  electron.ipcRenderer
    .invoke("request-next-exercise", data)
    .then((data: LessonDataDTO) => {
      app.ports.receiveExerciseData.send(data);
    });
  // TODO: Handle error
  // .catch(() => {
  //   app.ports.receiveExerciseData.send(null);
  // });
});

app.ports.sendRequestPreviousExercise.subscribe((data: preMadeLesson) => {
  electron.ipcRenderer
    .invoke("request-previous-exercise", data)
    .then((data: LessonDataDTO) => {
      app.ports.receiveExerciseData.send(data);
    });
  // TODO: Handle error
  // .catch(() => {
  //   app.ports.receiveExerciseData.send(null);
  // });
});
