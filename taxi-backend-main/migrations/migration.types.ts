import { Db } from "mongodb";

export type Migration = {
  up: (db: Db) => Promise<void>;
  down?: (db: Db) => Promise<void>;
};
