# choose_you repository instructions

## What this repository is

- **Choose You**: a real-time lottery (抽選) web app. An owner creates a room, shares an invite link, participants join by name, and the owner draws N people. Results are pushed to everyone live.
- Stack: Ruby 3.2.9 / Rails 8.0, ActionCable, Stimulus + Turbo bundled with esbuild, Tailwind via CDN. No database.
- Deployed to Render.com (`render.yaml`): one web service + Redis. UI copy is Japanese.

## Main files

- `app/controllers/rooms_controller.rb`: create / show / join / select / updates (polling JSON)
- `app/models/room_registry.rb`: facade that picks `RedisRoomService` (production with `REDIS_URL`) or `InMemoryRoomService` (dev/test, defined in the same file)
- `app/services/redis_room_service.rb`: Redis-backed room storage, 10-day TTL
- `app/services/room_authorization_service.rb`: owner/participant auth from signed cookies or URL params
- `app/services/action_cable_broadcast_service.rb`: `participants` / `selection` broadcasts on `room_<id>`
- `app/channels/room_channel.rb`: subscription; sends current participants and last selection on subscribe
- `app/javascript/controllers/room_controller.js`: all client behavior (ActionCable, polling fallback, rendering, confetti, copy)
- `app/views/rooms/{new,join_form,show}.html.erb`, `app/views/layouts/application.html.erb`
- `spec/`: RSpec (models, controllers, channels, features, helpers)
- `.claude/skills/choose-you-ops/SKILL.md`: run / build / test / browser-check / deploy flow (`/choose-you-ops`)
- `.claude/skills/choose-you-dev-loop/SKILL.md`: plan (Opus) → implement (Sonnet) → review (Opus) loop for code changes (`/choose-you-dev-loop`)
- `.claude/agents/choose-you-implementer.md`, `.claude/agents/choose-you-reviewer.md`: the subagents used by that loop

## Development workflow

Non-trivial code changes go through `/choose-you-dev-loop`: this session plans, `choose-you-implementer` (Sonnet) writes the code, `choose-you-reviewer` (Opus) verifies it, and this session reads the result before reporting done.

## Commands

Ruby is not installed on the host; run Ruby commands in Docker. Node/npm are on the host.

```bash
# tests (gems cached in the choose_you_bundle volume)
docker run --rm -v "$PWD":/app -v choose_you_bundle:/usr/local/bundle -w /app ruby:3.2.9 \
  bash -c "bundle install --quiet && bundle exec rspec"

# JS bundle (host)
npm run build
```

The README / TESTING.md mention `docker compose`, but there is no compose file in this repo; use the commands above.

The suite must stay at `0 failures`. `spec/support/room_registry.rb` gives every example a fresh `InMemoryRoomService`; specs never exercise `RedisRoomService`.

## Conventions and caveats

- **The JS bundle is committed.** After editing anything under `app/javascript/`, run `npm run build` and include `app/assets/builds/application.js` (+ `.map`) in the change. Note the layout loads `/assets/application.js`, which is served from `public/assets/` (gitignored, built by `npm run build:production` — `Dockerfile.prd` does this). Locally, run `npm run build:production` too or no JS loads.
- **Two storage backends must stay in sync.** Any change to room/participant data or `RoomRegistry` methods must be made in both `InMemoryRoomService` and `RedisRoomService`. Tests only exercise InMemory, so Redis changes must be checked by reading (Redis stores JSON with symbolized keys; Structs are rebuilt on read).
- **Two delivery paths must stay in sync.** ActionCable payloads (`ActionCableBroadcastService`, `RoomChannel#subscribed`) and the polling JSON (`RoomsController#room_updates_data`) feed the same `MessageHandler` in JS; keep their shapes consistent.
- **Never expose tokens.** `owner_token` / participant tokens grant access. They must not appear in broadcasts, polling JSON, rendered HTML shared with others, or logs.
- **Escape user input in JS.** Names are rendered through `innerHTML`; always go through `escapeHtml`.
- Respect `prefers-reduced-motion` for any new animation.
- User-facing text is Japanese; match the existing tone.
- Match existing style: Tailwind utility classes inline, Stimulus targets for DOM hooks, small helper classes in `room_controller.js`.

## Git

- Commit or push only when the user asks. Pushing to `main` may trigger a Render deploy — confirm before pushing.
