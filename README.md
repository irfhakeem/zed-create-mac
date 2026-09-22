<div align="center">
  <h1>Zed Create Mac</h1>
  <p><strong>Quickly create new File(s) & Folder(s) in Zed Editor with fuzzy directory matching.</strong></p>
  <p>Native macOS port of the popular VS Code extension <a href="https://github.com/HiDeoo/create">HiDeoo/create</a>.</p>
  <p>Made by <strong>irfhakeem</strong> w/ <strong>Antigravity Gemini</strong></p>
</div>

---

## Overview

In Zed, creating a file usually requires navigating the sidebar tree or manually typing full paths in the File Finder. **Zed Create Mac** brings a lightning-fast, keyboard-driven workflow directly to Zed on macOS:

1. Press **`Cmd + Option + N`** (`cmd-alt-n`) anywhere in Zed.
2. A borderless dark frosted-glass modal (styled to match Zed's Command Palette) appears at the center of your screen. **No terminal panel will ever open.**
3. **Step 1 (Directory Picker)**: Type to fuzzy-search project directories (e.g. `internal` $\rightarrow$ `./internal/domain/`). Use `↑` / `↓` and press `Enter`.
4. **Step 2 (File Name Input)**: Type the file name (e.g. `user.go`, `sub/user.go`, or folder `services/`).
5. Press `Enter`: Intermediate folders are created automatically (`mkdir -p`), and the file immediately opens in Zed!

---

## Features

- **Zero Terminal Interruption**: Runs silently via Zed Tasks using `"reveal": "never"` and `"hide": "always"`—no bottom docks or terminal tabs open.
- **Pure Native AppKit Architecture**: Sub-millisecond (<0.5ms) instantaneous fuzzy filtering on every keystroke.
- **Auto Parent Directory Creation**: `handlers/sub/service.go` creates all missing parent folders automatically.
- **Folder Creation**: Ending with a `/` (e.g. `services/`) creates a directory without creating an empty file.
- **Bash-style Brace Expansion**:
  - `user.{go,sql}` $\rightarrow$ creates `user.go` and `user.sql`.
  - `src/{components,utils}/{index,styles}.{ts,css}` $\rightarrow$ expands and creates all permutations.
- **On-The-Fly Directory Creation**: If you type a folder that doesn't exist yet, you can press Enter to create and use it immediately.
- **Smart Directory Exclusion**: Automatically ignores `.git`, `node_modules`, `.build`, `.next`, `dist`, `target`, `vendor`, and respects `.gitignore`.
- **Automatic Opening**: Calls Zed CLI (`zed <path>`) to instantly open newly created files in your existing window.

---

## Quick Installation

```bash
git clone https://github.com/irfhakeem/zed-create.git
cd zed-create
./install.sh
```

This script:
1. Compiles the native binary using `swiftc -O`.
2. Copies it to `~/.local/bin/zed-create`.
3. Configures `~/.config/zed/tasks.json` with `"reveal": "never"` and `"hide": "always"`.
4. Configures `~/.config/zed/keymap.json` with `cmd-alt-n`.

---

## Keyboard Shortcuts

Inside Zed:
* **`Cmd + Option + N`** (`cmd-alt-n`): Trigger the file & folder creator modal.

Inside the floating modal:
| Key | Action |
| :--- | :--- |
| `↑` / `↓` | Navigate directory search results |
| `Enter` | **Step 1**: Select directory<br>**Step 2**: Create file(s) and open in Zed |
| `Esc` | **Step 1**: Dismiss modal<br>**Step 2**: Go back to directory picker |
| `Click outside` | Dismiss modal |

---

## License

MIT License.
