#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
ZED_CONFIG_DIR="$HOME/.config/zed"
TARGET_BIN="$BIN_DIR/zed-create"

echo "=========================================="
echo " Installing zed-create for Zed (macOS)"
echo "=========================================="

bash "$SCRIPT_DIR/build.sh"

mkdir -p "$BIN_DIR"
cp -f "$SCRIPT_DIR/zed-create" "$TARGET_BIN"
chmod +x "$TARGET_BIN"
echo "==> Installed binary to: $TARGET_BIN"

rm -f "$SCRIPT_DIR/zed-create"

mkdir -p "$ZED_CONFIG_DIR"

python3 - << 'EOF'
import os
import json
import re

config_dir = os.path.expanduser("~/.config/zed")
tasks_file = os.path.join(config_dir, "tasks.json")
keymap_file = os.path.join(config_dir, "keymap.json")
bin_path = os.path.expanduser("~/.local/bin/zed-create")

def strip_json_comments(text):
    return re.sub(r'//.*', '', text)

def load_json(filepath, default):
    if not os.path.exists(filepath):
        return default
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = strip_json_comments(f.read()).strip()
            if not content:
                return default
            return json.loads(content)
    except Exception as e:
        print(f"Warning: Could not parse {filepath} ({e}), creating new.")
        return default

tasks = load_json(tasks_file, [])
if not isinstance(tasks, list):
    tasks = []

task_label = "Create File"
task_entry = {
    "label": task_label,
    "command": bin_path,
    "reveal": "never",
    "hide": "always",
    "allow_concurrent_runs": False
}

existing_idx = next((i for i, t in enumerate(tasks) if isinstance(t, dict) and t.get("label") == task_label), None)
if existing_idx is not None:
    tasks[existing_idx] = task_entry
else:
    tasks.append(task_entry)

with open(tasks_file, 'w', encoding='utf-8') as f:
    json.dump(tasks, f, indent=2)
print(f"==> Configured task (reveal: never, hide: always) in: {tasks_file}")

keymaps = load_json(keymap_file, [])
if not isinstance(keymaps, list):
    keymaps = []

workspace_entry = next((k for k in keymaps if isinstance(k, dict) and k.get("context") == "Workspace"), None)
if workspace_entry is None:
    workspace_entry = {
        "context": "Workspace",
        "bindings": {}
    }
    keymaps.append(workspace_entry)

if "bindings" not in workspace_entry or not isinstance(workspace_entry["bindings"], dict):
    workspace_entry["bindings"] = {}

workspace_entry["bindings"]["cmd-alt-n"] = ["task::Spawn", {"task_name": task_label}]

with open(keymap_file, 'w', encoding='utf-8') as f:
    json.dump(keymaps, f, indent=2)
print(f"==> Configured keybinding (cmd-alt-n) in: {keymap_file}")

EOF

echo "=========================================="
echo " Installation Complete!"
echo ""
echo " Shortcut: Cmd + Option + N (cmd-alt-n)"
echo " Zero terminal windows will open."
echo "=========================================="
