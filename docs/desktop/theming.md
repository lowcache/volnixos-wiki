# Theming Engine

The desktop stack uses a global, JSON-based color scheme engine. Configuration and scripts are located in `dots/color-engine/`.

## Themes

Themes are stored in the `themes/` directory as JSON files:
- `amalgamation.json` ("Muted Amalgamation (Detailed)")
- `petrified_spittoon.json` ("Petrified Spittoon (Detailed)")
- `radioactive_slime.json` ("Radioactive Slime")
- `ayu_green.json`
- `ayu_red.json`

!!! note
    `amalgamation.json` serves as the canonical template and master theme. Other themes define their palettes and reference mappings defined in this template.

## Scripts & Engine

The theming tools map JSON palettes onto various applications live:

- `apply_theme.py`: Applies a JSON theme across the system via a `TECHNICAL_MAP`. Targets include Noctalia v5 (`~/.config/noctalia/palettes/volnix.json`), Starship (`starship.toml`), and `kitty` (`current.conf` + `tab_bar.py`). Kitty theming is applied live through a remote control socket (`unix:@mykitty`).
- `check_theme.py`: Validates JSON theme structures. It hard-fails on invalid hex values or dangling mapping references, and warns if roles are missing compared to `amalgamation.json`.
- `make_theme.py`: Generates new JSON themes from hex arguments or a color file. It derives backgrounds, accents, containers, dim variants, and a 16-color terminal set. This script also includes internal validation and an `--apply` flag for immediate deployment.

## Workflow

The engine is primarily operated through direct script invocations (see [Makefile](../tooling/makefile.md)):

```bash
python3 dots/color-engine/check_theme.py <theme.json>
python3 dots/color-engine/apply_theme.py <theme.json> [true]      # 2nd arg = verbose
python3 dots/color-engine/make_theme.py '#1e1e2e' '#cba6f7' --name "My Theme" [--out PATH] [--from FILE] [--apply] [--force]
```

## Application Specifics

### Kitty Terminal Integration

The terminal environment is driven by a Home-Manager generated `kitty.conf` (located in `dots/kitty/`):
- Uses `fish` as the default shell.
- Font is "PunkMono Nerd Font" at size 11, with `symbol_map` settings for Nerd Font PUA ranges.
- Features a beam cursor with a `cursor_trail`.
- Contains a custom bottom tab bar powered by `tab_bar.py`.
- Integrates with the theming engine via `allow_remote_control` and `listen_on unix:@mykitty`.
- Additional colorschemes reside in `dots/kitty_colorschemes/` (e.g., `Custom.conf`, `"Modus Vivendi Tinted.conf"`).

### Fonts

The system designates specific font families for different UI roles:
- **Main**: "Google Sans Flex"
- **Monospace**: "JetBrains Mono NF"
- **Expressive**: "Space Grotesk"
- **Reading**: "Readex Pro"
