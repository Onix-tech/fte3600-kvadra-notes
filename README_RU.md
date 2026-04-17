# FocalTech FTE3600 на KVADRA NAU LE14U (Ubuntu 25.10)

English version: [README_EN.md](README_EN.md)  
Русская версия: [README_RU.md](README_RU.md)

> Этот репозиторий опирается на исходный проект **vobademi/FTEXX00-Ubuntu**.  
> Исходный проект: https://github.com/vobademi/FTEXX00-Ubuntu
>
> Здесь собрана проверенная рабочая схема для ноутбука **KVADRA NAU LE14U** с датчиком **FocalTech FTE3600** на **Ubuntu 25.10**, включая дополнительные заметки, диагностику и практический сценарий установки.

# Инструкция и памятка

Подробное руководство по запуску датчика отпечатка **FocalTech FTE3600** на ноутбуке **KVADRA NAU LE14U** под **Ubuntu 25.10**.

Этот документ основан на реально рабочей последовательности действий, проверенной на данном ноутбуке.

## Что в итоге оказалось рабочим

Рабочая комбинация для **KVADRA NAU LE14U + Ubuntu 25.10 + FTE3600**:

- репозиторий: `FTEXX00-Ubuntu`
- модуль SPI: **обязательно с альтернативным файлом `alt/focal_spi.c`**
- библиотека `libfprint`: **большой пакет**
  `libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_spi_amd64_20240620.deb`
- пакеты user-space:
  - `fprintd_1.94.3-1_amd64.deb`
  - `fprintd-doc_1.94.3-1_all.deb`
  - `libpam-fprintd_1.94.3-1_amd64.deb`
- критически важно, чтобы `fprintd` использовал **системную** `libfprint`, а не чужую копию из `/usr/local/lib/x86_64-linux-gnu/`

## Самые важные выводы заранее

Если хочется коротко:

1. Клонируем `FTEXX00-Ubuntu`
2. Скачиваем **правильный** `libfprint`-пакет `...20240620.deb`
3. Ставим совместимые `fprintd 1.94.3-1`
4. Удаляем конфликтующую `libfprint` из `/usr/local/lib/x86_64-linux-gnu/`, если она там есть
5. Меняем `focal_spi.c` на `alt/focal_spi.c`
6. Пересобираем DKMS-модуль
7. Проверяем `fprintd-enroll` и `fprintd-verify`

---

# 1. Подготовка

## 1.1. Что нужно

Открыть терминал и работать с правами `root` или через `sudo`.

## 1.2. Поставить базовые пакеты

```bash
sudo apt update
sudo apt install -y git dkms build-essential linux-headers-$(uname -r) mokutil
```

## 1.3. Клонировать репозиторий

```bash
cd ~
git clone https://github.com/vobademi/FTEXX00-Ubuntu.git
cd FTEXX00-Ubuntu
```

---

# 2. Нужные файлы

## 2.1. Скачать рабочий `libfprint`

Скачать именно этот файл:

```bash
wget https://github.com/oneXfive/ubuntu_spi/raw/main/libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_spi_amd64_20240620.deb
```

## 2.2. Скачать совместимые пакеты `fprintd`

```bash
wget http://launchpadlibrarian.net/723052793/fprintd_1.94.3-1_amd64.deb
wget http://launchpadlibrarian.net/723052789/fprintd-doc_1.94.3-1_all.deb
wget http://launchpadlibrarian.net/723052795/libpam-fprintd_1.94.3-1_amd64.deb
```

---

# 3. Установка SPI-драйвера

## 3.1. Сделать скрипты исполняемыми

```bash
chmod +x installspi.sh installlib.sh
```

## 3.2. Сначала поставить обычный модуль

```bash
./installspi.sh
```

## 3.3. Проверить, что модуль загрузился

```bash
lsmod | grep focal_spi
```

Если видна строка с `focal_spi`, модуль есть.

---

# 4. Установка `libfprint`

## 4.1. Оставить в папке только нужный `.deb`

Если в каталоге лежит несколько `libfprint`-пакетов, для этой модели нужен именно:

```text
libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_spi_amd64_20240620.deb
```

## 4.2. Запустить установочный скрипт

```bash
./installlib.sh
```

Если появится экран **PAM configuration**, нужно включить:

- `Fingerprint authentication`

и нажать `OK`.

---

# 5. Поставить совместимые версии `fprintd`

Для Ubuntu 25.10 системные версии могут конфликтовать с этой сборкой `libfprint`.

Поэтому ставим совместимые версии:

```bash
sudo dpkg -i --force-overwrite \
  fprintd_1.94.3-1_amd64.deb \
  fprintd-doc_1.94.3-1_all.deb \
  libpam-fprintd_1.94.3-1_amd64.deb
```

---

# 6. Очень важная проверка: нет ли чужой `libfprint` в `/usr/local`

Это был главный скрытый конфликт.

## 6.1. Проверить, откуда `fprintd` берёт библиотеку

```bash
ldd /usr/libexec/fprintd | grep libfprint
```

### Правильно

Должно быть что-то вроде:

```text
libfprint-2.so.2 => /lib/x86_64-linux-gnu/libfprint-2.so.2
```

или путь через `/usr/lib/x86_64-linux-gnu/...`

### Неправильно

Если увидишь:

```text
/usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2
```

значит используется чужая библиотека, и это нужно исправить.

## 6.2. Если в `/usr/local` лежит старая `libfprint`

Проверка:

```bash
ls -l /usr/local/lib/x86_64-linux-gnu/libfprint-2.so*
```

Если файлы есть, их нужно убрать:

```bash
sudo rm -f /usr/local/lib/x86_64-linux-gnu/libfprint-2.so
sudo rm -f /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2
sudo mv /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 /root/ 2>/dev/null || true
sudo mv /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.bak /root/ 2>/dev/null || true
sudo ldconfig
```

Потом снова проверить:

```bash
ldd /usr/libexec/fprintd | grep libfprint
```

---

# 7. Для KVADRA NAU LE14U обязательно использовать `alt/focal_spi.c`

На этом ноутбуке после обычной установки датчик определялся, но считывание зависало. В журнале были ошибки вида:

```text
fw9362_Update_Base err,ret=-1
```

Рабочим оказался только альтернативный вариант драйвера.

## 7.1. Остановить сервис и выгрузить модуль

```bash
sudo systemctl stop fprintd.service
sudo modprobe -r focal_spi
```

## 7.2. Подменить исходник на альтернативный

```bash
cp ./alt/focal_spi.c ./focal_spi.c
```

## 7.3. Удалить старый DKMS-модуль

```bash
sudo dkms remove -m focaltech-spi-dkms -v 1.0.3 --all
```

## 7.4. Пересобрать и поставить драйвер заново

```bash
./installspi.sh
```

## 7.5. Загрузить модуль

```bash
sudo modprobe focal_spi
lsmod | grep focal_spi
```

---

# 8. Проверка работы

## 8.1. Перезапустить `fprintd`

```bash
sudo systemctl daemon-reload
sudo systemctl restart fprintd
```

## 8.2. Записать отпечаток

Записывать лучше **от имени обычного пользователя**, а не от `root`.

```bash
fprintd-enroll
```

Если система спрашивает палец явно:

```bash
fprintd-enroll right-index-finger
```

Во время записи возможны сообщения:

- `enroll-stage-passed`
- `enroll-swipe-too-short`
- `enroll-completed`

`enroll-swipe-too-short` для этого сенсора не страшно. Главное, чтобы в конце было:

```text
Enroll result: enroll-completed
```

## 8.3. Проверить распознавание

```bash
fprintd-verify
```

Успешный результат:

```text
Verify result: verify-match (done)
```

---

# 9. Если GNOME пишет, что такой палец уже есть

Такое случилось, когда отпечаток был записан через терминал от имени `root`.

## 9.1. Проверить отпечатки пользователя `max`

```bash
fprintd-list max
```

## 9.2. Проверить отпечатки `root`

```bash
sudo fprintd-list root
```

## 9.3. Удалить отпечаток у `root`

```bash
sudo fprintd-delete root right-index-finger
```

После этого палец можно заново добавить уже через GNOME.

---

# 10. Быстрая рабочая последовательность команд именно для KVADRA NAU LE14U

Ниже короткая версия под эту модель.

```bash
sudo apt update
sudo apt install -y git dkms build-essential linux-headers-$(uname -r) mokutil

cd ~
git clone https://github.com/vobademi/FTEXX00-Ubuntu.git
cd FTEXX00-Ubuntu

wget https://github.com/oneXfive/ubuntu_spi/raw/main/libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_spi_amd64_20240620.deb
wget http://launchpadlibrarian.net/723052793/fprintd_1.94.3-1_amd64.deb
wget http://launchpadlibrarian.net/723052789/fprintd-doc_1.94.3-1_all.deb
wget http://launchpadlibrarian.net/723052795/libpam-fprintd_1.94.3-1_amd64.deb

chmod +x installspi.sh installlib.sh
./installspi.sh
./installlib.sh

sudo dpkg -i --force-overwrite \
  fprintd_1.94.3-1_amd64.deb \
  fprintd-doc_1.94.3-1_all.deb \
  libpam-fprintd_1.94.3-1_amd64.deb

sudo rm -f /usr/local/lib/x86_64-linux-gnu/libfprint-2.so
sudo rm -f /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2
sudo mv /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 /root/ 2>/dev/null || true
sudo mv /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.bak /root/ 2>/dev/null || true
sudo ldconfig

cp ./alt/focal_spi.c ./focal_spi.c
sudo systemctl stop fprintd.service
sudo modprobe -r focal_spi
sudo dkms remove -m focaltech-spi-dkms -v 1.0.3 --all
./installspi.sh
sudo modprobe focal_spi

sudo systemctl daemon-reload
sudo systemctl restart fprintd

fprintd-enroll
fprintd-verify

sudo apt-mark hold libfprint-2-2 fprintd fprintd-doc libpam-fprintd
echo focal_spi | sudo tee /etc/modules-load.d/focal_spi.conf

sudo tee /etc/systemd/system/focal-fprint-reinit.service > /dev/null <<'EOF'
[Unit]
Description=Reinitialize FocalTech fingerprint after boot
After=multi-user.target systemd-modules-load.service
Wants=systemd-modules-load.service

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'modprobe -r focal_spi || true; modprobe focal_spi; systemctl restart fprintd'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable focal-fprint-reinit.service
sudo systemctl start focal-fprint-reinit.service
```

---

# 11. Что делать после перезагрузки

Обычно после рабочей установки достаточно проверить две команды:

```bash
lsmod | grep focal_spi
fprintd-verify
```

Если всё хорошо, ты увидишь загруженный модуль и успешный `verify-match`.

## 11.1. Для этой модели лучше явно загружать модуль при старте

Добавить файл:

```bash
echo focal_spi | sudo tee /etc/modules-load.d/focal_spi.conf
cat /etc/modules-load.d/focal_spi.conf
```

Это заставит систему явно загружать `focal_spi` при загрузке.

## 11.2. Для этой модели полезен автоперезапуск связки после старта системы

На практике после первого ребута оказалось, что модуль загружается, но иногда датчик начинает стабильно отвечать только после повторной инициализации `focal_spi` и `fprintd`.

Рабочее решение — отдельный systemd-сервис.

Создать файл:

```bash
sudo nano /etc/systemd/system/focal-fprint-reinit.service
```

Содержимое:

```ini
[Unit]
Description=Reinitialize FocalTech fingerprint after boot
After=multi-user.target systemd-modules-load.service
Wants=systemd-modules-load.service

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'modprobe -r focal_spi || true; modprobe focal_spi; systemctl restart fprintd'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Потом включить:

```bash
sudo systemctl daemon-reload
sudo systemctl enable focal-fprint-reinit.service
sudo systemctl start focal-fprint-reinit.service
systemctl status focal-fprint-reinit.service --no-pager
```

Для `oneshot`-сервиса состояние `active (exited)` — это нормально.

## 11.3. Итоговая рабочая схема после ребута

На проверенной конфигурации после ребута успешно работали команды:

```bash
lsmod | grep focal_spi
fprintd-verify
```

С успешным результатом:

```text
Verify result: verify-match (done)
```

# 12. Что делать после обычного обновления системы

## 12.1. Сначала проверить, не сломалось ли

```bash
lsmod | grep focal_spi
fprintd-verify
```

## 12.2. Если отвалилось после обновления

Сначала проверить библиотеку:

```bash
ldd /usr/libexec/fprintd | grep libfprint
```

Потом версию пакетов:

```bash
dpkg -l | grep -E 'fprintd|libfprint'
```

И статус DKMS:

```bash
dkms status | grep focaltech-spi-dkms
```

## 12.3. Что чаще всего ломается

После обновлений обычно ломается одно из трёх:

1. обновился `fprintd` или `libfprint`
2. снова появилась чужая `libfprint` в `/usr/local`
3. модуль `focal_spi` не пересобрался под новое ядро

## 12.4. Полезно зафиксировать пакеты

```bash
sudo apt-mark hold libfprint-2-2 fprintd fprintd-doc libpam-fprintd
```

Если потом потребуется осознанно обновить:

```bash
sudo apt-mark unhold libfprint-2-2 fprintd fprintd-doc libpam-fprintd
```

---

# 13. Что делать после обновления ядра

Проверить текущее ядро:

```bash
uname -r
```

Проверить DKMS:

```bash
dkms status | grep focaltech-spi-dkms
```

Если для нового ядра модуль не собран, пересобрать:

```bash
cd ~/FTEXX00-Ubuntu
sudo dkms remove -m focaltech-spi-dkms -v 1.0.3 --all
./installspi.sh
sudo modprobe focal_spi
```

Потом проверить:

```bash
lsmod | grep focal_spi
fprintd-verify
```

---

# 14. Что делать после переустановки Ubuntu

После переустановки системы нужно считать, что всё делается заново.

## Минимальный план

1. установить зависимости
2. клонировать `FTEXX00-Ubuntu`
3. скачать правильные `.deb`
4. поставить `libfprint`
5. поставить совместимые `fprintd 1.94.3-1`
6. удалить конфликтующую `libfprint` из `/usr/local`, если она появилась
7. заменить `focal_spi.c` на `alt/focal_spi.c`
8. пересобрать DKMS
9. сделать `fprintd-enroll`
10. проверить `fprintd-verify`

Проще всего использовать раздел **10** из этого файла как чеклист.

---

# 15. Диагностика и полезные команды

## Проверка модуля

```bash
lsmod | grep focal_spi
```

## Проверка SPI-устройства

```bash
ls -l /sys/bus/spi/devices
```

Ожидаемо может быть что-то вроде:

```text
spi-FTE3600:00
```

## Проверка привязки драйвера

```bash
readlink -f /sys/bus/spi/devices/spi-FTE3600:00/driver
```

## Проверка устройства в `/dev`

```bash
ls -l /dev | grep -i focal
```

Ожидаемо:

```text
/dev/focal_moh_spi
```

## Проверка журнала `fprintd`

```bash
journalctl -u fprintd -b --no-pager -n 100
```

## Проверка, какой `libfprint` реально используется

```bash
ldd /usr/libexec/fprintd | grep libfprint
```

---

# 16. Симптомы и что они значат

## Симптом: `No devices available`

Обычно это одно из двух:

- неправильная библиотека `libfprint`
- `fprintd` использует не ту библиотеку из `/usr/local`

## Симптом: `Using device ...`, но запись висит

Если `fprintd-enroll` видит устройство, но висит на считывании, а в журнале есть:

```text
fw9362_Update_Base err,ret=-1
```

для **KVADRA NAU LE14U** надо переходить на **`alt/focal_spi.c`**.

## Симптом: GNOME говорит, что палец уже зарегистрирован

Скорее всего отпечаток был записан из-под другого пользователя, часто из-под `root`.

Проверить:

```bash
fprintd-list max
sudo fprintd-list root
```

Удалить у `root`:

```bash
sudo fprintd-delete root right-index-finger
```

---

# 17. Заметка для ИИ-помощника

Если пользователь снова обратится по этой теме, важно помнить следующее:

- ноутбук: **KVADRA NAU LE14U**
- система: **Ubuntu 25.10**
- датчик: **FocalTech FTE3600**
- рабочая схема уже найдена и подтверждена
- обычный `installspi.sh` сам по себе недостаточен
- нужен именно `libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_spi_amd64_20240620.deb`
- нужны совместимые пакеты:
  - `fprintd_1.94.3-1_amd64.deb`
  - `fprintd-doc_1.94.3-1_all.deb`
  - `libpam-fprintd_1.94.3-1_amd64.deb`
- был конфликт с чужой библиотекой в:
  - `/usr/local/lib/x86_64-linux-gnu/libfprint-2.so*`
- пока `fprintd` использовал `/usr/local/lib/...`, датчик не работал правильно
- после переключения на системный `libfprint` устройство определялось
- для нормального считывания пришлось заменить драйвер на `alt/focal_spi.c`
- рабочий результат был подтверждён командами:
  - `fprintd-enroll`
  - `fprintd-verify`
- отпечаток сначала случайно записали для `root`, потом удалили:
  - `sudo fprintd-delete root right-index-finger`

---

# 18. Финальная короткая проверка рабочего состояния

```bash
lsmod | grep focal_spi
ldd /usr/libexec/fprintd | grep libfprint
fprintd-verify
```

Если всё хорошо, должно быть так:

- модуль `focal_spi` загружен
- `libfprint` берётся не из `/usr/local`, а из системного пути
- `fprintd-verify` даёт `verify-match`

