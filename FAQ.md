# FAQ

## The fingerprint device is detected, but enrollment hangs

If `fprintd-enroll` sees the device but does not progress, check:

```bash
journalctl -u fprintd -b --no-pager -n 100
```

On KVADRA NAU LE14U, repeated errors like:

```text
fw9362_Update_Base err,ret=-1
```

were resolved by switching to `alt/focal_spi.c`, rebuilding DKMS, and reloading `focal_spi`.

## GNOME says the fingerprint already exists

This can happen if the fingerprint was previously enrolled under `root`.

Check:

```bash
fprintd-list max
sudo fprintd-list root
```

If needed, delete the root fingerprint:

```bash
sudo fprintd-delete root right-index-finger
```

Then enroll again as the normal desktop user.

## The sensor stops working after reboot

Check:

```bash
lsmod | grep focal_spi
fprintd-verify
```

For this setup, reboot persistence was improved by:
- loading `focal_spi` via `/etc/modules-load.d/focal_spi.conf`
- adding the `focal-fprint-reinit.service` systemd unit

## The sensor stops working after package updates

Check:

```bash
ldd /usr/libexec/fprintd | grep libfprint
dkms status | grep focaltech-spi-dkms
apt-mark showhold
```

Make sure:
- the fingerprint packages are still on hold
- `fprintd` is not using `/usr/local/lib/...`
- the DKMS module is still installed for the current kernel

## Why does this repository use the alternative driver?

On this hardware, the default path was not enough for stable enrollment and verification.  
The tested working setup required switching to:

```text
alt/focal_spi.c
```

## Why are there both English and Russian guides?

The English guide is meant for wider sharing.  
The Russian guide keeps the original detailed workflow and notes.
