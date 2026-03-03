import { execSync } from "child_process";

export default async function globalSetup() {
  const force = process.env.FORCE === "1";

  if (force) {
    console.log("[render-test] FORCE=1 — Resetting DB and loading fixtures...");
    // Terminate existing connections to the test DB (a running Rails server may hold one)
    execSync(
      `psql postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'jan_designer_api_test' AND pid <> pg_backend_pid()" 2>/dev/null || true`,
      { stdio: "pipe", cwd: import.meta.dirname },
    );
    execSync(
      "cd ../api && RAILS_ENV=test bundle exec rails db:test:prepare",
      { stdio: "inherit", cwd: import.meta.dirname },
    );
    execSync(
      "cd ../api && RAILS_ENV=test E2E_TEST_MODE=true bundle exec rails e2e:setup",
      { stdio: "inherit", cwd: import.meta.dirname },
    );
  } else {
    console.log("[render-test] Reusing existing DB (set FORCE=1 to reset).");
    try {
      execSync(
        "cd ../api && RAILS_ENV=test bundle exec rails db:migrate:status",
        { stdio: "pipe", cwd: import.meta.dirname },
      );
    } catch {
      console.log("[render-test] DB not ready, running setup...");
      execSync(
        "cd ../api && RAILS_ENV=test bundle exec rails db:test:prepare",
        { stdio: "inherit", cwd: import.meta.dirname },
      );
      execSync(
        "cd ../api && RAILS_ENV=test E2E_TEST_MODE=true bundle exec rails e2e:setup",
        { stdio: "inherit", cwd: import.meta.dirname },
      );
    }
  }
}
