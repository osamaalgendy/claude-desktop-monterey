# Contributing

Useful reports include: macOS version, Mac model/architecture, Claude version (`defaults read <Claude.app>/Contents/Info.plist CFBundleShortVersionString`), Electron version used, and the relevant lines from `~/Library/Logs/Claude/main.log`.

Pull requests should keep `build.sh` dependency-light (bash, node, curl, unzip, PlistBuddy) and must never add Anthropic binaries or app code to the repository.
