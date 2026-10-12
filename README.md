# Oposse

**All your personal assistants behind one icon in the [Omarchy](https://omarchy.org) bar:** Muse, ChatGPT Dots and your Grok Bot roster.

- Beside the icon, a short ranked row of faces (three at most): whoever has asked you something and is waiting on the answer, then whoever answered most recently that you have not read, then your pinned assistant (Muse or Dots by default) if a spot is left. A quiet day is just the pin; a change in the row means something happened. The pinned one is tagged `📌 in bar` in the list; hover another and click `pin` to move it; the `bar:` toggle in the panel header switches between "who's waiting" and "pinned only".
- Click the icon for the list of every assistant. Click one and the list turns into its chat, in place.
- Click anywhere off the chat to tuck it away. The tabs under it: `‹ all` (back to the list), `pop out` (a normal tiled window), `✕ close` (quit it).
- Hover a row for pop out / close on that assistant; `✕ close all` in the list header closes every one.

Combines my earlier omusey and odotsy plugins, and builds on [omabot](https://github.com/njpatel/omabot) by Neil Patel for Grok Bot (see [Credits](#credits)).

## Install

```sh
omarchy plugin add https://github.com/Telep-IO/oposse.git --enable
```

Omarchy asks you to confirm the clone (plugins run inside the shell, so read
the code first if you like) and where in the bar to put it; the default is the
centre, next to the clock. Then it is all automatic: the widget loads, and its
setup runs. What you will see, in order:

1. **Grok Bot.** If the `grok-bot` package is not installed, a floating
   terminal opens and runs `omarchy pkg add grok-bot`; type your password for
   sudo. Grok Bot then starts: hidden if you have signed in on this machine
   before, otherwise on screen so you can sign in.
2. **Muse and ChatGPT Dots.** Each opens in your browser as an app window,
   loads hidden, and is brought on screen only if it landed on a sign-in page.
   Sign in; the window can stay open or be closed afterwards.
3. **Notifications.** When chatgpt.com or muse.ai ask to send notifications,
   allow it. That is how Oposse knows a web chat replied, and how it learns
   your dot's name.

Click the icon in the bar: the list shows Muse (by your persona's name and
picture), Dots, and every Grok Bot, with the faces the app uses. Click a row
and its chat drops down from the bar.

This runs again on every shell start, so a Grok Bot you quit is back the next
morning and the web apps are warm before the first click. `autoSetup false`
turns that off (see Settings); run it by hand any time with
`~/.config/omarchy/plugins/telep.posse/bin/posse-setup`.

### Requirements

- Omarchy 4 (the Quickshell shell, Hyprland with the Lua config). Developed on 4.0.4.
- A Chromium-based default browser (Brave, Chromium, Chrome, Vivaldi, Edge) for
  the Muse and Dots web apps. Omarchy's default, Brave, is fine.
- `jq`, `python3`: both ship with Omarchy.
- Grok Bot: the `grok-bot` package from the Omarchy repo (installed for you),
  or the AppImage in `~/Applications/grok-bot` or `~/.local/bin/grok-bot`.
- Accounts: Grok Bot (grok.com), Muse (muse.ai) and ChatGPT with a dot, for
  whichever of the three you list in `services`. No Muse? `omarchy bar set
  telep.posse services dots,grok`.

### Making it yours

Everything is learned or defaulted, so a fresh install already matches a
working setup. Three things are worth a look:

```sh
omarchy bar set telep.posse dotsName Sam                   # your dot's name, if it has not been learned yet
omarchy bar set telep.posse dotsUrl https://chatgpt.com/dots/<id>   # open your dot directly, not the Dots home
omarchy bar set telep.posse barPin web:dots                # which face sits in the bar when nothing is happening
```

The dot's name arrives with its first notification; set it if you do not want
to wait. The pin can also be set from the panel: hover a row, click `pin`.

### Updating

```sh
omarchy plugin update telep.posse && omarchy restart shell
```

The shell's hot reload restarts the plugin's scripts but keeps the widget it
already compiled, so a changed `Widget.qml` only shows after a shell restart.

### If something is off

- A row does nothing when clicked: run `~/.config/omarchy/plugins/telep.posse/bin/posse-setup` in a terminal and read what it says.
- The header says "Grok Bot not running": `grok-bot` from a terminal shows why.
- Muse or Dots show the site's logo and name rather than yours: the browser
  has not shown Oposse a page with the persona on it yet. Open the chat once.
- A fresh look at everything: `omarchy restart shell`.

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
omarchy bar set telep.posse barMax 5                    # faces beside the icon, 1-6
omarchy bar set telep.posse barFollow false             # bar always shows the pinned assistant alone
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
