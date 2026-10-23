#!/usr/bin/env bash
# Установка opencode-overlay в пользовательские директории (~/.local).
# Повторный запуск безопасен: файлы перезаписываются, конфиг не трогается.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="$HOME/.local/bin"
share_dir="$HOME/.local/share/oc-popup"
icon_dir="$HOME/.local/share/icons/hicolor/512x512/apps"
cfg_dir="$HOME/.config/oc-popup"

mkdir -p "$bin_dir" "$share_dir" "$icon_dir" "$cfg_dir"

install -m 755 "$here/bin/oc-popup"              "$bin_dir/oc-popup"
install -m 755 "$here/bin/oc-popup-toggle"       "$bin_dir/oc-popup-toggle"
install -m 755 "$here/bin/copilot-key-listener"  "$bin_dir/copilot-key-listener"

install -m 644 "$here/web/index.html"   "$share_dir/index.html"
install -m 644 "$here/web/marked.min.js" "$share_dir/marked.min.js"

install -m 644 "$here/assets/oc-popup.png" "$icon_dir/oc-popup.png"

if [ ! -f "$cfg_dir/config.json" ]; then
    install -m 644 "$here/config.example.json" "$cfg_dir/config.json"
    echo "конфиг: создан $cfg_dir/config.json"
else
    echo "конфиг: $cfg_dir/config.json уже есть — не трогаю"
fi

echo
echo "готово. проверь зависимости:"
echo "  sudo dnf install python3-pyside6 python3-pyside6-webengine   # Fedora"
echo "запуск: oc-popup-toggle"
echo "кнопка Copilot: см. systemd/ в README"
