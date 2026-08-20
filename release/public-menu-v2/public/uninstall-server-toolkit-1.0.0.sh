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
  bootstrap_die 'uninstaller must run from its exact private root bootstrap directory'
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
[[ -f "$SELF_PATH" && ! -L "$SELF_PATH" ]] || bootstrap_die 'uninstaller must be a regular non-symlink file'
SELF_IDENTITY="$(/usr/bin/stat -c '%u:%g:%a:%h' -- "$SELF_PATH" 2>/dev/null)" || bootstrap_die 'cannot stat uninstaller identity'
readonly SELF_IDENTITY
[[ "$SELF_IDENTITY" == '0:0:700:1' ]] || bootstrap_die 'uninstaller must be root:root, mode 0700, with one hard link'
SELF_PARENT_FULL_IDENTITY="$(/usr/bin/stat -c '%d:%i:%u:%g:%a:%h' -- "$SELF_PARENT" 2>/dev/null)" ||
  bootstrap_die 'cannot record bootstrap directory inode'
readonly SELF_PARENT_FULL_IDENTITY
SELF_FULL_IDENTITY="$(/usr/bin/stat -c '%d:%i:%u:%g:%a:%h' -- "$SELF_PATH" 2>/dev/null)" ||
  bootstrap_die 'cannot record uninstaller inode'
readonly SELF_FULL_IDENTITY
SELF_SHA256="$(/usr/bin/sha256sum -- "$SELF_PATH" 2>/dev/null | /usr/bin/awk '{print $1}')" ||
  bootstrap_die 'cannot hash uninstaller bootstrap bytes'
readonly SELF_SHA256
[[ "$SELF_SHA256" =~ ^[0-9a-f]{64}$ ]] || bootstrap_die 'invalid uninstaller bootstrap hash readback'

readonly PRODUCT_VERSION='1.0.0'
readonly INSTALL_LIB_DIR='/usr/local/lib/server-toolkit'
readonly TRANSACTION_LIB_DIR='/usr/local/lib/.server-toolkit-txn-00f37b3b4ef5'
readonly MAIN_LAUNCHER='/usr/local/bin/server-toolkit'
readonly LIB_KNOWN_FIRST=3
readonly LIB_KNOWN_LAST=28

readonly -a KNOWN_PATHS=(
  '/usr/local/bin/server-toolkit-audit-v1'
  '/usr/local/bin/server-toolkit-audit-v1.sha256'
  '/usr/local/bin/server-toolkit.sha256'
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
  '/usr/local/bin/server-toolkit'
)

readonly -a TRANSACTION_PATHS=(
  '/usr/local/bin/.server-toolkit-txn-00f37b3b4ef5-server-toolkit-audit-v1'
  '/usr/local/bin/.server-toolkit-txn-00f37b3b4ef5-server-toolkit-audit-v1.sha256'
  '/usr/local/bin/.server-toolkit-txn-00f37b3b4ef5-server-toolkit.sha256'
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
  '/usr/local/bin/.server-toolkit-txn-00f37b3b4ef5-server-toolkit'
)

readonly -a KNOWN_HASHES=(
  '64172bba0387d931cbc0fd184f03e2ea8b36d6fe9363935837d5d83c8bfd79ea'
  'bd5b7cd5727ca41bad9966bb0c2cce5bbd51f9cee89859f8fdf3dae0c09b9e66'
  '57b3b10c21d4df92f54d3f97066cbec69bcd5dc755cf6e6b209ae0f6bbdac108'
  '3c944a03f2ef9878843218895d7335eca2210b2c6f7a0d7a13dceaa2e1b87c30'
  '19b1baa5286db1cc8661b4606b0581b98c526c8819c0fc1d6b1341ba9dfd3acf'
  '8c89e8b31c0d62c122ee823930083cb6ad30110bffb0c1811ec8c442d55a3320'
  '5e25d1ea97b4d8927bfdd53bf8ddcdf6a5d2741975e62e1c4af68150fc84e5a3'
  '7d903501eaba54d477b8c8ddfcff672306ac8a6e9429b5c6967656c587c4f0a3'
  '3f7b3b51acf51e1ad56b39aa0dbe3ba6338520e152d42df3155035f74d05bfa2'
  'da163b1b32802a3dd18604905228b27eca88831b5315d940b40c2a0b6b50097e'
  '0d6198b7c61b7f2dbb8c8dd21ed951e02006bf08b657eb5a3c460d56e2ffc215'
  'e00f4d26a1dc49c414eeb1e008ab69db2f698304ba2f4cf21227a2352232de19'
  '6d95eb02caea9a4642a20d4d5f9833ec5349bac79799c821ce58615006fb0f84'
  'b1feb346c49a06bd1cbe895f0e0ce4617a27ea829d9b01c927579f1ecf6e2adf'
  'c1b513cd48f4e3315f147575edadc05c3d83621778acdedd364eb88c609001da'
  '396cbdcb4ecab30635e880e77a5a053173a43af6a209d7b86bdf5ff3f65b7bd6'
  'fd3b582bd2db535d5154537e974cf82d1dac77f9d579ba6341772b4e40cdd8df'
  '785a35c8fca526e9178efe08dda86ef596ec84f4b82b08898d64122d23325271'
  'dc90239b6bcc8af9e4b66ad71bb5bf4fa97d2ab7517736b251aad395b0b3987c'
  '574e1949c98ceed6cb9cc8e2d74124f03bc0c0a2cbd901c8fbb1b7e63f5fba26'
  'a9660e3d5751ed1dce2a24623311671445322c5b0bbd85a0171333a3ffe87aa2'
  'e57fec6b33fd7abfefa1a06496749097cd331d2123a74ccafcd790d7d924cfe9'
  'e9e6b5a354e81711257062528ca356614586bfbb64e9a43824c99a991fb6ce30'
  '9f901b2167ff1a66295bd33a395bfe0e3ffb634d0e2f9fd0895a7644a1dd6f3a'
  'fcca43ba3d57427fe59f6ec1fead5496101af586e635fdfad5c775de5ce0804b'
  '9fa69df50c2e8a0613e828c71839bbf95dcfe2b6528066a442421e92a958cc51'
  '1b7fe2dab5d412d665102b97652521b53c7018c30b7ea4a1773096cfac924d68'
  '758c56b85634b37c1297fc149ccc03f49fd3349ee4b50dd95a6f3f8737184afa'
  'b6b98c6564e32797ac6fc5a3f59a6815009f3f3d06b40f59de068598f40e47b7'
  'd42890704fe40a3b896c863957985a238feab345dfeb46fc1a6c74d4b3006c27'
)

readonly -a KNOWN_MODES=(
  '0755'
  '0644'
  '0644'
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
  '0755'
)

declare -a KNOWN_PRESENT=()
declare -a KNOWN_IDENTITIES=()
declare -a KNOWN_HASH_CLASSES=()
declare -a TRANSACTION_PRESENT=()
declare -a TRANSACTION_IDENTITIES=()
declare -a TRANSACTION_HASH_CLASSES=()
BIN_PARENT_IDENTITY=''
LIB_PARENT_IDENTITY=''
FINAL_DIRECTORY_PRESENT=0
FINAL_DIRECTORY_FULL_IDENTITY=''
TRANSACTION_DIRECTORY_PRESENT=0
TRANSACTION_DIRECTORY_FULL_IDENTITY=''
FINAL_DIRECTORY_EXACT_CHILD_COUNT=0
TRANSACTION_DIRECTORY_EXACT_CHILD_COUNT=0

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
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

  [[ -d "$path" && ! -L "$path" ]] || die "trusted directory is missing, not a directory, or a symlink: $path"
  identity="$(stat_identity "$path")" || die "cannot stat trusted directory: $path"
  IFS=: read -r uid gid mode links <<<"$identity"
  [[ "$uid" == '0' && "$gid" == '0' ]] || die "trusted directory is not root-owned: $path"
  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || die "unexpected mode from stat for trusted directory: $path"
  (( (8#$mode & 8#022) == 0 )) || die "trusted directory is group/world writable: $path"
  [[ "$links" =~ ^[0-9]+$ ]] || die "unexpected link count from stat for trusted directory: $path"
}

validate_known_file() {
  local path="$1"
  local expected_hash="$2"
  local expected_mode="$3"
  local identity uid gid mode links actual_hash

  [[ ! -L "$path" ]] || die "refusing symlink at Toolkit path: $path"
  [[ -f "$path" ]] || die "Toolkit path is not a regular file: $path"
  identity="$(stat_identity "$path")" || die "cannot stat Toolkit file: $path"
  IFS=: read -r uid gid mode links <<<"$identity"
  [[ "$uid" == '0' && "$gid" == '0' ]] || die "Toolkit file is not root-owned: $path"
  [[ "${mode#0}" == "${expected_mode#0}" ]] || die "Toolkit file mode mismatch for $path: $mode"
  [[ "$links" == '1' ]] || die "Toolkit file has an unexpected hard-link count: $path"
  actual_hash="$(/usr/bin/sha256sum -- "$path" | /usr/bin/awk '{print $1}')"
  [[ "$actual_hash" == "$expected_hash" ]] || die "Toolkit file hash mismatch: $path"
}

validate_transaction_file() {
  local path="$1"
  local expected_hash="$2"
  local expected_mode="$3"
  local identity uid gid mode links actual_hash

  [[ ! -L "$path" ]] || die "refusing symlink at transaction path: $path"
  [[ -f "$path" ]] || die "transaction path is not a regular file: $path"
  identity="$(stat_identity "$path")" || die "cannot stat transaction file: $path"
  IFS=: read -r uid gid mode links <<<"$identity"
  [[ "$uid" == '0' && "$gid" == '0' ]] || die "transaction file is not root-owned: $path"
  [[ "$links" == '1' ]] || die "transaction file has an unexpected hard-link count: $path"

  [[ "${mode#0}" == '600' || "${mode#0}" == "${expected_mode#0}" ]] ||
    die "transaction file mode is neither staged 0600 nor expected: $path"
  actual_hash="$(/usr/bin/sha256sum -- "$path" | /usr/bin/awk '{print $1}')"
  [[ "$actual_hash" == "$expected_hash" ]] ||
    die "transaction file is not an exact completed staged object; preserving it for manual recovery: $path"
}

record_validated_known_file() {
  local index="$1"
  local path="${KNOWN_PATHS[$index]}"
  local before after

  if [[ ! -e "$path" && ! -L "$path" ]]; then
    KNOWN_PRESENT[index]=0
    KNOWN_IDENTITIES[index]=''
    KNOWN_HASH_CLASSES[index]='absent'
    return 0
  fi
  before="$(stat_full_identity "$path")" || die "cannot record Toolkit file identity: $path"
  validate_known_file "$path" "${KNOWN_HASHES[$index]}" "${KNOWN_MODES[$index]}"
  after="$(stat_full_identity "$path")" || die "cannot recheck Toolkit file identity: $path"
  [[ "$after" == "$before" ]] || die "Toolkit file identity changed during prevalidation: $path"
  KNOWN_PRESENT[index]=1
  KNOWN_IDENTITIES[index]="$before"
  KNOWN_HASH_CLASSES[index]='exact'
}

record_validated_transaction_file() {
  local index="$1"
  local path="${TRANSACTION_PATHS[$index]}"
  local before after

  if [[ ! -e "$path" && ! -L "$path" ]]; then
    TRANSACTION_PRESENT[index]=0
    TRANSACTION_IDENTITIES[index]=''
    TRANSACTION_HASH_CLASSES[index]='absent'
    return 0
  fi
  before="$(stat_full_identity "$path")" || die "cannot record transaction file identity: $path"
  validate_transaction_file "$path" "${KNOWN_HASHES[$index]}" "${KNOWN_MODES[$index]}"
  after="$(stat_full_identity "$path")" || die "cannot recheck transaction file identity: $path"
  [[ "$after" == "$before" ]] || die "transaction file identity changed during prevalidation: $path"
  TRANSACTION_PRESENT[index]=1
  TRANSACTION_IDENTITIES[index]="$before"
  TRANSACTION_HASH_CLASSES[index]='exact-transaction'
}

require_recorded_parent_identity() {
  local path="$1"
  local recorded="$2"
  local allow_link_change="${3:-0}"
  local current recorded_dev recorded_inode recorded_mode recorded_links
  local current_dev current_inode current_uid current_gid current_mode current_links

  [[ -d "$path" && ! -L "$path" ]] || die "validated parent was replaced or became unsafe; preserving Toolkit paths: $path"
  current="$(stat_full_identity "$path")" || die "cannot recheck validated parent; preserving Toolkit paths: $path"
  IFS=: read -r recorded_dev recorded_inode _ _ recorded_mode recorded_links <<<"$recorded"
  IFS=: read -r current_dev current_inode current_uid current_gid current_mode current_links <<<"$current"
  [[ "$current_dev:$current_inode" == "$recorded_dev:$recorded_inode" ]] ||
    die "validated parent inode changed; preserving Toolkit paths: $path"
  [[ "$current_uid" == '0' && "$current_gid" == '0' && "$current_mode" == "$recorded_mode" ]] ||
    die "validated parent ownership or mode changed; preserving Toolkit paths: $path"
  (( (8#$current_mode & 8#022) == 0 )) || die "validated parent became group/world writable: $path"
  if [[ "$allow_link_change" == '0' ]]; then
    [[ "$current_links" == "$recorded_links" ]] || die "validated parent link count changed; preserving Toolkit paths: $path"
  fi
}

require_recorded_toolkit_directory() {
  local path="$1"
  local present="$2"
  local recorded="$3"
  local current

  if [[ "$present" == '0' ]]; then
    [[ ! -e "$path" && ! -L "$path" ]] || die "unvalidated Toolkit directory appeared; preserving it: $path"
    return 0
  fi
  [[ -d "$path" && ! -L "$path" ]] || die "validated Toolkit directory was replaced; preserving path: $path"
  current="$(stat_full_identity "$path")" || die "cannot recheck validated Toolkit directory: $path"
  [[ "$current" == "$recorded" ]] || die "validated Toolkit directory identity changed; preserving path: $path"
}

require_recorded_parent_for_path() {
  local path="$1"

  case "$path" in
    /usr/local/bin/*)
      require_recorded_parent_identity /usr/local/bin "$BIN_PARENT_IDENTITY"
      ;;
    "$INSTALL_LIB_DIR"/*)
      require_recorded_parent_identity /usr/local/lib "$LIB_PARENT_IDENTITY"
      require_recorded_toolkit_directory "$INSTALL_LIB_DIR" "$FINAL_DIRECTORY_PRESENT" "$FINAL_DIRECTORY_FULL_IDENTITY"
      ;;
    "$TRANSACTION_LIB_DIR"/*)
      require_recorded_parent_identity /usr/local/lib "$LIB_PARENT_IDENTITY"
      require_recorded_toolkit_directory "$TRANSACTION_LIB_DIR" "$TRANSACTION_DIRECTORY_PRESENT" "$TRANSACTION_DIRECTORY_FULL_IDENTITY"
      ;;
    *)
      die "refusing removal outside the exact validated Toolkit parents: $path"
      ;;
  esac
}

require_recorded_file_identity() {
  local path="$1"
  local recorded="$2"
  local hash_class="$3"
  local expected_hash="$4"
  local expected_mode="$5"
  local current uid gid mode links actual_hash

  [[ -f "$path" && ! -L "$path" ]] || die "validated Toolkit file was replaced; preserving path: $path"
  current="$(stat_full_identity "$path")" || die "cannot recheck validated Toolkit file: $path"
  [[ "$current" == "$recorded" ]] || die "validated Toolkit file identity changed; preserving path: $path"
  IFS=: read -r _ _ uid gid mode links <<<"$current"
  [[ "$uid" == '0' && "$gid" == '0' && "$links" == '1' ]] ||
    die "validated Toolkit file ownership or link count changed: $path"
  case "$hash_class" in
    exact)
      [[ "${mode#0}" == "${expected_mode#0}" ]] || die "validated Toolkit file mode changed: $path"
      actual_hash="$(/usr/bin/sha256sum -- "$path" | /usr/bin/awk '{print $1}')"
      [[ "$actual_hash" == "$expected_hash" ]] || die "validated Toolkit file hash changed: $path"
      ;;
    exact-transaction)
      [[ "${mode#0}" == '600' || "${mode#0}" == "${expected_mode#0}" ]] ||
        die "validated exact transaction mode changed: $path"
      actual_hash="$(/usr/bin/sha256sum -- "$path" | /usr/bin/awk '{print $1}')"
      [[ "$actual_hash" == "$expected_hash" ]] ||
        die "validated exact transaction hash changed; preserving it for manual recovery: $path"
      ;;
    *)
      die "internal validated hash class is invalid for: $path"
      ;;
  esac
}

remove_validated_file() {
  local path="$1"
  local present="$2"
  local recorded="$3"
  local hash_class="$4"
  local expected_hash="$5"
  local expected_mode="$6"

  require_recorded_parent_for_path "$path"
  if [[ "$present" == '0' ]]; then
    [[ ! -e "$path" && ! -L "$path" ]] || die "unvalidated Toolkit file appeared; preserving it: $path"
    return 0
  fi
  require_recorded_file_identity "$path" "$recorded" "$hash_class" "$expected_hash" "$expected_mode"
  /bin/rm -f -- "$path"
  [[ ! -e "$path" && ! -L "$path" ]] || die "Toolkit path remains or reappeared after removal: $path"
  require_recorded_parent_for_path "$path"
}

remove_validated_known_index() {
  local index="$1"
  remove_validated_file "${KNOWN_PATHS[$index]}" "${KNOWN_PRESENT[$index]}" \
    "${KNOWN_IDENTITIES[$index]}" "${KNOWN_HASH_CLASSES[$index]}" \
    "${KNOWN_HASHES[$index]}" "${KNOWN_MODES[$index]}"
}

remove_validated_transaction_index() {
  local index="$1"
  remove_validated_file "${TRANSACTION_PATHS[$index]}" "${TRANSACTION_PRESENT[$index]}" \
    "${TRANSACTION_IDENTITIES[$index]}" "${TRANSACTION_HASH_CLASSES[$index]}" \
    "${KNOWN_HASHES[$index]}" "${KNOWN_MODES[$index]}"
}

is_known_path() {
  local candidate="$1"
  local path
  for path in "${KNOWN_PATHS[@]}"; do
    [[ "$candidate" == "$path" ]] && return 0
  done
  return 1
}

is_transaction_path() {
  local candidate="$1"
  local path
  for path in "${TRANSACTION_PATHS[@]}"; do
    [[ "$candidate" == "$path" ]] && return 0
  done
  return 1
}

assert_no_unknown_directory_entries() {
  local directory="$1"
  local inventory_kind="$2"
  local entry
  [[ -e "$directory" || -L "$directory" ]] || return 0
  require_trusted_directory "$directory"

  # Process substitution does not propagate the producer's status to the
  # parent shell. Prove that the bounded one-level inventory is readable
  # before consuming it, so an unreadable directory cannot look empty.
  /usr/bin/find "$directory" -mindepth 1 -maxdepth 1 -print0 >/dev/null ||
    die "cannot enumerate Toolkit directory: $directory"

  while IFS= read -r -d '' entry; do
    case "$inventory_kind" in
      final)
        is_known_path "$entry" || die "unknown entry in final Toolkit directory: $entry"
        ;;
      transaction)
        is_transaction_path "$entry" || die "unknown entry in Toolkit transaction directory: $entry"
        ;;
      *)
        die 'internal directory inventory kind is invalid'
        ;;
    esac
  done < <(/usr/bin/find "$directory" -mindepth 1 -maxdepth 1 -print0)
}

require_directory_removal_provenance() {
  local directory="$1"
  local present="$2"
  local exact_child_count="$3"
  local label="$4"

  [[ "$present" == '0' || "$present" == '1' ]] || die "internal $label directory presence is invalid"
  [[ "$exact_child_count" =~ ^[0-9]+$ ]] || die "internal $label exact-child count is invalid"
  if [[ "$present" == '1' ]] && (( exact_child_count == 0 )); then
    die "$label directory has no exact known Toolkit child provenance; preserving it for manual recovery: $directory"
  fi
}

resolved_path_is_toolkit() {
  local candidate="$1"
  local path

  case "$candidate" in
    "$INSTALL_LIB_DIR" | "$INSTALL_LIB_DIR"/* | "$TRANSACTION_LIB_DIR" | "$TRANSACTION_LIB_DIR"/*)
      return 0
      ;;
  esac
  for path in "${KNOWN_PATHS[@]}" "${TRANSACTION_PATHS[@]}"; do
    [[ "$candidate" == "$path" ]] && return 0
  done
  return 1
}

candidate_resolves_to_toolkit() {
  local candidate="$1"
  local cwd="$2"
  local joined resolved

  candidate="${candidate% (deleted)}"
  [[ -n "$candidate" && "$candidate" != -* ]] || return 1
  if [[ "$candidate" == /* ]]; then
    joined="$candidate"
  else
    [[ -n "$cwd" && "$cwd" == /* ]] || return 2
    joined="$cwd/$candidate"
  fi
  resolved="$(/usr/bin/readlink --canonicalize-missing -- "$joined" 2>/dev/null)" || return 2
  resolved_path_is_toolkit "$resolved"
}

read_process_starttime() {
  local pid="$1"
  /usr/bin/awk '
    {
      line=$0
      sub(/^.*\) /, "", line)
      count=split(line, fields, " ")
      if (count < 20 || fields[1] !~ /^[A-Za-z]$/ || fields[20] !~ /^[0-9]+$/) exit 1
      print fields[20]
    }
  ' "/proc/$pid/stat" 2>/dev/null
}

read_process_state() {
  local pid="$1"
  /usr/bin/awk '
    {
      line=$0
      sub(/^.*\) /, "", line)
      count=split(line, fields, " ")
      if (count < 20 || fields[1] !~ /^[A-Za-z]$/ || fields[20] !~ /^[0-9]+$/) exit 1
      print fields[1]
    }
  ' "/proc/$pid/stat" 2>/dev/null
}

read_process_kthread() {
  local pid="$1"
  /usr/bin/awk -v expected_pid="$pid" '
    $1 == "Pid:" {
      pid_count++
      if (NF != 2 || ($2 "") != (expected_pid "")) invalid=1
    }
    $1 == "Kthread:" {
      kthread_count++
      if (NF != 2 || $2 !~ /^[01]$/) invalid=1
      else kthread=$2
    }
    END {
      if (invalid || pid_count != 1 || kthread_count != 1) exit 1
      print kthread
    }
  ' "/proc/$pid/status" 2>/dev/null
}

process_identity_still_matches() {
  local pid="$1"
  local before="$2"
  local after

  if after="$(read_process_starttime "$pid")"; then
    [[ "$after" == "$before" ]] && return 0
    return 2
  fi
  [[ ! -d "/proc/$pid" ]] && return 1
  die "stable process identity became unreadable for PID $pid"
}

require_process_stable_or_vanished() {
  local pid="$1"
  local before="$2"
  local rc

  if process_identity_still_matches "$pid" "$before"; then
    return 0
  else
    rc=$?
  fi
  (( rc == 1 )) && return 1
  die "process identity changed during bounded scan for PID $pid"
}

parse_shell_argv() {
  local pid="$1"
  local exe_base="$2"
  local index=1 arg value

  shell_script_operand=''
  shell_command_string=''
  shell_reference_operands=()
  shell_reference_count=0
  while (( index < ${#argv[@]} )); do
    arg="${argv[$index]}"
    case "$exe_base" in
      bash)
        case "$arg" in
          --)
            index=$((index + 1))
            if (( index < ${#argv[@]} )); then
              shell_script_operand="${argv[$index]}"
            fi
            return 0
            ;;
          -c | --command)
            index=$((index + 1))
            (( index < ${#argv[@]} )) ||
              die "malformed Bash command option has no command string for PID $pid"
            shell_command_string="${argv[$index]}"
            [[ -n "$shell_command_string" ]] ||
              die "malformed Bash command option has an empty command string for PID $pid"
            return 0
            ;;
          -s)
            return 0
            ;;
          -O | -o | +O | +o)
            index=$((index + 1))
            (( index < ${#argv[@]} )) ||
              die "malformed Bash option has no required value for PID $pid: $arg"
            value="${argv[$index]}"
            [[ "$value" =~ ^[A-Za-z0-9_-]+$ ]] ||
              die "malformed Bash option value for PID $pid: $arg"
            ;;
          -O?* | -o?* | +O?* | +o?*)
            value="${arg:2}"
            [[ "$value" =~ ^[A-Za-z0-9_-]+$ ]] ||
              die "malformed combined Bash option value for PID $pid: $arg"
            ;;
          --rcfile | --init-file)
            index=$((index + 1))
            (( index < ${#argv[@]} )) ||
              die "malformed Bash startup-file option has no path for PID $pid: $arg"
            value="${argv[$index]}"
            [[ -n "$value" && "$value" != -* ]] ||
              die "malformed Bash startup-file path for PID $pid: $arg"
            shell_reference_operands[$shell_reference_count]="$value"
            shell_reference_count=$((shell_reference_count + 1))
            ;;
          --rcfile=* | --init-file=*)
            value="${arg#*=}"
            [[ -n "$value" && "$value" != -* ]] ||
              die "malformed combined Bash startup-file path for PID $pid: $arg"
            shell_reference_operands[$shell_reference_count]="$value"
            shell_reference_count=$((shell_reference_count + 1))
            ;;
          --debugger | --dump-po-strings | --dump-strings | --help | --login | \
          --noediting | --noprofile | --norc | --posix | --pretty-print | \
          --restricted | --verbose | --version)
            ;;
          -[abefhikmnprTuvxBCDEHPl]*c)
            value="${arg#-}"
            [[ "$value" =~ ^[abefhikmnprTuvxBCDEHPl]*c$ ]] ||
              die "unknown or ambiguous combined Bash command option for PID $pid: $arg"
            index=$((index + 1))
            (( index < ${#argv[@]} )) ||
              die "malformed combined Bash command option has no command string for PID $pid"
            shell_command_string="${argv[$index]}"
            [[ -n "$shell_command_string" ]] ||
              die "malformed combined Bash command option has an empty command string for PID $pid"
            return 0
            ;;
          -[abefhikmnprTuvxBCDEHPl]*s)
            value="${arg#-}"
            [[ "$value" =~ ^[abefhikmnprTuvxBCDEHPl]*s$ ]] ||
              die "unknown or ambiguous combined Bash stdin option for PID $pid: $arg"
            return 0
            ;;
          -* | +*)
            if [[ "$arg" =~ ^[-+][abefhiklmnrptuvxBCDEHPT]+$ ]]; then
              :
            else
              die "unknown or ambiguous Bash option in process evidence for PID $pid: $arg"
            fi
            ;;
          *)
            shell_script_operand="$arg"
            return 0
            ;;
        esac
        ;;
      dash | sh)
        case "$arg" in
          --)
            index=$((index + 1))
            if (( index < ${#argv[@]} )); then
              shell_script_operand="${argv[$index]}"
            fi
            return 0
            ;;
          -c)
            index=$((index + 1))
            (( index < ${#argv[@]} )) ||
              die "malformed shell command option has no command string for PID $pid"
            shell_command_string="${argv[$index]}"
            [[ -n "$shell_command_string" ]] ||
              die "malformed shell command option has an empty command string for PID $pid"
            return 0
            ;;
          -s)
            return 0
            ;;
          -*)
            if [[ "$arg" =~ ^-[aefnuvx]+$ ]]; then
              :
            else
              die "unknown or ambiguous shell option in process evidence for PID $pid: $arg"
            fi
            ;;
          *)
            shell_script_operand="$arg"
            return 0
            ;;
        esac
        ;;
      *)
        return 0
        ;;
    esac
    index=$((index + 1))
  done
}

command_string_mentions_toolkit() {
  local command_string="$1"
  local path

  for path in "$INSTALL_LIB_DIR" "$TRANSACTION_LIB_DIR" \
    "${KNOWN_PATHS[@]}" "${TRANSACTION_PATHS[@]}"; do
    [[ "$command_string" == *"$path"* ]] && return 0
  done
  [[ "$command_string" =~ (^|[^A-Za-z0-9._/-])(server-toolkit|server-toolkit-audit-v1)([^A-Za-z0-9._/-]|$) ]]
}

command_string_is_proven_unrelated() {
  local command_string="$1"

  # Never evaluate or expand live process evidence. Only inert fixed commands
  # with no operands, redirections, substitutions or indirection are accepted
  # as provably unrelated. Everything else is an ambiguous active shell.
  case "$command_string" in
    ':' | 'true' | 'false') return 0 ;;
    *) return 1 ;;
  esac
}

scan_one_process() {
  local pid="$1"
  local before state kthread exe cwd matched=0 arg exe_base shell_script_operand='' shell_command_string=''
  local shell_reference_count=0
  local -a argv=() shell_reference_operands=()

  [[ "$pid" == "$$" ]] && return 0
  if ! before="$(read_process_starttime "$pid")"; then
    [[ ! -d "/proc/$pid" ]] && return 0
    die "cannot read stable process identity for PID $pid"
  fi
  if ! state="$(read_process_state "$pid")"; then
    require_process_stable_or_vanished "$pid" "$before" || return 0
    die "cannot read process state for stable PID $pid"
  fi
  if [[ "$state" == 'Z' || "$state" == 'X' ]]; then
    require_process_stable_or_vanished "$pid" "$before" || return 0
    return 0
  fi

  if ! kthread="$(read_process_kthread "$pid")"; then
    require_process_stable_or_vanished "$pid" "$before" || return 0
    die "cannot read valid process status for stable PID $pid"
  fi
  if [[ "$kthread" == '1' ]]; then
    require_process_stable_or_vanished "$pid" "$before" || return 0
    return 0
  fi

  if [[ ! -r "/proc/$pid/cmdline" ]]; then
    require_process_stable_or_vanished "$pid" "$before" || return 0
    die "stable process cmdline is unreadable for PID $pid"
  fi
  while IFS= read -r -d '' arg; do
    argv[${#argv[@]}]="$arg"
  done <"/proc/$pid/cmdline"

  if [[ -L "/proc/$pid/exe" ]]; then
    exe="$(/usr/bin/readlink -- "/proc/$pid/exe" 2>/dev/null)" || {
      require_process_stable_or_vanished "$pid" "$before" || return 0
      die "stable process exe is unreadable for PID $pid"
    }
  else
    exe=''
  fi

  if (( ${#argv[@]} == 0 )) && [[ -z "$exe" ]]; then
    require_process_stable_or_vanished "$pid" "$before" || return 0
    die "stable non-zombie process has no readable exe/cmdline evidence for PID $pid"
  fi
  if [[ -z "$exe" ]]; then
    require_process_stable_or_vanished "$pid" "$before" || return 0
    die "stable user process exe is unreadable for PID $pid"
  fi

  cwd="$(/usr/bin/readlink -- "/proc/$pid/cwd" 2>/dev/null)" || {
    require_process_stable_or_vanished "$pid" "$before" || return 0
    die "stable process cwd is unreadable for PID $pid"
  }
  cwd="${cwd% (deleted)}"

  if candidate_resolves_to_toolkit "$exe" "$cwd"; then
    matched=1
  else
    case $? in 1) ;; *) die "cannot canonicalize process exe for PID $pid" ;; esac
  fi

  # Only path-shaped argv entries are inspected generally. Shell argv is also
  # parsed with exact option arity so option values cannot hide the real script.
  exe_base="${exe% (deleted)}"
  exe_base="${exe_base##*/}"
  case "$exe_base" in
    bash | dash | sh)
      parse_shell_argv "$pid" "$exe_base"
      ;;
  esac

  for arg in "${argv[@]}"; do
    [[ "$arg" == */* ]] || continue
    if candidate_resolves_to_toolkit "$arg" "$cwd"; then
      matched=1
    else
      case $? in 1) ;; *) die "cannot canonicalize process argv path for PID $pid" ;; esac
    fi
  done
  if (( shell_reference_count > 0 )); then
    for arg in "${shell_reference_operands[@]}"; do
      if candidate_resolves_to_toolkit "$arg" "$cwd"; then
        matched=1
      else
        case $? in 1) ;; *) die "cannot canonicalize shell option operand for PID $pid" ;; esac
      fi
    done
  fi
  if [[ -n "$shell_script_operand" ]]; then
    if candidate_resolves_to_toolkit "$shell_script_operand" "$cwd"; then
      matched=1
    else
      case $? in 1) ;; *) die "cannot canonicalize interpreter operand for PID $pid" ;; esac
    fi
  fi
  if [[ -n "$shell_command_string" ]]; then
    if command_string_mentions_toolkit "$shell_command_string"; then
      matched=1
    elif ! command_string_is_proven_unrelated "$shell_command_string"; then
      die "ambiguous shell command string cannot be proven unrelated to Toolkit for PID $pid"
    fi
  fi

  require_process_stable_or_vanished "$pid" "$before" || return 0
  (( matched == 0 )) || die "active Server Toolkit process prevents removal (PID $pid)"
}

run_internal_proc_scan() {
  local snapshot='' count=0 pid proc_entry self_seen=0 self_start self_arg

  [[ -d /proc && ! -L /proc ]] || die '/proc is unavailable or unsafe'
  self_start="$(read_process_starttime "$$")" || die '/proc self stat is unavailable or invalid'
  [[ "$self_start" =~ ^[0-9]+$ ]] || die '/proc self start time is invalid'
  [[ -r "/proc/$$/cmdline" ]] || die '/proc self cmdline is unavailable'
  if ! IFS= read -r -d '' self_arg <"/proc/$$/cmdline"; then
    die '/proc self cmdline is invalid'
  fi
  [[ -n "$self_arg" ]] || die '/proc self cmdline is empty'
  # A glob snapshot avoids treating a PID that vanished during external `find`
  # traversal as an enumeration error. Every PID that survives into its scan is
  # still checked against a stable start-time identity below.
  for proc_entry in /proc/[0-9]*; do
    [[ -d "$proc_entry" ]] || continue
    pid="${proc_entry##*/}"
    [[ "$pid" =~ ^[0-9]+$ ]] || die "invalid numeric process entry: $proc_entry"
    [[ "$pid" == "$$" ]] && self_seen=1
    count=$((count + 1))
    (( count <= 8192 )) || die "process table exceeds bounded scan limit: $count"
    snapshot+="$pid"$'\n'
  done
  (( self_seen == 1 )) || die '/proc self PID is absent from the bounded snapshot'

  while IFS= read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    scan_one_process "$pid"
  done <<<"$snapshot"
}

require_self_execution_identity() {
  local current_parent current_self current_hash

  [[ -d "$SELF_PARENT" && ! -L "$SELF_PARENT" ]] || die 'private bootstrap directory changed before process scan'
  current_parent="$(stat_full_identity "$SELF_PARENT")" || die 'cannot recheck private bootstrap directory before process scan'
  [[ "$current_parent" == "$SELF_PARENT_FULL_IDENTITY" ]] || die 'private bootstrap directory inode changed before process scan'
  [[ -f "$SELF_PATH" && ! -L "$SELF_PATH" ]] || die 'uninstaller bootstrap path changed before process scan'
  current_self="$(stat_full_identity "$SELF_PATH")" || die 'cannot recheck uninstaller inode before process scan'
  [[ "$current_self" == "$SELF_FULL_IDENTITY" ]] || die 'uninstaller inode changed before process scan'
  current_hash="$(/usr/bin/sha256sum -- "$SELF_PATH" | /usr/bin/awk '{print $1}')"
  [[ "$current_hash" == "$SELF_SHA256" ]] || die 'uninstaller bytes changed before process scan'
}

assert_no_active_toolkit_processes() {
  require_self_execution_identity
  /usr/bin/timeout --signal=TERM --kill-after=2s 8s \
    /usr/bin/env -i PATH='/usr/bin:/bin' HOME='/root' LC_ALL='C' LANG='C' TZ='UTC' PWD='/' \
      /bin/bash -p -- "$SELF_PATH" --internal-proc-scan ||
    die 'bounded fail-closed active-process scan failed'
}

(( EUID == 0 )) || die 'run this uninstaller as root'

for cmd in /usr/bin/awk /usr/bin/env /usr/bin/find /usr/bin/flock /usr/bin/readlink \
  /usr/bin/sha256sum /usr/bin/stat /usr/bin/timeout /bin/bash /bin/rm /bin/rmdir; do
  need_command "$cmd"
done

(( ${#KNOWN_PATHS[@]} == ${#KNOWN_HASHES[@]} )) || die 'internal uninstall hash inventory length mismatch'
(( ${#KNOWN_PATHS[@]} == ${#KNOWN_MODES[@]} )) || die 'internal uninstall mode inventory length mismatch'
(( ${#KNOWN_PATHS[@]} == ${#TRANSACTION_PATHS[@]} )) || die 'internal transaction inventory length mismatch'
[[ "${KNOWN_PATHS[${#KNOWN_PATHS[@]} - 1]}" == "$MAIN_LAUNCHER" ]] ||
  die 'internal safety invariant failed: main launcher inventory mismatch'

if (( $# == 1 )) && [[ "$1" == '--internal-proc-scan' ]]; then
  run_internal_proc_scan
  exit 0
fi
(( $# == 0 )) || die 'usage: uninstall-server-toolkit-1.0.0.sh'

for path in / /usr /usr/local /usr/local/bin /usr/local/lib; do
  require_trusted_directory "$path"
done

exec 9</usr/local/lib
/usr/bin/flock --exclusive --timeout 5 9 || die 'another Server Toolkit install/uninstall transaction holds the coordination lock'

BIN_PARENT_IDENTITY="$(stat_full_identity /usr/local/bin)" || die 'cannot record /usr/local/bin identity'
LIB_PARENT_IDENTITY="$(stat_full_identity /usr/local/lib)" || die 'cannot record /usr/local/lib identity'
require_recorded_parent_identity /usr/local/bin "$BIN_PARENT_IDENTITY"
require_recorded_parent_identity /usr/local/lib "$LIB_PARENT_IDENTITY"

if [[ -L "$INSTALL_LIB_DIR" || ( -e "$INSTALL_LIB_DIR" && ! -d "$INSTALL_LIB_DIR" ) ]]; then
  die "dedicated Toolkit library path is not an ordinary directory: $INSTALL_LIB_DIR"
fi
if [[ -L "$TRANSACTION_LIB_DIR" || ( -e "$TRANSACTION_LIB_DIR" && ! -d "$TRANSACTION_LIB_DIR" ) ]]; then
  die "Toolkit transaction library path is not an ordinary directory: $TRANSACTION_LIB_DIR"
fi
[[ ! -d "$INSTALL_LIB_DIR" || ! -d "$TRANSACTION_LIB_DIR" ]] ||
  die 'final and transaction library directories cannot coexist'

final_directory_mode=''
if [[ -d "$INSTALL_LIB_DIR" ]]; then
  require_trusted_directory "$INSTALL_LIB_DIR"
  final_directory_identity="$(stat_identity "$INSTALL_LIB_DIR")"
  final_directory_mode="$(printf '%s\n' "$final_directory_identity" | /usr/bin/awk -F: '{print $3}')"
  [[ "$final_directory_mode" == '700' || "$final_directory_mode" == '755' ]] ||
    die 'final Toolkit directory mode must be interrupted 0700 or complete 0755'
  FINAL_DIRECTORY_PRESENT=1
  FINAL_DIRECTORY_FULL_IDENTITY="$(stat_full_identity "$INSTALL_LIB_DIR")" ||
    die 'cannot record final Toolkit directory identity'
fi

transaction_directory_mode=''
if [[ -d "$TRANSACTION_LIB_DIR" ]]; then
  require_trusted_directory "$TRANSACTION_LIB_DIR"
  transaction_directory_identity="$(stat_identity "$TRANSACTION_LIB_DIR")"
  transaction_directory_mode="$(printf '%s\n' "$transaction_directory_identity" | /usr/bin/awk -F: '{print $3}')"
  [[ "$transaction_directory_mode" == '700' || "$transaction_directory_mode" == '755' ]] ||
    die 'transaction Toolkit directory mode must be partial 0700 or complete 0755'
  TRANSACTION_DIRECTORY_PRESENT=1
  TRANSACTION_DIRECTORY_FULL_IDENTITY="$(stat_full_identity "$TRANSACTION_LIB_DIR")" ||
    die 'cannot record transaction Toolkit directory identity'
fi

assert_no_unknown_directory_entries "$INSTALL_LIB_DIR" final
assert_no_unknown_directory_entries "$TRANSACTION_LIB_DIR" transaction

# Validate the complete present subset before deleting anything. This makes an
# interrupted installation removable without accepting modified or foreign data.
for index in "${!KNOWN_PATHS[@]}"; do
  record_validated_known_file "$index"
  record_validated_transaction_file "$index"
  if (( index >= LIB_KNOWN_FIRST && index <= LIB_KNOWN_LAST )); then
    [[ "${KNOWN_PRESENT[$index]}" == '1' ]] &&
      FINAL_DIRECTORY_EXACT_CHILD_COUNT=$((FINAL_DIRECTORY_EXACT_CHILD_COUNT + 1))
    [[ "${TRANSACTION_PRESENT[$index]}" == '1' ]] &&
      TRANSACTION_DIRECTORY_EXACT_CHILD_COUNT=$((TRANSACTION_DIRECTORY_EXACT_CHILD_COUNT + 1))
  fi
done

require_directory_removal_provenance "$INSTALL_LIB_DIR" "$FINAL_DIRECTORY_PRESENT" \
  "$FINAL_DIRECTORY_EXACT_CHILD_COUNT" 'final Toolkit'
require_directory_removal_provenance "$TRANSACTION_LIB_DIR" "$TRANSACTION_DIRECTORY_PRESENT" \
  "$TRANSACTION_DIRECTORY_EXACT_CHILD_COUNT" 'Toolkit transaction'

require_recorded_parent_identity /usr/local/bin "$BIN_PARENT_IDENTITY"
require_recorded_parent_identity /usr/local/lib "$LIB_PARENT_IDENTITY"
require_recorded_toolkit_directory "$INSTALL_LIB_DIR" "$FINAL_DIRECTORY_PRESENT" "$FINAL_DIRECTORY_FULL_IDENTITY"
require_recorded_toolkit_directory "$TRANSACTION_LIB_DIR" "$TRANSACTION_DIRECTORY_PRESENT" "$TRANSACTION_DIRECTORY_FULL_IDENTITY"

if [[ "$final_directory_mode" == '755' ]]; then
  for (( index=LIB_KNOWN_FIRST; index <= LIB_KNOWN_LAST; index++ )); do
    path="${KNOWN_PATHS[$index]}"
    [[ -e "$path" && ! -L "$path" ]] || die "complete final Toolkit directory is missing: $path"
  done
fi
if [[ "$transaction_directory_mode" == '755' ]]; then
  for (( index=LIB_KNOWN_FIRST; index <= LIB_KNOWN_LAST; index++ )); do
    transaction_path="${TRANSACTION_PATHS[$index]}"
    [[ -e "$transaction_path" && ! -L "$transaction_path" ]] ||
      die "complete Toolkit transaction directory is missing: $transaction_path"
    validate_known_file "$transaction_path" "${KNOWN_HASHES[$index]}" "${KNOWN_MODES[$index]}"
  done
fi

assert_no_active_toolkit_processes

# Remove the complete executable launcher set before scan #2 so neither the
# public nor audit entry point can start a new Toolkit process during removal.
launcher_last_index=$((${#KNOWN_PATHS[@]} - 1))
remove_validated_known_index "$launcher_last_index"
remove_validated_known_index 0
remove_validated_transaction_index "$launcher_last_index"
remove_validated_transaction_index 0
assert_no_active_toolkit_processes

for index in "${!KNOWN_PATHS[@]}"; do
  (( index == 0 || index == launcher_last_index )) && continue
  remove_validated_known_index "$index"
  remove_validated_transaction_index "$index"
done

require_recorded_parent_identity /usr/local/lib "$LIB_PARENT_IDENTITY"
require_recorded_toolkit_directory "$INSTALL_LIB_DIR" "$FINAL_DIRECTORY_PRESENT" "$FINAL_DIRECTORY_FULL_IDENTITY"
if [[ "$FINAL_DIRECTORY_PRESENT" == '1' ]]; then
  /bin/rmdir -- "$INSTALL_LIB_DIR" || die "dedicated Toolkit directory is not empty: $INSTALL_LIB_DIR"
fi
[[ ! -e "$INSTALL_LIB_DIR" && ! -L "$INSTALL_LIB_DIR" ]] || die 'dedicated Toolkit directory still exists'
require_recorded_parent_identity /usr/local/lib "$LIB_PARENT_IDENTITY" 1
require_recorded_toolkit_directory "$TRANSACTION_LIB_DIR" "$TRANSACTION_DIRECTORY_PRESENT" "$TRANSACTION_DIRECTORY_FULL_IDENTITY"
if [[ "$TRANSACTION_DIRECTORY_PRESENT" == '1' ]]; then
  /bin/rmdir -- "$TRANSACTION_LIB_DIR" || die "Toolkit transaction directory is not empty: $TRANSACTION_LIB_DIR"
fi
[[ ! -e "$TRANSACTION_LIB_DIR" && ! -L "$TRANSACTION_LIB_DIR" ]] || die 'Toolkit transaction directory still exists'
require_recorded_parent_identity /usr/local/lib "$LIB_PARENT_IDENTITY" 1

assert_no_active_toolkit_processes
for path in "${KNOWN_PATHS[@]}" "${TRANSACTION_PATHS[@]}"; do
  [[ ! -e "$path" && ! -L "$path" ]] || die "Toolkit path remains after removal: $path"
done

printf 'Server Toolkit %s installation removed.\n' "$PRODUCT_VERSION"
