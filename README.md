# Odropsy

Your AI chats in the [Omarchy](https://omarchy.org) bar: **Muse**, **ChatGPT Dots** and **Grok Bot**, one icon each. Click to drop one down from the top, click again to tuck it away. The `pop out` tab under a dropdown turns it into a normal window.

Replaces [omusey](https://github.com/telep-io/omusey) and [odotsy](https://github.com/JonTelep/odotsy).

## Install

```sh
omarchy plugin add https://github.com/JonTelep/odropsy.git --enable
~/.config/omarchy/plugins/telep.drops/bin/drops-setup   # one-time sign-in
omarchy restart shell
```

`drops-setup` opens Muse and ChatGPT in your browser profile and starts Grok Bot so you can sign in to each once. It also installs Grok Bot's `.desktop` entry, which the AppImage doesn't ship installed.

## One widget per service

The widget can be added more than once; each copy picks its `service`:

```sh
omarchy bar set telep.drops service grok      # muse | dots | grok
omarchy bar set telep.drops url https://chatgpt.com/dots/<id>
omarchy bar set telep.drops width 560         # 360-1200
omarchy bar set telep.drops heightPercent 70  # 30-90
omarchy bar set telep.drops avatar ~/Pictures/me.png
```

Or edit the entries in `~/.config/omarchy/shell.json` under `bar.layout`:

```json
{ "id": "telep.drops", "service": "muse" },
{ "id": "telep.drops", "service": "dots", "url": "https://chatgpt.com/dots/<id>" },
{ "id": "telep.drops", "service": "grok" }
```

## Adding a service

One `case` line in `bin/drop-toggle` (window-class match + launch command), `icons/<service>.png`, and the name in the manifest's `service` options.

## Remove

```sh
omarchy plugin remove telep.drops
```
