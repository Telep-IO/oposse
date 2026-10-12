# Oposse

**All your personal assistants behind one icon in the [Omarchy](https://omarchy.org) bar:** Muse, ChatGPT Dots and your Grok Bot roster.

- One avatar sits next to the icon: whoever has asked you something and is waiting on the answer, otherwise your pinned assistant (Muse or Dots by default). Unread alone does not take the spot. The pinned one is tagged `📌 in bar` in the list; hover another and click `pin` to move it; the `bar:` toggle in the panel header switches between "who's waiting" and "pinned only".
- Click the icon for the list of every assistant. Click one and the list turns into its chat, in place.
- Click anywhere off the chat to tuck it away. The tabs under it: `‹ all` (back to the list), `pop out` (a normal tiled window), `✕ close` (quit it).
- Hover a row for pop out / close on that assistant; `✕ close all` in the list header closes every one.

Combines my earlier omusey and odotsy plugins, and builds on [omabot](https://github.com/njpatel/omabot) by Neil Patel for Grok Bot (see [Credits](#credits)).

## Install

```sh
omarchy plugin add https://github.com/Telep-IO/oposse.git --enable
```

That is all. The first time the widget loads (and on every shell start after)
it runs `bin/posse-setup --auto`, which:

- installs the `grok-bot` package if it is missing (a floating terminal runs
  `omarchy pkg add grok-bot`, so sudo can ask for your password) and starts it:
  hidden if you have signed in before, on screen if not, so you can;
- opens Muse and ChatGPT Dots hidden in your browser profile, warmed up for
  the first click, and brings one on screen only if it landed on a sign-in page.

Sign in to whatever it put on screen, then leave or close the window. Turn the
automatic run off with `omarchy bar set telep.posse autoSetup false`; run it by
hand any time with `~/.config/omarchy/plugins/telep.posse/bin/posse-setup`.

The list shows who you are actually talking to: your Muse persona's name and
picture, and your dot's name, are picked up from the browser (window titles,
history, the site's own notifications). Override either if it guesses wrong:
`omarchy bar set telep.posse museName Felipe`, `dotsName Sam`.

### Requirements

- Omarchy Quattro (the Quickshell-based shell, Hyprland with Lua config)
- A Chromium-based default browser for the Muse and Dots web apps
- `jq`, `python3`
- Grok Bot: the `grok-bot` package from the Omarchy repo (installed for you),
  or the AppImage in `~/Applications/grok-bot` / `~/.local/bin/grok-bot`

**Allow notifications** for chatgpt.com and muse.ai when the browser asks. That is how Oposse knows a web chat has replied (and how it learns your dot's name).

## How "waiting on you" works

| Assistant | Signal |
|---|---|
| Grok Bot | The app's own `awaitingUserResponse` flag, read from `~/.config/Grok Bot`; "running" is the app's process |
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
omarchy bar set telep.posse dotsName Sam                  # names: found automatically, this overrides
omarchy bar set telep.posse museName Felipe
omarchy bar set telep.posse dotsAvatar ~/Pictures/dot.png
omarchy bar set telep.posse museAvatar ~/Pictures/muse.png
omarchy bar set telep.posse autoSetup false               # no setup run on shell start
omarchy bar set telep.posse barFollow false             # bar always shows the pinned assistant, even when one is waiting on you
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
rm -rf ~/.local/state/omarchy/posse   # cached avatars and learned names
omarchy pkg remove grok-bot           # if you only had it for this
```

Window rules are runtime-only and go away with the shell.

## Credits

The Grok Bot side of Oposse uses code from **[omabot](https://github.com/njpatel/omabot) by Neil Patel**, under the Apache License 2.0 (full text in [`LICENSE-omabot`](LICENSE-omabot)):

- `Avatar.qml`: the Grok Bot avatars, their shapes, colours, eye geometry, poses and blinking. Oposse adds the live eyes on Muse and Dots pictures.
- `Widget.qml`: the roster list, keyboard controls, ordering and redact mode were started from omabot's widget and modified here to add Muse, Dots, in-place chats, pop out and close.
- `bin/drops-watch`: reading Grok Bot's state from `~/.config/Grok Bot`.

If you only use Grok Bot, omabot is the original and worth a look. Thanks, Neil.

Oposse's own code is MIT (see [`LICENSE`](LICENSE)).

Oposse is an independent project. It is not affiliated with, endorsed by or sponsored by Meta, OpenAI or xAI. Muse, ChatGPT, Dots and Grok are trademarks of their respective owners.
