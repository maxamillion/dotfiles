#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [--allow-insecure-pcr7] [/dev/LUKS_DEVICE]" >&2
}

die() {
    echo "[-] $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

ALLOW_INSECURE_PCR7=0
TARGET_DEV=""
for arg in "$@"; do
    case "$arg" in
        --allow-insecure-pcr7)
            ALLOW_INSECURE_PCR7=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            usage
            die "Unknown option: $arg"
            ;;
        *)
            [[ -z "$TARGET_DEV" ]] || { usage; die "Only one LUKS device may be specified."; }
            TARGET_DEV="$arg"
            ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    die "This script must be run as root."
fi

for command_name in awk basename blkid cmp cp cryptsetup dracut findmnt grep install lsblk mkdir mktemp mv od python3 readlink rm systemd-cryptenroll; do
    require_command "$command_name"
done

ROOT_MNT_SOURCE=""
if [[ -z "$TARGET_DEV" ]]; then
    echo "[*] No block device specified. Detecting the LUKS container beneath the root filesystem..."
    ROOT_MNT_SOURCE=$(findmnt -nro SOURCE --nofsroot /)
    [[ -b "$ROOT_MNT_SOURCE" ]] || die "Root mount source is not a block device: $ROOT_MNT_SOURCE"
    TARGET_DEV=$(lsblk -s -rno PATH,FSTYPE "$ROOT_MNT_SOURCE" | awk '$2 == "crypto_LUKS" && !found { print $1; found = 1 }')
fi

[[ -n "$TARGET_DEV" && -b "$TARGET_DEV" ]] || die "Could not resolve a LUKS block device. Specify one explicitly."
TARGET_DEV=$(readlink -f "$TARGET_DEV")
cryptsetup isLuks "$TARGET_DEV" || die "$TARGET_DEV is not a LUKS device."

LUKS_VERSION=$(cryptsetup luksDump "$TARGET_DEV" | awk '/^Version:/ && !found { print $2; found = 1 }')
[[ "$LUKS_VERSION" == "2" ]] || die "TPM2 token enrollment requires LUKS2; $TARGET_DEV is LUKS$LUKS_VERSION."

LUKS_UUID=$(blkid -s UUID -o value "$TARGET_DEV")
[[ -n "$LUKS_UUID" ]] || die "Could not read the LUKS UUID from $TARGET_DEV."

echo "[+] Target device: $TARGET_DEV"
echo "[+] LUKS container UUID: $LUKS_UUID"

TPM_DEVICE_LIST=$(systemd-cryptenroll --tpm2-device=list 2>/dev/null) ||
    die "Could not enumerate TPM2 devices."
if ! grep -E '^/dev/' <<< "$TPM_DEVICE_LIST" >/dev/null; then
    die "No usable TPM2 device was detected."
fi

SECURE_BOOT_STATE="unavailable"
shopt -s nullglob
SECURE_BOOT_VARS=(/sys/firmware/efi/efivars/SecureBoot-*)
shopt -u nullglob
if (( ${#SECURE_BOOT_VARS[@]} > 0 )) && [[ -r "${SECURE_BOOT_VARS[0]}" ]]; then
    SECURE_BOOT_STATE=$(od -An -tu1 -j4 -N1 "${SECURE_BOOT_VARS[0]}" | awk '{ print ($1 == 1 ? "enabled" : "disabled") }')
fi

if [[ "$SECURE_BOOT_STATE" != "enabled" ]]; then
    if (( ALLOW_INSECURE_PCR7 == 0 )); then
        die "Secure Boot is $SECURE_BOOT_STATE. PCR 7 alone is unsafe without Secure Boot; enable it or explicitly pass --allow-insecure-pcr7."
    fi
    echo "[!] WARNING: Secure Boot is $SECURE_BOOT_STATE; PCR 7 does not establish a trusted boot chain." >&2
else
    echo "[!] Security note: PCR 7 trusts boot paths accepted by the configured Secure Boot authorities; it does not uniquely authenticate the kernel or initramfs." >&2
fi

DRACUT_MODULES=$(dracut --list-modules 2>/dev/null) ||
    die "Could not enumerate dracut modules."
if ! grep -E '^[[:space:]]*tpm2-tss[[:space:]]*$' <<< "$DRACUT_MODULES" >/dev/null; then
    die "The dracut tpm2-tss module is not installed."
fi

# 1. Idempotently enroll exactly one unattended TPM2 token bound only to PCR 7.
echo "[*] Checking TPM2 token state on $TARGET_DEV..."
TOKEN_JSON=$(cryptsetup luksDump --dump-json-metadata "$TARGET_DEV") ||
    die "Could not read LUKS2 token metadata from $TARGET_DEV."
TOKEN_STATE=$(python3 -c '
import json
import sys

metadata = json.load(sys.stdin)
tokens = [
    token for token in metadata.get("tokens", {}).values()
    if token.get("type") == "systemd-tpm2"
]

def pcr7_only(token):
    try:
        pcrs = [int(pcr) for pcr in token.get("tpm2-pcrs", [])]
    except (TypeError, ValueError):
        return False
    return pcrs == [7]

def unattended_plain_pcr_policy(token):
    return (
        pcr7_only(token)
        and token.get("tpm2-pin", False) is False
        and token.get("tpm2-pcrlock", False) is False
        and "tpm2-public-key" not in token
        and "tpm2-public-key-pcrs" not in token
    )

if not tokens:
    print("absent")
elif len(tokens) == 1 and unattended_plain_pcr_policy(tokens[0]):
    print("current")
else:
    print("different")
' <<< "$TOKEN_JSON") || die "Could not determine the existing TPM2 token state."

TPM_TOKEN_WORKS=0
if [[ "$TOKEN_STATE" == "current" ]]; then
    echo "[*] Testing the existing TPM2 token noninteractively..."
    if cryptsetup open --test-passphrase --token-only --token-type systemd-tpm2 "$TARGET_DEV" </dev/null; then
        TPM_TOKEN_WORKS=1
    else
        echo "[!] The existing PCR 7 token cannot currently unlock this volume; it will be replaced." >&2
        TOKEN_STATE="different"
    fi
fi

case "$TOKEN_STATE" in
    current)
        echo "[+] One usable, unattended systemd-tpm2 token bound only to PCR 7 is enrolled."
        ;;
    different)
        echo "[*] Replacing existing TPM2 enrollment with one unattended PCR 7 enrollment..."
        systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=no --tpm2-public-key= --tpm2-pcrlock= --wipe-slot=tpm2 "$TARGET_DEV"
        echo "[+] TPM2 successfully enrolled into the LUKS header."
        ;;
    absent)
        echo "[*] Enrolling an unattended TPM2 token bound only to PCR 7..."
        systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=no --tpm2-public-key= --tpm2-pcrlock= "$TARGET_DEV"
        echo "[+] TPM2 successfully enrolled into the LUKS header."
        ;;
    *)
        die "Could not determine the existing TPM2 token state."
        ;;
esac

if (( ! TPM_TOKEN_WORKS )); then
    echo "[*] Verifying the new TPM2 enrollment noninteractively..."
    cryptsetup open --test-passphrase --token-only --token-type systemd-tpm2 "$TARGET_DEV" </dev/null ||
        die "The TPM2 enrollment was written, but it cannot unlock $TARGET_DEV in the current boot state."
fi

# 2. Update /etc/crypttab atomically
CRYPTTAB="/etc/crypttab"
echo "[*] Verifying $CRYPTTAB..."
if [[ ! -e "$CRYPTTAB" ]]; then
    install -m 600 -o root -g root /dev/null "$CRYPTTAB"
fi
[[ -f "$CRYPTTAB" ]] || die "$CRYPTTAB is not a regular file."

TARGET_BASENAME=$(basename "$TARGET_DEV")
MAPPER_NAME=$(lsblk -rno NAME,PKNAME,TYPE "$TARGET_DEV" | awk -v parent="$TARGET_BASENAME" '$2 == parent && $3 == "crypt" && !found { print $1; found = 1 }')
if [[ -z "$MAPPER_NAME" && -n "$ROOT_MNT_SOURCE" && "$ROOT_MNT_SOURCE" == /dev/mapper/* ]]; then
    MAPPER_NAME=$(basename "$ROOT_MNT_SOURCE")
fi
[[ -n "$MAPPER_NAME" ]] || MAPPER_NAME="luks-${LUKS_UUID}"

CRYPTTAB_TMP=$(mktemp "${CRYPTTAB}.tmp.XXXXXX")
cleanup() {
    rm -f "$CRYPTTAB_TMP" "${DRACUT_TMP:-}"
}
trap cleanup EXIT

# Resolve any existing path-based sources before editing so that this script does
# not append a second entry for the same LUKS container.
declare -A CRYPTTAB_SOURCE_UUIDS=()
while IFS=$'\t' read -r line_number source; do
    [[ -n "$line_number" && -n "$source" ]] || continue
    case "$source" in
        UUID=*)
            CRYPTTAB_SOURCE_UUIDS["$line_number"]=${source#UUID=}
            ;;
        /dev/disk/by-uuid/*)
            CRYPTTAB_SOURCE_UUIDS["$line_number"]=${source##*/}
            ;;
        /dev/*)
            if [[ -b "$source" ]]; then
                SOURCE_UUID=$(blkid -s UUID -o value -- "$source" 2>/dev/null || true)
                [[ -n "$SOURCE_UUID" ]] && CRYPTTAB_SOURCE_UUIDS["$line_number"]=$SOURCE_UUID
            fi
            ;;
    esac
done < <(awk '!/^[[:space:]]*(#|$)/ && NF >= 2 { print NR "\t" $2 }' "$CRYPTTAB")

CRYPTTAB_MATCH_LINES=()
CRYPTTAB_MAPPER_CONFLICTS=()
while IFS=$'\t' read -r line_number name; do
    [[ -n "$line_number" ]] || continue
    SOURCE_UUID=${CRYPTTAB_SOURCE_UUIDS[$line_number]:-}
    if [[ "$SOURCE_UUID" == "$LUKS_UUID" ]]; then
        CRYPTTAB_MATCH_LINES+=("$line_number")
    elif [[ "$name" == "$MAPPER_NAME" ]]; then
        CRYPTTAB_MAPPER_CONFLICTS+=("$line_number")
    fi
done < <(awk '!/^[[:space:]]*(#|$)/ { print NR "\t" $1 }' "$CRYPTTAB")

(( ${#CRYPTTAB_MAPPER_CONFLICTS[@]} == 0 )) ||
    die "$CRYPTTAB maps '$MAPPER_NAME' to a different or unresolved source on line(s): ${CRYPTTAB_MAPPER_CONFLICTS[*]}"
(( ${#CRYPTTAB_MATCH_LINES[@]} <= 1 )) ||
    die "Duplicate active $CRYPTTAB entries for UUID=$LUKS_UUID on line(s): ${CRYPTTAB_MATCH_LINES[*]}"

CRYPTTAB_MATCH_LINE=${CRYPTTAB_MATCH_LINES[0]:-0}
awk -v uuid="$LUKS_UUID" -v mapper="$MAPPER_NAME" -v target_line="$CRYPTTAB_MATCH_LINE" '
/^[[:space:]]*(#|$)/ { print; next }
NR == target_line {
    name = $1
    keyfile = (NF >= 3 ? $3 : "none")
    options = (NF >= 4 && substr($4, 1, 1) != "#" ? $4 : "")
    comment = ""
    comment_start = (NF >= 4 && substr($4, 1, 1) == "#" ? 4 : 5)
    for (i = comment_start; i <= NF; i++)
        comment = comment (comment == "" ? " " : OFS) $i
    count = split(options, option, ",")
    present = 0
    for (i = 1; i <= count; i++)
        if (option[i] == "tpm2-device=auto") present = 1
    if (!present) options = (options == "" ? "tpm2-device=auto" : options ",tpm2-device=auto")
    printf "%s UUID=%s %s %s%s\n", name, uuid, keyfile, options, comment
    next
}
{ print }
END {
    if (target_line == 0) printf "%s UUID=%s none tpm2-device=auto\n", mapper, uuid
}
' "$CRYPTTAB" > "$CRYPTTAB_TMP" || die "Could not safely update $CRYPTTAB."

CRYPTTAB_CHANGED=0
if ! cmp -s "$CRYPTTAB" "$CRYPTTAB_TMP"; then
    cp --attributes-only --preserve=all "$CRYPTTAB" "$CRYPTTAB_TMP"
    mv -f "$CRYPTTAB_TMP" "$CRYPTTAB"
    CRYPTTAB_CHANGED=1
    echo "[+] Updated $CRYPTTAB."
else
    rm -f "$CRYPTTAB_TMP"
    echo "[+] $CRYPTTAB is already configured for TPM2 auto-unlock."
fi

# 3. Configure dracut using a file owned by this script
DRACUT_CONF_DIR="/etc/dracut.conf.d"
DRACUT_CONF="${DRACUT_CONF_DIR}/90-auto-luks-tpm2.conf"
mkdir -p "$DRACUT_CONF_DIR"
DRACUT_TMP=$(mktemp "${DRACUT_CONF}.tmp.XXXXXX")
printf '%s\n' 'add_dracutmodules+=" tpm2-tss "' > "$DRACUT_TMP"
DRACUT_CHANGED=0
if [[ ! -f "$DRACUT_CONF" ]] || ! cmp -s "$DRACUT_CONF" "$DRACUT_TMP"; then
    install -m 644 -o root -g root "$DRACUT_TMP" "$DRACUT_CONF"
    DRACUT_CHANGED=1
    echo "[+] Configured dracut TPM2 support in $DRACUT_CONF."
else
    echo "[+] Dracut TPM2 support is already configured."
fi
rm -f "$DRACUT_TMP"

# /etc/crypttab is authoritative for this volume. Unscoped rd.luks.options
# applies only to volumes without a crypttab entry, while UUID-scoped options
# unrelated to this volume must be left untouched. Avoid parsing or rewriting
# GRUB_CMDLINE_LINUX: doing so can change other volumes' policy or lose shell
# quoting. Warn if a target-specific kernel option exists without TPM2 support.
GRUB_DEFAULT="/etc/default/grub"
if [[ -f "$GRUB_DEFAULT" ]]; then
    TARGET_KERNEL_OPTIONS=$(grep -Eo "rd\.luks\.options=(luks-)?${LUKS_UUID}=[^\"'[:space:]]*" "$GRUB_DEFAULT" || true)
    while IFS= read -r kernel_option; do
        [[ -n "$kernel_option" ]] || continue
        options=${kernel_option#*=}
        options=${options#*=}
        if ! grep -Eq '(^|,)tpm2-device=auto(,|$)' <<< "$options"; then
            die "$GRUB_DEFAULT has a UUID-scoped rd.luks.options override for $LUKS_UUID without tpm2-device=auto; update or remove that override explicitly."
        fi
    done <<< "$TARGET_KERNEL_OPTIONS"
fi

if (( CRYPTTAB_CHANGED || DRACUT_CHANGED )); then
    echo "[*] Regenerating initramfs images with dracut..."
    dracut -f --regenerate-all
else
    echo "[+] Boot configuration is unchanged; skipping GRUB and initramfs rebuilds."
fi

echo "[+] Setup completed successfully. The volume will attempt TPM2 auto-unlock on next reboot."
