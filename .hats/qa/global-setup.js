import { execSync } from "child_process";

export default async function globalSetup() {
  console.log("[qa] Setting up E2E test database...");
  execSync(
    "cd ../../api && RAILS_ENV=test bundle exec rails db:test:prepare",
    { stdio: "inherit", cwd: import.meta.dirname },
  );
  execSync(
    "cd ../../api && RAILS_ENV=test E2E_TEST_MODE=true bundle exec rails e2e:setup",
    { stdio: "inherit", cwd: import.meta.dirname },
  );
}
