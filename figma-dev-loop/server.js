const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const PORT = 4000;
const BUNDLE_PATH = path.join(__dirname, "../figma-plugin/dist/dev-bundle.js");
const TRIGGER_TTL_MS = 30_000;

let trigger = null;
let result = null;

function json(res, status, data) {
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  });
  res.end(JSON.stringify(data));
}

function readBody(req) {
  return new Promise((resolve) => {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        resolve(JSON.parse(body));
      } catch {
        resolve({});
      }
    });
  });
}

const server = http.createServer(async (req, res) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    res.end();
    return;
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);
  const route = `${req.method} ${url.pathname}`;

  // GET /bundle — serve fresh dev-bundle.js from disk
  if (route === "GET /bundle") {
    try {
      const code = fs.readFileSync(BUNDLE_PATH, "utf-8");
      res.writeHead(200, {
        "Content-Type": "application/javascript",
        "Access-Control-Allow-Origin": "*",
      });
      res.end(code);
    } catch {
      json(res, 404, { error: "dev-bundle.js not found" });
    }
    return;
  }

  // POST /trigger — Claude queues a command
  if (route === "POST /trigger") {
    const body = await readBody(req);
    trigger = {
      action: body.action || "run",
      code: body.code || null,
      js: body.js || null,
      expression: body.expression || null,
      at: Date.now(),
    };
    result = null;
    json(res, 200, { ok: true });
    return;
  }

  // GET /poll — plugin polls for pending commands
  if (route === "GET /poll") {
    if (trigger && Date.now() - trigger.at < TRIGGER_TTL_MS) {
      const pending = { action: trigger.action };
      if (trigger.code) pending.code = trigger.code;
      if (trigger.js) pending.js = trigger.js;
      if (trigger.expression) pending.expression = trigger.expression;
      trigger = null;
      json(res, 200, pending);
    } else {
      trigger = null;
      json(res, 200, { action: "none" });
    }
    return;
  }

  // POST /result — plugin posts render/eval/inspect result
  if (route === "POST /result") {
    const body = await readBody(req);
    result = {
      status: body.status || "unknown",
      error: body.error || null,
      value: body.value || null,
      frame_name: body.frame_name || null,
      logs: (body.logs || []).slice(0, 200),
      at: new Date().toISOString(),
    };
    json(res, 200, { ok: true });
    return;
  }

  // GET /result — Claude reads latest result
  if (route === "GET /result") {
    json(res, 200, result || { status: "pending" });
    return;
  }

  // GET /health
  if (route === "GET /health") {
    json(res, 200, {
      status: "ok",
      pending: trigger !== null && Date.now() - trigger.at < TRIGGER_TTL_MS,
      has_result: result !== null,
    });
    return;
  }

  json(res, 404, { error: "not found" });
});

server.listen(PORT, () => {
  console.log(`figma-dev-loop relay running on http://localhost:${PORT}`);
  console.log(`  GET  /bundle   — serve dev-bundle.js`);
  console.log(`  POST /trigger  — queue command (action: run|eval|inspect)`);
  console.log(`  GET  /poll     — plugin polls for commands`);
  console.log(`  POST /result   — plugin posts result`);
  console.log(`  GET  /result   — read latest result`);
  console.log(`  GET  /health   — status check`);
});
