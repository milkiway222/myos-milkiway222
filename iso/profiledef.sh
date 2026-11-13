#!/usr/bin/env bash
# shellcheck disable=SC2034
# Профиль archiso для MyOS.

iso_name="myos"
iso_label="MYOS_$(date +%Y%m)"
iso_publisher="MyOS <https://example.org/myos>"
iso_application="MyOS Live"
iso_version="$(date +%Y.%m.%d)"
install_dir="myos"

buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"

airootfs_image_type="squashfs"
# xz даёт минимальный ISO (важно для флешки на 6 ГБ), zstd — быстрее собирается.
# Переключается переменной окружения: MYOS_COMPRESS=zstd sudo ./build.sh
case "${MYOS_COMPRESS:-xz}" in
    zstd) airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M') ;;
    *)    airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M') ;;
esac

kernel_params_x86_64="quiet loglevel=3 nowatchdog"

file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/local/bin/myos-configure"]="0:0:755"
  ["/usr/local/bin/myos-live-user"]="0:0:755"
  ["/usr/local/bin/myos-build-hook"]="0:0:755"
  ["/usr/local/bin/myos-install"]="0:0:755"
  ["/usr/local/bin/myos-set-wallpaper"]="0:0:755"
  ["/usr/share/myos"]="0:0:755"
)
