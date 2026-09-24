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

Wait until `http://localhost:3000/up` returns 200, then use the wmux browser panel (not Playwright) so the user can watch:

1. `wmux browser open http://localhost:3000` → create a room as the owner.
2. Note the invite link on the room page.
3. The participant needs a separate cookie jar. Since the panel shares cookies with the owner, open the invite link in a private context if available; otherwise check the participant side with `curl -c/-b` against the join form and `/rooms/:id/updates`, and tell the user which side was checked visually.
4. Run a draw and confirm: results appear, participant count and empty states update, no console errors (`wmux browser eval` to inspect), confetti fires once.
5. Stop the server when done: `docker stop choose_you_dev`.

If `wmux` is not on PATH or not running (the CLI lives at `/mnt/c/Users/morin/Downloads/wmux-0.7.0-win-x64/resources/cli/wmux.js`; run it with `node` and it prints "wmux is not running" when the app is closed), fall back to `curl` with separate cookie jars per role: fetch the `authenticity_token` from the form, POST `/rooms` and `/rooms/:id/join`, then inspect redirects, cookies, the rendered HTML and `/rooms/:id/updates`. Tell the user that JS behavior was not checked visually.

## 4. Deploy (Render)

Render builds from the repo per `render.yaml`. Before deploying:

1. Tests pass (step 1) and the JS bundle is rebuilt (step 2).
2. `git status` is clean apart from the intended change.
3. **Ask the user before pushing** — pushing to `main` may trigger a production deploy.

After deploy, check `https://<service>.onrender.com/up` (ask the user for the service URL if unknown) and do a quick owner-side smoke test in the browser.

## Output style

- Lead with pass/fail (`N examples, M failures`) or what was observed in the browser.
- Say explicitly which checks were visual and which were only command-line.
