import { DatabaseSync } from "node:sqlite";
import { resolve } from "node:path";
import { ROOT } from "../paths.js";

/**
 * Local SQLite store, so configuration is owned by the Setup screen rather than
 * by a dotfile. Uses node:sqlite (built into Node 22.5+/24) — no native module,
 * nothing to compile.
 *
 * The file lives next to the app and is gitignored. Credentials sit in it in
 * plain text, exactly as they would in a .env; it is a local dev tool, not a
 * secret store.
 */
export const DB_PATH = resolve(ROOT, "loadtest.db");

let db: DatabaseSync | null = null;

function open(): DatabaseSync {
  if (db) return db;
  db = new DatabaseSync(DB_PATH);
  db.exec("PRAGMA journal_mode = WAL");
  db.exec("PRAGMA foreign_keys = ON");
  db.exec(`
    CREATE TABLE IF NOT EXISTS settings (
      key        TEXT PRIMARY KEY,
      value      TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    );
  `);
  return db;
}

export function getSetting<T>(key: string): T | null {
  const row = open().prepare("SELECT value FROM settings WHERE key = ?").get(key) as { value?: string } | undefined;
  if (!row?.value) return null;
  try {
    return JSON.parse(row.value) as T;
  } catch {
    return null;
  }
}

export function putSetting(key: string, value: unknown): void {
  open()
    .prepare(
      `INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
    )
    .run(key, JSON.stringify(value), Date.now());
}

export function settingUpdatedAt(key: string): number | null {
  const row = open().prepare("SELECT updated_at FROM settings WHERE key = ?").get(key) as
    | { updated_at?: number }
    | undefined;
  return row?.updated_at ?? null;
}

export function closeDb(): void {
  db?.close();
  db = null;
}
