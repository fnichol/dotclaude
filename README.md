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
- [What This Syncs](#what-this-syncs)
- [What This Excludes](#what-this-excludes)
- [Helper Scripts](#helper-scripts)
  - [sync-plugin-versions](#sync-plugin-versions)
  - [verify-plugin-versions](#verify-plugin-versions)
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

# Sync current plugin versions
~/.claude/bin/sync-plugin-versions.sh

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

# Start Claude Code - it will download plugins automatically
claude

# Verify plugins match expected versions
~/.claude/bin/verify-plugin-versions.sh
```

## Usage

### Pull Latest Configuration

```bash
homeshick pull dotclaude
```

### Update Plugin Versions

After updating plugins locally:

```bash
# Capture new versions
~/.claude/bin/sync-plugin-versions.sh

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
~/.claude/bin/verify-plugin-versions.sh
```

Exit codes:

- `0` - All plugins match
- `1` - Missing or mismatched plugins

## What This Syncs

- `CLAUDE.md` - Global instructions
- `settings.json` - User settings (plugins, environment variables)
- `plugins/config.json` - Plugin configuration
- `plugins/known_marketplaces.json` - Marketplace registry
- `plugins/.plugin-versions` - Plugin version tracking
- `bin/` - Helper scripts for plugin management

## What This Excludes

Machine-specific runtime data is excluded via `.gitignore`:

- Conversation history
- Session state
- File history
- Debug logs
- Project-specific data
- Plugin cache (downloaded on each machine)

## Helper Scripts

### sync-plugin-versions

Scans installed plugins and updates `.plugin-versions` with current commit hashes.

**Requirements:** `jq`

**Usage:**

```bash
~/.claude/bin/sync-plugin-versions.sh
```

### verify-plugin-versions.sh

Compares installed plugins against `.plugin-versions` and reports discrepancies.

**Requirements:** `jq`

**Usage:**

```bash
~/.claude/bin/verify-plugin-versions.sh
```

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

Run `~/.claude/bin/verify-plugin-versions.sh` to see differences. Update plugins in
Claude Code, then run `~/.claude/bin/sync-plugin-versions.sh` to capture new
versions.

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
    └── .claude/
        ├── CLAUDE.md       # Global instructions
        ├── settings.json   # User settings
        ├── bin/
        │   ├── sync-plugin-versions.sh     # Capture plugin versions
        │   └── verify-plugin-versions.sh   # Verify plugin versions
        └── plugins/
            ├── config.json              # Plugin config
            ├── known_marketplaces.json  # Marketplace registry
            └── .plugin-versions         # Plugin version tracking
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
