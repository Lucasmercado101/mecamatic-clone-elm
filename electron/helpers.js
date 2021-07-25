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
exports.createFolderIfNotExists = exports.createFile = exports.createFolder = exports.readDir = exports.readFile = exports.dirOrFileExists = void 0;
const fs = require("fs");
const dirOrFileExists = (path) => new Promise((res) => fs.stat(path, (err) => (err ? res(false) : res(true))));
exports.dirOrFileExists = dirOrFileExists;
const readFile = (path) => new Promise((res, rej) => fs.readFile(path, { encoding: "utf8" }, (err, data) => {
    if (err)
        rej(err);
    res(data);
}));
exports.readFile = readFile;
const readDir = (path) => new Promise((res, rej) => fs.readdir(path, (err, files) => {
    if (err) {
        rej(err);
    }
    res(files);
}));
exports.readDir = readDir;
const createFolder = (path) => new Promise((res, rej) => fs.mkdir(path, (err) => (err ? rej(err) : res(undefined))));
exports.createFolder = createFolder;
const createFile = (path, data) => new Promise((res, rej) => fs.writeFile(path, data, { encoding: "utf8" }, (err) => err ? rej(err) : res(undefined)));
exports.createFile = createFile;
const createFolderIfNotExists = (path) => __awaiter(void 0, void 0, void 0, function* () {
    const exists = yield exports.dirOrFileExists(path);
    if (!exists)
        return exports.createFolder(path);
});
exports.createFolderIfNotExists = createFolderIfNotExists;
