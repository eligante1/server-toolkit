#!/bin/bash -p

case "$-" in
  *p*) ;;
  *)
    printf 'ERROR: privileged Bash mode is required; execute the verified root-owned mode-0700 script directly.\n' >&2
    exit 125
    ;;
esac

set -Eeuo pipefail
umask 077

bootstrap_die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 125
}

validate_bootstrap_environment() {
  local entry name value required_seen=0

  /usr/bin/env --null >/dev/null || bootstrap_die 'cannot enumerate exported environment'
  while IFS= read -r -d '' entry; do
    [[ "$entry" == *=* ]] || bootstrap_die 'malformed exported environment entry'
    name="${entry%%=*}"
    value="${entry#*=}"
    case "$name" in
      PATH)
        [[ "$value" == '/usr/bin:/bin' ]] || bootstrap_die 'PATH must be exactly /usr/bin:/bin'
        required_seen=$((required_seen + 1))
        ;;
      LC_ALL | LANG)
        [[ "$value" == 'C' ]] || bootstrap_die "$name must be exactly C"
        required_seen=$((required_seen + 1))
        ;;
      HOME)
        [[ "$value" == '/root' ]] || bootstrap_die 'HOME must be exactly /root'
        required_seen=$((required_seen + 1))
        ;;
      TZ)
        [[ "$value" == 'UTC' ]] || bootstrap_die 'TZ must be exactly UTC'
        required_seen=$((required_seen + 1))
        ;;
      PWD)
        [[ "$value" == '/' ]] || bootstrap_die 'official bootstrap must execute from /'
        required_seen=$((required_seen + 1))
        ;;
      SHLVL)
        [[ "$value" =~ ^[0-9]{1,2}$ ]] || bootstrap_die 'invalid SHLVL service value'
        (( 10#$value <= 32 )) || bootstrap_die 'invalid SHLVL service value'
        required_seen=$((required_seen + 1))
        ;;
      _)
        [[ "$value" == '/usr/bin/env' ]] || bootstrap_die 'unexpected exported underscore value'
        required_seen=$((required_seen + 1))
        ;;
      *)
        bootstrap_die "unexpected exported environment variable: $name"
        ;;
    esac
  done < <(/usr/bin/env --null)
  (( required_seen == 8 )) || bootstrap_die 'official bootstrap environment is incomplete'
}

validate_bootstrap_environment
readonly PATH='/usr/bin:/bin'
readonly LC_ALL='C'
readonly LANG='C'
readonly HOME='/root'
readonly TZ='UTC'
export PATH LC_ALL LANG HOME TZ
IFS=$' \t\n'
unset BASH_ENV ENV CDPATH GLOBIGNORE BASH_XTRACEFD TAR_OPTIONS

(( UID == 0 && EUID == 0 )) || bootstrap_die 'official bootstrap must run as real and effective root'
readonly SELF_PATH="$0"
[[ "$SELF_PATH" == /* && "${BASH_SOURCE[0]}" == "$SELF_PATH" ]] || bootstrap_die 'execute this script directly by its absolute path'
readonly SELF_PARENT="${SELF_PATH%/*}"
[[ "$SELF_PARENT" =~ ^/root/\.server-toolkit-bootstrap\.[A-Za-z0-9]{6}$ ]] ||
  bootstrap_die 'installer must run from its exact private root bootstrap directory'
[[ -d /root && ! -L /root ]] || bootstrap_die '/root must be an ordinary non-symlink directory'
ROOT_IDENTITY="$(/usr/bin/stat -c '%u:%g:%a:%h' -- /root 2>/dev/null)" || bootstrap_die 'cannot stat /root identity'
IFS=: read -r root_uid root_gid root_mode root_links <<<"$ROOT_IDENTITY"
[[ "$root_uid" == '0' && "$root_gid" == '0' && "$root_mode" =~ ^[0-7]{3,4}$ ]] ||
  bootstrap_die '/root must be root-owned with a valid mode'
(( (8#$root_mode & 8#022) == 0 )) || bootstrap_die '/root must not be group/world writable'
[[ "$root_links" =~ ^[0-9]+$ ]] || bootstrap_die '/root link count is invalid'
[[ -d "$SELF_PARENT" && ! -L "$SELF_PARENT" ]] || bootstrap_die 'bootstrap directory is missing or a symlink'
SELF_PARENT_IDENTITY="$(/usr/bin/stat -c '%u:%g:%a:%h' -- "$SELF_PARENT" 2>/dev/null)" ||
  bootstrap_die 'cannot stat bootstrap directory identity'
readonly SELF_PARENT_IDENTITY
[[ "$SELF_PARENT_IDENTITY" == '0:0:700:'* ]] ||
  bootstrap_die 'bootstrap directory must be root:root mode 0700'
[[ -f "$SELF_PATH" && ! -L "$SELF_PATH" ]] || bootstrap_die 'installer must be a regular non-symlink file'
SELF_IDENTITY="$(/usr/bin/stat -c '%u:%g:%a:%h' -- "$SELF_PATH" 2>/dev/null)" || bootstrap_die 'cannot stat installer identity'
readonly SELF_IDENTITY
[[ "$SELF_IDENTITY" == '0:0:700:1' ]] || bootstrap_die 'installer must be root:root, mode 0700, with one hard link'

readonly PRODUCT_VERSION='1.0.0'
readonly PACKAGE_NAME='server-toolkit-public-menu-v2.tar.gz.b64'
readonly EXPECTED_B64_SHA256='eedd63793cf4a407e12e071ba1395250269902259be4f15ca2f9322c3b18532d'
readonly EXPECTED_B64_BYTES='214818'
readonly EXPECTED_ARCHIVE_SHA256='c01f90fa0c5f28bcbe0c5c33e2743730389af9179ea7220a17337bbbfd932862'
readonly EXPECTED_ARCHIVE_BYTES='159019'
readonly EXPECTED_MANIFEST_SHA256='8d5d1af1eebf9c2a4d8add03bf658d821825501802afb1648afeda771113aedd'
readonly EXPECTED_INTERNAL_SUMS_SHA256='b3ee90010226a103e28c9c98bedec608fccec59726c0ab165eb2c237fcd37623'
readonly EXPECTED_LAUNCHER_SHA256='d42890704fe40a3b896c863957985a238feab345dfeb46fc1a6c74d4b3006c27'

readonly INSTALL_LIB_DIR='/usr/local/lib/server-toolkit'
readonly TRANSACTION_LIB_DIR='/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5'
readonly MAIN_LAUNCHER='/usr/local/bin/server-toolkit'
readonly LIB_FILE_COUNT=26

readonly -a INSTALL_RELATIVE=(
  'usr/local/lib/server-toolkit/server-toolkit-audit-v1.sh'
  'usr/local/lib/server-toolkit/server-toolkit-audit-v1.sh.sha256'
  'usr/local/lib/server-toolkit/public-menu-controller-v2.sh'
  'usr/local/lib/server-toolkit/public-menu-controller-v2.sh.sha256'
  'usr/local/lib/server-toolkit/public-menu-dispatcher-v2.sh'
  'usr/local/lib/server-toolkit/public-menu-dispatcher-v2.sh.sha256'
  'usr/local/lib/server-toolkit/sonar-presentation-0.4.1-rc4-round2.sh'
  'usr/local/lib/server-toolkit/sonar-presentation-0.4.1-rc4-round2.sh.sha256'
  'usr/local/lib/server-toolkit/server-toolkit-quick-v2.sh'
  'usr/local/lib/server-toolkit/server-toolkit-quick-v2.sh.sha256'
  'usr/local/lib/server-toolkit/server-toolkit-last-report-v2.sh'
  'usr/local/lib/server-toolkit/server-toolkit-last-report-v2.sh.sha256'
  'usr/local/lib/server-toolkit/progress-0.4.1-rc4-round2.sh'
  'usr/local/lib/server-toolkit/progress-0.4.1-rc4-round2.sh.sha256'
  'usr/local/lib/server-toolkit/platform-compatibility-0.4.1-rc4-round2.sh'
  'usr/local/lib/server-toolkit/platform-compatibility-0.4.1-rc4-round2.sh.sha256'
  'usr/local/lib/server-toolkit/pressure-diagnostics-0.4.1-rc4-round2.sh'
  'usr/local/lib/server-toolkit/pressure-diagnostics-0.4.1-rc4-round2.sh.sha256'
  'usr/local/lib/server-toolkit/storage-diagnostics-0.4.1-rc4-round2.sh'
  'usr/local/lib/server-toolkit/storage-diagnostics-0.4.1-rc4-round2.sh.sha256'
  'usr/local/lib/server-toolkit/application-service-diagnostics-0.4.1-rc4-round2.sh'
  'usr/local/lib/server-toolkit/application-service-diagnostics-0.4.1-rc4-round2.sh.sha256'
  'usr/local/lib/server-toolkit/failed-services-policy-0.4.1-rc4-round2.sh'
  'usr/local/lib/server-toolkit/failed-services-policy-0.4.1-rc4-round2.sh.sha256'
  'usr/local/lib/server-toolkit/quick-check-classifier-v2.sh'
  'usr/local/lib/server-toolkit/quick-check-classifier-v2.sh.sha256'
  'usr/local/bin/server-toolkit-audit-v1.sha256'
  'usr/local/bin/server-toolkit.sha256'
  'usr/local/bin/server-toolkit-audit-v1'
  'usr/local/bin/server-toolkit'
)

readonly -a INSTALL_DESTINATION=(
  '/usr/local/lib/server-toolkit/server-toolkit-audit-v1.sh'
  '/usr/local/lib/server-toolkit/server-toolkit-audit-v1.sh.sha256'
  '/usr/local/lib/server-toolkit/public-menu-controller-v2.sh'
  '/usr/local/lib/server-toolkit/public-menu-controller-v2.sh.sha256'
  '/usr/local/lib/server-toolkit/public-menu-dispatcher-v2.sh'
  '/usr/local/lib/server-toolkit/public-menu-dispatcher-v2.sh.sha256'
  '/usr/local/lib/server-toolkit/sonar-presentation-0.4.1-rc4-round2.sh'
  '/usr/local/lib/server-toolkit/sonar-presentation-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/server-toolkit/server-toolkit-quick-v2.sh'
  '/usr/local/lib/server-toolkit/server-toolkit-quick-v2.sh.sha256'
  '/usr/local/lib/server-toolkit/server-toolkit-last-report-v2.sh'
  '/usr/local/lib/server-toolkit/server-toolkit-last-report-v2.sh.sha256'
  '/usr/local/lib/server-toolkit/progress-0.4.1-rc4-round2.sh'
  '/usr/local/lib/server-toolkit/progress-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/server-toolkit/platform-compatibility-0.4.1-rc4-round2.sh'
  '/usr/local/lib/server-toolkit/platform-compatibility-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/server-toolkit/pressure-diagnostics-0.4.1-rc4-round2.sh'
  '/usr/local/lib/server-toolkit/pressure-diagnostics-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/server-toolkit/storage-diagnostics-0.4.1-rc4-round2.sh'
  '/usr/local/lib/server-toolkit/storage-diagnostics-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/server-toolkit/application-service-diagnostics-0.4.1-rc4-round2.sh'
  '/usr/local/lib/server-toolkit/application-service-diagnostics-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/server-toolkit/failed-services-policy-0.4.1-rc4-round2.sh'
  '/usr/local/lib/server-toolkit/failed-services-policy-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/server-toolkit/quick-check-classifier-v2.sh'
  '/usr/local/lib/server-toolkit/quick-check-classifier-v2.sh.sha256'
  '/usr/local/bin/server-toolkit-audit-v1.sha256'
  '/usr/local/bin/server-toolkit.sha256'
  '/usr/local/bin/server-toolkit-audit-v1'
  '/usr/local/bin/server-toolkit'
)

# Same-filesystem transaction names are derived from the frozen manifest.
readonly -a INSTALL_TRANSACTION=(
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/server-toolkit-audit-v1.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/server-toolkit-audit-v1.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/public-menu-controller-v2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/public-menu-controller-v2.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/public-menu-dispatcher-v2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/public-menu-dispatcher-v2.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/sonar-presentation-0.4.1-rc4-round2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/sonar-presentation-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/server-toolkit-quick-v2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/server-toolkit-quick-v2.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/server-toolkit-last-report-v2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/server-toolkit-last-report-v2.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/progress-0.4.1-rc4-round2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/progress-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/platform-compatibility-0.4.1-rc4-round2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/platform-compatibility-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/pressure-diagnostics-0.4.1-rc4-round2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/pressure-diagnostics-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/storage-diagnostics-0.4.1-rc4-round2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/storage-diagnostics-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/application-service-diagnostics-0.4.1-rc4-round2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/application-service-diagnostics-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/failed-services-policy-0.4.1-rc4-round2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/failed-services-policy-0.4.1-rc4-round2.sh.sha256'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/quick-check-classifier-v2.sh'
  '/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5/quick-check-classifier-v2.sh.sha256'
  '/usr/local/bin/.server-toolkit-txn-00f37b3b4ef5-server-toolkit-audit-v1.sha256'
  '/usr/local/bin/.server-toolkit-txn-00f37b3b4ef5-server-toolkit.sha256'
  '/usr/local/bin/.server-toolkit-txn-00f37b3b4ef5-server-toolkit-audit-v1'
  '/usr/local/bin/.server-toolkit-txn-00f37b3b4ef5-server-toolkit'
)

readonly -a INSTALL_MODE=(
  '0700'
  '0644'
  '0644'
  '0644'
  '0755'
  '0644'
  '0644'
  '0644'
  '0700'
  '0644'
  '0700'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0644'
  '0755'
  '0755'
)

scratch=''
scratch_identity=''
declare -a OWNED_PATHS=()
declare -a OWNED_DEV_INODES=()
declare -a OWNED_KINDS=()
declare -a OWNED_EXPECTED_MODES=()
declare -a OWNED_EXPECTED_HASHES=()
declare -a OWNED_ACTIVE=()
declare -a INSTALL_CLAIM_INDEX=()
declare -a INSTALL_EXPECTED_HASH=()
LAST_CLAIM_INDEX=''

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

file_size() {
  local value
  if value="$(/usr/bin/stat -c '%s' -- "$1" 2>/dev/null)"; then
    printf '%s\n' "$value"
  elif value="$(/usr/bin/stat -f '%z' "$1" 2>/dev/null)"; then
    printf '%s\n' "$value"
  else
    return 1
  fi
}

stat_identity() {
  local value
  if value="$(/usr/bin/stat -c '%u:%g:%a:%h' -- "$1" 2>/dev/null)"; then
    printf '%s\n' "$value"
  elif value="$(/usr/bin/stat -f '%u:%g:%Lp:%l' "$1" 2>/dev/null)"; then
    printf '%s\n' "$value"
  else
    return 1
  fi
}

stat_full_identity() {
  local value
  if value="$(/usr/bin/stat -c '%d:%i:%u:%g:%a:%h' -- "$1" 2>/dev/null)"; then
    printf '%s\n' "$value"
  elif value="$(/usr/bin/stat -f '%d:%i:%u:%g:%Lp:%l' "$1" 2>/dev/null)"; then
    printf '%s\n' "$value"
  else
    return 1
  fi
}

require_trusted_directory() {
  local path="$1"
  local identity uid gid mode links

  [[ -d "$path" && ! -L "$path" ]] || die "trusted parent is missing, not a directory, or a symlink: $path"
  identity="$(stat_identity "$path")" || die "cannot stat trusted parent: $path"
  IFS=: read -r uid gid mode links <<<"$identity"
  [[ "$uid" == '0' && "$gid" == '0' ]] || die "trusted parent is not root-owned: $path"
  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || die "unexpected mode from stat for trusted parent: $path"
  (( (8#$mode & 8#022) == 0 )) || die "trusted parent is group/world writable: $path"
  [[ "$links" =~ ^[0-9]+$ ]] || die "unexpected link count from stat for trusted parent: $path"
}

require_no_collision() {
  local path="$1"
  [[ ! -e "$path" && ! -L "$path" ]] || die "installation path already exists: $path"
}

verify_regular_file() {
  local path="$1"
  local expected_mode="$2"
  local expected_hash="$3"
  local identity uid gid mode links actual_hash

  [[ -f "$path" && ! -L "$path" ]] || die "installed path is not a regular non-symlink file: $path"
  identity="$(stat_identity "$path")" || die "cannot stat installed file: $path"
  IFS=: read -r uid gid mode links <<<"$identity"
  [[ "$uid" == '0' && "$gid" == '0' ]] || die "installed file is not root-owned: $path"
  [[ "${mode#0}" == "${expected_mode#0}" ]] || die "unexpected installed mode for $path: $mode"
  [[ "$links" == '1' ]] || die "unexpected hard-link count for installed file: $path"
  actual_hash="$(/usr/bin/sha256sum -- "$path" | /usr/bin/awk '{print $1}')"
  [[ "$actual_hash" == "$expected_hash" ]] || die "installed hash mismatch: $path"
}

add_owned_claim() {
  local path="$1"
  local identity="$2"
  local kind="$3"
  local expected_mode="$4"
  local expected_hash="$5"
  local dev inode uid gid mode links index

  IFS=: read -r dev inode uid gid mode links <<<"$identity"
  [[ "$dev" =~ ^[0-9]+$ && "$inode" =~ ^[0-9]+$ ]] || die "cannot establish owned inode for: $path"
  [[ "$uid" == '0' && "$gid" == '0' ]] || die "new Toolkit object is not root-owned: $path"
  [[ "$mode" =~ ^[0-7]{3,4}$ && "$links" =~ ^[0-9]+$ ]] || die "invalid new Toolkit object identity: $path"
  index="${#OWNED_PATHS[@]}"
  OWNED_PATHS[index]="$path"
  OWNED_DEV_INODES[index]="$dev:$inode"
  OWNED_KINDS[index]="$kind"
  OWNED_EXPECTED_MODES[index]="$expected_mode"
  OWNED_EXPECTED_HASHES[index]="$expected_hash"
  OWNED_ACTIVE[index]=1
  LAST_CLAIM_INDEX="$index"
}

claim_path_has_recorded_inode() {
  local index="$1"
  local path="${OWNED_PATHS[$index]}"
  local identity dev inode uid gid mode links

  [[ -e "$path" || -L "$path" ]] || return 1
  identity="$(stat_full_identity "$path")" || return 1
  IFS=: read -r dev inode uid gid mode links <<<"$identity"
  [[ "$dev:$inode" == "${OWNED_DEV_INODES[$index]}" ]]
}

claim_is_safe_to_remove() {
  local index="$1"
  local path="${OWNED_PATHS[$index]}"
  local kind="${OWNED_KINDS[$index]}"
  local expected_mode="${OWNED_EXPECTED_MODES[$index]}"
  local expected_hash="${OWNED_EXPECTED_HASHES[$index]}"
  local identity dev inode uid gid mode links actual_hash

  claim_path_has_recorded_inode "$index" || return 1
  identity="$(stat_full_identity "$path")" || return 1
  IFS=: read -r dev inode uid gid mode links <<<"$identity"
  [[ "$uid" == '0' && "$gid" == '0' ]] || return 1
  case "$kind" in
    transaction-file)
      [[ -f "$path" && ! -L "$path" && "$links" == '1' ]] || return 1
      [[ "${mode#0}" == '600' || "${mode#0}" == "${expected_mode#0}" ]] || return 1
      actual_hash="$(/usr/bin/sha256sum -- "$path" 2>/dev/null | /usr/bin/awk '{print $1}')" || return 1
      [[ "$actual_hash" == "$expected_hash" ]]
      ;;
    final-file)
      [[ -f "$path" && ! -L "$path" && "$links" == '1' ]] || return 1
      [[ "${mode#0}" == "${expected_mode#0}" ]] || return 1
      actual_hash="$(/usr/bin/sha256sum -- "$path" 2>/dev/null | /usr/bin/awk '{print $1}')" || return 1
      [[ "$actual_hash" == "$expected_hash" ]]
      ;;
    transaction-directory | final-directory)
      [[ -d "$path" && ! -L "$path" ]] || return 1
      [[ "$mode" == '700' || "$mode" == '755' ]]
      ;;
    *)
      return 1
      ;;
  esac
}

cleanup_owned_claims() {
  local index path kind

  for (( index=${#OWNED_PATHS[@]} - 1; index >= 0; index-- )); do
    [[ "${OWNED_ACTIVE[$index]}" == '1' ]] || continue
    path="${OWNED_PATHS[$index]}"
    kind="${OWNED_KINDS[$index]}"
    if [[ ! -e "$path" && ! -L "$path" ]]; then
      OWNED_ACTIVE[index]=0
      continue
    fi
    if ! claim_is_safe_to_remove "$index"; then
      printf 'WARNING: preserving unowned or changed path during rollback: %s\n' "$path" >&2
      continue
    fi
    case "$kind" in
      transaction-file | final-file)
        /bin/rm -f -- "$path" 2>/dev/null || true
        ;;
      transaction-directory | final-directory)
        /bin/rmdir -- "$path" 2>/dev/null || true
        ;;
    esac
    if [[ ! -e "$path" && ! -L "$path" ]]; then
      OWNED_ACTIVE[index]=0
    else
      printf 'WARNING: owned rollback path remains: %s\n' "$path" >&2
    fi
  done
}

create_owned_stage_file() {
  local source_path="$1"
  local transaction="$2"
  local expected_mode="$3"
  local expected_hash="$4"
  local source_identity destination_identity claim_index
  local dev inode uid gid mode links destination_dev destination_inode

  [[ -f "$source_path" && ! -L "$source_path" ]] || die "staging source is not a regular non-symlink file: $source_path"
  source_identity="$(stat_full_identity "$source_path")" || die "cannot stat staging source: $source_path"
  IFS=: read -r dev inode uid gid mode links <<<"$source_identity"
  [[ "$uid" == '0' && "$gid" == '0' && "$mode" == '600' && "$links" == '1' ]] ||
    die "staging source identity is not root:root mode 0600 link-count 1: $source_path"
  [[ "$dev" == "$(/usr/bin/stat -c '%d' -- "${transaction%/*}")" ]] ||
    die "staging source is not on the transaction destination device: $source_path"

  /usr/bin/env -i PATH='/usr/bin:/bin' HOME='/root' LC_ALL='C' LANG='C' TZ='UTC' \
    /usr/bin/mv --no-clobber --no-target-directory -- "$source_path" "$transaction" ||
    die "atomic transaction staging failed: $transaction"
  [[ ! -e "$source_path" && ! -L "$source_path" ]] || die "transaction path collision: $transaction"
  [[ -f "$transaction" && ! -L "$transaction" ]] || die "transaction staging destination is missing or unsafe: $transaction"
  destination_identity="$(stat_full_identity "$transaction")" || die "cannot stat staged transaction file: $transaction"
  IFS=: read -r destination_dev destination_inode uid gid mode links <<<"$destination_identity"
  [[ "$destination_dev:$destination_inode" == "$dev:$inode" ]] ||
    die "staged transaction destination does not have the verified source inode: $transaction"
  add_owned_claim "$transaction" "$source_identity" transaction-file "$expected_mode" "$expected_hash"
  claim_index="$LAST_CLAIM_INDEX"
  claim_path_has_recorded_inode "$claim_index" || die "transaction path inode changed while staging: $transaction"
  verify_regular_file "$transaction" '0600' "$expected_hash"
  /bin/chmod "$expected_mode" "$transaction"
  claim_path_has_recorded_inode "$claim_index" || die "transaction path inode changed before mode verification: $transaction"
  verify_regular_file "$transaction" "$expected_mode" "$expected_hash"
}

move_owned_claim_to_path() {
  local index="$1"
  local destination="$2"
  local final_kind="$3"

  OWNED_PATHS[index]="$destination"
  OWNED_KINDS[index]="$final_kind"
  if ! claim_path_has_recorded_inode "$index"; then
    OWNED_ACTIVE[index]=0
    return 1
  fi
}

cleanup_scratch() {
  local current recorded_dev recorded_inode current_dev current_inode current_uid current_gid current_mode
  if [[ -n "$scratch" && "$scratch" == "$SELF_PARENT/scratch" && -d "$scratch" && ! -L "$scratch" ]]; then
    current="$(stat_full_identity "$scratch" 2>/dev/null || true)"
    IFS=: read -r recorded_dev recorded_inode _ _ _ _ <<<"$scratch_identity"
    IFS=: read -r current_dev current_inode current_uid current_gid current_mode _ <<<"$current"
    if [[ -n "$scratch_identity" && "$current_dev:$current_inode" == "$recorded_dev:$recorded_inode" &&
          "$current_uid" == '0' && "$current_gid" == '0' && "$current_mode" == '700' ]]; then
      /bin/rm -rf -- "$scratch"
    else
      printf 'WARNING: preserving changed private bootstrap scratch path: %s\n' "$scratch" >&2
    fi
  fi
}

on_exit() {
  local rc=$?
  trap - EXIT HUP INT TERM
  if (( rc != 0 )); then
    cleanup_owned_claims
  fi
  cleanup_scratch
  exit "$rc"
}

trap on_exit EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

(( EUID == 0 )) || die 'run this installer as root'
(( $# == 1 )) || die 'usage: install-server-toolkit-1.0.0.sh <immutable raw GitHub commit base URL>'

readonly BASE_URL="$1"
[[ "$BASE_URL" =~ ^https://raw\.githubusercontent\.com/eligante1/server-toolkit/[0-9a-f]{40}/release/public-menu-v2/public$ ]] ||
  die 'base URL must be the exact HTTPS raw GitHub URL pinned to a 40-hex commit'

for cmd in /usr/bin/awk /usr/bin/base64 /usr/bin/curl /usr/bin/env /usr/bin/find /usr/bin/flock \
  /usr/bin/mv /usr/bin/sha256sum /usr/bin/stat /usr/bin/tar /usr/bin/timeout \
  /usr/bin/wc /bin/chmod /bin/chown /bin/mkdir /bin/rm /bin/rmdir; do
  need_command "$cmd"
done

[[ -r /etc/os-release ]] || die '/etc/os-release is not readable'
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in
  ubuntu | debian) ;;
  *) die "unsupported operating system for this test installer: ${ID:-unknown}" ;;
esac

(( ${#INSTALL_RELATIVE[@]} == ${#INSTALL_DESTINATION[@]} )) || die 'internal install inventory length mismatch'
(( ${#INSTALL_RELATIVE[@]} == ${#INSTALL_TRANSACTION[@]} )) || die 'internal transaction inventory length mismatch'
(( ${#INSTALL_RELATIVE[@]} == ${#INSTALL_MODE[@]} )) || die 'internal install mode inventory length mismatch'
[[ "${INSTALL_DESTINATION[${#INSTALL_DESTINATION[@]} - 1]}" == "$MAIN_LAUNCHER" ]] ||
  die 'internal safety invariant failed: main launcher is not last'
for index in "${!INSTALL_DESTINATION[@]}"; do
  if (( index < LIB_FILE_COUNT )); then
    [[ "${INSTALL_DESTINATION[$index]%/*}" == "$INSTALL_LIB_DIR" ]] || die 'unexpected library final path'
    [[ "${INSTALL_TRANSACTION[$index]%/*}" == "$TRANSACTION_LIB_DIR" ]] || die 'unexpected library transaction path'
  else
    [[ "${INSTALL_DESTINATION[$index]%/*}" == "${INSTALL_TRANSACTION[$index]%/*}" ]] ||
      die 'binary transaction path is not in the final destination parent'
  fi
  [[ "${INSTALL_DESTINATION[$index]}" != "${INSTALL_TRANSACTION[$index]}" ]] ||
    die 'transaction and final paths must differ'
  for (( previous=0; previous < index; previous++ )); do
    [[ "${INSTALL_DESTINATION[$previous]}" != "${INSTALL_DESTINATION[$index]}" ]] || die 'duplicate final install path'
    [[ "${INSTALL_TRANSACTION[$previous]}" != "${INSTALL_TRANSACTION[$index]}" ]] || die 'duplicate transaction path'
  done
done

for path in / /usr /usr/local /usr/local/bin /usr/local/lib; do
  require_trusted_directory "$path"
done

exec 9</usr/local/lib
/usr/bin/flock --exclusive --timeout 5 9 || die 'another Server Toolkit install/uninstall transaction holds the coordination lock'

require_no_collision "$INSTALL_LIB_DIR"
require_no_collision "$TRANSACTION_LIB_DIR"
for path in "${INSTALL_DESTINATION[@]}"; do
  require_no_collision "$path"
done
for path in "${INSTALL_TRANSACTION[@]}"; do
  require_no_collision "$path"
done

scratch="$SELF_PARENT/scratch"
[[ ! -e "$scratch" && ! -L "$scratch" ]] || die 'private bootstrap scratch path already exists'
/bin/mkdir -- "$scratch" || die 'cannot create private bootstrap scratch directory'
[[ -d "$scratch" && ! -L "$scratch" ]] || die 'private bootstrap scratch directory is unsafe'
/bin/chmod 0700 "$scratch"
scratch_identity="$(stat_full_identity "$scratch")" || die 'cannot record private bootstrap scratch identity'
[[ "$scratch_identity" == *':0:0:700:'* ]] || die 'private bootstrap scratch must be root:root mode 0700'

readonly B64_PATH="$scratch/$PACKAGE_NAME"
readonly ARCHIVE_PATH="$scratch/server-toolkit-public-menu-v2.tar.gz"
readonly EXTRACT_DIR="$scratch/extracted"
downloaded_bytes="$({
  /usr/bin/env -i PATH='/usr/bin:/bin' LC_ALL='C' LANG='C' \
    /usr/bin/curl \
    --disable \
    --proto '=https' \
    --proto-redir '=https' \
    --tlsv1.2 \
    --fail \
    --silent \
    --show-error \
    --max-redirs 0 \
    --connect-timeout 10 \
    --max-time 60 \
    --max-filesize "$EXPECTED_B64_BYTES" \
    --output "$B64_PATH" \
    --write-out '%{size_download}' \
    "$BASE_URL/$PACKAGE_NAME"
} 2>&1)" || die "package download failed: $downloaded_bytes"
[[ "$downloaded_bytes" == "$EXPECTED_B64_BYTES" ]] || die "download byte count mismatch: $downloaded_bytes"
[[ "$(file_size "$B64_PATH")" == "$EXPECTED_B64_BYTES" ]] || die 'downloaded package size readback mismatch'

printf '%s  %s\n' "$EXPECTED_B64_SHA256" "$B64_PATH" | /usr/bin/sha256sum -c - >/dev/null ||
  die 'base64 package SHA-256 mismatch'

/usr/bin/timeout --signal=TERM --kill-after=2s 15s \
  /usr/bin/env -i PATH='/usr/bin:/bin' LC_ALL='C' LANG='C' \
    /usr/bin/base64 --decode "$B64_PATH" >"$ARCHIVE_PATH" || die 'base64 decode failed or timed out'
[[ "$(file_size "$ARCHIVE_PATH")" == "$EXPECTED_ARCHIVE_BYTES" ]] || die 'decoded archive size mismatch'
printf '%s  %s\n' "$EXPECTED_ARCHIVE_SHA256" "$ARCHIVE_PATH" | /usr/bin/sha256sum -c - >/dev/null ||
  die 'decoded archive SHA-256 mismatch'

/bin/mkdir -- "$EXTRACT_DIR"
/usr/bin/timeout --signal=TERM --kill-after=2s 15s \
  /usr/bin/env -i PATH='/usr/bin:/bin' LC_ALL='C' LANG='C' \
    /usr/bin/tar --extract --gzip --file "$ARCHIVE_PATH" --directory "$EXTRACT_DIR" \
      --no-same-owner --no-same-permissions || die 'archive extraction failed or timed out'

[[ "$(/usr/bin/find "$EXTRACT_DIR" -type f | /usr/bin/wc -l | /usr/bin/awk '{print $1}')" == '32' ]] ||
  die 'unexpected extracted regular-file count'
[[ "$(/usr/bin/find "$EXTRACT_DIR" -type d | /usr/bin/wc -l | /usr/bin/awk '{print $1}')" == '7' ]] ||
  die 'unexpected extracted directory count'
if /usr/bin/find "$EXTRACT_DIR" ! -type f ! -type d -print | /usr/bin/awk 'NF { found=1 } END { exit !found }'; then
  die 'archive contains a non-regular entry'
fi

readonly PACKAGE_ROOT="$EXTRACT_DIR/server-toolkit-public-menu-v2"
[[ -d "$PACKAGE_ROOT" && ! -L "$PACKAGE_ROOT" ]] || die 'expected package root is missing or unsafe'
readonly MANIFEST_PATH="$PACKAGE_ROOT/MANIFEST.json"
readonly INTERNAL_SUMS_PATH="$PACKAGE_ROOT/SHA256SUMS"
readonly EXTRACTED_LAUNCHER="$PACKAGE_ROOT/usr/local/bin/server-toolkit"
printf '%s  %s\n' "$EXPECTED_MANIFEST_SHA256" "$MANIFEST_PATH" | /usr/bin/sha256sum -c - >/dev/null ||
  die 'internal MANIFEST.json SHA-256 mismatch'
printf '%s  %s\n' "$EXPECTED_INTERNAL_SUMS_SHA256" "$INTERNAL_SUMS_PATH" | /usr/bin/sha256sum -c - >/dev/null ||
  die 'internal SHA256SUMS SHA-256 mismatch'
printf '%s  %s\n' "$EXPECTED_LAUNCHER_SHA256" "$EXTRACTED_LAUNCHER" | /usr/bin/sha256sum -c - >/dev/null ||
  die 'launcher SHA-256 mismatch'
(
  cd "$PACKAGE_ROOT"
  /usr/bin/timeout --signal=TERM --kill-after=2s 20s /usr/bin/sha256sum -c SHA256SUMS >/dev/null
) || die 'internal full-file SHA-256 verification failed or timed out'

for relative in "${INSTALL_RELATIVE[@]}"; do
  [[ -f "$PACKAGE_ROOT/$relative" && ! -L "$PACKAGE_ROOT/$relative" ]] || die "missing package file: $relative"
done

# Recheck the trusted parent chain immediately before the first installation write.
for path in / /usr /usr/local /usr/local/bin /usr/local/lib; do
  require_trusted_directory "$path"
done
require_no_collision "$INSTALL_LIB_DIR"
require_no_collision "$TRANSACTION_LIB_DIR"
for path in "${INSTALL_DESTINATION[@]}"; do
  require_no_collision "$path"
done
for path in "${INSTALL_TRANSACTION[@]}"; do
  require_no_collision "$path"
done

/bin/mkdir -- "$TRANSACTION_LIB_DIR" || die "cannot create transaction directory: $TRANSACTION_LIB_DIR"
transaction_directory_identity="$(stat_full_identity "$TRANSACTION_LIB_DIR")" ||
  die 'cannot establish new transaction directory inode'
add_owned_claim "$TRANSACTION_LIB_DIR" "$transaction_directory_identity" transaction-directory '' ''
transaction_directory_claim_index="$LAST_CLAIM_INDEX"
/bin/chown root:root "$TRANSACTION_LIB_DIR"
/bin/chmod 0700 "$TRANSACTION_LIB_DIR"
claim_path_has_recorded_inode "$transaction_directory_claim_index" ||
  die 'transaction library directory inode changed after creation'
[[ "$(stat_identity "$TRANSACTION_LIB_DIR")" == '0:0:700:'* ]] || die 'transaction library directory identity mismatch after creation'
[[ "$(/usr/bin/stat -c '%d' -- "$TRANSACTION_LIB_DIR")" == "$(/usr/bin/stat -c '%d' -- /usr/local/lib)" ]] ||
  die 'transaction library directory is not on the /usr/local/lib device'

for (( index=0; index < LIB_FILE_COUNT; index++ )); do
  source_path="$PACKAGE_ROOT/${INSTALL_RELATIVE[$index]}"
  destination="${INSTALL_DESTINATION[$index]}"
  transaction="${INSTALL_TRANSACTION[$index]}"
  mode="${INSTALL_MODE[$index]}"
  source_hash="$(/usr/bin/sha256sum -- "$source_path" | /usr/bin/awk '{print $1}')"

  require_no_collision "$destination"
  create_owned_stage_file "$source_path" "$transaction" "$mode" "$source_hash"
  INSTALL_CLAIM_INDEX[index]="$LAST_CLAIM_INDEX"
  INSTALL_EXPECTED_HASH[index]="$source_hash"
done

/bin/chmod 0755 "$TRANSACTION_LIB_DIR"
claim_path_has_recorded_inode "$transaction_directory_claim_index" ||
  die 'transaction library directory inode changed before publication'
for (( index=0; index < LIB_FILE_COUNT; index++ )); do
  claim_path_has_recorded_inode "${INSTALL_CLAIM_INDEX[$index]}" ||
    die "library transaction inode changed before publication: ${INSTALL_TRANSACTION[$index]}"
done
[[ "$(stat_identity "$TRANSACTION_LIB_DIR")" == '0:0:755:'* ]] || die 'complete transaction library directory identity mismatch'
require_no_collision "$INSTALL_LIB_DIR"
/usr/bin/env -i PATH='/usr/bin:/bin' HOME='/root' LC_ALL='C' LANG='C' TZ='UTC' \
  /usr/bin/mv --no-clobber --no-target-directory -- "$TRANSACTION_LIB_DIR" "$INSTALL_LIB_DIR" ||
  die 'atomic library publication failed'
[[ ! -e "$TRANSACTION_LIB_DIR" && ! -L "$TRANSACTION_LIB_DIR" ]] || die 'atomic library publication did not consume the transaction directory'
[[ -d "$INSTALL_LIB_DIR" && ! -L "$INSTALL_LIB_DIR" ]] || die 'atomic library publication did not create the final directory'
move_owned_claim_to_path "$transaction_directory_claim_index" "$INSTALL_LIB_DIR" final-directory ||
  die 'published library directory does not have the owned source inode'
[[ "$(stat_identity "$INSTALL_LIB_DIR")" == '0:0:755:'* ]] || die 'published library directory identity mismatch'

publication_claim_error=0
for (( index=0; index < LIB_FILE_COUNT; index++ )); do
  source_path="$PACKAGE_ROOT/${INSTALL_RELATIVE[$index]}"
  destination="${INSTALL_DESTINATION[$index]}"
  mode="${INSTALL_MODE[$index]}"
  source_hash="${INSTALL_EXPECTED_HASH[$index]}"
  if ! move_owned_claim_to_path "${INSTALL_CLAIM_INDEX[$index]}" "$destination" final-file; then
    printf 'WARNING: published library file does not have the owned source inode: %s\n' "$destination" >&2
    publication_claim_error=1
    continue
  fi
  verify_regular_file "$destination" "$mode" "$source_hash"
done
(( publication_claim_error == 0 )) || die 'one or more published library inode claims changed'

# Publish the four /usr/local/bin entries independently and atomically. The
# user-facing launcher is index 29 and therefore remains strictly last.
for (( index=LIB_FILE_COUNT; index < ${#INSTALL_RELATIVE[@]}; index++ )); do
  source_path="$PACKAGE_ROOT/${INSTALL_RELATIVE[$index]}"
  destination="${INSTALL_DESTINATION[$index]}"
  transaction="${INSTALL_TRANSACTION[$index]}"
  mode="${INSTALL_MODE[$index]}"
  source_hash="$(/usr/bin/sha256sum -- "$source_path" | /usr/bin/awk '{print $1}')"

  require_no_collision "$destination"
  create_owned_stage_file "$source_path" "$transaction" "$mode" "$source_hash"
  INSTALL_CLAIM_INDEX[index]="$LAST_CLAIM_INDEX"
  INSTALL_EXPECTED_HASH[index]="$source_hash"
  claim_path_has_recorded_inode "${INSTALL_CLAIM_INDEX[$index]}" ||
    die "transaction path inode changed before publication: $transaction"
  /usr/bin/env -i PATH='/usr/bin:/bin' HOME='/root' LC_ALL='C' LANG='C' TZ='UTC' \
    /usr/bin/mv --no-clobber --no-target-directory -- "$transaction" "$destination" ||
    die "atomic publication failed: $destination"
  [[ ! -e "$transaction" && ! -L "$transaction" ]] || die "atomic publication did not consume transaction path: $transaction"
  move_owned_claim_to_path "${INSTALL_CLAIM_INDEX[$index]}" "$destination" final-file ||
    die "published destination does not have the owned source inode: $destination"
  verify_regular_file "$destination" "$mode" "$source_hash"
done

for path in / /usr /usr/local /usr/local/bin /usr/local/lib "$INSTALL_LIB_DIR"; do
  require_trusted_directory "$path"
done
for path in "${INSTALL_TRANSACTION[@]}" "$TRANSACTION_LIB_DIR"; do
  [[ ! -e "$path" && ! -L "$path" ]] || die "transaction residue remains after successful publication: $path"
done

/usr/bin/timeout --signal=TERM --kill-after=5s 30s \
  /usr/bin/env -i PATH='/usr/bin:/bin' HOME='/root' LC_ALL='C' LANG='C' TZ='UTC' \
    "$MAIN_LAUNCHER" --verify ||
  die 'installed Toolkit closure verification failed or timed out'

printf 'Server Toolkit %s installation verified.\n' "$PRODUCT_VERSION"
