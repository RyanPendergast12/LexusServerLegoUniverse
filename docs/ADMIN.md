# Running the server

## Accounts

- **Your admin account:** `lu create-account`, choose GM level 9.
- **Players:** register on the Nexus Dashboard (`http://<server IP>:8000`).
  Turn sign-ups off with `ND_ENABLE_REGISTER=` (empty) in `.env`, then `lu start`.
- `lu accounts` lists accounts; `lu set-gm <name> <level>` changes GM level.
- Moderation (approve names, pets, properties, ban/mute, send mail, view
  inventories) is done on the dashboard by GM accounts.
- New character names need approval on the dashboard before other players see them.

## GM levels

| Level | Meaning |
|-------|---------|
| 0 | Normal player (use for real gameplay; GMs play differently) |
| 2 | Kick, mute |
| 4 | Ban |
| 5 | Approve properties |
| 8 | Almost everything (developer commands) |
| 9 | Everything, including universe shutdown |

In game, type `/gmlevel <n>` to switch a character to a level your account allows.

## Play keys

Off by default (anyone with an account can log in). To require keys, set in `.env`:
```
DONT_USE_KEYS=0
ND_REQUIRE_PLAY_KEY=1
```
then `lu start`, and create keys on the dashboard's Play Keys page.

> Nexus Dashboard treats any non-empty value as ON (even `0` or `False`).
> To turn a dashboard option off, leave it empty.

## Config files

After the first start, the `.ini` files appear in `server/config/`:

- `worldconfig.ini` – gameplay options (extra backpack, solo racing, hardcore mode,
  skip cinematics, pets using imagination…)
- `authconfig.ini`, `chatconfig.ini`, `masterconfig.ini`, `sharedconfig.ini`

Edit them, then `lu restart`. Values set in `.env` / `docker-compose.yml`
(database, IP, play keys) override the `.ini` files.

## Useful in-game commands

Full list: https://github.com/DarkflameUniverse/DarkflameServer/blob/main/docs/Commands.md

| Command | GM | Does |
|---------|----|------|
| `/help` | 0 | List commands |
| `/who` | 0 | Players in this world |
| `/fly` | 8 | Toggle flying |
| `/teleport x y z` or `/tp player` | 6 | Teleport |
| `/gmadditem <id> (count)` | 8 | Give yourself an item |
| `/lookup <text>` | 8 | Find item/object IDs |
| `/setlevel <n>` | 8 | Set your level |
| `/announce` | 8 | Server-wide announcement (after `/setanntitle` + `/setannmsg`) |
| `/shutdownuniverse` | 9 | Shut down with a 10 minute warning |

## Backups

`lu backup` saves the database and configs to `backups/`. `lu update`
backs up automatically first. Copy `backups/` somewhere else now and then.
Restore with `lu restore backups/db-XXXX.sql`.
