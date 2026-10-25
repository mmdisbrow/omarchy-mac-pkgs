#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/base-test.sh"

dropin=$ROOT/files/etc/mkinitcpio.conf.d/90-omarchy-mac.conf
encrypt=$ROOT/files/etc/mkinitcpio.conf.d/91-omarchy-mac-encrypt.conf

hooks_after() {
  HOOKS=("$@")
  source "$dropin"
  printf '%s\n' "${HOOKS[*]}"
}

check_hooks() {
  local description=$1 expected=$2 actual
  shift 2
  actual=$(hooks_after "$@")
  [[ $actual == "$expected" ]] || fail "$description: $actual"
  pass "$description"
}

check_hooks 'an existing asahi hook still receives the systemd firmware loader' \
  'base asahi systemd block omarchy-vendorfw filesystems fsck' \
  base asahi systemd block filesystems fsck
check_hooks 'a fresh line receives both firmware hooks before filesystems' \
  'base systemd block asahi omarchy-vendorfw filesystems fsck' \
  base systemd block filesystems fsck
check_hooks 'an existing vendor loader does not hide a missing asahi hook' \
  'base systemd omarchy-vendorfw block asahi filesystems fsck' \
  base systemd omarchy-vendorfw block filesystems fsck
check_hooks 'a complete configuration keeps its order' \
  'base systemd asahi omarchy-vendorfw block filesystems fsck' \
  base systemd asahi omarchy-vendorfw block filesystems fsck
check_hooks 'a line without filesystems still receives missing firmware hooks' \
  'base systemd asahi block omarchy-vendorfw' \
  base systemd asahi block
check_hooks 'hooks already later in the line are not duplicated' \
  'base systemd filesystems asahi omarchy-vendorfw fsck' \
  base systemd filesystems asahi omarchy-vendorfw fsck
check_hooks 'a busybox encrypted line without asahi still receives its runtime hook' \
  'base udev block encrypt asahi filesystems fsck' \
  base udev block encrypt filesystems fsck

after_conversion=$(
  HOOKS=(base asahi udev keyboard keymap consolefont block filesystems fsck)
  source "$dropin"
  source "$encrypt"
  printf '%s\n' "${HOOKS[*]}"
)
[[ $after_conversion == 'base asahi systemd keyboard sd-vconsole block omarchy-vendorfw omarchy-mac-encrypt sd-encrypt filesystems fsck' ]] ||
  fail "an inherited asahi line keeps firmware loading through systemd conversion: $after_conversion"
pass 'an inherited asahi line keeps firmware loading through systemd conversion'

after_busybox=$(
  HOOKS=(base asahi udev keyboard keymap block encrypt filesystems fsck)
  source "$dropin"
  source "$encrypt"
  printf '%s\n' "${HOOKS[*]}"
)
[[ $after_busybox == 'base asahi udev keyboard keymap block encrypt filesystems fsck' ]] ||
  fail "a busybox encrypted Mac keeps its init and unlock hooks: $after_busybox"
pass 'a busybox encrypted Mac keeps its init and unlock hooks'

for initial in 'base asahi systemd block filesystems' 'base systemd block filesystems' \
  'base systemd omarchy-vendorfw block' 'base systemd filesystems asahi omarchy-vendorfw'; do
  read -ra HOOKS <<<"$initial"
  source "$dropin"
  once=${HOOKS[*]}
  source "$dropin"
  [[ ${HOOKS[*]} == "$once" ]] || fail "sourcing the firmware drop-in twice changes the line: $initial"
done
pass 'sourcing the firmware drop-in twice is idempotent'
