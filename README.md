# opencode-overlay

> **EN:** A floating overlay chat for [opencode](https://opencode.ai) on KDE Plasma 6 / Wayland,
> summoned by a long-press of the Copilot key. Streaming answers with thinking blocks and tool
> calls, session palette, queued prompts, live token/context usage — in a translucent glass panel
> above all windows. Russian UI. BSD 3-Clause.

Плавающий оверлей-чат для [opencode](https://opencode.ai) поверх всех окон: длинное нажатие
кнопки Copilot — панель всплывает в углу экрана, ещё раз — сворачивается обратно в «звезду».
Сделано для KDE Plasma 6 на Wayland, но подход (Wayland-родитель + XWayland-ребёнок
с WebEngine) переносим и на другие окружения.

## Возможности

- **Мгновенный вызов** — длинное нажатие Meta+F23 (кнопка Copilot) или
  `oc-popup-toggle`; короткое нажатие можно повесить на что-то своё (VPN, мик, что угодно)
- **Полный стриминг** — блоки Thinking с таймером, ответ живым текстом, чипы инструментов
  (`shell`, `edit`, …) с временем выполнения и выхлопом команд
- **Сессии** — палитра Ctrl+P: переключение, пин, переименование, удаление (Del×2),
  автопереименование новых сессий моделью
- **Очередь промптов** — сообщения, отправленные во время генерации, встают в очередь
  (колонка чипов слева) и уходят по одному; Esc при очереди скипает текущий ход
- **Esc как в opencode** — первое нажатие предупреждение, второе остановка генерации
- **Живой счётчик контекста** — `94.7K (47%)`: токены последнего ответа × реальное окно
  модели (данные [models.dev](https://models.dev), кэшируются локально)
- **Команды сервера** — `/init`, `/review`, «Сжать контекст» (compact) прямо из палитры,
  компакция стримится сводкой в чат
- **Продолжение с середины** — открыл попап, а ход уже идёт в TUI? Подхватывается стрим
- **Нативный Wayland** — позиционирование через KWin Scripting, прозрачность, always-on-top;
  web-часть живёт в XWayland-ребёнке (у Qt WebEngine нет per-pixel alpha на Wayland)
- **Холодный старт** — закрыл попап: процесс погас, открыл: свежий запуск без мусора

## Требования

- Linux, KDE Plasma 6 (Wayland) — позиционирование и always-on-top через KWin-скрипты
- Python 3.12+, PySide6 (Qt 6.11+) с модулями WebEngine, WebChannel, DBus
- `opencode` в PATH, запущенный хотя бы раз (попап говорит с его HTTP/SSE-сервисом
  через `~/.local/state/opencode/service.json`)
- XWayland для web-ребёнка (`DISPLAY=:0`)

Fedora: `sudo dnf install python3-pyside6 python3-pyside6-webengine`

## Установка

```bash
git clone https://github.com/yutofur/opencode-overlay.git
cd opencode-overlay
./install.sh
```

`install.sh` раскладывает файлы:

| файл | куда |
|---|---|
| `bin/oc-popup` | `~/.local/bin/oc-popup` |
| `bin/oc-popup-toggle` | `~/.local/bin/oc-popup-toggle` |
| `bin/copilot-key-listener` | `~/.local/bin/copilot-key-listener` (для юнита от root) |
| `web/index.html`, `web/marked.min.js` | `~/.local/share/oc-popup/` |
| `assets/oc-popup.png` | `~/.local/share/icons/hicolor/512x512/apps/` |
| `config.example.json` | `~/.config/oc-popup/config.json` (если ещё нет) |

Запуск руками: `oc-popup-toggle` (поднимет демона и покажет окно).

## Кнопка Copilot (Meta+F23)

Слушатель читает `/dev/input/event*` напрямую, поэтому работает от root:

```bash
sudo cp systemd/copilot-key.service /etc/systemd/system/
sudo sed -i "s/__USER__/$USER/" /etc/systemd/system/copilot-key.service
sudo systemctl daemon-reload && sudo systemctl enable --now copilot-key
```

Порог длинного нажатия и команда короткого — в `~/.config/oc-popup/config.json`:

```json
{
  "width": 608, "height": 820,
  "hold_ms": 600,
  "timeout_s": 300,
  "opencode": "",
  "agent": "build",
  "short_cmd": "~/.local/bin/flclash-toggle"
}
```

`short_cmd` пуст → короткое нажатие игнорируется. `agent` — имя агента opencode
(в своём конфиге opencode можно описать специальный агент с промптом
автопереименования сессий — см. `~/.config/opencode/opencode.json`).

## Конфигурация

| ключ | смысл | по умолчанию |
|---|---|---|
| `width`, `height` | размер панели, px | 608×820 |
| `hold_ms` | порог длинного нажатия | 600 |
| `timeout_s` | таймаут одного хода | 300 |
| `opencode` | путь к бинарнику opencode, если не в PATH | `""` |
| `agent` | агент по умолчанию | `build` |

Состояние (текущая сессия, позиция окна, пины) — в `~/.local/state/oc-popup/state.json`,
лог — `~/.local/state/oc-popup/host.log`.

## Архитектура

Два процесса:

1. **Родитель** (`oc-popup`) — нативное Wayland-окно: «звезда»-орб и позиционирование.
   Говорит с сервисом opencode по HTTP (`/api/session`, `/api/prompt`, `/api/event` SSE),
   поднимает KWin-скрипты для always-on-top/позиции, принимает команды через unix-сокет
   `$XDG_RUNTIME_DIR/oc-popup.sock`.
2. **Ребёнок** (`oc-popup --web`, XWayland) — QtWebEngine со страницей `web/index.html`,
   связь через QWebChannel. На Wayland у WebEngine нет per-pixel alpha, поэтому HTML-часть
   живёт в X-ребёнке, а прозрачная рамка — в родителе.

Внутри страницы: markdown через [marked](https://github.com/markedjs/marked) (MIT),
самописный стрим-рендер (Thinking/ответы/чипы/очередь), палитра Ctrl+P.

## Ограничения

- KDE Plasma 6: KWin-скрипты — основной механизм позиции/слоя (на других DE позиция
  через QML-хаки не сработает, окно просто появится где даст композитор)
- Закрытие попапа гасит оба процесса (холодный старт) — так задумано
- `opencode session export` обрезается в пайпе на 255KB — история читается во временный файл

## Сторонние компоненты

- [marked.js](https://github.com/markedjs/marked) v12.0.2 — MIT, лежит в `web/marked.min.js`

## Лицензия

BSD 3-Clause + шапка об авторстве — см. [LICENSE](LICENSE). © 2026 Yuto.
