# Odropsy

**All your personal assistants behind one icon in the [Omarchy](https://omarchy.org) bar:** Muse, ChatGPT Dots and your Grok Bot roster.

- When an assistant finishes and is waiting on you, its avatar appears next to the icon.
- Click the icon for the list of every assistant. Click one and the list turns into its chat, in place.
- Click anywhere off the chat to tuck it away. The tabs under it: `‹ all` (back to the list), `pop out` (a normal tiled window), `✕ close` (quit it).
- Hover a row for pop out / close on that assistant; `✕ close all` in the list header closes every one.

Replaces omusey, odotsy and omabot. The Grok Bot roster and avatars are built on [omabot](https://github.com/njpatel/omabot) by Neil Patel (Apache-2.0, see `LICENSE-omabot`).

## Install

```sh
omarchy plugin add https://github.com/JonTelep/odropsy.git --enable
~/.config/omarchy/plugins/telep.drops/bin/drops-setup   # one-time sign-in
omarchy restart shell
```

`drops-setup` opens Muse and ChatGPT in your browser profile and starts Grok Bot, so you sign in to each once. It also installs Grok Bot's `.desktop` entry, which the AppImage never does.

**Allow notifications** for chatgpt.com and muse.ai when the browser asks. That is how Odropsy knows a web chat has replied.

## How "waiting on you" works

| Assistant | Signal |
|---|---|
| Grok Bot | The app's own `awaitingUserResponse` flag, read from `~/.config/Grok Bot` |
| Dots, Muse | A browser notification from the site; cleared when you focus its window |

## Use

| | |
|---|---|
| click icon | open the list (or, with a chat down, go back to it) |
| click a row / ⏎ | turn the list into that chat |
| click off the chat | tuck it away |
| right-click icon | drop the assistant waiting longest |
| middle-click / r | cycle what sits beside the icon: avatars, count, none |
| g | cycle order: attention, channels, flat |
| h | redact names (for screenshots) |

## Settings

```sh
omarchy bar set telep.drops services dots,grok        # which assistants to list
omarchy bar set telep.drops dotsUrl https://chatgpt.com/dots/<id>
omarchy bar set telep.drops dotsAvatar ~/Pictures/dot.png
omarchy bar set telep.drops museAvatar ~/Pictures/muse.png
omarchy bar set telep.drops width 560                 # dropdown px, 360-1200
omarchy bar set telep.drops heightPercent 70          # dropdown % of screen, 30-90
```

Avatar pictures with a face get live eyes that follow the pointer and blink:
the eyes are found in the picture itself (two matching dark spots, side by
side), so any picture works with no setup. A picture with no face, like the
Muse logo, turns as a whole instead. If it picks the wrong spots:

```sh
omarchy bar set telep.drops museEyes 0.35,0.32,0.53,0.30,0.07,0.05   # lx,ly,rx,ry,w,h as fractions
omarchy bar set telep.drops museEyes none                            # no live eyes
```

Check the eye finder: `qml6 tests/eyes.qml` (exit 0 = pass).

## Adding an assistant

1. `bin/drop-toggle`: one `case` line (window class + launch command).
2. `bin/drops-watch`: one `WEB` entry (window class + notification text).
3. `icons/<name>.png`.

## Remove

```sh
omarchy plugin remove telep.drops
```
