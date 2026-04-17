# FocalTech FTE3600 on KVADRA NAU LE14U (Ubuntu 25.10)

English version: [README_EN.md](README_EN.md)  
Russian version: [README_RU.md](README_RU.md)

> This repository is based on the original work from **vobademi/FTEXX00-Ubuntu**.  
> Original project: https://github.com/vobademi/FTEXX00-Ubuntu
>
> This repository documents a tested working setup for the **KVADRA NAU LE14U** laptop with the **FocalTech FTE3600** fingerprint sensor on **Ubuntu 25.10**, including additional notes, troubleshooting details, and a helper install workflow.

---

## Tested hardware and OS

- **Laptop:** KVADRA NAU LE14U
- **Fingerprint sensor:** FocalTech FTE3600
- **OS:** Ubuntu 25.10
- **Kernel used during testing:** 6.17.x
- **Fingerprint backend:** `FTEXX00-Ubuntu` project + compatible `libfprint/fprintd` combination

---

## Final working combination

The setup only became stable after using **all** of the following:

- `FTEXX00-Ubuntu` repository
- the **larger** `libfprint` package:

```text
libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_spi_amd64_20240620.deb
```

- compatible userspace packages:

```text
fprintd_1.94.3-1_amd64.deb
fprintd-doc_1.94.3-1_all.deb
libpam-fprintd_1.94.3-1_amd64.deb
```

- removal of a conflicting `libfprint` copy from:

```text
/usr/local/lib/x86_64-linux-gnu/
```

- replacing the kernel driver source with the **alternative** driver file:

```text
alt/focal_spi.c
```

- loading `focal_spi` automatically at boot
- a small systemd service to reinitialize the fingerprint stack after boot

Without the `alt/focal_spi.c` replacement, the device was detected but enrollment/verification stalled.

---

## Symptoms that were observed

### 1. Device not available
Initial state:

```text
No devices available
```

This was caused by a wrong `libfprint` being used and an incompatible package combination.

### 2. Device visible, but enrollment hangs
After the correct library was loaded, the device started to appear:

```text
Using device /net/reactivated/Fprint/Device/0
Enrolling right-index-finger finger.
```

but enrollment did not progress.

Journal output showed repeated errors similar to:

```text
fw9362_Update_Base err,ret=-1
```

This was solved by switching to `alt/focal_spi.c`, rebuilding DKMS, and reloading `focal_spi`.

### 3. GNOME says the finger already exists
This happened because the fingerprint was accidentally enrolled for `root` first.
It was fixed by deleting the root fingerprint and enrolling again in the normal user session.

---

## Important note about `libfprint`

A major hidden issue was that `fprintd` was loading a conflicting local library from:

```text
/usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2
```

instead of the packaged system library from `/lib` or `/usr/lib`.

Check with:

```bash
ldd /usr/libexec/fprintd | grep libfprint
```

If you see `/usr/local/...`, remove the conflicting local library files and run:

```bash
sudo ldconfig
```

---

## Installation outline

### 1. Install dependencies

```bash
sudo apt update
sudo apt install -y git dkms build-essential linux-headers-$(uname -r) mokutil
```

### 2. Clone the repository

```bash
cd ~
git clone https://github.com/vobademi/FTEXX00-Ubuntu.git
cd FTEXX00-Ubuntu
chmod +x installspi.sh installlib.sh
```

### 3. Download the correct files

```bash
wget https://github.com/oneXfive/ubuntu_spi/raw/main/libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_spi_amd64_20240620.deb
wget http://launchpadlibrarian.net/723052793/fprintd_1.94.3-1_amd64.deb
wget http://launchpadlibrarian.net/723052789/fprintd-doc_1.94.3-1_all.deb
wget http://launchpadlibrarian.net/723052795/libpam-fprintd_1.94.3-1_amd64.deb
```

### 4. Install the SPI module once

```bash
./installspi.sh
```

### 5. Install the custom `libfprint`

```bash
./installlib.sh
```

If PAM configuration appears, enable:

- `Fingerprint authentication`

### 6. Install compatible `fprintd` packages

```bash
sudo dpkg -i --force-overwrite \
  fprintd_1.94.3-1_amd64.deb \
  fprintd-doc_1.94.3-1_all.deb \
  libpam-fprintd_1.94.3-1_amd64.deb
```

### 7. Remove conflicting local `libfprint` files

```bash
sudo rm -f /usr/local/lib/x86_64-linux-gnu/libfprint-2.so
sudo rm -f /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2
sudo mv /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 /root/ 2>/dev/null || true
sudo mv /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.bak /root/ 2>/dev/null || true
sudo ldconfig
```

### 8. Switch to the alternative driver

```bash
sudo systemctl stop fprintd.service
sudo modprobe -r focal_spi
cp ./alt/focal_spi.c ./focal_spi.c
sudo dkms remove -m focaltech-spi-dkms -v 1.0.3 --all
./installspi.sh
sudo modprobe focal_spi
```

### 9. Restart the fingerprint stack

```bash
sudo systemctl daemon-reload
sudo systemctl restart fprintd
```

### 10. Enroll and verify fingerprints as the normal user

```bash
fprintd-enroll
fprintd-verify
```

Expected final verification result:

```text
Verify result: verify-match (done)
```

---

## Making it survive reboot

### Load the module at boot

```bash
echo focal_spi | sudo tee /etc/modules-load.d/focal_spi.conf
```

### Reinitialize the stack automatically after boot

Create:

```bash
sudo nano /etc/systemd/system/focal-fprint-reinit.service
```

with:

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

Enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable focal-fprint-reinit.service
sudo systemctl start focal-fprint-reinit.service
```

---

## Preventing breakage after package updates

Pin the working fingerprint packages:

```bash
sudo apt-mark hold libfprint-2-2 fprintd fprintd-doc libpam-fprintd
```

Check:

```bash
apt-mark showhold
```

---

## Quick health checks

### Check whether the module is loaded

```bash
lsmod | grep focal_spi
```

### Check which `libfprint` is actually used

```bash
ldd /usr/libexec/fprintd | grep libfprint
```

### Check DKMS state

```bash
dkms status | grep focaltech-spi-dkms
```

### Verify the sensor

```bash
fprintd-verify
```

---

## Root fingerprint cleanup

If a fingerprint was enrolled under `root` by mistake:

List root fingerprints:

```bash
sudo fprintd-list root
```

Delete the root fingerprint:

```bash
sudo fprintd-delete root right-index-finger
```

Then enroll again as the normal desktop user.

---

## Notes for maintainers / future readers

This setup was tested successfully after:
- removing the conflicting `/usr/local` `libfprint`
- using the **20240620** `libfprint` package instead of the smaller alternative package
- downgrading to compatible `fprintd 1.94.3-1`
- switching to `alt/focal_spi.c`
- adding boot-time reinitialization

On this hardware, simply following the default repository steps was **not enough** for reliable operation.

---

## Suggested ways to publish this

This file can be published as:

- a GitHub Gist
- a `README_EN.md` file in your own repository
- a pull request to the original project
- an issue comment / discussion post with a tested working recipe

A good filename would be:

```text
KVADRA_NAU_LE14U_FTE3600_Ubuntu_25.10_EN.md
```
