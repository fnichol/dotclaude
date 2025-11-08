# Claude Configuration Castle

Homeshick castle for syncing Claude Code configuration across multiple systems.

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

## Setup

### First Machine (Initial Setup)

```bash
# Castle should already exist if you're reading this
# If not, run the setup script first

# Link the castle files
homeshick link dotclaude

# Sync current plugin versions
~/.claude/bin/sync-plugin-versions

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
~/.claude/bin/verify-plugin-versions
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
~/.claude/bin/sync-plugin-versions

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
~/.claude/bin/verify-plugin-versions
```

Exit codes:
- `0` - All plugins match
- `1` - Missing or mismatched plugins

## Helper Scripts

### sync-plugin-versions

Scans installed plugins and updates `.plugin-versions` with current commit hashes.

**Requirements:** `jq`

**Usage:**
```bash
~/.claude/bin/sync-plugin-versions
```

### verify-plugin-versions

Compares installed plugins against `.plugin-versions` and reports discrepancies.

**Requirements:** `jq`

**Usage:**
```bash
~/.claude/bin/verify-plugin-versions
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

Claude Code downloads plugins automatically on first run when it detects `plugins/config.json` but missing cache. Just start Claude Code normally.

### Version mismatches

Run `~/.claude/bin/verify-plugin-versions` to see differences. Update plugins in Claude Code, then run `~/.claude/bin/sync-plugin-versions` to capture new versions.

### Symlink issues on Windows

Enable Developer Mode in Windows Settings, or run Git Bash/terminal as Administrator when running `homeshick link dotclaude`.

## Repository Structure

```
dotclaude/
├── .gitignore              # Excludes machine-specific data
├── .gitattributes          # Normalizes line endings
├── README.md               # This file
└── home/
    └── .claude/
        ├── CLAUDE.md       # Global instructions
        ├── settings.json   # User settings
        ├── bin/
        │   ├── sync-plugin-versions     # Capture plugin versions
        │   └── verify-plugin-versions   # Verify plugin versions
        └── plugins/
            ├── config.json              # Plugin config
            ├── known_marketplaces.json  # Marketplace registry
            └── .plugin-versions         # Plugin version tracking
```

## License

Your preferred license here.
