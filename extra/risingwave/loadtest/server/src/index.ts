import { existsSync } from "node:fs";
import { resolve } from "node:path";
import Fastify from "fastify";
import fastifyStatic from "@fastify/static";
import { ROOT, getConfig, storeInfo } from "./config.js";
import { registerRoutes } from "./routes.js";

const port = Number(process.env.PORT ?? 5180);

const app = Fastify({
  logger: { level: process.env.LOG_LEVEL ?? "info", transport: undefined },
  // A run posts thousands of ids in a stop/start payload at most; keep it small.
  bodyLimit: 2_000_000,
});

/*
 * Several endpoints are bodyless POSTs (/api/discover, /api/runs/current/stop).
 * Fastify's default JSON parser rejects an empty body when the request declares
 * Content-Type: application/json — which browsers and most HTTP clients do by
 * default. Treat an empty JSON body as {} rather than making every caller
 * remember to omit the header.
 */
app.addContentTypeParser("application/json", { parseAs: "string" }, (_req, body, done) => {
  const text = typeof body === "string" ? body.trim() : "";
  if (!text) return done(null, {});
  try {
    done(null, JSON.parse(text));
  } catch (e) {
    done(Object.assign(e as Error, { statusCode: 400 }), undefined);
  }
});

await registerRoutes(app);

// In dev, Vite serves the UI on 5181 and proxies /api here. In production
// (`npm run build && npm start`) the built assets are served from this process.
const webDist = resolve(ROOT, "web/dist");
if (existsSync(webDist)) {
  await app.register(fastifyStatic, { root: webDist });
  app.setNotFoundHandler((req, reply) => {
    if (req.url.startsWith("/api")) return reply.code(404).send({ error: "not found" });
    return reply.sendFile("index.html");
  });
}

const cfg = getConfig();
const store = storeInfo();
app.log.info({ dbPath: store.dbPath, savedAt: store.savedAt, configured: store.configured }, "settings store");
if (store.importedFrom)
  app.log.warn(
    `imported settings from ${store.importedFrom} into SQLite and renamed it to ${store.importedFrom}.imported — ` +
      "the Setup screen owns configuration from now on",
  );
app.log.info(
  { lago: cfg.lago.apiUrl || "(unset)", risingwave: cfg.risingwave.url.replace(/:[^:@/]*@/, ":***@") || "(unset)", clickhouse: cfg.clickhouse.url || "(unset)" },
  "targets",
);
if (!store.configured) app.log.warn("not configured yet — open the UI and fill in the Setup screen");

await app.listen({ port, host: "0.0.0.0" });
app.log.info(`loadtest server on http://localhost:${port}${existsSync(webDist) ? "" : " (run the web dev server for the UI)"}`);
