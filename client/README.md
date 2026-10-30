# Put your LEGO Universe client here (or point CLIENT_PATH at it)

This repo does **not** include the game. You need your own copy of the
LEGO Universe **1.10.64** client (packed or unpacked).

Either:

- copy the whole client folder's contents into this `client/` folder, so that
  `client/legouniverse.exe`, `client/res/` and `client/locale/` exist, **or**
- leave the client where it is and set `CLIENT_PATH=` in `.env` to its folder.

Rules:

- Do **not** keep the client inside OneDrive (or any synced folder). DLU does not support it.
- Avoid spaces in the path if you can.
- Everything in this folder except this README is git-ignored.

See [`docs/CLIENT.md`](../docs/CLIENT.md) for how to verify your client and
how to point it at your server (`boot.cfg`).
