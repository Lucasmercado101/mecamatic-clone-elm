import Electron from "electron";

declare global {
  interface Window {
    require(moduleSpecifier: "electron"): typeof Electron;
  }
}
