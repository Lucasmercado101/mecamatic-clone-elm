const fs = require("fs");
// const { curry } = require("ramda");

/**
 * @param {string} path
 * @returns {Promise<boolean>}
 * does not reject to an error
 */
const dirOrFileExists = (path) =>
  new Promise((res) => fs.stat(path, (err) => (err ? res(false) : res(true))));

/**
 * @param {string} path
 * @returns {Promise<string>}
 * if error rejects to an {NodeJS.ErrnoException} error
 */
const readFile = (path) =>
  new Promise((res, rej) =>
    fs.readFile(path, { encoding: "utf8" }, (err, data) => {
      if (err) rej(err);
      res(data);
    })
  );

/**
 * @param {string} path
 * @returns {Promise<string[]>}
 * if error rejects to an {NodeJS.ErrnoException} error
 */
const readDir = (path) =>
  new Promise((res, rej) =>
    fs.readdir(path, (err, files) => {
      if (err) {
        rej(err);
      }
      res(files);
    })
  );

/**
 * @param {string} path
 * @returns {Promise<undefined>}}
 * if error rejects to an {NodeJS.ErrnoException} error
 *
 */
const createFolder = (path) =>
  new Promise((res, rej) =>
    fs.mkdir(path, (err) => (err ? rej(err) : res(undefined)))
  );

/**
 * @param {string} path
 * @param {string} data
 * @returns {Promise<undefined>}
 * if error rejects to an {NodeJS.ErrnoException} error
 */
const createFile = (path, data) =>
  new Promise((res, rej) =>
    fs.writeFile(path, data, { encoding: "utf8" }, (err) =>
      err ? rej(err) : res(undefined)
    )
  );

/**
 * @param {string} path
 * @returns {Promise<undefined>}
 */
const createFolderIfNotExists = async (path) => {
  const exists = await dirOrFileExists(path);
  if (!exists) {
    return createFolder(path);
  }
};

module.exports = {
  dirOrFileExists,
  readFile,
  createFolder,
  createFile,
  createFolderIfNotExists,
  readDir
};
