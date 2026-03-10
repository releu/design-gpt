# Heroku Deployment — Monorepo (Option B)

## Architecture

Rails serves both the API (`/api/*`) and the Vue SPA (all other routes). No Caddy needed in production. Heroku runs two buildpacks: Node (builds frontend) then Ruby (runs Rails).

The SPA fallback route and controller action already exist in `routes.rb` and `application_controller.rb` — no changes needed there.

## Files to Create

### 1. `bin/build` (make executable: `chmod +x bin/build`)

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "-----> Building Vue frontend"
cd app
npm ci
npm run build
cd ..

echo "-----> Copying frontend assets to api/public/"
rm -rf api/public/assets api/public/index.html
cp -r app/dist/* api/public/

echo "-----> Frontend build complete"
```

### 2. `app.json`

```json
{
  "name": "design-gpt",
  "buildpacks": [
    { "url": "heroku/nodejs" },
    { "url": "heroku/ruby" }
  ],
  "formation": {
    "web": { "quantity": 1, "size": "basic" },
    "worker": { "quantity": 1, "size": "basic" }
  },
  "env": {
    "RAILS_MASTER_KEY": { "required": true },
    "AUTH0_DOMAIN": { "required": true },
    "AUTH0_AUDIENCE": { "required": true },
    "OPENAI_API_KEY": { "required": true },
    "FIGMA_ACCESS_TOKEN": { "required": true }
  },
  "addons": ["heroku-postgresql:essential-0"]
}
```

### 3. `package.json` (root level — tells Node buildpack what to build)

```json
{
  "name": "design-gpt",
  "private": true,
  "engines": {
    "node": "22.x"
  },
  "scripts": {
    "build": "./bin/build",
    "heroku-postbuild": "./bin/build"
  }
}
```

Check `app/package.json` for the actual Node version and match it in `engines.node`.

## Files to Modify

### 4. `api/config/environments/production.rb`

Add Heroku hostname to allowed hosts. Add this line alongside the existing ones:

```ruby
config.hosts << ENV["HEROKU_APP_HOST"] if ENV["HEROKU_APP_HOST"]
```

### 5. `Procfile` — already correct, no changes needed

```
web: cd api && bin/rails server -p $PORT -b 0.0.0.0
worker: cd api && bin/jobs
release: cd api && bin/rails db:migrate
```

### 6. `.gitignore` — add build artifacts

```
api/public/assets/
api/public/index.html
```

## Deployment Steps

```bash
# 1. Create Heroku app
heroku create design-gpt

# 2. Add buildpacks (order matters — Node first, Ruby second)
heroku buildpacks:add heroku/nodejs
heroku buildpacks:add heroku/ruby

# 3. Add PostgreSQL
heroku addons:create heroku-postgresql:essential-0

# 4. Set environment variables
heroku config:set RAILS_MASTER_KEY=$(cat api/config/master.key)
heroku config:set AUTH0_DOMAIN=your-domain.auth0.com
heroku config:set AUTH0_AUDIENCE=your-audience
heroku config:set OPENAI_API_KEY=sk-...
heroku config:set FIGMA_ACCESS_TOKEN=figd_...
heroku config:set HEROKU_APP_HOST=design-gpt-xxxxx.herokuapp.com
heroku config:set BUNDLE_GEMFILE=api/Gemfile

# 5. Deploy
git push heroku main

# 6. Scale worker dyno
heroku ps:scale worker=1
```

## How the Build Works on Heroku

1. **Node buildpack** detects root `package.json`, runs `heroku-postbuild`
2. `heroku-postbuild` → `bin/build` → builds Vue app, copies `app/dist/*` → `api/public/`
3. **Ruby buildpack** detects `api/Gemfile` via `BUNDLE_GEMFILE`, runs `bundle install`
4. **Release phase** runs `cd api && bin/rails db:migrate`
5. **Web dyno** starts Rails — serves API routes and static frontend from `public/`

## Critical: BUNDLE_GEMFILE

Since `Gemfile` is in `api/` (not root), the Ruby buildpack needs:

```bash
heroku config:set BUNDLE_GEMFILE=api/Gemfile
```

## Cost Estimate

- Basic dynos: $7/mo each (web + worker = $14/mo)
- Essential-0 Postgres: $5/mo
- **Total: ~$19/mo**

## Auth0 Callback URLs

Update Auth0 dashboard to add the Heroku URL:
- Allowed Callback URLs: `https://your-app.herokuapp.com/callback`
- Allowed Logout URLs: `https://your-app.herokuapp.com`
- Allowed Web Origins: `https://your-app.herokuapp.com`
