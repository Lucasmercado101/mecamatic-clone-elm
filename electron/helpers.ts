import * as fs from "fs";
import { ResultAsync } from "neverthrow";

export const dirOrFileExists = (path: string): Promise<boolean> =>
  new Promise((res) => fs.stat(path, (err) => (err ? res(false) : res(true))));

export function readFile(
  path: string
): ResultAsync<string, NodeJS.ErrnoException | null> {
  return ResultAsync.fromPromise(
    new Promise((res, rej) =>
      fs.readFile(path, { encoding: "utf8" }, (err, data) => {
        if (err) rej(err);
        res(data);
      })
    ),
    (e) => e as NodeJS.ErrnoException | null
  );
}

export function readDir(
  path: string
): ResultAsync<string[], NodeJS.ErrnoException | null> {
  return ResultAsync.fromPromise(
    new Promise((res, rej) =>
      fs.readdir(path, (err, files) => {
        if (err) {
          rej(err);
        }
        res(files);
      })
    ),
    (e) => e as NodeJS.ErrnoException | null
  );
}

export function createFolder(
  path: string
): ResultAsync<undefined, NodeJS.ErrnoException | null> {
  return ResultAsync.fromPromise(
    new Promise((res, rej) =>
      fs.mkdir(path, (err) => (err ? rej(err) : res(undefined)))
    ),
    (e) => e as NodeJS.ErrnoException | null
  );
}

export function createTextFile(
  path: string,
  data: string
): ResultAsync<undefined, NodeJS.ErrnoException | null> {
  return ResultAsync.fromPromise(
    new Promise((res, rej) =>
      fs.writeFile(path, data, { encoding: "utf8" }, (err) =>
        err ? rej(err) : res(undefined)
      )
    ),
    (e) => e as NodeJS.ErrnoException | null
  );
}

export const createFolderIfNotExists = async (path: string) => {
  const exists = await dirOrFileExists(path);
  if (!exists) return createFolder(path);
};
