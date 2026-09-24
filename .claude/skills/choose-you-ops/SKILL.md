---
name: choose-you-ops
description: >-
  Run the choose_you app's standard operating flows: run the test suite, rebuild the JS bundle, start the app
  locally in Docker, check the real-time owner/participant flow in the wmux browser panel, and prepare a Render deploy.
  Use when users ask to "テストを回して", "ローカルで起動", "ブラウザで確認", "JSをビルド", "デプロイ準備",
  or want the same run/verify workflow reproduced in another session.
---

# choose_you ops

## Repository assumptions

- Ruby is **not** installed on the host. All Ruby/Rails commands run in the `ruby:3.2.9` Docker image, with gems cached in the `choose_you_bundle` volume.
- Node/npm are on the host; `node_modules/` is present.
- Dev and test use `InMemoryRoomService` (no Redis needed). Production uses Redis via `REDIS_URL`.
- The compiled JS bundle `app/assets/builds/application.js` is committed.

## 1. Tests

```bash
docker run --rm -v "$PWD":/app -v choose_you_bundle:/usr/local/bundle -w /app ruby:3.2.9 \
  bash -c "bundle install --quiet && bundle exec rspec"
```

Single file: append the path, e.g. `bundle exec rspec spec/controllers/rooms_controller_spec.rb`.
The first run installs gems into the volume and is slow; later runs are fast.

Feature specs do not run JavaScript, so real-time behavior must be checked in the browser (step 3).

## 2. JS bundle

```bash
npm run build
git status app/assets/builds
```

Run after any change under `app/javascript/`. The rebuilt bundle is part of the change.

## 3. Run locally and check in the browser

Start the server in the background:

```bash
docker run --rm --name choose_you_dev -p 3000:3000 \
  -v "$PWD":/app -v choose_you_bundle:/usr/local/bundle -w /app ruby:3.2.9 \
  bash -c "bundle install --quiet && bin/dev"
```

The layout loads `/assets/application.js`, which only exists under `public/assets/` (gitignored; production builds it in `Dockerfile.prd`). Without it no JS runs locally. Run `npm run build:production` before checking in the browser, and again after JS changes.

Wait until `http://localhost:3000/up` returns 200, then use the wmux browser panel (not Playwright) so the user can watch:

1. `wmux browser open http://localhost:3000` → create a room as the owner.
2. The panel has one cookie jar. For a two-role check, make the panel one role and drive the other with `curl` cookie jars (fetch `authenticity_token` from the form, POST `/rooms` or `/rooms/:id/join`, JSON `POST /rooms/:id/select` with the page's `csrf-token`).
3. Run a draw and confirm: roulette, results, won/lost banner, history, participant count, connection label.
4. Stop the server when done: `docker stop choose_you_dev` (in-memory rooms are lost on restart).

wmux CLI notes (wmux 0.7.0 from WSL):
- `wmux` is `~/.local/bin/wmux`, which runs the CLI via `wmux.exe` in Electron-as-node mode (Linux node can't open the Windows pipe). Each call takes ~1–2 s.
- `browser fill/click/type @eN` fail with "Invalid parameters"; drive the page with `wmux browser eval` instead. Schedule clicks with `setTimeout(() => el.click(), 50)` so a navigation doesn't abort the eval.
- There is no `browser reload`; use `eval "location.reload()"`. `screenshot --full` renders blank outside the viewport; scroll and take viewport screenshots.
- For anything shorter than a few seconds (roulette, flash auto-dismiss), record state in-page with `setInterval` into a `window.__samples` array and read it afterwards; a background panel throttles timers to ~1 s.
- Stub `window.confirm = () => true` before clicking buttons that confirm.

If wmux is not running (`wmux` prints "wmux is not running"), fall back to `curl` only and tell the user that JS behavior was not checked visually.

## 4. Deploy (Render)

Render builds from the repo per `render.yaml`. Before deploying:

1. Tests pass (step 1) and the JS bundle is rebuilt (step 2).
2. `git status` is clean apart from the intended change.
3. **Ask the user before pushing** — pushing to `main` may trigger a production deploy.

After deploy, check `https://<service>.onrender.com/up` (ask the user for the service URL if unknown) and do a quick owner-side smoke test in the browser.

## Output style

- Lead with pass/fail (`N examples, M failures`) or what was observed in the browser.
- Say explicitly which checks were visual and which were only command-line.
