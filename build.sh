#!/usr/bin/env bash
# =============================================================================
#  build.sh — сборка ISO MyOS. Запускать на Arch Linux (или в Docker) от root.
#
#  Переменные окружения:
#    WORK_DIR      каталог сборки      (по умолчанию ./work)
#    OUT_DIR       каталог результата   (по умолчанию ./out)
#    KEEP_WORK=1   не удалять work после сборки
#    MYOS_COMPRESS=xz|zstd  сжатие squashfs (по умолчанию xz — меньше ISO)
#    MIN_FREE_GB   минимум свободного места (по умолчанию 12)
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$PWD"
PROFILE="$ROOT/iso"
WORK="${WORK_DIR:-$ROOT/work}"
OUT="${OUT_DIR:-$ROOT/out}"
MIN_FREE_GB="${MIN_FREE_GB:-12}"

if [[ ${EUID} -ne 0 ]]; then
    echo "Запусти от root: sudo ./build.sh"
    exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "mkarchiso не найден. Установи: sudo pacman -S --needed archiso"
    exit 1
fi

[[ -n "$WORK" && "$WORK" != "/" ]] || { echo "Некорректный WORK_DIR: '$WORK'"; exit 1; }
[[ -n "$OUT"  && "$OUT"  != "/" ]] || { echo "Некорректный OUT_DIR: '$OUT'"; exit 1; }
mkdir -p "$(dirname "$WORK")" "$(dirname "$OUT")"
FREE_GB=$(df -BG --output=avail "$(dirname "$WORK")" | tail -n1 | tr -dc '0-9')
if (( ${FREE_GB:-0} < MIN_FREE_GB )); then
    cat <<EOF
Недостаточно места: свободно ${FREE_GB} ГБ, для сборки нужно ~${MIN_FREE_GB} ГБ.

Варианты:
  1. Освободи место или подключи внешний SSD и укажи его:
       sudo WORK_DIR=/mnt/ssd/myos-work OUT_DIR=/mnt/ssd/myos-out ./build.sh
  2. Собери образ на другой машине с Arch Linux / Docker.

Готовый ISO занимает ~3 ГБ — в 6 ГБ он помещается, а вот сборка нет.
EOF
    exit 1
fi

echo "[myos] Генерирую список пакетов для ISO..."
{
    grep -hvE '^[[:space:]]*(#|$)' "$ROOT/packages/base.x86_64"
    grep -hvE '^[[:space:]]*(#|$)' "$ROOT/packages/live.x86_64"
} > "$PROFILE/packages.x86_64"

echo "[myos] Копирую список пакетов для установщика..."
install -Dm644 "$ROOT/packages/base.x86_64" "$PROFILE/airootfs/usr/share/myos/packages.x86_64"

echo "[myos] Включаю live-службу создания пользователя..."
LIVE_WANTS="$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
mkdir -p "$LIVE_WANTS"
ln -sfn /etc/systemd/system/myos-live-setup.service "$LIVE_WANTS/myos-live-setup.service"
# Plasma 6.8 тянет plasma-login-manager. В live-системе нужен только SDDM,
# поэтому жёстко маскируем второй менеджер входа.
ln -sfn /dev/null "$PROFILE/airootfs/etc/systemd/system/plasmalogin.service"
# Дублируем включение служб на уровне профиля: не зависим от того, выполнится ли
# pacman-хук при сборке.
for unit in sddm.service NetworkManager.service bluetooth.service \
            systemd-timesyncd.service systemd-oomd.service; do
    ln -sfn "/usr/lib/systemd/system/$unit" "$LIVE_WANTS/$unit"
done
mkdir -p "$PROFILE/airootfs/etc/systemd/system/timers.target.wants"
ln -sfn /usr/lib/systemd/system/fstrim.timer \
    "$PROFILE/airootfs/etc/systemd/system/timers.target.wants/fstrim.timer"

echo "[myos] Готовлю каталоги..."
rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"

echo "[myos] Сжатие squashfs: ${MYOS_COMPRESS:-xz}"
echo "[myos] Сборка (20-60 минут)..."
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

ISO=$(find "$OUT" -maxdepth 1 -name '*.iso' -printf '%p\n' | head -n1)
if [[ -z "$ISO" ]]; then
    echo "ISO не найден в $OUT"
    exit 1
fi

SIZE_MB=$(du -m "$ISO" | cut -f1)
echo
echo "[myos] Готово: $ISO (${SIZE_MB} МБ)"

if (( SIZE_MB > 6000 )); then
    echo "[myos] ВНИМАНИЕ: ISO больше 6 ГБ. Уменьши список пакетов."
else
    echo "[myos] ISO помещается в 6 ГБ (запас $((6000 - SIZE_MB)) МБ)."
fi

if [[ "${KEEP_WORK:-0}" != "1" ]]; then
    echo "[myos] Удаляю временный каталог сборки (KEEP_WORK=1 чтобы сохранить)..."
    rm -rf "$WORK"
fi

echo "[myos] Записать на флешку: sudo dd if=\"$ISO\" of=/dev/sdX bs=8M status=progress oflag=sync"
