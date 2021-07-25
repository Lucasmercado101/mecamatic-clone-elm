import * as fs from "fs";

export const dirOrFileExists = (path: string): Promise<boolean> =>
  new Promise((res) => fs.stat(path, (err) => (err ? res(false) : res(true))));

/**
 * if error rejects to an {NodeJS.ErrnoException} error
 */
export const readFile = (path: string): Promise<string> =>
  new Promise((res, rej) =>
    fs.readFile(path, { encoding: "utf8" }, (err, data) => {
      if (err) rej(err);
      res(data);
    })
  );

/**
 * if error rejects to an {NodeJS.ErrnoException} error
 */
export const readDir = (path: string): Promise<string[]> =>
  new Promise((res, rej) =>
    fs.readdir(path, (err, files) => {
      if (err) {
        rej(err);
      }
      res(files);
    })
  );

/**
 * if error rejects to an {NodeJS.ErrnoException} error
 */
export const createFolder = (path: string): Promise<undefined> =>
  new Promise((res, rej) =>
    fs.mkdir(path, (err) => (err ? rej(err) : res(undefined)))
  );

/**
 * if error rejects to an {NodeJS.ErrnoException} error
 */
export const createFile = (path: string, data: string): Promise<undefined> =>
  new Promise((res, rej) =>
    fs.writeFile(path, data, { encoding: "utf8" }, (err) =>
      err ? rej(err) : res(undefined)
    )
  );

/**
 * if error rejects to an {NodeJS.ErrnoException} error
 */
export const createFolderIfNotExists = async (path: string) => {
  const exists = await dirOrFileExists(path);
  if (!exists) return createFolder(path);
};
