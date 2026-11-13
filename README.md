# MyOS — свой дистрибутив на базе Arch + KDE Plasma

Готовый проект сборки собственного установочного ISO: KDE Plasma,
русский язык по умолчанию, брендинг, оптимизации под отзывчивость
и простой установщик на диск.

```
myos/
├── build.sh              сборка на Arch Linux (sudo ./build.sh)
├── build.ps1             сборка через Docker из Windows
├── SIZE.md               габариты и как уложиться в 6 ГБ
├── packages/
│   ├── base.x86_64       пакеты системы (live + установка)
│   └── live.x86_64       только для live-образа
├── tools/
│   └── make-wallpaper.ps1  генератор обоев
└── iso/                  профиль archiso
    ├── profiledef.sh
    ├── pacman.conf
    ├── efiboot/          загрузка UEFI (systemd-boot)
    ├── syslinux/         загрузка BIOS
    └── airootfs/         файлы, которые попадут в систему
```

## Что получится

- **Live-система**: грузится сразу в KDE, автовход `myos` / пароль `myos`,
  `sudo` без пароля.
- **Установка**: `sudo myos-install /dev/nvme0n1` (UEFI, диск стирается).
- **Своё**: имя MyOS, свой экран входа, обои, тёмная тема, русская локаль.
- **Оптимизации**: zram, `noatime`, низкая задержка композитора,
  отключены анимации KDE и файловый индексатор Baloo, выключена телеметрия
  (в live — через `systemd-timesyncd` только синхронизация времени).

## Требования к сборке

| Что | Значение |
|---|---|
| ОС для сборки | Arch Linux или Docker Desktop |
| Место | ~12 ГБ свободно (готовый ISO ~3 ГБ) |
| RAM | 4 ГБ минимум, 8 ГБ комфортно |
| Время | 20–60 минут |

Собрать в Windows «напрямую» нельзя: archiso работает только на Linux.
Из Windows — через Docker Desktop (`build.ps1`).

> **Важно:** не собирай внутри OneDrive-папки, если не хочешь, чтобы
> гигабайты временных файлов синхронизировались в облако. Скопируй проект
> в `C:\myos` или собери на внешнем диске.

## Сборка

### Вариант 1: Arch Linux

```bash
sudo pacman -S --needed archiso
sudo ./build.sh
```

Результат: `out/myos-<дата>-x86_64.iso`.

Быстрая сборка (больше ISO, меньше времени):

```bash
sudo MYOS_COMPRESS=zstd ./build.sh
```

Мало места на системном диске:

```bash
sudo WORK_DIR=/mnt/ssd/myos-work OUT_DIR=/mnt/ssd/myos-out ./build.sh
```

### Вариант 2: Windows + Docker Desktop

1. Установи Docker Desktop (движок WSL2), дождись запуска.
2. В PowerShell:

```powershell
cd "C:\Users\vafli\OneDrive\Документы\Проект по умолчанию\myos"
.\build.ps1
```

Скрипт создаст контейнер, скопирует туда проект, скачает `archiso`,
соберёт ISO и заберёт его обратно в `out\`. Кириллица и пробелы в пути
не мешают, потому что сборка идёт внутри контейнера, а не на Windows-разделе.

Если свободного места на `C:` мало, укажи другой диск:

```powershell
.\build.ps1 -OutDir "D:\myos-out"
```

Docker Desktop должен иметь доступ к диску с результатом (Settings →
Resources → File sharing).

## Запись на флешку

**Rufus (Windows):** выбери ISO, схема GPT, целевая система UEFI,
режим «ISO-образ». Secure Boot выключи.

**Linux:**

```bash
sudo dd if=out/myos-*.iso of=/dev/sdX bs=8M status=progress oflag=sync
```

`/dev/sdX` — именно флешка, не раздел и не диск с данными.

## Установка

Загрузись с флешки (UEFI), дождись KDE, открой Konsole:

```bash
sudo myos-install /dev/nvme0n1
```

Установщик спросит имя пользователя, пароль, часовой пояс и имя компьютера,
затем:

1. разметит диск (GPT: ESP 1 ГБ + ext4);
2. скачает и установит пакеты (~1.5 ГБ, нужен интернет);
3. настроит локаль, службы, брендинг и оптимизации;
4. поставит systemd-boot;
5. почистит кэш пакетов, чтобы не занимать лишнее.

После установки: вынуть флешку, перезагрузиться, войти своим пользователем.

## Как менять

| Что | Где |
|---|---|
| Набор пакетов | `packages/base.x86_64`, `packages/live.x86_64` |
| Имя, версия, метка ISO | `iso/profiledef.sh` |
| Название системы, локаль, твики | `iso/airootfs/usr/local/bin/myos-configure` |
| Экран входа | там же, блок SDDM |
| Обои | `iso/airootfs/usr/share/wallpapers/MyOS/...` (или `tools/make-wallpaper.ps1`) |
| Пользователь live | `iso/airootfs/usr/local/bin/myos-live-user` |
| Установщик | `iso/airootfs/usr/local/bin/myos-install` |
| Загрузочное меню | `iso/efiboot/`, `iso/syslinux/` |

После правок — снова `sudo ./build.sh`.

## Ограничения

- Только **UEFI**. BIOS-загрузка ISO работает, но установщик ставит
  systemd-boot и GPT — для старых BIOS-машин нужен GRUB, это отдельная доработка.
- **Secure Boot выключен**: образ не подписан.
- NVIDIA: проприетарный драйвер не включён (лицензия/размер). Поставь после
  установки: `sudo pacman -S nvidia-dkms` (или `nvidia-open`).
- Установщик стирает **весь диск** — это осознанное упрощение.
- Данные пользователя и настройки KDE — стандартные для Arch, обновления
  через `pacman -Syu`.

## Если что-то не так

| Симптом | Причина/решение |
|---|---|
| `mkarchiso: command not found` | `sudo pacman -S archiso` |
| «Недостаточно места» | 12 ГБ мало? укажи `WORK_DIR`/`OUT_DIR` на другой диск |
| Не грузится в VirtualBox | включи EFI в настройках VM, отключи Secure Boot |
| Чёрный экран после установки | проверь `bootctl status`, пункт `MyOS` в меню; Secure Boot off |
| Нет Wi-Fi | `nmcli device wifi list`, `nmcli device wifi connect ...` |
| Не работает вход | логи SDDM: `journalctl -u sddm -b` |
| Ошибка пакета при сборке | проверь имя пакета: `pacman -Ss <имя>` |

Логи сборки archiso лежат в `work/` (если собирал с `KEEP_WORK=1`).
