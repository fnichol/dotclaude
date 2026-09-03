# dotclaude

[![CI](https://api.cirrus-ci.com/github/fnichol/dotclaude.svg)](https://cirrus-ci.com/github/fnichol/dotclaude)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A personal set of Claude Code configuration for syncing across multiple systems.

|                  |                                                           |
| ---------------: | --------------------------------------------------------- |
|               CI | [![CI](https://api.cirrus-ci.com/github/fnichol/dotclaude.svg)](https://cirrus-ci.com/github/fnichol/dotclaude) |
|          License | [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) |

**Table of Contents**

<!-- toc -->

- [Installation](#installation)
  - [First Machine (Initial Setup)](#first-machine-initial-setup)
  - [Additional Machines](#additional-machines)
- [Usage](#usage)
  - [Pull Latest Configuration](#pull-latest-configuration)
  - [Update Plugin Versions](#update-plugin-versions)
  - [Verify Plugin Versions](#verify-plugin-versions)
  - [Render Settings](#render-settings)
  - [Capture Live Plugin Changes](#capture-live-plugin-changes)
- [What This Syncs](#what-this-syncs)
- [What This Excludes](#what-this-excludes)
- [Local-Only Configuration](#local-only-configuration)
- [Helper Scripts](#helper-scripts)
  - [claude-plugins](#claude-plugins)
- [Cross-Platform Notes](#cross-platform-notes)
  - [Windows](#windows)
  - [Dependencies](#dependencies)
- [Troubleshooting](#troubleshooting)
  - [Plugins not downloading](#plugins-not-downloading)
  - [Version mismatches](#version-mismatches)
  - [Symlink issues on Windows](#symlink-issues-on-windows)
- [Repository Structure](#repository-structure)
- [Issues](#issues)
- [Contributing](#contributing)
- [Authors](#authors)
- [License](#license)

<!-- tocstop -->

## Installation

This project is structured to work with
[homeshick](https://github.com/andsens/homeshick) which uses Git to track
updates and changes.

### First Machine (Initial Setup)

```bash
# Castle should already exist if you're reading this
# If not, run the setup script first

# Link the castle files
homeshick link dotclaude

# Install plugins to match lock file versions
claude-plugins install

# Commit and push
homeshick cd dotclaude
git add -A
git commit -m "Update plugin versions"
git remote add origin git@github.com:USERNAME/dotclaude.git
git push -u origin main
```

### Additional Machines

```bash
# Clone the castle
homeshick clone USERNAME/dotclaude

# Link files
homeshick link dotclaude

# Install plugins to match lock file versions
claude-plugins install

# Verify plugins match expected versions
claude-plugins verify
```

## Usage

### Pull Latest Configuration

```bash
homeshick pull dotclaude
```

### Update Plugin Versions

After updating plugins locally:

```bash
# Update and capture new versions
claude-plugins update

# Review changes
homeshick cd dotclaude
git diff

# Commit and push
git add -A
git commit -m "Update plugin versions"
git push
```

### Verify Plugin Versions

Check if installed plugins match expected versions:

```bash
claude-plugins verify
```

Exit codes:

- `0` - All plugins match
- `1` - Missing or mismatched plugins

`verify` also checks whether `~/.claude/settings.json` still matches what
`settings.base.json` + the local overlay would render (see
[Local-Only Configuration](#local-only-configuration)), without fixing it.

### Render Settings

`claude-plugins install` always renders `~/.claude/settings.json` first, so
you don't normally need to run this separately. It's useful on its own after
hand-editing `settings.base.json` or the local overlay file, when you don't
want to also sync marketplaces/plugins:

```bash
claude-plugins render
```

### Capture Live Plugin Changes

Toggling a plugin via `/plugin` inside Claude Code edits the generated
`~/.claude/settings.json` directly, not `settings.base.json` or the local
overlay - so the next `render` (or `install`) would discard that change.
Before committing, capture any such changes back into the right source file:

```bash
claude-plugins capture
```

For each changed plugin/marketplace entry, you'll be asked whether to route
it into `settings.base.json` (shared, synced to every machine), the local
overlay (this machine only), or skip it. It then re-renders automatically.

## What This Syncs

- `CLAUDE.md` - Global instructions
- `settings.base.json` - Base user settings (plugins, environment
  variables), shared across every machine
- `plugins/config.json` - Plugin configuration
- `plugins/.marketplaces.lock.json` - Marketplaces lock file
- `plugins/.plugins.lock.json` - Plugins lock file
- `.local/bin/` - Helper scripts for plugin management

`~/.claude/settings.json` itself is **not** synced - it's generated on each
machine by `claude-plugins render`/`install` from `settings.base.json` plus
that machine's local overlay (see below).

## What This Excludes

Machine-specific runtime data is excluded via `.gitignore`:

- Conversation history
- Session state
- File history
- Debug logs
- Project-specific data
- Plugin cache (downloaded on each machine)

## Local-Only Configuration

This is a convention specific to this repo, not a Claude Code feature.

`~/.claude/settings.local-overlay.json` holds machine-local additions (e.g.
extra plugins/marketplaces you only want on one computer) that should never
be synced anywhere. It is:

- **Never version-controlled.** It lives directly in your real `$HOME`, not
  in this castle's source tree, so there's nothing to `.gitignore` and no
  risk of it ending up in a commit.
- **Auto-created** as an empty stub the first time you run
  `claude-plugins render` or `install` on a machine, if it doesn't already
  exist:

  ```json
  {
    "enabledPlugins": {},
    "extraKnownMarketplaces": {}
  }
  ```

- **Merged on top of `settings.base.json`** (local overlay wins on any key
  conflict) every time `render`/`install` runs, to produce the real
  `~/.claude/settings.json`.
- **Yours to hand-edit.** Add plugin/marketplace entries here directly for
  anything that should only apply to this one machine.
- **Not backed up by this repo, by design.** If a machine is wiped or
  reinstalled, its local overlay is simply gone. If you want it preserved,
  that's a separate, deliberate choice on your part (e.g. a private note or
  backup), not something `dotclaude` handles.

If you toggle plugins via Claude Code's `/plugin` UI instead of editing
these files directly, run `claude-plugins capture` before committing to
route the change into `settings.base.json` or the local overlay.

## Helper Scripts

### claude-plugins

Unified tool for managing Claude Code plugin marketplaces and installations.

**Requirements:** `jq`, `git`

**Usage:**

```bash
# Install/sync plugins to match lock file versions
claude-plugins install

# Update marketplaces and capture current plugin versions
claude-plugins update

# Verify installed plugins match lock file versions
claude-plugins verify

# Render settings.json from settings.base.json + the local overlay
claude-plugins render

# Capture live settings.json changes back into base or local overlay
claude-plugins capture

# Show help
claude-plugins help
```

**Subcommands:**

- `install` - Sync installed marketplaces and plugins to exact lock file versions (equivalent to old `sync-plugins.sh`)
  - Renders `~/.claude/settings.json` from `settings.base.json` + the local overlay first
  - Automatically detects and adds new marketplaces to the lock file
  - Detects and adds new enabled plugins to the lock file
- `update` - Install/update marketplaces and capture current plugin versions (equivalent to old `update-plugins.sh`)
- `verify` - Verify installed marketplaces and plugins match lock file versions (equivalent to old `verify-plugins.sh`), including whether `settings.json` matches what would be rendered
- `render` - Render `~/.claude/settings.json` from `settings.base.json` + the local overlay, creating an empty local overlay stub if one doesn't exist yet
- `capture` - Route live `settings.json` changes (e.g. from toggling plugins in the `/plugin` UI) into `settings.base.json` or the local overlay, then re-render

**Notes:**

- Only **enabled** plugins (from the rendered `settings.json`) are tracked in the lock files
- Disabled plugins are automatically excluded from sync and verification operations
- When you enable a plugin from a new marketplace, run `claude-plugins install` to add both the marketplace and plugin to the lock files
- Claude Code's internal `known_marketplaces.json`/`installed_plugins.json` files are not public API; `claude-plugins` asserts their expected shape before trusting them and fails loudly if that shape looks unexpected, rather than silently mis-recording drift

## Cross-Platform Notes

### Windows

Requires one of:

- Git Bash
- WSL (Windows Subsystem for Linux)
- MSYS2

Symlinks require:

- Windows Developer Mode enabled, OR
- Administrator privileges

### Dependencies

All platforms need:

- Git
- [Homeshick](https://github.com/andsens/homeshick)
- `jq` (for plugin version scripts)

Install `jq`:

- **Linux:** `apt install jq` / `dnf install jq` / `pacman -S jq`
- **macOS:** `brew install jq`
- **Windows:** `choco install jq` / via package manager in WSL

## Troubleshooting

### Plugins not downloading

Claude Code downloads plugins automatically on first run when it detects
`plugins/config.json` but missing cache. Just start Claude Code normally.

### Version mismatches

Run `claude-plugins verify` to see differences. Update plugins in
Claude Code, then run `claude-plugins update` to capture new versions.

### Settings drift ("DRIFT" from `verify`, or an unrecognized "Unexpected shape" error)

If `claude-plugins verify` reports that `settings.json` differs from what
`settings.base.json` + the local overlay would render, you've likely
toggled a plugin via the `/plugin` UI - run `claude-plugins capture` to
route the change into the right file, then re-verify.

If instead you see an "Unexpected shape" error mentioning
`known_marketplaces.json` or `installed_plugins.json`, Claude Code's
internal file format has likely changed in a way this script doesn't
understand yet. Don't run `install`/`update` against it - open an issue
with your `claude --version` and the error output.

### Symlink issues on Windows

Enable Developer Mode in Windows Settings, or run Git Bash/terminal as
Administrator when running `homeshick link dotclaude`.

## Repository Structure

```
dotclaude/
├── .cirrus.yml             # CI configuration
├── .gitignore              # Excludes machine-specific data
├── .gitattributes          # Normalizes line endings
├── LICENSE.txt             # License file
├── Makefile                # Build automation
├── README.md               # This file
├── vendor/
│   └── mk/                 # Vendored Makefile utilities
│       ├── base.mk
│       ├── json.mk
│       ├── shell.mk
│       └── yaml.mk
└── home/
    ├── .local/
    │   └── bin/
    │       └── claude-plugins          # Unified plugin management tool
    └── .claude/
        ├── CLAUDE.md       # Global instructions
        ├── settings.base.json   # Base user settings, shared everywhere
        └── plugins/
            ├── config.json                  # Plugin config
            ├── .marketplaces.lock.json      # Marketplaces lock file
            └── .plugins.lock.json           # Plugins lock file
```

## Issues

If you have any problems with or questions about this project, please contact us
through a [GitHub issue](https://github.com/fnichol/dotclaude/issues).

## Contributing

You are invited to contribute to new features, fixes, or updates, large or
small; we are always thrilled to receive pull requests, and do our best to
process them as fast as we can.

Before you start to code, we recommend discussing your plans through a [GitHub
issue](https://github.com/fnichol/dotclaude/issues), especially for more
ambitious contributions. This gives other contributors a chance to point you in
the right direction, give you feedback on your design, and help you find out if
someone else is working on the same thing.

## Authors

Created and maintained by [Fletcher Nichol](https://github.com/fnichol)
(<fnichol@nichol.ca>).

## License

Licensed under the MIT license
([LICENSE.txt](https://github.com/fnichol/dotclaude/blob/main/LICENSE.txt) or
<https://opensource.org/licenses/MIT>). Unless you explicitly state otherwise,
any contribution intentionally submitted for inclusion in the work by you, as
defined in the MIT license, shall be licensed as above, without any additional
terms or conditions.
