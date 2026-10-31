# The game client

The server needs a copy of the **LEGO Universe 1.10.64** client on the host
PC (it reads game data from it), and every player needs the client to play.
This repo doesn't include it; you need your own copy.

## Where to put it

Anywhere on the host PC **outside OneDrive / synced folders**, ideally with no
spaces in the path. Either set `CLIENT_PATH` in `.env` (the install script
does this when you pass `CLIENT=...`) or copy it into this repo's `client/`
folder.

Which folder `CLIENT_PATH` points at depends on the client type:

- **Unpacked:** the folder containing `legouniverse.exe`, `res/` and `locale/`.
- **Packed:** the archive usually extracts as `LEGOUniverse/client/` plus
  `LEGOUniverse/versions/`. Point `CLIENT_PATH` at **`LEGOUniverse`** (the
  parent), because the server needs `versions/` too. `legouniverse.exe` and
  `boot.cfg` are in `client/`; the scripts find them automatically.

- **Unpacked client** (has `res/cdclient.fdb`): best. Everything works,
  including the dashboard's property/model viewer.
- **Packed client** (has `res/pack/*.pk`): the game server works, but the
  Nexus Dashboard can't run (it needs `res/brickdb.zip` and
  `res/brickprimitives`). Create accounts with `create-account` instead.

On first start, the server converts `cdclient.fdb` into
`server/res/CDServer.sqlite`. This takes a few minutes, once.

## Verify your client (optional)

If you have the original **.rar** archive, its SHA256 should match one of these
(from the DarkflameServer README):

| Client | SHA256 |
|--------|--------|
| packed | `8f6c7e84eca3bab93232132a88c4ae6f8367227d7eafeaa0ef9c40e86c14edf5` |
| packed + extra locales | `c1531bf9401426042e8bab2de04ba1b723042dc01d9907c2635033d417de9e05` |
| unpacked + extra locales | `0d862f71eedcadc4494c4358261669721b40b2131101cbd6ef476c5a6ec6775b` |

```
certutil -hashfile <file.rar> SHA256      # Windows
shasum -a 256 <file.rar>                  # Linux / macOS
```

A Darkflame Universe client (not the original live one) needs
`CLIENT_NET_VERSION=171023` in `.env`.

## Point a client at the server (`boot.cfg`)

On the host PC: `.\lu.ps1 boot-cfg` / `./lu.sh boot-cfg` does it automatically.

On a friend's PC, open `boot.cfg` in the client folder with Notepad and make sure it has:

```
AUTHSERVERIP=0:<server IP>,
UGCUSE3DSERVICES=7:0
```

Keep the trailing comma after the IP. `<server IP>` is the host's LAN IP for
the same network, or its public IP / DDNS name for internet play.
Running `boot-cfg` saves the original file as `boot.cfg.original`.

## Running the client

- Windows: double-click `legouniverse.exe`.
- Linux/macOS: run it with Wine (`wine legouniverse.exe`), or through Lutris/CrossOver.
