.PHONY: dev dev-prod dev-loop clean_dev prod-db test test-api test-app test-e2e test-render test-render-fresh setup setup-e2e prod-run dev-inspect dev-run dev-eval dev-result dev-wait

# Start all development servers (Rails API + Vite frontend + Caddy proxy)
dev:
	@trap 'kill -- -$$; sleep 1; kill -9 -- -$$ 2>/dev/null; psql postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname LIKE '"'"'jan_designer_api_%'"'"' AND pid <> pg_backend_pid()" > /dev/null 2>&1; exit' INT TERM; \
	cd api && bin/rails server -p 3000 -b 0.0.0.0 & \
	cd api && bin/jobs & \
	cd app && npm run dev & \
	cd caddy && caddy run --config Caddyfile & \
	wait

# Start dev servers against local prod DB copy
dev-prod:
	@trap 'kill -- -$$; sleep 1; kill -9 -- -$$ 2>/dev/null; exit' INT TERM; \
	cd api && DATABASE_URL=postgres://localhost/jan_designer_api_prodcopy bin/rails server -p 3000 -b 127.0.0.1 & \
	cd app && npm run dev & \
	cd caddy && caddy run --config Caddyfile & \
	wait

# Start the Figma dev loop relay server
dev-loop:
	cd figma-dev-loop && node server.js

# Rebuild database from scratch and start dev servers
clean_dev:
	-psql postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname LIKE 'jan_designer_api_%' AND pid <> pg_backend_pid()" > /dev/null
	cd api && bin/rails db:drop db:create db:migrate
	$(MAKE) dev

# Pull production database to local for debugging
prod-db:
	@echo "Pulling production database..."
	dropdb --if-exists jan_designer_api_prodcopy
	heroku pg:pull DATABASE_URL jan_designer_api_prodcopy --app design-gpt
	@echo "Done. Run: make dev-prod"

# Run all test layers
test: test-api test-app

# Layer 1: API unit/integration tests (RSpec)
test-api:
	cd api && bundle exec rspec

# Layer 2: Frontend unit tests (Vitest)
test-app:
	cd app && npm test

# Layer 3: E2E integration tests (Playwright)
# Starts Rails, Vite, and Caddy automatically
test-e2e:
	cd api && RAILS_ENV=test bundle exec rails db:test:prepare
	cd api && RAILS_ENV=test E2E_TEST_MODE=true bundle exec rails e2e:setup
	cd e2e && npx bddgen && npx playwright test

# Layer 4: Component rendering validation (reuses existing Figma import)
test-render:
	cd e2e && npx bddgen --config playwright.render.config.js && npx playwright test --config playwright.render.config.js

# Component rendering validation (fresh DB + Figma import)
test-render-fresh:
	cd e2e && npx bddgen --config playwright.render.config.js && FORCE=1 npx playwright test --config playwright.render.config.js

# Install E2E dependencies
setup-e2e:
	cd e2e && npm install && npx playwright install chromium

# Run a Rails runner script against local prod DB copy
# Usage: make prod-run FILE=tmp/debug.rb
prod-run:
	cd api && DATABASE_URL=postgres://localhost/jan_designer_api_prodcopy bin/rails runner $(FILE)

# Dev loop CLI helpers
# Usage: make dev-inspect EXPR="figma.currentPage.children.length"
#        make dev-run CODE=5ksqr3
#        make dev-eval JS="console.log('hi')"
#        make dev-result
#        make dev-wait
dev-inspect:
	cd figma-dev-loop && ./cli.sh trigger-inspect "$$(cat $(or $(FILE),inspect.js))" && ./cli.sh wait-result

dev-run:
	cd figma-dev-loop && ./cli.sh trigger-run "$(CODE)" && ./cli.sh wait-result 60

dev-eval:
	cd figma-dev-loop && ./cli.sh trigger-eval "$(JS)" && ./cli.sh wait-result

dev-result:
	cd figma-dev-loop && ./cli.sh result

dev-wait:
	cd figma-dev-loop && ./cli.sh wait-result 30

# Install all dependencies
setup:
	cd app && npm install
	cd api && bundle install
	$(MAKE) setup-e2e
