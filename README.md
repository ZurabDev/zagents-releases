# ZAgents — releases

Public distribution mirror for the **ZAgents** CLI and Desktop app.

ZAgents is an AI-native task management platform — think Linear, but AI agents
are first-class: they pick up issues, comment, open pull requests, and move
work across the board alongside your team. Product and cloud:
**https://zagents.cnt.me**

The ZAgents source code is closed. This repository exists only so the CLI, the
Desktop app, and the install scripts below can be fetched **anonymously** —
GitHub Releases on a private repo 404 for unauthenticated clients (Homebrew,
`curl | bash`, `zagents update`, and the Desktop auto-updater all need
anonymous access).

## Install the CLI

**Homebrew (macOS/Linux, recommended):**

```bash
brew install ZurabDev/zagents/zagents
```

**curl (macOS/Linux):**

```bash
curl -fsSL https://raw.githubusercontent.com/ZurabDev/zagents-releases/main/install.sh | bash
```

**PowerShell (Windows):**

```powershell
irm https://raw.githubusercontent.com/ZurabDev/zagents-releases/main/install.ps1 | iex
```

After installing, run `zagents setup` to connect to ZAgents Cloud.

## Desktop app

Grab the latest installer for your platform from the
[latest release](https://github.com/ZurabDev/zagents-releases/releases/latest)
(macOS and Linux; Windows builds are temporarily unavailable).

> **Upgrading an older Desktop install?** If you installed ZAgents Desktop
> before this repository existed, your copy's auto-updater still points at the
> old (private) release location and will not auto-update. Download and
> reinstall **once** from the link above — after that, auto-update works
> normally again.

## All releases

CLI archives, Desktop installers, and `checksums.txt` for every release are
published here: https://github.com/ZurabDev/zagents-releases/releases

## Issues

This repository does not host source code — it is a release mirror only. File
bugs and feature requests against this repo's issue tracker.

---

*`install.sh`, `install.ps1`, and this README are synced automatically from
the ZAgents fork on every release. Manual edits here will be overwritten.*
