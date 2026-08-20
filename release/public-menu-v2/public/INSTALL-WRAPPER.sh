#!/bin/bash -p

case "$-" in
  *p*) ;;
  *) printf 'ERROR: protected Bash mode is required.\n' >&2; exit 125 ;;
esac
set -Eeuo pipefail
umask 077
cd /

[[ "$(/usr/bin/id -u)" == '0' ]] || { printf 'ERROR: root required.\n' >&2; exit 1; }
(( $# == 1 )) || { printf 'ERROR: usage: INSTALL-WRAPPER.sh <immutable raw GitHub commit base URL>.\n' >&2; exit 78; }
readonly BASE="$1"
[[ "$BASE" =~ ^https://raw\.githubusercontent\.com/eligante1/server-toolkit/[0-9a-f]{40}/release/public-menu-v2/public$ ]] || {
  printf 'ERROR: publication URL is not an immutable reviewed raw GitHub commit URL.\n' >&2
  exit 78
}
bootstrap_dir=''
bootstrap_key=''

cleanup() {
  local rc=$?
  local current=''
  trap - EXIT HUP INT TERM
  set +e
  if [[ -n "$bootstrap_dir" ]]; then
    current="$(/usr/bin/stat -c '%d:%i:%u:%g:%a' -- "$bootstrap_dir" 2>/dev/null)"
    if [[ -d "$bootstrap_dir" && ! -L "$bootstrap_dir" && "$current" == "$bootstrap_key:0:0:700" ]]; then
      /bin/rm -rf --one-file-system -- "$bootstrap_dir"
      [[ ! -e "$bootstrap_dir" && ! -L "$bootstrap_dir" ]] || rc=1
    else
      printf 'ERROR: preserving changed bootstrap directory.\n' >&2
      rc=1
    fi
  fi
  exit "$rc"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

[[ -d /root && ! -L /root ]] || { printf 'ERROR: /root is unsafe.\n' >&2; exit 1; }
root_identity="$(/usr/bin/stat -c '%u:%g:%a' -- /root)"
IFS=: read -r root_uid root_gid root_mode <<<"$root_identity"
[[ "$root_uid" == '0' && "$root_gid" == '0' && "$root_mode" =~ ^[0-7]{3,4}$ ]] || exit 1
(( (8#$root_mode & 8#022) == 0 )) || { printf 'ERROR: /root is writable by group/world.\n' >&2; exit 1; }

bootstrap_dir="$(/usr/bin/mktemp -d /root/.server-toolkit-bootstrap.XXXXXX)"
[[ "$bootstrap_dir" =~ ^/root/\.server-toolkit-bootstrap\.[A-Za-z0-9]{6}$ ]] || exit 1
[[ "$(/usr/bin/stat -c '%u:%g:%a' -- "$bootstrap_dir")" == '0:0:700' ]] || exit 1
bootstrap_key="$(/usr/bin/stat -c '%d:%i' -- "$bootstrap_dir")"
readonly script="$bootstrap_dir/install-server-toolkit-1.0.0.sh"

/usr/bin/env -i PATH='/usr/bin:/bin' HOME='/root' LANG='C' LC_ALL='C' TZ='UTC' \
  /usr/bin/curl --disable --proto '=https' --proto-redir '=https' --tlsv1.2 \
  --fail --silent --show-error --max-redirs 0 --connect-timeout 10 --max-time 30 \
  --max-filesize 34915 --output "$script" "$BASE/install-server-toolkit-1.0.0.sh"
[[ "$(/usr/bin/stat -c '%u:%g:%a:%h:%s' -- "$script")" == '0:0:600:1:34915' ]] || exit 1
printf '%s  %s\n' '5cad28f389b4db33ce0c72a76030e793543e1b77a19d1b30ecd605b19702bf75' "$script" | /usr/bin/sha256sum -c -
/bin/chown root:root "$script"
/bin/chmod 0700 "$script"
[[ "$(/usr/bin/stat -c '%u:%g:%a:%h:%s' -- "$script")" == '0:0:700:1:34915' ]] || exit 1

set +e
/usr/bin/timeout --signal=TERM --kill-after=5s 180s \
  /usr/bin/env -i PATH='/usr/bin:/bin' HOME='/root' LANG='C' LC_ALL='C' TZ='UTC' PWD='/' \
  /bin/bash -p -- "$script" "$BASE"
rc=$?
if [[ ! -x /usr/bin/pgrep ]]; then
  printf 'ERROR: pgrep is unavailable.\n' >&2
  rc=1
else
  /usr/bin/pgrep -f -- "$bootstrap_dir|/usr/local/bin/server-toolkit|/usr/local/bin/server-toolkit-audit-v1|/usr/local/lib/server-toolkit|/usr/local/lib/\.server-toolkit-txn-33094a242a92|/usr/local/bin/\.server-toolkit-txn-33094a242a92" >/dev/null 2>&1
  pgrep_rc=$?
  case "$pgrep_rc" in
    0) printf 'ERROR: installer process residue detected.\n' >&2; rc=1 ;;
    1) ;;
    *) printf 'ERROR: process residue check failed closed.\n' >&2; rc=1 ;;
  esac
fi
set -e

if (( rc == 0 )); then
  for path in \
    /usr/local/lib/.server-toolkit-txn-33094a242a92 \
    /usr/local/bin/.server-toolkit-txn-33094a242a92-server-toolkit \
    /usr/local/bin/.server-toolkit-txn-33094a242a92-server-toolkit-audit-v1 \
    /usr/local/bin/.server-toolkit-txn-33094a242a92-server-toolkit.sha256 \
    /usr/local/bin/.server-toolkit-txn-33094a242a92-server-toolkit-audit-v1.sha256; do
    if [[ -e "$path" || -L "$path" ]]; then
      printf 'ERROR: install transaction residue remains: %s\n' "$path" >&2
      rc=1
    fi
  done
  for path in /usr/local/bin/server-toolkit /usr/local/bin/server-toolkit-audit-v1 /usr/local/lib/server-toolkit; do
    [[ -e "$path" && ! -L "$path" ]] || { printf 'ERROR: expected installation path is missing or unsafe: %s\n' "$path" >&2; rc=1; }
  done
fi
exit "$rc"
