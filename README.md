# Odropsy

**All your personal assistants behind one icon in the [Omarchy](https://omarchy.org) bar:** Muse, ChatGPT Dots and your Grok Bot roster.

- When an assistant finishes and is waiting on you, its avatar appears next to the icon.
- Click the icon for the list of every assistant. Click one and its chat drops down from the bar.
- Click the icon again to tuck the chat away. The `pop out` tab under the dropdown turns it into a normal window.

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
| click icon | open the list |
| click a row / ⏎ | drop that chat down |
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

## Adding an assistant

1. `bin/drop-toggle`: one `case` line (window class + launch command).
2. `bin/drops-watch`: one `WEB` entry (window class + notification text).
3. `icons/<name>.png`.

## Remove

```sh
omarchy plugin remove telep.drops
```
