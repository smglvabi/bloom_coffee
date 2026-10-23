#!/usr/bin/env bash
# Works with the Bash 3.2 included in macOS. Never changes signing credentials.
set -euo pipefail

ROOT_DIR="$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${BLOOM_FLUTTER:-flutter}"
cd "$ROOT_DIR"

fail() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }
require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$2"
}
require_flutter() {
  require_command "$FLUTTER_BIN" 'Flutter не найден. Добавьте flutter/bin в PATH или задайте BLOOM_FLUTTER=/путь/к/flutter.'
}
flutter_cmd() {
  # SDK freshness checks can wait on git fetch before the command does any work.
  # This skips only the update check; artifact and package verification stay on.
  "$FLUTTER_BIN" --no-version-check "$@"
}
progress() { printf '\n%s\n' "$*" >&2; }
require_mac() {
  [ "$(uname -s)" = Darwin ] || fail 'Сборка и запуск iOS требуют Mac с Xcode. Проверки кода: bash tool/ios.sh check.'
  require_command xcode-select 'Установите Xcode и его Command Line Tools.'
  require_command xcodebuild 'Установите полный Xcode из App Store.'
  require_command xcrun 'Установите Command Line Tools через Xcode → Settings → Locations.'
  xcode-select -p >/dev/null 2>&1 || fail 'Выберите Xcode в Xcode → Settings → Locations → Command Line Tools.'
  xcodebuild -version >/dev/null 2>&1 || fail 'Откройте Xcode, завершите установку компонентов и выберите его в Settings → Locations → Command Line Tools.'
}
require_python() {
  require_command python3 'Нужен python3 для чтения списка устройств. Установите Command Line Tools через Xcode → Settings → Locations.'
}
prepare() {
  require_flutter
  require_mac
  progress '1/3: Загрузка компонентов Flutter для iOS…'
  flutter_cmd precache --ios
  progress '2/3: Установка закреплённых зависимостей…'
  flutter_cmd pub get --enforce-lockfile
  progress '3/3: Подготовка проекта Xcode…'
  flutter_cmd build ios --config-only --no-codesign
}
usage() {
  cat <<'HELP'
Bloom — запуск на Mac и iPhone

  bash tool/ios.sh doctor             Проверить Xcode, Flutter и устройства
  bash tool/ios.sh prepare            Подготовить iOS-зависимости и конфигурацию Xcode
  bash tool/ios.sh simulator [UDID]    Запустить iPhone 16 Pro в симуляторе
  bash tool/ios.sh device [UDID]       Запустить release на подключённом iPhone
  bash tool/ios.sh check              Выполнить анализатор и тесты

Без UDID выбирается единственный подключённый физический iPhone.
Для simulator без UDID используется iPhone 16 Pro в новейшем установленном iOS runtime.
Подпись: ios/Runner.xcworkspace → Runner → Signing & Capabilities → ваша Team.
HELP
}

select_phone() {
  flutter_cmd devices --machine | python3 -c '
import json, sys
try:
    devices = [d for d in json.load(sys.stdin) if d.get("targetPlatform") == "ios" and not d.get("emulator", False) and d.get("isSupported", True)]
except (ValueError, TypeError) as error:
    sys.exit("Не удалось прочитать список устройств Flutter: " + str(error))
requested = sys.argv[1]
if requested:
    devices = [d for d in devices if d.get("id") == requested]
if len(devices) == 1:
    print(devices[0]["id"])
elif not devices:
    sys.exit("Физический iPhone не найден. Подключите его кабелем, разблокируйте, подтвердите доверие Mac и включите Режим разработчика в Настройки → Конфиденциальность и безопасность. Проверьте flutter devices.")
else:
    sys.stderr.write("Найдено несколько iPhone. Повторите bash tool/ios.sh device UDID:\n")
    for d in devices:
        sys.stderr.write("  " + d.get("name", "iPhone") + "  " + d["id"] + "\n")
    sys.exit(1)
' "${1:-}"
}

select_simulator() {
  xcrun simctl list --json | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except (ValueError, TypeError) as error:
    sys.exit("Не удалось прочитать список симуляторов Xcode: " + str(error))
requested = sys.argv[1]
runtimes = [r for r in data.get("runtimes", []) if r.get("isAvailable", False) and ".iOS-" in r.get("identifier", "")]
def version(runtime):
    return tuple(int(part) for part in runtime.get("version", "0").split("."))
runtimes.sort(key=version, reverse=True)
if not runtimes:
    sys.exit("Нет установленного iOS Simulator runtime. Откройте Xcode → Settings → Components (в старых Xcode — Platforms) и загрузите iOS.")
if requested:
    for runtime in runtimes:
        for device in data.get("devices", {}).get(runtime["identifier"], []):
            if device.get("udid") == requested and device.get("isAvailable", False):
                print("existing|" + device["udid"] + "|" + device.get("state", "Shutdown"))
                sys.exit(0)
    sys.exit("UDID не найден среди доступных iOS-симуляторов. Проверьте xcrun simctl list devices available.")
runtime = runtimes[0]
devices = [d for d in data.get("devices", {}).get(runtime["identifier"], []) if d.get("name") == "iPhone 16 Pro" and d.get("isAvailable", False)]
if devices:
    devices.sort(key=lambda d: d.get("state") != "Booted")
    device = devices[0]
    print("existing|" + device["udid"] + "|" + device.get("state", "Shutdown"))
elif any(d.get("identifier") == "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro" for d in data.get("devicetypes", [])):
    print("create|" + runtime["identifier"] + "|Shutdown")
else:
    sys.exit("В этом Xcode нет модели iPhone 16 Pro. Обновите Xcode или передайте UDID другого iPhone-симулятора.")
' "${1:-}"
}

mode="${1:-help}"
[ "$#" -le 2 ] || { usage >&2; exit 1; }
case "$mode" in
  help|-h|--help) usage ;;
  doctor)
    require_flutter
    require_mac
    xcodebuild -version
    progress 'Версия установленного Flutter (без сетевой проверки обновлений)…'
    flutter_cmd --version
    flutter_cmd doctor -v
    flutter_cmd devices
    ;;
  prepare) prepare ;;
  check)
    require_flutter
    flutter_cmd pub get --enforce-lockfile
    flutter_cmd analyze
    flutter_cmd test
    ;;
  simulator)
    require_flutter
    require_mac
    require_python
    selection="$(select_simulator "${2:-}")"
    IFS='|' read -r kind target state <<< "$selection"
    prepare
    if [ "$kind" = create ]; then
      target="$(xcrun simctl create 'iPhone 16 Pro' com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro "$target")"
    fi
    if [ "$state" != Booted ]; then xcrun simctl boot "$target"; fi
    open -a Simulator
    xcrun simctl bootstatus "$target" -b
    flutter_cmd run -d "$target"
    ;;
  device)
    require_flutter
    require_mac
    require_python
    target="$(select_phone "${2:-}")"
    prepare
    flutter_cmd run --release -d "$target"
    ;;
  *) usage >&2; fail "Неизвестная команда: $mode" ;;
esac
