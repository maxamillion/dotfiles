#!/usr/bin/env bash
set -euo pipefail

# Gemma 4 26B-A4B CPU inference with an external Q8_0 MTP drafter.
#
# Based on this blog series:
#   https://point.free/blog/open-weights-not-open-source/
#   https://point.free/blog/gemma-4-mtp/
#   https://point.free/blog/gemma-4-on-a-2016-xeon/
#
# Override install locations with CPU_INFERENCE_HOME, IK_LLAMA_DIR, or MODEL_DIR.

CPU_INFERENCE_HOME="${CPU_INFERENCE_HOME:-${HOME}/.local/share/cpu-inference}"
IK_LLAMA_DIR="${IK_LLAMA_DIR:-${CPU_INFERENCE_HOME}/ik_llama.cpp}"
MODEL_DIR="${MODEL_DIR:-${CPU_INFERENCE_HOME}/models/gemma-4-26B-A4B-it}"
BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
RUNNER="${BIN_DIR}/gemma4-26b-cpu"
CONFIG_FILE="${CPU_INFERENCE_HOME}/gemma4-26b-cpu.env"

IK_LLAMA_REPO="https://github.com/ikawrakow/ik_llama.cpp.git"
IK_LLAMA_REV="${IK_LLAMA_REV:-d5f53d9f9a3d819a68655c19fc51140e8f7421eb}"
MODEL_REPO="unsloth/gemma-4-26B-A4B-it-GGUF"
MODEL_REV="c099eb48e663fd284577b04978a94ffccb261841"
MODEL_FILE="gemma-4-26B-A4B-it-Q8_0.gguf"
MODEL_SHA256="5f7cbd0f4564e84342fc34321a09acb54b1a3da9215124e5bf444baa6dda152c"
MODEL_BYTES=26859861728
DRAFT_REPO="cafkafk/gemma-4-26B-A4B-it-assistant-GGUF-noimatrix"
DRAFT_REV="f0af3b1c76c1b562946acadd066af791a1699d48"
DRAFT_FILE="gemma-4-26B-A4B-it-assistant-Q8_0.gguf"
DRAFT_SHA256="e373de23c9157373d2327ec520e3c160e2946dd6cd7beabfc3d79913aea0648f"
DRAFT_BYTES=461765504
DOWNLOAD_HEADROOM_BYTES=$((2 * 1024 * 1024 * 1024))
MEMLOCK_HEADROOM_KIB=$((1024 * 1024))
REQUIRED_MEMLOCK_KIB=$(((MODEL_BYTES + DRAFT_BYTES + 1023) / 1024 + MEMLOCK_HEADROOM_KIB))

log() {
    printf '[cpu-inference] %s\n' "$*"
}

warn() {
    printf '[cpu-inference] WARNING: %s\n' "$*" >&2
}

die() {
    printf '[cpu-inference] ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Builds a CPU-native ik_llama.cpp and installs:
  ${RUNNER}

Options:
  --skip-packages         Do not install system packages
  --skip-models           Do not download the verifier or MTP drafter
  --skip-memlock-config   Do not configure a persistent PAM memlock limit
  --skip-smoke-test       Do not test model loading after a change
  --smoke-test            Test model loading even when nothing changed
  -h, --help              Show this help

Downloads 27.3 GB into ${MODEL_DIR}. The default 32768-token context needs
roughly 35-45 GB of RAM at runtime. Settings can be persisted in
${CONFIG_FILE}; extra llama-cli flags may also be passed to the runner.

A new login session may be required after the first run so the configured
memlock limit takes effect. The runner detects THP, NUMA, CPU count, memory,
and the effective memlock limit each time it starts.
EOF
}

SKIP_PACKAGES=false
SKIP_MODELS=false
SKIP_MEMLOCK_CONFIG=false
SKIP_SMOKE_TEST=false
FORCE_SMOKE_TEST=false
while (($#)); do
    case "$1" in
        --skip-packages) SKIP_PACKAGES=true ;;
        --skip-models) SKIP_MODELS=true ;;
        --skip-memlock-config) SKIP_MEMLOCK_CONFIG=true ;;
        --skip-smoke-test) SKIP_SMOKE_TEST=true ;;
        --smoke-test) FORCE_SMOKE_TEST=true ;;
        -h | --help)
            usage
            exit 0
            ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

[[ "$(uname -s)" == "Linux" ]] || die "Only Linux is supported."
[[ "$(uname -m)" == "x86_64" ]] || die "This script currently supports x86_64 only."
[[ -r /proc/cpuinfo ]] || die "/proc/cpuinfo is required for CPU feature detection."

install_packages() {
    if [[ "${SKIP_PACKAGES}" == true ]]; then
        log 'Skipping package installation.'
        return
    fi

    local -a elevate=()
    if ((EUID != 0)); then
        command -v sudo >/dev/null || die "sudo is required to install system packages; rerun with --skip-packages after installing them manually."
        elevate=(sudo)
    fi

    if command -v dnf >/dev/null; then
        "${elevate[@]}" dnf install -y \
            gcc gcc-c++ cmake ninja-build git curl ca-certificates libgomp binutils \
            coreutils util-linux gawk grep
    elif command -v apt-get >/dev/null; then
        "${elevate[@]}" apt-get update
        "${elevate[@]}" apt-get install -y \
            build-essential cmake ninja-build git curl ca-certificates libgomp1 binutils \
            coreutils util-linux gawk grep
    else
        die "Unsupported package manager. Install a C/C++ toolchain, cmake, ninja, git, curl, OpenMP, binutils, coreutils, util-linux, awk, and grep, then use --skip-packages."
    fi
}

cpu_has() {
    grep -qw "$1" /proc/cpuinfo
}

physical_cores() {
    local count
    count="$(lscpu -p=CORE,SOCKET 2>/dev/null | awk -F, '!/^#/ { seen[$1 FS $2]=1 } END { print length(seen) }')"
    if [[ ! "${count}" =~ ^[1-9][0-9]*$ ]]; then
        count="$(getconf _NPROCESSORS_ONLN)"
    fi
    printf '%s\n' "${count}"
}

install_packages

for required_command in git cmake ninja c++ curl sha256sum lscpu awk grep getconf objdump flock \
    mktemp install cmp df stat timeout date; do
    command -v "${required_command}" >/dev/null || die "Required command not found: ${required_command}"
done

mkdir -p "${CPU_INFERENCE_HOME}" "${MODEL_DIR}" "${BIN_DIR}" "$(dirname "${IK_LLAMA_DIR}")"
exec 9>"${CPU_INFERENCE_HOME}/bootstrap.lock"
flock -n 9 || die "Another CPU inference bootstrap is already running."

CLEANUP_PATHS=()
cleanup() {
    local path
    for path in "${CLEANUP_PATHS[@]}"; do
        if [[ -e "${path}" || -L "${path}" ]]; then
            rm -rf --one-file-system -- "${path}"
        fi
    done
    return 0
}
trap cleanup EXIT

configure_memlock() {
    if [[ "${SKIP_MEMLOCK_CONFIG}" == true ]]; then
        log 'Skipping persistent memlock configuration.'
        return
    fi

    local hard_limit current_user safe_user target temporary
    hard_limit="$(ulimit -Hl)"
    if [[ "${hard_limit}" == unlimited ]] ||
        [[ "${hard_limit}" =~ ^[0-9]+$ && ${hard_limit} -ge ${REQUIRED_MEMLOCK_KIB} ]]; then
        log "The current hard memlock limit is already sufficient."
        return
    fi

    current_user="$(id -un)"
    safe_user="${current_user//[^A-Za-z0-9_.-]/_}"
    target="/etc/security/limits.d/90-cpu-inference-${safe_user}.conf"
    temporary="$(mktemp "${CPU_INFERENCE_HOME}/memlock.XXXXXX")"
    CLEANUP_PATHS+=("${temporary}")
    cat >"${temporary}" <<EOF
# Managed by bootstrap-cpu-inference.sh for Gemma 4 model memory pinning.
${current_user} soft memlock ${REQUIRED_MEMLOCK_KIB}
${current_user} hard memlock ${REQUIRED_MEMLOCK_KIB}
EOF

    if [[ -r "${target}" ]] && cmp -s "${temporary}" "${target}"; then
        log "Persistent memlock configuration is already current: ${target}"
        warn "If this shell still reports a lower hard limit, start a new login session."
        return
    fi

    local -a elevate=()
    if ((EUID != 0)); then
        command -v sudo >/dev/null || die "sudo is required to configure ${target}; use --skip-memlock-config to opt out."
        elevate=(sudo)
    fi
    "${elevate[@]}" mkdir -p /etc/security/limits.d
    "${elevate[@]}" install -o root -g root -m 0644 "${temporary}" "${target}"
    log "Configured a ${REQUIRED_MEMLOCK_KIB} KiB memlock limit in ${target}."
    warn "Start a new login session before inference so the new memlock limit is applied."
}

configure_memlock

clone_tmp=''
if [[ ! -d "${IK_LLAMA_DIR}/.git" ]]; then
    [[ ! -e "${IK_LLAMA_DIR}" ]] || die "${IK_LLAMA_DIR} exists but is not a Git checkout."
    clone_tmp="${IK_LLAMA_DIR}.clone.$$"
    [[ ! -e "${clone_tmp}" ]] || rm -rf -- "${clone_tmp}"
    CLEANUP_PATHS+=("${clone_tmp}")
    log "Cloning ik_llama.cpp into ${IK_LLAMA_DIR}."
    git clone "${IK_LLAMA_REPO}" "${clone_tmp}"
    mv "${clone_tmp}" "${IK_LLAMA_DIR}"
elif [[ "$(git -C "${IK_LLAMA_DIR}" remote get-url origin)" != "${IK_LLAMA_REPO}" ]]; then
    die "Existing checkout has an unexpected origin: ${IK_LLAMA_DIR}"
fi

if ! git -C "${IK_LLAMA_DIR}" cat-file -e "${IK_LLAMA_REV}^{commit}" 2>/dev/null; then
    log "Fetching pinned ik_llama.cpp revision ${IK_LLAMA_REV}."
    git -C "${IK_LLAMA_DIR}" fetch --depth 1 origin "${IK_LLAMA_REV}"
fi

if [[ -n "$(git -C "${IK_LLAMA_DIR}" status --porcelain --untracked-files=no)" ]]; then
    die "Refusing to replace modified tracked files in ${IK_LLAMA_DIR}."
fi

if [[ "$(git -C "${IK_LLAMA_DIR}" rev-parse HEAD)" != "$(git -C "${IK_LLAMA_DIR}" rev-parse "${IK_LLAMA_REV}^{commit}")" ]]; then
    log "Checking out pinned ik_llama.cpp revision ${IK_LLAMA_REV}."
    git -C "${IK_LLAMA_DIR}" checkout --detach "${IK_LLAMA_REV}"
fi

BUILD_DIR="${IK_LLAMA_DIR}/build-cpu-native"
AVX512=OFF
AVX512_VBMI=OFF
AVX512_VNNI=OFF
AVX512_BF16=OFF
SIMD_DESCRIPTION="native"

if cpu_has avx512f && cpu_has avx512dq && cpu_has avx512bw && cpu_has avx512vl; then
    AVX512=ON
    SIMD_DESCRIPTION="AVX-512"
    if cpu_has avx512vbmi; then
        AVX512_VBMI=ON
        SIMD_DESCRIPTION+=" + VBMI"
    fi
    if cpu_has avx512_vnni || cpu_has avx512vnni; then
        AVX512_VNNI=ON
        SIMD_DESCRIPTION+=" + VNNI"
    fi
    if cpu_has avx512_bf16 || cpu_has avx512bf16; then
        AVX512_BF16=ON
        SIMD_DESCRIPTION+=" + BF16"
    fi
elif cpu_has avx2; then
    SIMD_DESCRIPTION="AVX2"
fi

CMAKE_FLAGS=(
    -G Ninja
    -DCMAKE_BUILD_TYPE=Release
    -DGGML_NATIVE=ON
    -DGGML_OPENMP=ON
    -DGGML_AVX512="${AVX512}"
    -DGGML_AVX512_VBMI="${AVX512_VBMI}"
    -DGGML_AVX512_VNNI="${AVX512_VNNI}"
    -DGGML_AVX512_BF16="${AVX512_BF16}"
)

CPU_FINGERPRINT="$({
    printf 'revision=%s\n' "${IK_LLAMA_REV}"
    printf 'machine=%s\n' "$(uname -m)"
    printf 'cpu=%s\n' "$(lscpu | awk -F: '/Vendor ID|Model name|CPU family|Model:|Stepping:/{gsub(/^[ \t]+/, "", $2); print $1 "=" $2}')"
    printf 'flags=%s\n' "$(grep -m1 '^flags' /proc/cpuinfo | cut -d: -f2-)"
    printf 'compiler=%s\n' "$(cmake --version | head -1); $(c++ --version | head -1)"
    printf 'cmake_flags=%s\n' "${CMAKE_FLAGS[*]}"
} | sha256sum | awk '{print $1}')"
FINGERPRINT_FILE="${BUILD_DIR}/.cpu-build-fingerprint"
if [[ -d "${BUILD_DIR}" ]] &&
    { [[ ! -r "${FINGERPRINT_FILE}" ]] || [[ "$(<"${FINGERPRINT_FILE}")" != "${CPU_FINGERPRINT}" ]]; }; then
    log "CPU, compiler, revision, or build options changed; removing the stale native build."
    rm -rf -- "${BUILD_DIR}"
fi

OLD_BINARY_SHA=''
if [[ -x "${BUILD_DIR}/bin/llama-cli" ]]; then
    OLD_BINARY_SHA="$(sha256sum "${BUILD_DIR}/bin/llama-cli" | awk '{print $1}')"
fi

log "Configuring a ${SIMD_DESCRIPTION} CPU build."
cmake -S "${IK_LLAMA_DIR}" -B "${BUILD_DIR}" "${CMAKE_FLAGS[@]}"
cmake --build "${BUILD_DIR}" --target llama-cli --parallel "$(getconf _NPROCESSORS_ONLN)"
[[ -x "${BUILD_DIR}/bin/llama-cli" ]] || die "llama-cli was not built."
printf '%s\n' "${CPU_FINGERPRINT}" >"${FINGERPRINT_FILE}.tmp"
mv -f "${FINGERPRINT_FILE}.tmp" "${FINGERPRINT_FILE}"

NEW_BINARY_SHA="$(sha256sum "${BUILD_DIR}/bin/llama-cli" | awk '{print $1}')"
NEED_SMOKE_TEST=false
[[ "${OLD_BINARY_SHA}" == "${NEW_BINARY_SHA}" && -n "${OLD_BINARY_SHA}" ]] || NEED_SMOKE_TEST=true

if [[ "${AVX512_VNNI}" == ON ]]; then
    GGML_LIBRARY="${BUILD_DIR}/ggml/src/libggml.so"
    [[ -r "${GGML_LIBRARY}" ]] || die "Expected ggml library not found: ${GGML_LIBRARY}"
    if [[ "$(objdump -d "${GGML_LIBRARY}" | grep -c 'vpdpbusd' || true)" -eq 0 ]]; then
        die "The CPU advertises AVX-512 VNNI, but libggml does not contain a VNNI instruction."
    fi
fi

# llama-cli currently returns a nonzero status after printing valid help output.
CLI_HELP="$("${BUILD_DIR}/bin/llama-cli" --help 2>&1 || true)"
[[ -n "${CLI_HELP}" ]] || die "llama-cli did not produce help output."
for expected_option in --model-draft --spec-type --spec-autotune --cpu-moe \
    --merge-up-gate-experts --flash-attn --mla-use --run-time-repack --no-kv-offload; do
    grep -q -- "${expected_option}" <<<"${CLI_HELP}" ||
        die "Pinned llama-cli does not provide required option: ${expected_option}"
done

available_bytes() {
    df --output=avail -B1 "$1" | awk 'NR == 2 { print $1 }'
}

require_download_space() {
    local destination="$1" expected_bytes="$2" partial="$3"
    local partial_bytes=0 required available
    if [[ -f "${partial}" ]]; then
        partial_bytes="$(stat -c %s "${partial}")"
        ((partial_bytes <= expected_bytes)) || partial_bytes=0
    fi
    required=$((expected_bytes - partial_bytes + DOWNLOAD_HEADROOM_BYTES))
    available="$(available_bytes "$(dirname "${destination}")")"
    [[ "${available}" =~ ^[0-9]+$ ]] || die "Could not determine free space for ${destination}."
    ((available >= required)) ||
        die "Insufficient disk space for $(basename "${destination}"): need $((required / 1024 / 1024 / 1024 + 1)) GiB free including safety headroom."
}

MODEL_CHANGED=false
download_model() {
    local repo="$1" revision="$2" file="$3" expected_sha="$4" expected_bytes="$5"
    local destination="${MODEL_DIR}/${file}" partial="${MODEL_DIR}/${file}.part"
    local url="https://huggingface.co/${repo}/resolve/${revision}/${file}?download=true"

    if [[ -f "${destination}" ]] &&
        printf '%s  %s\n' "${expected_sha}" "${destination}" | sha256sum --check --status; then
        log "Already downloaded and verified: ${file}"
        return
    fi

    require_download_space "${destination}" "${expected_bytes}" "${partial}"
    log "Downloading immutable revision ${repo}@${revision}/${file}."
    if ! curl --fail --location --retry 5 --retry-all-errors --continue-at - \
        --output "${partial}" "${url}"; then
        warn "Resume failed for ${file}; retrying from byte zero."
        rm -f -- "${partial}"
        curl --fail --location --retry 5 --retry-all-errors \
            --output "${partial}" "${url}"
    fi

    if [[ "$(stat -c %s "${partial}")" -ne "${expected_bytes}" ]] ||
        ! printf '%s  %s\n' "${expected_sha}" "${partial}" | sha256sum --check --status; then
        warn "Resumed content verification failed for ${file}; retrying from byte zero."
        rm -f -- "${partial}"
        require_download_space "${destination}" "${expected_bytes}" "${partial}"
        curl --fail --location --retry 5 --retry-all-errors \
            --output "${partial}" "${url}"
        if [[ "$(stat -c %s "${partial}")" -ne "${expected_bytes}" ]] ||
            ! printf '%s  %s\n' "${expected_sha}" "${partial}" | sha256sum --check --status; then
            rm -f -- "${partial}"
            die "Size or SHA-256 verification failed for ${file}."
        fi
    fi

    if [[ -e "${destination}" ]]; then
        mv -f -- "${destination}" "${destination}.invalid.$(date +%Y%m%d%H%M%S).$$"
    fi
    mv -f -- "${partial}" "${destination}"
    MODEL_CHANGED=true
}

if [[ "${SKIP_MODELS}" == false ]]; then
    download_model "${MODEL_REPO}" "${MODEL_REV}" "${MODEL_FILE}" "${MODEL_SHA256}" "${MODEL_BYTES}"
    download_model "${DRAFT_REPO}" "${DRAFT_REV}" "${DRAFT_FILE}" "${DRAFT_SHA256}" "${DRAFT_BYTES}"
else
    log 'Skipping model downloads.'
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
    config_tmp="$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")"
    CLEANUP_PATHS+=("${config_tmp}")
    cat >"${config_tmp}" <<'EOF'
# Optional overrides for gemma4-26b-cpu. This is a Bash configuration file.
# GEMMA4_CTX_SIZE=32768
# GEMMA4_BATCH_SIZE=1024
# GEMMA4_UBATCH_SIZE=1024
# GEMMA4_THREADS=6
# GEMMA4_THREADS_BATCH=6
# GEMMA4_THREADS_DRAFT=6
# GEMMA4_THP=auto                 # auto, on, or off
# GEMMA4_NUMA_MODE=auto           # auto, off, distribute, isolate, or numactl
# GEMMA4_MLOCK=auto               # auto, require, or off
# GEMMA4_EXTRA_ARGS=(--temp 0.7)
EOF
    bash -n "${config_tmp}"
    chmod 0600 "${config_tmp}"
    mv "${config_tmp}" "${CONFIG_FILE}"
fi

runner_tmp="$(mktemp "${RUNNER}.tmp.XXXXXX")"
CLEANUP_PATHS+=("${runner_tmp}")
{
    printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' ''
    printf 'LLAMA_CLI=%q\n' "${BUILD_DIR}/bin/llama-cli"
    printf 'MODEL=%q\n' "${MODEL_DIR}/${MODEL_FILE}"
    printf 'DRAFT_MODEL=%q\n' "${MODEL_DIR}/${DRAFT_FILE}"
    printf 'CONFIG_FILE=%q\n' "${CONFIG_FILE}"
    cat <<'EOF'
GEMMA4_EXTRA_ARGS=()

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

[[ -x "${LLAMA_CLI}" ]] || { printf 'Missing executable: %s\n' "${LLAMA_CLI}" >&2; exit 1; }
[[ -f "${MODEL}" ]] || { printf 'Missing model: %s\n' "${MODEL}" >&2; exit 1; }
[[ -f "${DRAFT_MODEL}" ]] || { printf 'Missing draft model: %s\n' "${DRAFT_MODEL}" >&2; exit 1; }

physical_cores() {
    local count
    count="$(lscpu -p=CORE,SOCKET 2>/dev/null | awk -F, '!/^#/ { seen[$1 FS $2]=1 } END { print length(seen) }')"
    [[ "${count}" =~ ^[1-9][0-9]*$ ]] || count="$(getconf _NPROCESSORS_ONLN)"
    printf '%s\n' "${count}"
}

numa_nodes() {
    local count
    count="$(lscpu -p=NODE 2>/dev/null | awk -F, '!/^#/ && $1 >= 0 { seen[$1]=1 } END { print length(seen) }')"
    [[ "${count}" =~ ^[1-9][0-9]*$ ]] || count=1
    printf '%s\n' "${count}"
}

CORES="$(physical_cores)"
NODES="$(numa_nodes)"
ARGS=(
    --model "${MODEL}"
    --model-draft "${DRAFT_MODEL}"
    --spec-type 'mtp:n_max=3,p_min=0.0'
    --spec-autotune
    --conversation --color --jinja
    --ctx-size "${GEMMA4_CTX_SIZE:-32768}"
    --batch-size "${GEMMA4_BATCH_SIZE:-1024}"
    --ubatch-size "${GEMMA4_UBATCH_SIZE:-1024}"
    --cache-type-k q8_0 --cache-type-v q8_0
    --threads "${GEMMA4_THREADS:-${CORES}}"
    --threads-batch "${GEMMA4_THREADS_BATCH:-${CORES}}"
    --threads-draft "${GEMMA4_THREADS_DRAFT:-${CORES}}"
    --parallel 1
    --cpu-moe --merge-up-gate-experts
    --flash-attn on --mla-use 3
    --run-time-repack --no-kv-offload
)

case "${GEMMA4_THP:-auto}" in
    auto)
        if [[ -r /sys/kernel/mm/transparent_hugepage/enabled ]] &&
            grep -qv '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled; then
            ARGS+=(--transparent-huge-pages)
        fi
        ;;
    on) ARGS+=(--transparent-huge-pages) ;;
    off) ;;
    *) printf 'Invalid GEMMA4_THP: %s\n' "${GEMMA4_THP}" >&2; exit 2 ;;
esac

case "${GEMMA4_NUMA_MODE:-auto}" in
    auto) ((NODES > 1)) && ARGS+=(--numa distribute) ;;
    off) ;;
    distribute | isolate | numactl) ARGS+=(--numa "${GEMMA4_NUMA_MODE}") ;;
    *) printf 'Invalid GEMMA4_NUMA_MODE: %s\n' "${GEMMA4_NUMA_MODE}" >&2; exit 2 ;;
esac

MODEL_BYTES="$(stat -c %s "${MODEL}")"
DRAFT_BYTES="$(stat -c %s "${DRAFT_MODEL}")"
REQUIRED_MEMLOCK_KIB=$(((MODEL_BYTES + DRAFT_BYTES + 1023) / 1024 + 1024 * 1024))
MEMLOCK_MODE="${GEMMA4_MLOCK:-auto}"
case "${MEMLOCK_MODE}" in
    auto | require)
        HARD_MEMLOCK_KIB="$(ulimit -Hl)"
        if [[ "${HARD_MEMLOCK_KIB}" == unlimited ]] ||
            [[ "${HARD_MEMLOCK_KIB}" =~ ^[0-9]+$ && ${HARD_MEMLOCK_KIB} -ge ${REQUIRED_MEMLOCK_KIB} ]]; then
            if ulimit -Sl "${REQUIRED_MEMLOCK_KIB}" 2>/dev/null; then
                ARGS+=(--mlock)
            elif [[ "${MEMLOCK_MODE}" == require ]]; then
                printf 'Unable to raise the soft memlock limit to %s KiB.\n' "${REQUIRED_MEMLOCK_KIB}" >&2
                exit 1
            fi
        elif [[ "${MEMLOCK_MODE}" == require ]]; then
            printf 'Hard memlock limit %s KiB is below the required %s KiB. Start a new login session or update limits.d.\n' \
                "${HARD_MEMLOCK_KIB}" "${REQUIRED_MEMLOCK_KIB}" >&2
            exit 1
        else
            printf 'WARNING: --mlock disabled: hard limit %s KiB is below required %s KiB. Start a new login session after running the bootstrap.\n' \
                "${HARD_MEMLOCK_KIB}" "${REQUIRED_MEMLOCK_KIB}" >&2
        fi
        ;;
    off) ;;
    *) printf 'Invalid GEMMA4_MLOCK: %s\n' "${MEMLOCK_MODE}" >&2; exit 2 ;;
esac

if [[ -r /proc/meminfo ]]; then
    AVAILABLE_KIB="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
    if [[ "${AVAILABLE_KIB}" =~ ^[0-9]+$ ]] && ((AVAILABLE_KIB < 35 * 1024 * 1024)); then
        printf 'WARNING: only %s GiB RAM is currently available; this configuration generally needs 35-45 GiB.\n' \
            "$((AVAILABLE_KIB / 1024 / 1024))" >&2
    fi
fi

exec "${LLAMA_CLI}" "${ARGS[@]}" "${GEMMA4_EXTRA_ARGS[@]}" "$@"
EOF
} >"${runner_tmp}"
bash -n "${runner_tmp}"
chmod 0755 "${runner_tmp}"
mv -f "${runner_tmp}" "${RUNNER}"

smoke_test() {
    local log_file
    log_file="$(mktemp "${CPU_INFERENCE_HOME}/smoke-test.XXXXXX.log")"
    CLEANUP_PATHS+=("${log_file}")
    log "Running a one-token verifier/MTP compatibility smoke test (timeout: 15 minutes)."
    if ! timeout 900 "${BUILD_DIR}/bin/llama-cli" \
        --model "${MODEL_DIR}/${MODEL_FILE}" \
        --model-draft "${MODEL_DIR}/${DRAFT_FILE}" \
        --spec-type mtp:n_max=1,p_min=0.0 \
        --ctx-size 512 --batch-size 128 --ubatch-size 128 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --threads "$(physical_cores)" --threads-draft "$(physical_cores)" \
        --parallel 1 --cpu-moe --merge-up-gate-experts \
        --flash-attn on --mla-use 3 --run-time-repack --no-kv-offload \
        --jinja --prompt 'Reply with OK.' --n-predict 1 --temp 0 \
        >"${log_file}" 2>&1 </dev/null; then
        cat "${log_file}" >&2
        die "Verifier/MTP smoke test failed."
    fi
    if ! grep -Eqi 'mtp|speculat' "${log_file}"; then
        cat "${log_file}" >&2
        die "Smoke test completed but did not report MTP/speculative decoding initialization."
    fi
    for marker in 'flash_attn[[:space:]]*=[[:space:]]*1' 'fused_up_gate[[:space:]]*=[[:space:]]*1'; do
        grep -Eq "${marker}" "${log_file}" || warn "Smoke-test log did not confirm optimization marker: ${marker}"
    done
    log 'Verifier and MTP drafter smoke test passed.'
}

if [[ "${SKIP_MODELS}" == false && "${SKIP_SMOKE_TEST}" == false ]] &&
    { [[ "${FORCE_SMOKE_TEST}" == true ]] || [[ "${NEED_SMOKE_TEST}" == true ]] || [[ "${MODEL_CHANGED}" == true ]]; }; then
    smoke_test
elif [[ "${FORCE_SMOKE_TEST}" == true && "${SKIP_MODELS}" == true ]]; then
    die "--smoke-test cannot be combined with --skip-models."
fi

log "Installed ${RUNNER} and config ${CONFIG_FILE}."
log "Detected $(physical_cores) physical cores and ${SIMD_DESCRIPTION}."
if [[ "${SKIP_MODELS}" == true ]]; then
    log "Model download was skipped; the runner needs ${MODEL_DIR}/${MODEL_FILE} and ${MODEL_DIR}/${DRAFT_FILE}."
else
    log "Run: ${RUNNER}"
fi
