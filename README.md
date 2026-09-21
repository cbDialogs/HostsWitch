# HostsWitch

A native macOS app for editing `/etc/hosts` — a modern, Apple-silicon
replacement for the abandoned [iHosts](https://github.com/toolinbox/iHosts),
with a witch on the broomstick. Group host entries, keep one node active per
group (dev / staging / production), switch from the menu bar, and see the
live file at any time.

## Features

- **Nodes and groups** — a node is a block of hosts entries; a group holds
  several nodes and, by default, keeps exactly one of them active (switch on
  *Staging* and *Development* goes off). Groups can be set to allow several.
- **Menu bar** — the witch's hat in the menu bar lists every node with a
  checkmark; picking one rewrites `/etc/hosts` on the spot.
- **Edit Hosts** — a monospaced editor with IPs in ember and comments dimmed;
  **Cast** (⌘S) commits the text and writes the file and shows a badge saying
  what happened, **Revert** discards edits. **Find & Replace** (⌥⌘F) sits
  above the editor.
- **View Hosts** — the live `/etc/hosts`, read-only, with the block HostsWitch
  manages highlighted. Updates when anything else changes the file.
- **Only its own block** — HostsWitch writes one fenced region at the end of
  the file (`# ==== HostsWitch begin … end ====`) and never touches anything
  outside it. Switching everything off removes the block and leaves the file
  byte-for-byte as it was.
- **Backup** — the untouched file is copied to
  `~/Library/Application Support/HostsWitch/hosts.original` before the first
  write; Settings can restore it.
- **Pause** — leaves `/etc/hosts` exactly as the system had it while keeping
  your on/off choices for later.
- **Permissions** — if `/etc/hosts` is root-owned, every cast asks for your
  administrator password through the standard macOS prompt. Settings offers a
  one-time "Let HostsWitch own /etc/hosts" so later writes need no password
  (and a button to hand it back to root).

Shortcuts: ⌘N new node · ⇧⌘N new group · ⌘S cast · ⇧⌘R revert · ⌥⌘F find & replace · ⌘E edit
hosts · ⇧⌘V view hosts · ⌘, settings.

Your library lives in `~/Library/Application Support/HostsWitch/library.json`.

## Install

Download `HostsWitch-x.y.z.dmg` from the [Releases](../../releases) page,
open it, and drag the app to Applications. Releases are Developer ID signed
and notarized, so the app opens normally on first launch.

## Build from source

Requires Xcode (or the command-line tools) on macOS 14+:

```
./App/build-app.sh
```

That compiles the Swift package, assembles `HostsWitch.app` in the repository
root, and ad-hoc signs it. `App/make-icon.swift` regenerates the app icon
(`swift App/make-icon.swift && iconutil -c icns AppIcon.iconset -o App/AppIcon.icns`).
`App/release.sh` makes the signed, notarized DMG (needs the Developer ID
certificate and the `AC_NOTARY` notarytool profile).

Source layout (`App/Sources/HostsWitch/`):

| File | Holds |
|------|-------|
| `App.swift` | scenes: main window, Settings, menu-bar extra, menu commands |
| `Model.swift` | `HostNode`, `HostGroup`, `HostItem`, the starter library |
| `Store.swift` | the observable library, cast/apply, file watching, persistence |
| `HostsFile.swift` | read / compose / strip the managed block, direct or privileged write |
| `HostsTextView.swift` | the NSTextView wrapper with hosts-file colouring |
| `Views.swift` | the window: top bar, sidebar, editor pane, view pane, settings |
| `Theme.swift` | the Coven palette, bundled fonts, the hat |

## Design

The look is the *Coven* direction from five mockups (see `design/`), on one
Design canvas: <https://claude.ai/artifact/FzRAo8ewA1s1fmdzp2wtWp>

| # | Name | Look |
|---|------|------|
| 1 | Cupertino | Stock macOS: grey source list, unified toolbar, SF Mono editor. |
| 2 | Slate | Dark developer tool: graphite, cool blue, toggles in the sidebar. |
| 3 | Terminal | Monospace everything, hairlines, forest-green accent. |
| 4 | **Coven** (shipped) | Moonlit indigo, ember accent with a glow, Cormorant Garamond titles, witch's-hat icon, Apply → "Cast". |
| 5 | Hearth | Parchment and candle-amber, Newsreader serif, cauldron icon. |

- `design/generate.py` writes the artboards (`design/project/*.dc.html`) and
  `design/project/canvas.json`; `design/render-png.sh` renders them to
  `design/png/` with headless Chrome.

## License

The code is licensed under the MIT License. The bundled
[Cormorant Garamond](https://github.com/CatharsisFonts/Cormorant) and
[JetBrains Mono](https://github.com/JetBrains/JetBrainsMono) fonts are
licensed separately under the SIL Open Font License 1.1
(`App/Fonts/OFL-*.txt`).
