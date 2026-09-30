# Oposse

**All your personal assistants behind one icon in the [Omarchy](https://omarchy.org) bar:** Muse, ChatGPT Dots and your Grok Bot roster.

- When an assistant finishes and is waiting on you, its avatar appears next to the icon.
- Click the icon for the list of every assistant. Click one and the list turns into its chat, in place.
- Click anywhere off the chat to tuck it away. The tabs under it: `‹ all` (back to the list), `pop out` (a normal tiled window), `✕ close` (quit it).
- Hover a row for pop out / close on that assistant; `✕ close all` in the list header closes every one.

Combines my earlier omusey and odotsy plugins, and builds on [omabot](https://github.com/njpatel/omabot) by Neil Patel for Grok Bot (see [Credits](#credits)).

## Install

```sh
omarchy plugin add https://github.com/Telep-IO/oposse.git --enable
~/.config/omarchy/plugins/telep.posse/bin/posse-setup   # one-time sign-in
omarchy restart shell
```

### Requirements

- Omarchy Quattro (the Quickshell-based shell, Hyprland with Lua config)
- A Chromium-based default browser for the Muse and Dots web apps
- `jq`, `python3`
- Optional: [Grok Bot](https://grok.com) AppImage in `~/Applications/grok-bot` for the bot roster

`posse-setup` opens Muse and ChatGPT in your browser profile and starts Grok Bot, so you sign in to each once. It also installs Grok Bot's `.desktop` entry, which the AppImage never does.

**Allow notifications** for chatgpt.com and muse.ai when the browser asks. That is how Oposse knows a web chat has replied.

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
omarchy bar set telep.posse services dots,grok        # which assistants to list
omarchy bar set telep.posse dotsUrl https://chatgpt.com/dots/<id>
omarchy bar set telep.posse dotsAvatar ~/Pictures/dot.png
omarchy bar set telep.posse museAvatar ~/Pictures/muse.png
omarchy bar set telep.posse width 560                 # dropdown px, 360-1200
omarchy bar set telep.posse heightPercent 70          # dropdown % of screen, 30-90
```

Avatar pictures with a face get live eyes that follow the pointer and blink:
the eyes are found in the picture itself (two matching dark spots, side by
side), so any picture works with no setup. A picture with no face, like the
Muse logo, turns as a whole instead. If it picks the wrong spots:

```sh
omarchy bar set telep.posse museEyes 0.35,0.32,0.53,0.30,0.07,0.05   # lx,ly,rx,ry,w,h as fractions
omarchy bar set telep.posse museEyes none                            # no live eyes
```

Check the eye finder: `qml6 tests/eyes.qml` (exit 0 = pass).

## Adding an assistant

1. `bin/drop-toggle`: one `case` line (window class + launch command).
2. `bin/drops-watch`: one `WEB` entry (window class + notification text).
3. `icons/<name>.png`.

## Remove

```sh
omarchy plugin remove telep.posse
rm -rf ~/.local/state/omarchy/posse   # cached bot avatars
```

Window rules are runtime-only and go away with the shell. `posse-setup` leaves Grok Bot's `.desktop` entry in `~/.local/share/applications`; that belongs to Grok Bot, so it stays.

## Credits

The Grok Bot side of Oposse uses code from **[omabot](https://github.com/njpatel/omabot) by Neil Patel**, under the Apache License 2.0 (full text in [`LICENSE-omabot`](LICENSE-omabot)):

- `Avatar.qml`: the Grok Bot avatars, their shapes, colours, eye geometry, poses and blinking. Oposse adds the live eyes on Muse and Dots pictures.
- `Widget.qml`: the roster list, keyboard controls, ordering and redact mode were started from omabot's widget and modified here to add Muse, Dots, in-place chats, pop out and close.
- `bin/drops-watch`: reading Grok Bot's state from `~/.config/Grok Bot`.

If you only use Grok Bot, omabot is the original and worth a look. Thanks, Neil.

Oposse's own code is MIT (see [`LICENSE`](LICENSE)).
