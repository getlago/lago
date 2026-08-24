import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// Split out from config.ts so the SQLite store can import it without a cycle.
const here = dirname(fileURLToPath(import.meta.url));
export const ROOT = resolve(here, "..", "..");
export const RUNS_DIR = resolve(ROOT, "runs");
