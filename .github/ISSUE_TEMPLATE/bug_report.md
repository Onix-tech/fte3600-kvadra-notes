---
name: Bug report
about: Report a problem with the setup or fingerprint workflow
title: "[Bug] "
---

## Summary

Describe the problem briefly.

## Hardware

- Laptop model:
- Fingerprint sensor:
- BIOS/firmware version (if known):

## System

- Distribution:
- Version:
- Kernel:
- Desktop environment:

## What happened

Describe what you expected and what actually happened.

## Steps to reproduce

1.
2.
3.

## Relevant command output

Paste the output of the following commands if possible:

```bash
lsmod | grep focal_spi
dkms status | grep focaltech-spi-dkms
ldd /usr/libexec/fprintd | grep libfprint
fprintd-verify
journalctl -u fprintd -b --no-pager -n 100