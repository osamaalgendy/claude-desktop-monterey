# claude-desktop-monterey

Run **Claude Desktop** on **macOS 12 Monterey** (and other Macs the official app no longer supports), including newer models such as Sonnet 5.5 and Haiku 5.5.

> **Unofficial.** This project is not affiliated with or endorsed by Anthropic. It contains no Anthropic code. See [Disclaimer](#disclaimer).

## The problem

Recent Claude Desktop releases ship on Electron 44, which requires macOS 13 (Ventura) or later. On Monterey the official app won't install or won't open, and the installed older version stops receiving updates, so new models never show up in the model picker.

## How it works

Claude Desktop is an Electron app. Its logic lives in `app.asar`, which is independent of the Electron runtime it ships with. Electron 43 is the newest major that still supports macOS 12 ([breaking changes](https://www.electronjs.org/docs/latest/breaking-changes)), so this script:

1. Takes the Claude.app **you downloaded yourself** from [claude.ai/download](https://claude.ai/download).
2. Downloads Electron 43 from the [official Electron releases](https://github.com/electron/electron/releases).
3. Puts Claude's `app.asar`, resources and helpers into the Electron 43 shell.
4. Fixes the bundle (name, bundle id, icon, `claude://` sign-in URL scheme, executable name so `app.isPackaged` is true).
5. Disables the in-app updater, so an update can't replace the build with one that won't run.
6. Ad-hoc signs the result.

No native module stubs were needed in testing: the bundled `.node` addons load fine on Electron 43.

## Requirements

- macOS 12 Monterey (the script is also architecture-aware for Apple Silicon)
- [Node.js](https://nodejs.org) (provides `npm` and `npx`)
- Xcode Command Line Tools (`xcode-select --install`)
- A Claude account

## Usage

1. Download the macOS app from <https://claude.ai/download> in your browser (the download link is behind a bot check, so `curl` won't work). Your Mac may warn about macOS 13; the file still downloads.
2. Mount the `.dmg`. **Do not drag the app into Applications.**
3. Run:

```bash
git clone https://github.com/osamaalgendy/claude-desktop-monterey.git
cd claude-desktop-monterey
SRC_APP="/Volumes/Claude/Claude.app" ./build.sh --install
```

Then open **Claude-Monterey** from `/Applications` and sign in. Omit `--install` to keep the build in `~/claude-monterey`.

| Option | Meaning |
| --- | --- |
| `SRC_APP` | Path to the official `Claude.app` (default `/Applications/Claude.app`) |
| `WORKDIR` | Build directory (default `~/claude-monterey`) |
| `--install` | Copy the result to `/Applications` |
| `<version>` | Electron version to use (default `43.7.10`) |

## Updating

Auto-update is disabled on purpose. To update: download the latest `.dmg` in your browser, mount it, quit Claude-Monterey, and run `./build.sh --install` again. Your sign-in and chats are kept, because they live in `~/Library/Application Support/Claude`.

## Known limitations

- Only tested on one machine: MacBook Pro mid-2015 (Intel), macOS 12.7.6, Claude 2.31226.1, Electron 43.7.10. Reports from other setups are welcome via issues.
- The **Claude Code** tab works in testing. Its bundle download failed a checksum check once at first launch, then succeeded on a later attempt; if it fails for you, quit and relaunch.
- Features that need macOS 13+ APIs may be missing or degraded. Chat, sign-in, model selection and the Claude Code tab work.
- Electron 43 will eventually stop receiving security fixes. Treat this as a bridge until you can upgrade macOS.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Auto-update patch did not match` | Claude changed its updater code. Open an issue with the version shown by the script. |
| App starts then can't find resources | The executable must not be named `Electron`. The script handles this; don't rename it back. |
| Nothing happens when launching a second time | Another instance holds the lock. Quit it fully (Cmd+Q) or `pkill -f Claude-Monterey`. |
| Sign-in doesn't return to the app | Make sure only one app registers `claude://`, then re-run `./build.sh --install`. |
| Logs | `~/Library/Logs/Claude/main.log` |

## Disclaimer

This is a personal-use compatibility workaround provided as is, with no warranty. It modifies a local copy of an application you obtained legitimately and downloads nothing from Anthropic itself. You are responsible for complying with Anthropic's terms of service for Claude. "Claude" and "Anthropic" are trademarks of Anthropic, PBC. Prefer upgrading to a supported macOS when you can.

## License

[MIT](LICENSE) for the scripts and documentation in this repository.
