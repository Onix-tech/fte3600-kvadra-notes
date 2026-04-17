#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
WORKDIR="${HOME}/FTEXX00-Ubuntu"

REPO_URL="https://github.com/vobademi/FTEXX00-Ubuntu.git"
LIBFPRINT_DEB="libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_spi_amd64_20240620.deb"
LIBFPRINT_URL="https://github.com/oneXfive/ubuntu_spi/raw/main/${LIBFPRINT_DEB}"

FPRINTD_DEB="fprintd_1.94.3-1_amd64.deb"
FPRINTD_URL="http://launchpadlibrarian.net/723052793/${FPRINTD_DEB}"

FPRINTD_DOC_DEB="fprintd-doc_1.94.3-1_all.deb"
FPRINTD_DOC_URL="http://launchpadlibrarian.net/723052789/${FPRINTD_DOC_DEB}"

LIBPAM_FPRINTD_DEB="libpam-fprintd_1.94.3-1_amd64.deb"
LIBPAM_FPRINTD_URL="http://launchpadlibrarian.net/723052795/${LIBPAM_FPRINTD_DEB}"

DKMS_NAME="focaltech-spi-dkms"
DKMS_VERSION="1.0.3"
SERVICE_NAME="focal-fprint-reinit.service"

say() { printf '[*] %s\n' "$*"; }
ok() { printf '[+] %s\n' "$*"; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage:
  sudo ./${SCRIPT_NAME} install
  sudo ./${SCRIPT_NAME} repair
  sudo ./${SCRIPT_NAME} status
  sudo ./${SCRIPT_NAME} unhold

Commands:
  install  Full setup for KVADRA NAU LE14U / Ubuntu 25.10 / FTE3600
  repair   Re-apply the known working setup
  status   Show current state
  unhold   Remove apt hold from fingerprint packages
EOF
}

need_root() {
  [[ "${EUID}" -eq 0 ]] || die "Run with sudo."
}

install_base_packages() {
  say "Installing base packages"
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y \
    git wget curl dkms build-essential linux-headers-$(uname -r) mokutil
}

prepare_repo() {
  say "Preparing repo in ${WORKDIR}"
  if [[ -d "${WORKDIR}/.git" ]]; then
    ok "Repo already exists"
  else
    git clone "${REPO_URL}" "${WORKDIR}"
  fi
  cd "${WORKDIR}"
  chmod +x installspi.sh installlib.sh
}

download_files() {
  cd "${WORKDIR}"
  say "Downloading required files"
  wget -O "${LIBFPRINT_DEB}" "${LIBFPRINT_URL}"
  wget -O "${FPRINTD_DEB}" "${FPRINTD_URL}"
  wget -O "${FPRINTD_DOC_DEB}" "${FPRINTD_DOC_URL}"
  wget -O "${LIBPAM_FPRINTD_DEB}" "${LIBPAM_FPRINTD_URL}"
}

remove_conflicting_local_libfprint() {
  say "Removing conflicting local libfprint from /usr/local if present"
  rm -f /usr/local/lib/x86_64-linux-gnu/libfprint-2.so || true
  rm -f /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2 || true
  if [[ -e /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 ]]; then
    mv /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 /root/
  fi
  if [[ -e /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.bak ]]; then
    mv /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.bak /root/
  fi
  ldconfig
}

install_initial_spi() {
  cd "${WORKDIR}"
  say "Installing initial SPI module"
  ./installspi.sh
}

install_libfprint() {
  cd "${WORKDIR}"
  say "Installing custom libfprint"
  export DEBIAN_FRONTEND=noninteractive
  ./installlib.sh || true
}

install_compatible_fprintd() {
  cd "${WORKDIR}"
  say "Installing compatible fprintd packages"
  dpkg -i --force-overwrite \
    "${FPRINTD_DEB}" \
    "${FPRINTD_DOC_DEB}" \
    "${LIBPAM_FPRINTD_DEB}" || apt -f install -y
}

switch_to_alt_driver() {
  cd "${WORKDIR}"
  say "Switching to alt/focal_spi.c"
  systemctl stop fprintd.service || true
  modprobe -r focal_spi || true
  cp ./alt/focal_spi.c ./focal_spi.c
  dkms remove -m "${DKMS_NAME}" -v "${DKMS_VERSION}" --all || true
  ./installspi.sh
  modprobe focal_spi
}

enable_pam_fprintd() {
  say "Trying to enable PAM fprintd integration"
  if command -v pam-auth-update >/dev/null 2>&1; then
    pam-auth-update --enable fprintd || true
  fi
}

configure_boot_persistence() {
  say "Configuring module auto-load"
  printf 'focal_spi\n' > /etc/modules-load.d/focal_spi.conf

  say "Creating systemd reinit service"
  cat > "/etc/systemd/system/${SERVICE_NAME}" <<'EOF'
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

  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}"
  systemctl start "${SERVICE_NAME}" || true
}

hold_packages() {
  say "Holding fingerprint packages"
  apt-mark hold libfprint-2-2 fprintd fprintd-doc libpam-fprintd
}

unhold_packages() {
  need_root
  apt-mark unhold libfprint-2-2 fprintd fprintd-doc libpam-fprintd || true
}

restart_stack() {
  say "Restarting fprintd"
  systemctl daemon-reload
  systemctl restart fprintd || true
}

status_report() {
  echo
  say "Kernel"
  uname -r || true
  echo
  say "DKMS"
  dkms status | grep -E 'focal|fprint' || true
  echo
  say "Loaded module"
  lsmod | grep focal_spi || true
  echo
  say "SPI devices"
  ls -l /sys/bus/spi/devices 2>/dev/null || true
  echo
  say "Device in /dev"
  ls -l /dev | grep -i focal || true
  echo
  say "libfprint used by fprintd"
  ldd /usr/libexec/fprintd | grep libfprint || true
  echo
  say "Held packages"
  apt-mark showhold | grep -E 'fprintd|libfprint' || true
  echo
  say "Reinit service"
  systemctl status "${SERVICE_NAME}" --no-pager || true
  echo
  say "Next manual steps as normal user:"
  echo "  fprintd-enroll"
  echo "  fprintd-verify"
}

install_flow() {
  need_root
  install_base_packages
  prepare_repo
  download_files
  install_initial_spi
  install_libfprint
  install_compatible_fprintd
  remove_conflicting_local_libfprint
  switch_to_alt_driver
  enable_pam_fprintd
  configure_boot_persistence
  restart_stack
  hold_packages
  status_report
}

repair_flow() {
  need_root
  install_base_packages
  prepare_repo
  download_files
  install_compatible_fprintd
  remove_conflicting_local_libfprint
  switch_to_alt_driver
  configure_boot_persistence
  restart_stack
  hold_packages
  status_report
}

main() {
  [[ $# -ge 1 ]] || { usage; exit 1; }
  case "$1" in
    install) install_flow ;;
    repair) repair_flow ;;
    status) status_report ;;
    unhold) unhold_packages ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
