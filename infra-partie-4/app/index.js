import express from "express";
import pkg from "pg";
import { createClient } from "redis";

const app = express();
const port = +(process.env.PORT || 3000);

const { Pool } = pkg;
const pgPool = new Pool({
  host: process.env.PGHOST || "db",
  port: +(process.env.PGPORT || 5432),
  user: process.env.PGUSER || "app",
  password: process.env.PGPASSWORD || "appsecret",
  database: process.env.PGDATABASE || "tpdb"
});

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

async function waitForPostgres(retries = 30) {
  while (retries-- > 0) {
    try { const c = await pgPool.connect(); await c.query("SELECT 1"); c.release(); return; }
    catch { await sleep(1000); }
  }
  throw new Error("Postgres not ready");
}

async function waitForRedis(retries = 30) {
  const client = createClient({
    url: `redis://${process.env.REDIS_HOST || "cache"}:${process.env.REDIS_PORT || 6379}`
  });
  client.on("error", () => {});
  while (retries-- > 0) {
    try { await client.connect(); return client; }
    catch { await sleep(1000); }
  }
  throw new Error("Redis not ready");
}

const redis = await waitForRedis();
await waitForPostgres();

// bootstrap DB
{
  const c = await pgPool.connect();
  try {
    await c.query(`
      CREATE TABLE IF NOT EXISTS products(
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL
      );
    `);
    const { rows } = await c.query("SELECT COUNT(*)::int AS c FROM products");
    if (rows[0].c === 0) {
      await c.query("INSERT INTO products(name) VALUES ('Livre'), ('Stylo'), ('Cahier');");
    }
  } finally { c.release(); }
}

app.get("/health", async (_req, res) => {
  try { await pgPool.query("SELECT 1"); const pong = await redis.ping(); res.json({ ok:true, pg:"up", redis:pong }); }
  catch (e) { res.status(500).json({ ok:false, error:e.message }); }
});

app.get("/products", async (_req, res) => {
  const key = "products_cache";
  const cached = await redis.get(key);
  if (cached) return res.json({ source:"cache", data: JSON.parse(cached) });
  const { rows } = await pgPool.query("SELECT id,name FROM products ORDER BY id");
  await redis.set(key, JSON.stringify(rows), { EX: 30 });
  res.json({ source:"postgres", data: rows });
});

app.listen(port, () => console.log(`API running on http://localhost:${port}`));