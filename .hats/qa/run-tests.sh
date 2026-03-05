#!/usr/bin/env bash
set -euo pipefail

# QA Test Runner for DesignGPT
# Run from the qa/ directory or from the project root via: bash qa/run-tests.sh
#
# Usage:
#   bash qa/run-tests.sh              # Run all tests (includes slow Figma import)
#   bash qa/run-tests.sh fast         # Run fast tests only (API, auth, health, UI layout)
#   bash qa/run-tests.sh render       # Run component rendering validation only
#   bash qa/run-tests.sh workflow     # Run full design workflow tests only (includes UI layout)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
  echo "[qa] Installing dependencies..."
  npm install
  npx playwright install chromium
fi

MODE="${1:-all}"

case "$MODE" in
  fast)
    echo "[qa] Running fast tests (API, auth, health)..."
    npx bddgen --config playwright.fast.config.js
    npx playwright test --config playwright.fast.config.js
    ;;
  render)
    echo "[qa] Running component rendering validation..."
    npx bddgen --config playwright.render.config.js
    npx playwright test --config playwright.render.config.js
    ;;
  workflow)
    echo "[qa] Running full design workflow tests..."
    npx bddgen --config playwright.workflow.config.js
    # Remove serial mode from generated specs so failures don't cascade-skip
    # subsequent tests. Each scenario is self-contained (navigates from scratch).
    echo "[qa] Patching generated specs: removing serial mode..."
    find .features-gen-workflow -name '*.spec.js' -exec sed -i '' 's/"mode":"serial"/"mode":"default"/g' {} +
    npx playwright test --config playwright.workflow.config.js
    ;;
  all)
    echo "[qa] Running ALL tests..."
    npx bddgen
    # Remove serial mode from generated specs so failures don't cascade-skip
    find .features-gen -name '*.spec.js' -exec sed -i '' 's/"mode":"serial"/"mode":"default"/g' {} +
    npx playwright test
    ;;
  *)
    echo "Usage: $0 [fast|render|workflow|all]"
    exit 1
    ;;
esac

echo ""
echo "[qa] Tests complete."
