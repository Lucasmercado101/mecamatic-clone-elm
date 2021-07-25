import * as fs from "fs";

export const dirOrFileExists = (path: string): Promise<boolean> =>
  new Promise((res) => fs.stat(path, (err) => (err ? res(false) : res(true))));

export const readFile = (
  path: string
): Promise<NodeJS.ErrnoException | string> =>
  new Promise((res, rej) =>
    fs.readFile(path, { encoding: "utf8" }, (err, data) => {
      if (err) rej(err);
      res(data);
    })
  );

export const readDir = (
  path: string
): Promise<NodeJS.ErrnoException | string[]> =>
  new Promise((res, rej) =>
    fs.readdir(path, (err, files) => {
      if (err) {
        rej(err);
      }
      res(files);
    })
  );

export const createFolder = (
  path: string
): Promise<NodeJS.ErrnoException | undefined> =>
  new Promise((res, rej) =>
    fs.mkdir(path, (err) => (err ? rej(err) : res(undefined)))
  );

export const createFile = (
  path: string,
  data: string
): Promise<NodeJS.ErrnoException | undefined> =>
  new Promise((res, rej) =>
    fs.writeFile(path, data, { encoding: "utf8" }, (err) =>
      err ? rej(err) : res(undefined)
    )
  );

export const createFolderIfNotExists = async (path: string) => {
  const exists = await dirOrFileExists(path);
  if (!exists) return createFolder(path);
};
