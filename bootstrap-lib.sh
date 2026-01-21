#!/bin/bash
#
# Basic library functions for my dotfiles
#

# Detect if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _SCRIPT_SOURCED=false
else
    _SCRIPT_SOURCED=true
fi

# Strict error handling (only when executing directly)
if [[ "${_SCRIPT_SOURCED}" == "false" ]]; then
    set -euo pipefail
fi

# Global variables
declare -a _ERRORS=()
declare -a _INSTALLED_PACKAGES=()
declare -a _CREATED_DIRECTORIES=()
declare -a _CREATED_SYMLINKS=()

_MACHINE_ARCH=$(uname -m)

_LOCAL_COMPLETIONS_DIR="${HOME}/.local/share/bash-completion/completions"
_LOCAL_BIN_DIR="${HOME}/.local/bin"

# Architecture mapping for Go downloads
_GOLANG_ARCH=$(
    case "${_MACHINE_ARCH}" in
    x86_64) printf "amd64" ;;
    aarch64) printf "arm64" ;;
    *) printf "unsupported" ;;
esac)

if [[ "${_GOLANG_ARCH}" == "unsupported" ]]; then
    printf "ERROR: Unsupported architecture: %s\n" "${_MACHINE_ARCH}" >&2
    fn_safe_exit 1
fi

# Security and networking configuration
readonly CURL_TIMEOUT=30
readonly CURL_MAX_TIME=300
readonly MAX_RETRIES=3
readonly RETRY_DELAY=2

# Safe exit function that handles both sourcing and executing contexts
fn_safe_exit() {
    local exit_code=${1:-$?}
    if [[ "${_SCRIPT_SOURCED}" == "false" ]]; then
        exit ${exit_code}
    else
        return ${exit_code}
    fi
}

# Cleanup function for trap
fn_cleanup() {
    local exit_code=$?
    
    # Clean up temporary files
    find /tmp -name "*.$$" -user "$(id -u)" -delete 2>/dev/null || true
    
    # If script failed and we have changes to rollback
    if [[ ${exit_code} -ne 0 ]] && [[ ${#_CREATED_SYMLINKS[@]} -gt 0 || ${#_CREATED_DIRECTORIES[@]} -gt 0 ]]; then
        printf "Script failed. Rolling back changes...\n" >&2
        fn_rollback_changes
    fi
    
    fn_safe_exit ${exit_code}
}

# Set up signal handlers (only when executing directly)
if [[ "${_SCRIPT_SOURCED}" == "false" ]]; then
    trap 'fn_cleanup' EXIT ERR INT TERM
fi

fn_check_distro() {
    # Set defaults for os-release variables
    ID="${ID:-unknown}"
    VERSION_CODENAME="${VERSION_CODENAME:-}"
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/etc/os-release
        source /etc/os-release
    fi

    if [[ -n "${TERMUX_VERSION:-}" ]]; then
        export ID="Termux"
    fi

}

fn_log_error() {
    _ERRORS+=("${@}")
}

fn_print_errors() {
    if [[ ${#_ERRORS[@]} -gt 0 ]]; then
        printf "\n\nERRORS:\n"
        for error in "${_ERRORS[@]}"; do
            printf "%s\n" "${error}"
        done
    fi
}

# Security functions
fn_validate_url() {
    local url="$1"
    
    # Check if URL starts with https
    if [[ ! "${url}" =~ ^https:// ]]; then
        printf "ERROR: URL must use HTTPS: %s\n" "${url}" >&2
        return 1
    fi
    
    # Basic URL format validation
    if [[ ! "${url}" =~ ^https://[a-zA-Z0-9.-]+/.*$ ]]; then
        printf "ERROR: Invalid URL format: %s\n" "${url}" >&2
        return 1
    fi
    
    return 0
}

fn_verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    local hash_type="${3:-sha256}"
    
    if [[ ! -f "${file}" ]]; then
        printf "ERROR: File not found for checksum verification: %s\n" "${file}" >&2
        return 1
    fi
    
    local actual_checksum
    case "${hash_type}" in
        sha256)
            actual_checksum=$(sha256sum "${file}" | cut -d' ' -f1)
            ;;
        sha512)
            actual_checksum=$(sha512sum "${file}" | cut -d' ' -f1)
            ;;
        *)
            printf "ERROR: Unsupported hash type: %s\n" "${hash_type}" >&2
            return 1
            ;;
    esac
    
    if [[ "${actual_checksum}" != "${expected_checksum}" ]]; then
        printf "ERROR: Checksum mismatch for %s\n" "${file}" >&2
        printf "Expected: %s\n" "${expected_checksum}" >&2
        printf "Actual:   %s\n" "${actual_checksum}" >&2
        return 1
    fi
    
    return 0
}

fn_secure_download() {
    local url="$1"
    local output_file="$2"
    local expected_checksum="${3:-}"
    local hash_type="${4:-sha256}"
    local retries=0
    
    # Validate URL
    fn_validate_url "${url}" || return 1
    
    # Create output directory if needed
    local output_dir
    output_dir="$(dirname "${output_file}")"
    if [[ ! -d "${output_dir}" ]]; then
        mkdir -p "${output_dir}" || {
            printf "ERROR: Failed to create directory: %s\n" "${output_dir}" >&2
            return 1
        }
    fi
    
    # Download with retries
    while [[ ${retries} -lt ${MAX_RETRIES} ]]; do
        if curl --fail --silent --show-error --location \
                --tlsv1.2 --proto '=https' \
                --connect-timeout "${CURL_TIMEOUT}" \
                --max-time "${CURL_MAX_TIME}" \
                --output "${output_file}" \
                "${url}"; then
            
            # Verify checksum if provided
            if [[ -n "${expected_checksum}" ]]; then
                if fn_verify_checksum "${output_file}" "${expected_checksum}" "${hash_type}"; then
                    return 0
                else
                    rm -f "${output_file}"
                    return 1
                fi
            fi
            
            return 0
        fi
        
        ((retries++))
        if [[ ${retries} -lt ${MAX_RETRIES} ]]; then
            printf "Download failed, retrying in %s seconds... (%s/%s)\n" \
                "${RETRY_DELAY}" "${retries}" "${MAX_RETRIES}" >&2
            sleep "${RETRY_DELAY}"
        fi
    done
    
    printf "ERROR: Failed to download after %s attempts: %s\n" \
        "${MAX_RETRIES}" "${url}" >&2
    return 1
}

fn_validate_path() {
    local path="$1"
    
    # Resolve path and check for directory traversal
    local resolved_path
    resolved_path="$(realpath -m "${path}" 2>/dev/null)" || {
        printf "ERROR: Invalid path: %s\n" "${path}" >&2
        return 1
    }
    
    # Ensure path is within HOME directory for user files
    if [[ "${path}" =~ ^${HOME}/ ]] && [[ ! "${resolved_path}" =~ ^${HOME}/ ]]; then
        printf "ERROR: Path traversal detected: %s -> %s\n" \
            "${path}" "${resolved_path}" >&2
        return 1
    fi
    
    return 0
}

fn_rollback_changes() {
    printf "Rolling back changes...\n"
    
    # Remove created symlinks
    if [[ ${#_CREATED_SYMLINKS[@]} -gt 0 ]]; then
        printf "Removing created symlinks...\n"
        for symlink in "${_CREATED_SYMLINKS[@]}"; do
            if [[ -L "${symlink}" ]]; then
                rm "${symlink}" && printf "Removed symlink: %s\n" "${symlink}"
            fi
        done
    fi
    
    # Remove created directories (in reverse order)
    if [[ ${#_CREATED_DIRECTORIES[@]} -gt 0 ]]; then
        printf "Removing created directories...\n"
        local i
        for ((i=${#_CREATED_DIRECTORIES[@]}-1; i>=0; i--)); do
            local dir="${_CREATED_DIRECTORIES[i]}"
            if [[ -d "${dir}" ]] && [[ -z "$(ls -A "${dir}" 2>/dev/null)" ]]; then
                rmdir "${dir}" && printf "Removed directory: %s\n" "${dir}"
            fi
        done
    fi
    
    printf"Rollback completed.\n"
}

# Common function for GitHub API releases
fn_get_github_latest_release() {
    local repo="$1"
    local filter="${2:-.*}"  # Optional filter for release names
    local temp_file="/tmp/github-releases.$$"
    
    if fn_secure_download "https://api.github.com/repos/${repo}/tags" "${temp_file}"; then
        if command -v jq >/dev/null 2>&1; then
            local release
            release=$(jq -r ".[] | select(.name | test(\"${filter}\")).name" "${temp_file}" 2>/dev/null | head -1)
            rm -f "${temp_file}"
            
            if [[ -n "${release}" && "${release}" != "null" ]]; then
                printf "%s\n" "${release}"
                return 0
            fi
        fi
        rm -f "${temp_file}"
    fi
    
    printf "ERROR: Failed to get latest release for %s\n" "${repo}" >&2
    return 1
}

# Validate input parameters for install functions
fn_validate_install_params() {
    local tool_name="$1"
    local install_path="$2"
    
    if [[ -z "${tool_name}" ]]; then
        printf "ERROR: Tool name cannot be empty" >&2
        return 1
    fi
    
    if [[ -z "${install_path}" ]]; then
        printf "ERROR: Install path cannot be empty" >&2
        return 1
    fi
    
    # Validate install path is within expected directories
    if [[ ! "${install_path}" =~ ^(${_LOCAL_BIN_DIR}|${HOME}/.cargo/bin|${HOME}/go/bin)/ ]]; then
        printf "ERROR: Install path outside allowed directories: %s\n" "${install_path}" >&2
        return 1
    fi
    
    return 0
}

# Ensure the needed dirs exist
fn_mkdir_if_needed() {
    local dir="$1"
    
    # Validate path
    fn_validate_path "${dir}" || return 1
    
    if [[ ! -d "${dir}" ]]; then
        if mkdir -p "${dir}"; then
            _CREATED_DIRECTORIES+=("${dir}")
            printf "Created directory: %s\n" "${dir}"
        else
            fn_log_error "Failed to create directory: ${dir}"
            return 1
        fi
    fi
}

fn_system_install_chrome() {
    # Chrome is stilly and special because $reasons 
    if ! rpm -q google-chrome-stable &>/dev/null; then
        sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm \
            || fn_log_error "${FUNCNAME[0]}: failed to dnf install google-chrome-stable"
    fi

    ###########################################################################
    # FIXME: This does not behave well on RHEL9 so we'll wait for now ...
    #
    #   For some reason this messes up the scaling of the display, font
    #   preferences, and accessability settings.
    ###########################################################################
    # # force wayland for chrome
    # chrome_desktop_file_path="/usr/share/applications/google-chrome.desktop"
    # chrome_desktop_local_path="${HOME}/.local/share/applications/google-chrome.desktop"
    # if [[ -f ${chrome_desktop_file_path} ]]; then
    #     if [[ ! -f ${chrome_desktop_local_path} ]]; then
    #         printf "Forcing wayland for google-chrome...\n"
    #         cp "${chrome_desktop_file_path}" "${chrome_desktop_local_path}"
    #
    #         sed -i \
    #             's|Exec=/usr/bin/google-chrome-stable|Exec=google-chrome-stable --enable-features=UseOzonePlatform --ozone-platform=wayland|'
    #             "${chrome_desktop_local_path}"
    #         update-desktop-database ~/.local/share/applications/
    #     fi
    # elif [[ -f ${chrome_desktop_local_path} ]]; then
    #     printf "Removing local google-chrome desktop file...\n"
    #     rm "${chrome_desktop_local_path}"
    # fi
}

fn_system_install_gcloud() {
    fn_check_distro
    if [[ "${ID}" == "rhel" ]] || [[ "${ID}" == "redhat" ]] || [[ "${ID}" == "centos" ]]; then
        if [[ ! -f /etc/yum.repos.d/google-cloud-sdk.repo ]]; then
            printf "Installing gcloud repo...\n"
            sudo tee /etc/yum.repos.d/google-cloud-sdk.repo &>/dev/null << "EOF"
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el$releasever-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
        fi
        if ! rpm -q google-cloud-cli &>/dev/null; then
            printf "Installing gcloud...\n"
            sudo dnf install -y libxcrypt-compat.x86_64 || fn_log_error "${FUNCNAME[0]}: failed to dnf install libxcrypt-compat"
            sudo dnf install -y google-cloud-cli || fn_log_error "${FUNCNAME[0]}: failed to dnf install google-cloud-cli"
        fi
    fi
}

fn_system_setup_rht_copr() {
    fn_check_distro
    local repofile='/etc/yum.repos.d/_copr:copr.devel.redhat.com:group_endpoint-systems-sysadmins:unsupported-fedora-packages.repo'
    # Use Billings' COPR
    
    if ! [[ -f ${repofile} ]]; then
        printf "Installing rht-copr repo...\n"
        if [[ "${ID}" == "rhel" ]] || [[ "${ID}" == "redhat" ]] || [[ "${ID}" == "centos" ]]; then
            sudo tee ${repofile} &>/dev/null << "EOF"
[copr:copr.devel.redhat.com:group_endpoint-systems-sysadmins:unsupported-fedora-packages]
name=Copr repo for unsupported-fedora-packages owned by @endpoint-systems-sysadmins
baseurl=https://coprbe.devel.redhat.com/results/@endpoint-systems-sysadmins/unsupported-fedora-packages/epel-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://coprbe.devel.redhat.com/results/@endpoint-systems-sysadmins/unsupported-fedora-packages/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF
        fi
        
        if [[ "${ID}" == "fedora" ]]; then
            sudo tee ${repofile} &>/dev/null << "EOF"
[copr:copr.devel.redhat.com:group_endpoint-systems-sysadmins:unsupported-fedora-packages]
name=Copr repo for unsupported-fedora-packages owned by @endpoint-systems-sysadmins
baseurl=https://coprbe.devel.redhat.com/results/@endpoint-systems-sysadmins/unsupported-fedora-packages/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://coprbe.devel.redhat.com/results/@endpoint-systems-sysadmins/unsupported-fedora-packages/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF
        fi
    fi
    
    if ! [[ -f ${repofile} ]]; then
        fn_log_error "${FUNCNAME[0]}: Failed to setup rht copr"
    fi
}

# Symlink the conf files
fn_symlink_if_needed() {
    local source="$1"
    local target="$2"
    local backup_file
    
    # Validate paths
    fn_validate_path "${source}" || return 1
    fn_validate_path "${target}" || return 1
    
    # Check if source exists
    if [[ ! -e "${source}" ]]; then
        fn_log_error "Source file does not exist: ${source}"
        return 1
    fi
    
    # Create atomic operation for file backup and symlinking
    if [[ -f "${target}" ]] && [[ ! -L "${target}" ]]; then
        backup_file="${target}.old$(date +%Y%m%d_%H%M%S)"
        printf "File found: %s ... backing up to %s\n" "${target}" "${backup_file}"
        
        if ! mv "${target}" "${backup_file}"; then
            fn_log_error "Failed to back up ${target}"
            return 1
        fi
    fi
    
    if [[ ! -f "${target}" ]] && [[ ! -L "${target}" ]]; then
        printf "Symlinking: %s -> %s\n" "${source}" "${target}"
        
        local target_dir
        target_dir="$(dirname "${target}")"
        if [[ ! -d "${target_dir}" ]]; then
            fn_mkdir_if_needed "${target_dir}" || return 1
        fi
        
        if ln -s "${source}" "${target}"; then
            _CREATED_SYMLINKS+=("${target}")
        else
            fn_log_error "Failed to create symlink: ${source} -> ${target}"
            return 1
        fi
    fi
}

fn_rm_on_update_if_needed() {
    # 
    # Arguments:
    #   $1 - str: path to local installed executable
    #   $2 - str: latest upstream release
    #   $3 - str: string representation of the current locally installed version
    #   $4 - array: list of files to remove
    local uninstall_paths
    uninstall_paths=("$@")
    # drop the first three strings
    unset "uninstall_paths[0]"
    unset "uninstall_paths[1]"
    unset "uninstall_paths[2]"

    if [[ -f ${1:-} ]]; then
        if [[ ${2:-} != "${3:-}" ]]; then
            rm -f "${uninstall_paths[@]}" || fn_log_error "${FUNCNAME[0]}: failed to rm ${1:-}"
        fi
    fi
}

fn_system_polkit_libvirt_nonroot_user() {
    local polkit_file_path="/etc/polkit-1/rules.d/50-org.libvirt.unix.manage.rules"
    if ! sudo test -f "${polkit_file_path}"; then
        printf "Setting polkit libvirt non-root user...\n"
        sudo tee "${polkit_file_path}" &>/dev/null << EOF
polkit.addRule(function(action, subject) {
        if (action.id == "org.libvirt.unix.manage" &&
            subject.user == "${USER}") {
                return polkit.Result.YES;
                polkit.log("action=" + action);
                polkit.log("subject=" + subject);
        }
});
EOF
fi
    if ! sudo test -f ${polkit_file_path}; then
        fn_log_error "${FUNCNAME[0]}: failed to set polkit libvirt non-root user"
    fi
}

fn_system_install_tailscale() {
    fn_check_distro
    if [[ "${ID}" == "debian" ]]; then 
        # tailscale
        local tailscale_keyring="/usr/share/keyrings/tailscale-archive-keyring.gpg"
        local tailscale_aptlist="/etc/apt/sources.list.d/tailscale.list"
        local temp_keyring="/tmp/tailscale-keyring.gpg"
        local temp_aptlist="/tmp/tailscale.list"
        
        if ! dpkg -l tailscale > /dev/null 2>&1; then
            printf "Installing Tailscale for Debian...\n"
            
            # Download keyring securely
            if fn_secure_download "https://pkgs.tailscale.com/stable/debian/${VERSION_CODENAME}.noarmor.gpg" "${temp_keyring}"; then
                sudo mv "${temp_keyring}" "${tailscale_keyring}" || fn_log_error "${FUNCNAME[0]}: failed to install keyring"
            else
                fn_log_error "${FUNCNAME[0]}: failed to download keyring"
                return 1
            fi

            # Download apt list securely
            if fn_secure_download "https://pkgs.tailscale.com/stable/debian/${VERSION_CODENAME}.tailscale-keyring.list" "${temp_aptlist}"; then
                sudo mv "${temp_aptlist}" "${tailscale_aptlist}" || fn_log_error "${FUNCNAME[0]}: failed to install apt list"
            else
                fn_log_error "${FUNCNAME[0]}: failed to download apt list"
                return 1
            fi

            sudo apt update || fn_log_error "${FUNCNAME[0]}: failed to update package list"
            sudo apt install -y tailscale || fn_log_error "${FUNCNAME[0]}: failed to install tailscale"
        fi
    fi
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        if ! rpm -q tailscale &>/dev/null; then
            local el_major_version
            el_major_version=$(rpm -E %rhel)
            sudo dnf config-manager --add-repo "https://pkgs.tailscale.com/stable/rhel/${el_major_version}/tailscale.repo"
            #sudo dnf config-manager addrepo "https://pkgs.tailscale.com/stable/rhel/${el_major_version}/tailscale.repo"
            sudo dnf install -y tailscale || fn_log_error "${FUNCNAME[0]}: failed to install tailscale"
            sudo systemctl enable --now tailscaled || fn_log_error "${FUNCNAME[0]}: failed to enable tailscale.service"
        fi
    fi
    if [[ "${ID}" == "fedora" ]]; then
        if ! rpm -q tailscale &>/dev/null; then
            # sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo
            sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo --overwrite
            sudo dnf install -y tailscale || fn_log_error "${FUNCNAME[0]}: failed to install tailscale"
            sudo systemctl enable --now tailscaled || fn_log_error "${FUNCNAME[0]}: failed to enable tailscale.service"
        fi
    fi

}

fn_system_install_command_line_assistant() {
    fn_check_distro
    local pkg_name="command-line-assistant"
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" || "${ID}" == "fedora" ]]; then
        if ! rpm -q "${pkg_name}" &>/dev/null; then
            if [[ "${ID}" == "fedora" ]]; then
                sudo dnf copr enable @rhel-lightspeed/command-line-assistant
            fi
            sudo dnf install -y "${pkg_name}" || fn_log_error "${FUNCNAME[0]}: failed to install ${pkg_name}"
        fi
    fi

}

fn_system_install_packages() {
    # accept a list of packages and install them
    
    fn_check_distro

    # Input validation
    if [[ $# -eq 0 ]]; then
        fn_log_error "${FUNCNAME[0]}: No packages specified"
        return 1
    fi

    local pending_install_pkgs=()
    for pkg in "${@}"; do
        # Validate package name (basic alphanumeric + common chars)
        if [[ ! "${pkg}" =~ ^[a-zA-Z0-9._+-]+$ ]]; then
            fn_log_error "${FUNCNAME[0]}: Invalid package name: ${pkg}"
            continue
        fi
        if [[ "${ID}" == "debian" || "${ID}" == "Termux" ]]; then 
            if ! dpkg -s "${pkg}" | grep "Status: install ok installed" > /dev/null 2>&1; then
                pending_install_pkgs+=("${pkg}")
            fi
        fi
        if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" || "${ID}" == "fedora" ]]; then
            if ! rpm -q "${pkg}" &>/dev/null; then
                pending_install_pkgs+=("${pkg}")
            fi
        fi
    done
    if [[ -n "${pending_install_pkgs[*]}" ]]; then
        printf "Installing packages... %s\n" "${pending_install_pkgs[@]}"
        if [[ "${ID}" == "debian" ]]; then 
            sudo apt install -y "${pending_install_pkgs[@]}" || fn_log_error "${FUNCNAME[0]}: failed to install packages: ${pending_install_pkgs[*]}"
        fi
        if [[ "${ID}" == "Termux" ]]; then 
            pkg install -y "${pending_install_pkgs[@]}" || fn_log_error "${FUNCNAME[0]}: failed to install packages: ${pending_install_pkgs[*]}"
        fi
        if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" || "${ID}" == "fedora" ]]; then
            # intentionally want word splitting so don't quote
            sudo dnf install -y --allowerasing "${pending_install_pkgs[@]}" || fn_log_error "${FUNCNAME[0]}: failed to install packages: ${pending_install_pkgs[*]}"
        fi
    fi
}

fn_flatpak_overrides() {
    # # Chrome
    # local chrome_override_file="${HOME}/.local/share/flatpak/overrides/com.google.Chrome"
    # fn_mkdir_if_needed "$(dirname "${chrome_override_file}")"
    # cat > "${chrome_override_file}" << "EOF"
# [Context]
# filesystems=~/.local/share/icons/;~/.local/share/applications/
# EOF
    # if ! [[ -f "${chrome_override_file}" ]]; then
    #     fn_log_error "${FUNCNAME[0]}: failed to create flatpak override file: ${chrome_override_file}"
    # fi


    # Slack
    local slack_override_file="${HOME}/.local/share/flatpak/overrides/com.slack.Slack"
    fn_mkdir_if_needed "$(dirname "${slack_override_file}")"
    cat > "${slack_override_file}" << "EOF"
[Context]
filesystems=~/Pictures/Screenshots/
EOF
    if ! [[ -f "${slack_override_file}" ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to create flatpak override file: ${slack_override_file}"
    fi
    
    # # GNOME Web (epiphany)
    # local gnome_web_override_file="${HOME}/.local/share/flatpak/overrides/org.gnome.Epiphany"
    # fn_mkdir_if_needed "$(dirname "${gnome_web_override_file}")"
    # cat > "${gnome_web_override_file}" << "EOF"
# [Context]
# filesystems=~/.local/share/icons/;~/.local/share/applications/
# EOF
    # if ! [[ -f "${gnome_web_override_file}" ]]; then
    #     fn_log_error "${FUNCNAME[0]}: failed to create flatpak override file: ${gnome_web_override_file}"
    # fi
}

fn_flathub_install() {
    fn_flatpak_overrides

    local flatpak_pkgs
    flatpak_pkgs=(
        "hu.irl.cameractrls"
        "com.slack.Slack"
        "org.onlyoffice.desktopeditors"
        "io.podman_desktop.PodmanDesktop"
        "com.google.Chrome"
        "com.github.tchx84.Flatseal"
        "org.signal.Signal"
        "im.fluffychat.Fluffychat"
        "org.gnome.Epiphany"
    )
    if ! flatpak remotes --user | grep flathub &>/dev/null; then
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
            || fn_log_error "${FUNCNAME[0]}: failed to add flathub remote"
    fi
    for flatpak_pkg in "${flatpak_pkgs[@]}"; do
        if ! flatpak list | grep "${flatpak_pkg}" &>/dev/null; then
            flatpak install --user -y flathub "${flatpak_pkg}" \
                || fn_log_error "${FUNCNAME[0]}: failed to install flatpak ${flatpak_pkg}"
        fi
    done
}

fn_system_gnome_settings() {
    # key remap because fuck the capslock key
    local current_xkb_options
    local new_xkb_options

    if dconf help &>/dev/null; then
        current_xkb_options=$(dconf read /org/gnome/desktop/input-sources/xkb-options 2>/dev/null)
        if [[ -z "${current_xkb_options}" ]] || [[ "${current_xkb_options}" == "@as []" ]]; then
            # if current_xkb_options is empty, set it
            new_xkb_options="['caps:escape']"
        else
            # if current_xkb_options is empty, modify it
            new_xkb_options=${current_xkb_options//\[/\[\'caps:escape\', }
        fi
        if ! [[ "${current_xkb_options}" =~ "caps:escape" ]]; then
            dconf write /org/gnome/desktop/input-sources/xkb-options "${new_xkb_options}" \
                || fn_log_error "${FUNCNAME[0]}: failed to set xkb-options"
        fi
    fi

    if gsettings help &>/dev/null; then
        # set alt-tab behavior for sanity
        gsettings set org.gnome.desktop.wm.keybindings switch-applications "[]" \
            || fn_log_error "${FUNCNAME[0]}: failed to set gsettings switch-applications"
        gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "[]" \
            || fn_log_error "${FUNCNAME[0]}: failed to set gsettings switch-applications-backward"
        gsettings set org.gnome.desktop.wm.keybindings switch-windows "['<Alt>Tab']" \
            || fn_log_error "${FUNCNAME[0]}: failed to set gsettings switch-windows"
        gsettings set org.gnome.desktop.wm.keybindings switch-windows-backward "['<Shift><Alt>Tab']" \
            || fn_log_error "${FUNCNAME[0]}: failed to set gsettings switch-windows-backward"
        # enable GNOME Fractional Scaling
        # gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']" \
        #     || fn_log_error "${FUNCNAME[0]}: failed to set gsettings scale-monitor-framebuffer for fractional scaling"
    fi

}

fn_system_docker_crostini() {
    # https://docs.docker.com/engine/install/debian/
    # fucking docker ...
    if ! dpkg -l docker-ce | grep "${_GOLANG_ARCH}" > /dev/null 2>&1; then
        for pkg in docker.io docker-doc docker-compose podman-docker containerd runc
        do
            sudo apt remove "${pkg}" || fn_log_error "${FUNCNAME[0]}: failed to remove package ${pkg}"
        done
        sudo apt install -y ca-certificates curl gnupg || fn_log_error "${FUNCNAME[0]}: failed to install packages ca-certificates curl gnupg"
        sudo install -m 0755 -d /etc/apt/keyrings || fn_log_error "${FUNCNAME[0]}: failed to create /etc/apt/keyrings"
        curl -fsSL https://download.docker.com/linux/debian/gpg | \
            sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || fn_log_error "${FUNCNAME[0]}: failed to download docker gpg key"
        sudo chmod a+r /etc/apt/keyrings/docker.gpg || fn_log_error "${FUNCNAME[0]}: failed to set docker gpg key permission"
        echo \
            "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
            \"$(. /etc/os-release && echo "${VERSION_CODENAME}")\" stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
            || fn_log_error "${FUNCNAME[0]}: failed to install packages: docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
        if ! grep docker /etc/group >/dev/null; then
            sudo groupadd docker || fn_log_error "${FUNCNAME[0]}: failed to add group docker"
        fi
        if ! id -nG admiller | grep docker >/dev/null; then
            sudo usermod -aG docker "${USER}" || fn_log_error "${FUNCNAME[0]}: failed to add user ${USER} to group docker"
        fi
    fi
}

fn_system_setup_termux() {

    # random dev stuff
    local pkglist
    pkglist=(
        "apt-file"
        "python"
        "python-pip"
        "uv"
        "nodejs"
        "git"
        "tig"
        "tmux"
        "htop"
        "strace"
        "tree"
        "nmap"
        "jq"
        "luarocks"
        "clang"
        "make"
        "cmake"
        "ninja"
        "gettext"
        "unzip"
        "curl"
        "wget"
        "fd"
        "shellcheck"
        "ripgrep"
        "git-crypt"
        "rlwrap"
        "mosh"
        "golang"
        "openssh"
        "mandoc"
        "krb5"
    )
    fn_system_install_packages "${pkglist[@]}"

}

fn_system_setup_crostini() {
    fn_system_install_tailscale

    local nodejs_keyring="/etc/apt/keyrings/nodesource.gpg"
    local nodejs_aptfile="/etc/apt/sources.list.d/nodesource.list"

    # nodejs LTS
    NODE_MAJOR=22
    if ! dpkg -l nodejs | grep ${NODE_MAJOR}\. > /dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg || fn_log_error "${FUNCNAME[0]}: failed to install ca-certificates curl gnupg"
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o "${nodejs_keyring}"
        if ! [[ -f "${nodejs_keyring}" ]]; then
            fn_log_error "${FUNCNAME[0]}: failed to download ${nodejs_keyring}"
        fi
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | sudo tee "${nodejs_aptfile}"
        if ! [[ -f ${nodejs_aptfile} ]]; then
            fn_log_error "${FUNCNAME[0]}: failed to download ${nodejs_aptfile}"
        fi
        sudo apt update
        sudo apt install -y nodejs || fn_log_error "${FUNCNAME[0]}: failed to install nodejs"
    fi

    fn_system_docker_crostini

    # random dev stuff
    local pkglist
    pkglist=(
        "vim-nox"
        "apt-file"
        "debsums"
        "python3"
        "python3-pip"
        "python3-venv"
        "python3-q"
        "python3-pylsp"
        "python3-virtualenvwrapper"
        "python-is-python3"
        "uv"
        "git"
        "tig"
        "tmux"
        "htop"
        "btop"
        "iotop"
        "strace"
        "tree"
        "pipx"
        "libonig-dev"
        "firefox-esr"
        "debian-goodies"
        "flatpak"
        "bubblewrap"
        "tshark"
        "termshark"
        "nmap"
        "jq"
        "podman"
        "skopeo"
        "buildah"
        "luarocks"
        "cmake"
        "ninja-build"
        "gettext"
        "unzip"
        "curl"
        "fd-find"
        "shellcheck"
        "ripgrep"
        "git-crypt"
        "wl-clipboard"
        "rlwrap"
        "mosh"
    )
    fn_system_install_packages "${pkglist[@]}"

    # golang
    golang_version="1.23.3"
    if dpkg -l golang > /dev/null 2>&1; then
        sudo apt remove -y golang 
    fi

    if ! go version | grep "$golang_version" > /dev/null 2>&1; then
        sudo rm -fr /usr/local/go
    fi
    if [[ ! -d /usr/local/go ]]; then
        printf "Installing golang...\n"
        sudo curl -o "/usr/local/go-${golang_version}.tar.gz" "https://dl.google.com/go/go${golang_version}.linux-$(dpkg --print-architecture).tar.gz" \
            || fn_log_error "${FUNCNAME[0]}: failed to download /usr/local/go-${golang_version}.tar.gz"
        sudo tar -zxvf /usr/local/go-${golang_version}.tar.gz --directory=/usr/local/ \
            || fn_log_error "${FUNCNAME[0]}: failed to extract /usr/local/go-${golang_version}.tar.gz"
        sudo rm /usr/local/go-${golang_version}.tar.gz \
            || fn_log_error "${FUNCNAME[0]}: failed to remove /usr/local/go-${golang_version}.tar.gz"
    fi

    # podman subuid/subgid
    podman_system_migrate=""
    if ! grep -q "${USER}:10000:65536" /etc/subuid; then
        sudo sh -c "echo ${USER}:10000:65536 >> /etc/subuid"
        podman_system_migrate="true"
    fi
    if ! grep -q "${USER}:10000:65536" /etc/subgid; then
        sudo sh -c "echo ${USER}:10000:65536 >> /etc/subgid"
        podman_system_migrate="true"
    fi
    if [[ ${podman_system_migrate} == "true" ]]; then
        printf "Migrating podman system...\n"
        podman system migrate
    fi

    # Force wayland for firefox-esr
    firefox_esr_desktop_file_path="/usr/share/applications/firefox-esr.desktop"
    firefox_esr_desktop_local_path="${HOME}/.local/share/applications/firefox-esr.desktop"
    if [[ -f ${firefox_esr_desktop_file_path} ]]; then 
        if [[ ! -f ${firefox_esr_desktop_local_path} ]]; then
            printf "Forcing wayland for firefox-esr...\n"
            cp "${firefox_esr_desktop_file_path}" "${firefox_esr_desktop_local_path}"
            sed -i \
                's|Exec=/usr/lib/firefox-esr/firefox-esr %u|Exec=env MOZ_ENABLE_WAYLAND=1 /usr/lib/firefox-esr/firefox-esr %u|' \
                "${firefox_esr_desktop_local_path}"
        fi
        if [[ ! -f ${firefox_esr_desktop_local_path} ]]; then
            fn_log_error "${FUNCNAME[0]}: failed to set local firefox-esr desktop file"
        fi
    elif [[ -f ${firefox_esr_desktop_local_path} ]]; then
        printf "Removing local firefox-esr desktop file...\n"
        rm "${firefox_esr_desktop_local_path}"
    fi

    vscode_desktop_file_path="/usr/share/applications/code.desktop"
    vscode_local_file_path="${HOME}/.local/share/applications/code.desktop"
    if [[ -f ${vscode_desktop_file_path} ]]; then
        if [[ ! -f ${vscode_local_file_path} ]]; then
            printf "Forcing wayland for vscode...\n"
            cp "${vscode_desktop_file_path}" "${vscode_local_file_path}"
            sed -i \
                's|Exec=/usr/share/code/code|Exec=/usr/share/code/code --enable-features=UseOzonePlatform --ozone-platform=wayland|g' \
                "${vscode_local_file_path}"
        fi
        if [[ ! -f ${vscode_local_file_path} ]]; then
            fn_log_error "${FUNCNAME[0]}: failed to set local vscode desktop file"
        fi
    elif [[ -f "${vscode_local_file_path}" ]]; then
        printf "Removing local vscode desktop file...\n"
        rm "${vscode_local_file_path}"
    fi
}

fn_system_install_epel(){
    # Install EPEL
    local el_major_version
    el_major_version=$(rpm -E %rhel)
    if ! rpm -q epel-release &>/dev/null; then
        if [[ -f /etc/centos-release ]]; then
            sudo dnf config-manager --enable crb || fn_log_error "${FUNCNAME[0]}: failed to enable crb"
            sudo dnf -y install epel-release || fn_log_error "${FUNCNAME[0]}: failed to install epel-release"
        else
            sudo subscription-manager repos --enable "codeready-builder-for-rhel-${el_major_version}-$(arch)-rpms" \
                || fn_log_error "${FUNCNAME[0]}: failed to enable codeready-builder-for-rhel-${el_major_version}-$(arch)-rpms"
            sudo dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${el_major_version}.noarch.rpm" \
                || fn_log_error "${FUNCNAME[0]}: failed to install epel-release"
        fi
    fi

}

fn_system_setup_fedora_el() {
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        local el_major_version
        el_major_version=$(rpm -E %rhel)
    fi
    # Setup for Fedora/RHEL/CentOS-Stream
    #
    fn_mkdir_if_needed ~/.local/bin/
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"

    # random dev stuff
    local fedora_el_pkglist
    fedora_el_pkglist=(
        "vim-enhanced"
        "python3"
        "python3-pip"
        "python3-devel"
        "python-unversioned-command"
        "uv"
        "nodejs"
        "nodejs-npm"
        "git"
        "tig"
        "tmux"
        "htop"
        "btop"
        "strace"
        "tree"
        "pipx"
        "flatpak"
        "wireshark-cli"
        "nmap"
        "jq"
        "podman"
        "skopeo"
        "buildah"
        "luarocks"
        "cmake"
        "gcc"
        "gcc-c++"
        "golang"
        "rust"
        "cargo"
        "gettext"
        "unzip"
        "curl"
        "ShellCheck"
        "dconf"
        "xsel"
        "ripgrep"
        "centpkg"
        "centpkg-sig"
        "subscription-manager"
        "git-crypt"
        "wl-clipboard"
        "rlwrap"
        "mosh"
        "lm_sensors"
        "rpmconf"
        "ramalama"
        "iotop-c"
        "ninja-build"
        "fedpkg"
        "pcp-system-tools"
        "fzf"
        "fd-find"
    )
    
    # these are needed for the uv tool install of rh-aws-saml-login
    fedora_el_pkglist+=(
    "krb5-devel"
    "python3-devel"
    "clang"
    )

    if [[ -z "${TOOLBOX_PATH:-}" ]]; then
        # only install the toolbox package if we're not in a toolbox container
        fedora_el_pkglist+=(
            "toolbox"
        )
    fi
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        if [[ "${el_major_version}" -lt 10 ]]; then
            fedora_el_pkglist+=(
                "python3.12"
                "python3.12-pip"
            )
        fi
        # NEOVIM STUB
        # if [[ "${el_major_version}" -lt 10 ]]; then
        #     fn_local_install_neovim
        # fi
        # if [[ "${el_major_version}" -ge 10 ]]; then
        #     fedora_el_pkglist+=(
        #         "neovim"
        #     )
        # fi
    fi
    if [[ "${ID}" == "fedora" ]]; then
        fedora_el_pkglist+=(
            # NEOVIM STUB
            # "neovim"
            # "python3-neovim"
            "python3-torch"
            "fedora-review"
            "v4l-utils"
            "weechat"
        )
        if grep "AMD Ryzen" /proc/cpuinfo &>/dev/null; then
            fedora_el_pkglist+=(
            "rocminfo"
            "rocm-runtime"
            "rocm-smi"
            "nvtop"
        )
        fi
    fi

    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        fn_system_install_epel
    fi
    fn_system_setup_rht_copr

    fn_system_install_packages "${fedora_el_pkglist[@]}"
    sudo usermod "${USER}" -a -G mock

    # RHEL Lightspeed / command-line-assistant
    fn_system_install_command_line_assistant

    # NEOVIM STUB
    # if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
    #     if [[ "${el_major_version}" -lt 10 ]]; then
    #         fn_local_install_neovim
    #     fi
    # fi

    # Only install the GUI/machine utils if we're on a real system and not in a toolbox container
    if [[ -z "${TOOLBOX_PATH:-}" ]]; then
        fn_system_polkit_libvirt_nonroot_user

        fn_flathub_install

        fn_system_gnome_settings
 
        # Tailscale
        fn_system_install_tailscale
    fi
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        # Only disable ssh and cockpit if we're on a desktop system and not in a toolbox container
        if ! [[ -z "${DESKTOP_SESSION:-}" ]] && [[ -z "${TOOLBOX_PATH:-}" ]]; then
            local systemctl_sshd_enabled
            local systemctl_sshd_active
            systemctl_sshd_enabled="$(sudo systemctl is-enabled sshd || true)"
            systemctl_sshd_active="$(sudo systemctl is-active sshd || true)"

            if [[ "${systemctl_sshd_enabled}" == "enabled" || "${systemctl_sshd_active}" == "active" ]]; then
                printf "Disabling SSH...\n"
                sudo systemctl stop sshd || fn_log_error "${FUNCNAME[0]}: failed to stop sshd"
                sudo systemctl disable sshd || fn_log_error "${FUNCNAME[0]}: failed to disable sshd"

                if sudo firewall-cmd --list-all | grep ssh > /dev/null; then
                    sudo firewall-cmd --remove-service=ssh --permanent || fn_log_error "${FUNCNAME[0]}: failed to remove ssh from firewall-cmd permanently"
                    sudo firewall-cmd --remove-service=ssh || fn_log_error "${FUNCNAME[0]}: failed to remove ssh from firewall-cmd"
                fi
            fi

            local systemctl_cockpit_service_enabled
            local systemctl_cockpit_service_active
            local systemctl_cockpit_socket_enabled
            local systemctl_cockpit_socket_active
            systemctl_cockpit_service_enabled="$(sudo systemctl is-enabled cockpit.service || true)"
            systemctl_cockpit_service_active="$(sudo systemctl is-active cockpit.service || true)"
            systemctl_cockpit_socket_enabled="$(sudo systemctl is-enabled cockpit.socket || true)"
            systemctl_cockpit_socket_active="$(sudo systemctl is-active cockpit.socket || true)"
            if [[ "${systemctl_cockpit_service_enabled}" == "enabled" || "${systemctl_cockpit_socket_enabled}" == "enabled" || \
                "${systemctl_cockpit_service_active}" == "active" || "${systemctl_cockpit_socket_active}" == "active" ]]; then
                printf "Disabling cockpit...\n"
                sudo systemctl stop cockpit.socket || fn_log_error "${FUNCNAME[0]}: failed to stop cockpit.socket"
                sudo systemctl stop cockpit.service || fn_log_error "${FUNCNAME[0]}: failed to stop cockpit.service"
                sudo systemctl disable cockpit.socket || fn_log_error "${FUNCNAME[0]}: failed to disable cockpit.socket"
                sudo systemctl disable cockpit.service || fn_log_error "${FUNCNAME[0]}: failed to disable cockpit.service"

                if sudo firewall-cmd --list-all | grep cockpit > /dev/null; then
                    sudo firewall-cmd --remove-service=cockpit --permanent || fn_log_error "${FUNCNAME[0]}: failed to remove cockpit from firewall-cmd permanently"
                    sudo firewall-cmd --remove-service=cockpit || fn_log_error "${FUNCNAME[0]}: failed to remove cockpit from firewall-cmd"
                fi
            fi
        fi
    fi
}

fn_local_install_virtualenvwrapper(){
    # virtualenvwrapper
    if ! pip list | grep virtualenvwrapper &>/dev/null; then
        pip install --user virtualenvwrapper || fn_log_error "${FUNCNAME[0]}: failed to install virtualenvwrapper"
    fi
}

fn_ensure_npm_prefix() {
    local npm_prefix
    npm_prefix=$(npm get prefix)
    if ! [[ "${npm_prefix}" == "${HOME}/.local" ]]; then
        npm config set prefix "${HOME}/.local/"
    fi

    local npm_config_os
    npm_config_os=$(npm config get os)
    if ! [[ "${npm_config_os}" == "linux" ]]; then
        npm config set os linux
    fi
}

fn_local_install_claude_code() {
    fn_ensure_npm_prefix
    local bin_path
    bin_path="${HOME}/.local/bin/claude"
    if ! [[ -f "${bin_path}" ]]; then
        printf "Installing Claude Code...\n"
        npm install -g @anthropic-ai/claude-code
    fi
    if ! [[ -f "${bin_path}" ]]; then
        fn_log_error "Claude Code npm install failed"
    fi
}

fn_local_install_claude_code_requirements_builder() {
    fn_mkdir_if_needed "${HOME}/src/"
    fn_mkdir_if_needed "${HOME}/.claude/commands"
    if ! [[ -d "${HOME}/src/claude-code-requirements-builder" ]]; then
        git clone https://github.com/rizethereum/claude-code-requirements-builder.git "${HOME}/src/claude-code-requirements-builder"
        fn_symlink_if_needed "${HOME}/src/claude-code-requirements-builder" "${HOME}/.claude/commands"
    fi
}

fn_local_install_super_claude() {
    fn_mkdir_if_needed "${HOME}/.claude/commands/"
    local super_claude_path="${HOME}/.claude/commands/sc/"
    if ! [[ -d "${super_claude_path}" ]]; then
        uv tool run SuperClaude install --quick -y || fn_log_error "${FUNCNAME[0]}: failed to install SuperClaude"
    fi
}

fn_local_install_openai_codex() {
    fn_ensure_npm_prefix
    local bin_path
    bin_path="${HOME}/.local/bin/codex"
    if ! [[ -f "${bin_path}" ]]; then
        printf "Installing OpenAI Codex...\n"
        npm install -g @openai/codex
    fi
    if ! [[ -f "${bin_path}" ]]; then
        fn_log_error "OpenAI Codex npm install failed"
    fi
}


fn_local_install_amp_code() {
    fn_ensure_npm_prefix
    local bin_path
    bin_path="${HOME}/.local/bin/amp"
    if ! [[ -f "${bin_path}" ]]; then
        printf "Installing amp...\n"
        npm install -g @sourcegraph/amp
    fi
    if ! [[ -f "${bin_path}" ]]; then
        fn_log_error "Amp npm install failed"
    fi
}

fn_local_install_gemini() {
    fn_ensure_npm_prefix
    local bin_path
    bin_path="${HOME}/.local/bin/gemini"
    if ! [[ -f "${bin_path}" ]]; then
        printf "Installing Gemini CLI...\n"
        npm install -g @google/gemini-cli
    fi
    if ! [[ -f ${bin_path} ]]; then
        fn_log_error "Gemini CLI npm install failed"
    fi
}

fn_local_bash_language_server() {
    fn_ensure_npm_prefix
    local bin_path
    bin_path="${HOME}/.local/bin/bash-language-server"
    if ! [[ -f "${bin_path}" ]]; then
        printf "Installing bash language server...\n"
        npm install -g bash-language-server
    fi
    if ! [[ -f ${bin_path} ]]; then
        fn_log_error "Bash language server npm install failed"
    fi
}

fn_local_user_ssh_agent() {
    # ssh-agent systemd user unit
    local ssh_agent_unit="${HOME}/.config/systemd/user/ssh-agent.service"
    fn_mkdir_if_needed ~/.config/systemd/user

    if [[ ! -f ${ssh_agent_unit} ]]; then
        cat > ${ssh_agent_unit} << "EOF"
[Unit]
Description=SSH key agent

[Service]
Type=simple
Environment=SSH_AUTH_SOCK=%t/ssh-agent.socket
ExecStart=/usr/bin/ssh-agent -D -a ${SSH_AUTH_SOCK}

[Install]
WantedBy=default.target
EOF
        if [[ ! -f ${ssh_agent_unit} ]]; then 
            fn_log_error "${FUNCNAME[0]}: failed to create ${ssh_agent_unit}"
        fi
        systemctl --user daemon-reload
        systemctl --user enable ssh-agent.service || fn_log_error "${FUNCNAME[0]}: failed to enable ssh-agent.service"
        systemctl --user start ssh-agent.service || fn_log_error "${FUNCNAME[0]}: failed to start ssh-agent.service"
    fi
}

fn_local_install_distrobox() {
    local install_path="${_LOCAL_BIN_DIR}/distrobox"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"

    latest_release="$(curl -s 'https://api.github.com/repos/89luca89/distrobox/tags' | jq -r '.[0].name')"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(distrobox version | awk -F: '/^distrobox/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            local uninstall_paths=("${install_path}" "${install_path}-*")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
        if [[ ! -f ${install_path} ]]; then
            fn_log_error "${FUNCNAME[0]}: failed to install distrobox"
        fi
    fi
}

fn_local_install_opa() {
    local install_path="${_LOCAL_BIN_DIR}/opa"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"

    latest_release="$(curl -s 'https://api.github.com/repos/open-policy-agent/opa/tags' | jq -r '.[0].name')"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(opa version | awk -F: '/^Version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            local uninstall_paths=("${install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "v${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        if [[ ${_MACHINE_ARCH} == "x86_64" ]]; then
            curl -L -o "${install_path}" "https://openpolicyagent.org/downloads/${latest_release}/opa_linux_amd64_static"
        fi  
        if [[ ${_MACHINE_ARCH} == "aarch64" ]]; then
            curl -L -o "${install_path}" "https://openpolicyagent.org/downloads/${latest_release}/opa_linux_arm64_static"
        fi  
        if [[ ! -f ${install_path} ]]; then
            fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
        fi
        chmod +x "${install_path}"
    fi
}

fn_local_install_minikube() {
    local install_path="${_LOCAL_BIN_DIR}/minikube"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/minikube"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"

    latest_release="$(curl -s 'https://api.github.com/repos/kubernetes/minikube/tags' | jq -r '.[0].name')"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(minikube version | awk -F: '/^minikube version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    # minikube install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing minikube...\n"
        curl -LO "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${_GOLANG_ARCH}"
        chmod +x "./minikube-linux-${_GOLANG_ARCH}"
        cp "./minikube-linux-${_GOLANG_ARCH}" "${install_path}"
        rm "./minikube-linux-${_GOLANG_ARCH}"
        ${install_path} completion bash > "${completions_install_path}"
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_kind() {
    local install_path="${_LOCAL_BIN_DIR}/kind"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/kind"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    # kind tags alpha and stable, if it's alpha, use the latest stable - query with jq
    latest_release="$(curl -s 'https://api.github.com/repos/kubernetes-sigs/kind/tags' | jq -r '.[] | select(.name | contains("alpha") | not ).name' | head -1)"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(kind version | awk '/^kind/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    kind_numerical_version="${latest_release#v*}"

    # kind install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing kind...\n"
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${latest_release}/kind-linux-${_GOLANG_ARCH}"
        chmod +x ./kind
        cp ./kind "${install_path}"
        rm ./kind 
        ${install_path} completion bash > "${completions_install_path}"
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_helm() {
    local install_path="${_LOCAL_BIN_DIR}/helm"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/helm"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    # helm tags alpha and stable, if it's alpha, use the latest stable - query with jq
    latest_release="$(curl -s 'https://api.github.com/repos/helm/helm/tags' | jq -r '.[] | select(.name | contains("rc") | not ).name' | head -1)"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(helm version |awk -F, '/^version/ { print $1 }' | awk -F\" '{print $2}')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    helm_numerical_version="${latest_release#v*}"

    # helm install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing helm...\n"
        curl -Lo ./helm.tar.gz "https://get.helm.sh/helm-${latest_release}-linux-${_GOLANG_ARCH}.tar.gz"
        tar -zxvf ./helm.tar.gz
        chmod +x "./linux-${_GOLANG_ARCH}/helm"
        cp "./linux-${_GOLANG_ARCH}/helm" "${install_path}"
        rm -fr "./linux-${_GOLANG_ARCH}"
        rm ./helm.tar.gz
        ${install_path} completion bash > "${completions_install_path}"
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_kubectl() {
    local install_path="${_LOCAL_BIN_DIR}/kubectl"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/kubectl"
    local latest_release
    local currently_installed_version
    local temp_file="/tmp/kubectl.$$"
    
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}" || return 1
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}" || return 1

    # Get latest release version securely
    if ! latest_release=$(fn_secure_download "https://dl.k8s.io/release/stable.txt" "/tmp/kubectl-version.$$" && cat "/tmp/kubectl-version.$$" && rm "/tmp/kubectl-version.$$"); then
        fn_log_error "${FUNCNAME[0]}: failed to get latest kubectl version"
        return 1
    fi
    
    # Validate version format
    if [[ ! "${latest_release}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        fn_log_error "${FUNCNAME[0]}: invalid version format: ${latest_release}"
        return 1
    fi
    
    if [[ ${1:-} == "update" ]]; then
        if [[ -f "${install_path}" ]]; then
            currently_installed_version=$(kubectl version 2>/dev/null | awk -F: '/^Client Version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }' || printf "unknown")
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    # kubectl install
    if [[ ! -f "${install_path}" ]]; then
        printf "Installing kubectl %s...\n" "${latest_release}"
        
        local kubectl_url="https://dl.k8s.io/release/${latest_release}/bin/linux/${_GOLANG_ARCH}/kubectl"
        if fn_secure_download "${kubectl_url}" "${temp_file}"; then
            chmod +x "${temp_file}"
            mv "${temp_file}" "${install_path}" || {
                fn_log_error "${FUNCNAME[0]}: failed to install kubectl binary"
                rm -f "${temp_file}"
                return 1
            }
            
            # Generate completions
            if ! "${install_path}" completion bash > "${completions_install_path}"; then
                fn_log_error "${FUNCNAME[0]}: failed to generate kubectl completions"
            fi
        else
            fn_log_error "${FUNCNAME[0]}: failed to download kubectl"
            return 1
        fi
    fi

    if [[ ! -f "${install_path}" ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
        return 1
    fi
}

fn_local_install_rosa() {
    local install_path="${_LOCAL_BIN_DIR}/rosa"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/rosa"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"

    latest_release=$(curl -s 'https://api.github.com/repos/openshift/rosa/tags' \
        | jq -r '.[] | select(.name | contains("-rc") | not) | select(.name | contains("-testing") | not).name' | head -1)
    latest_numerical_version="${latest_release#v*}"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(rosa version 2>/dev/null | grep "${latest_numerical_version}" | td -d 'INFO: ')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    # rosa install
    if [[ ! -f ${install_path} ]]; then
        pushd /tmp/ || return
            printf "Installing rosa...\n"
            if [[ "${_MACHINE_ARCH}" == "x86_64" ]]; then
                wget -c "https://github.com/openshift/rosa/releases/download/${latest_release}/rosa_Linux_${_MACHINE_ARCH}.tar.gz"
                tar zxvf "rosa_Linux_${_MACHINE_ARCH}.tar.gz"
            elif [[ "${_MACHINE_ARCH}" == "aarch64" ]]; then
                wget -c "https://github.com/openshift/rosa/releases/download/${latest_release}/rosa_Linux_${_GOLANG_ARCH}.tar.gz"
                tar zxvf "rosa_Linux_${_GOLANG_ARCH}.tar.gz"
            else
                printf "ERROR: Unsupported ROSA architecture: %s\n" "${_MACHINE_ARCH}"
                return
            fi
            cp rosa "${install_path}"
            ${install_path} completion bash > "${completions_install_path}"
        popd || return
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_terraform() {
    local install_path="${_LOCAL_BIN_DIR}/terraform"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"

    # terraform tags alpha, beta, and rc ... don't get those
    latest_release="$(
        curl -s 'https://api.github.com/repos/hashicorp/terraform/tags' \
            | jq -r '.[] | select(.name | contains("alpha") | not )| select(.name | contains("beta") | not ) | select(.name | contains("rc") | not).name' \
            | head -1 \
    )"

    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(terraform version | awk '/^Terraform/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            local uninstall_paths=("${install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    local terraform_version="${latest_release#v*}"
    if [[ ! -f ${install_path} ]]; then
        printf "Installing terraform...\n"
        pushd /tmp/ || return
            rm -f terraform terraform.zip # just to make sure the zip command doesn't complain
            curl -Lo terraform.zip \
                "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_${_GOLANG_ARCH}.zip"
            unzip terraform.zip
            cp terraform "${install_path}"
        popd || return
        chmod +x "${install_path}"
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_rustup() {
    local install_path="${HOME}/.cargo/bin/rustup"
    local latest_release
    local currently_installed_version
    local rustup_script="/tmp/rustup-init.$$"

    # Get latest release info securely
    local temp_releases="/tmp/rustup-releases.$$"
    if fn_secure_download "https://api.github.com/repos/rust-lang/rustup/tags" "${temp_releases}"; then
        latest_release="$(jq -r '.[0].name' "${temp_releases}" 2>/dev/null || printf "unknown")"
        rm -f "${temp_releases}"
    else
        fn_log_error "${FUNCNAME[0]}: failed to get rustup release info"
        return 1
    fi
    
    if [[ ${1:-} == "update" ]]; then
        if [[ -f "${install_path}" ]]; then
            currently_installed_version=$(rustup --version 2>/dev/null| awk '/^rustup/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }' || printf "unknown")
            local uninstall_paths=("${install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f "${install_path}" ]]; then
        printf "Installing rustup...\n"

        # Download rustup installer securely
        if fn_secure_download "https://sh.rustup.rs" "${rustup_script}"; then
            chmod +x "${rustup_script}"

            # Run installer with strict settings
            if "${rustup_script}" -y --no-modify-path --profile minimal; then
                printf "Rustup installed successfully\n"
            else
                fn_log_error "${FUNCNAME[0]}: rustup installation failed"
                rm -f "${rustup_script}"
                return 1
            fi

            rm -f "${rustup_script}"
        else
            fn_log_error "${FUNCNAME[0]}: failed to download rustup installer"
            return 1
        fi
    fi

    if [[ ! -f "${install_path}" ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
        return 1
    fi
}

fn_local_install_gh() {
    local install_path="${_LOCAL_BIN_DIR}/gh"
    local latest_release
    local currently_installed_version
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/gh"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"

    latest_release="$(curl -s 'https://api.github.com/repos/cli/cli/tags' | jq -r '.[0].name')"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(gh version| awk '/^gh version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $3 }')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "v${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    local gh_numerical_version="${latest_release#v*}"
    if [[ ! -f ${install_path} ]]; then
        printf "Installing gh...\n"
        curl -Lo /tmp/gh.tar.gz "https://github.com/cli/cli/releases/download/${latest_release}/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}.tar.gz"
        tar -zxvf /tmp/gh.tar.gz -C /tmp/
        cp "/tmp/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}/bin/gh" "${install_path}"
        ${install_path} completion -s bash > "${completions_install_path}"
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_neovim() {
    local install_path="${_LOCAL_BIN_DIR}/nvim"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"

    latest_release="$(curl -s 'https://api.github.com/repos/neovim/neovim/tags' | jq -r '.[0].name')"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(nvim --version| awk '/^NVIM/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            local uninstall_paths=("${install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    local neovim_numerical_version="${latest_release#v*}"

    if [[ ! -f ${install_path} ]]; then
        printf "Installing neovim from source ... \n"

        pushd /tmp/ || return
            wget -c "https://github.com/neovim/neovim/archive/refs/tags/${latest_release}.tar.gz"
            tar -zxvf "${latest_release}.tar.gz"
            pushd "neovim-${neovim_numerical_version}/" || return
                make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="${HOME}/.local/"
                make install
            popd || return
            rm -fr "neovim-${latest_release}/"
        popd || return
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_vim_plug() {
    # Install vim-plug with secure download
    local VIM_PLUG_DIR="${HOME}/.vim/autoload"
    local VIM_PLUG_FILE="${VIM_PLUG_DIR}/plug.vim"
    local VIM_PLUG_URL="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"

    if [[ ! -f "${VIM_PLUG_FILE}" ]]; then
        printf "Installing vim-plug...\n"
        mkdir -p "${VIM_PLUG_DIR}" || fn_log_error "Failed to create vim autoload directory"
        
        if ! fn_secure_download "${VIM_PLUG_URL}" "${VIM_PLUG_FILE}"; then
            fn_log_error "Failed to download vim-plug"
        fi
    fi
}

fn_local_install_task() {
    local install_path="${_LOCAL_BIN_DIR}/task"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/task"
    local latest_release
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    latest_release="$(curl -s 'https://api.github.com/repos/go-task/task/tags' | jq -r '.[0].name')"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(task --version)
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        printf "Installing task...\n"

        pushd /tmp/ || return
            wget -c "https://github.com/go-task/task/releases/download/${latest_release}/task_linux_${_GOLANG_ARCH}.tar.gz"
            tar -zxvf "task_linux_${_GOLANG_ARCH}.tar.gz"
            cp task "${install_path}"
            cp completion/bash/task.bash "${completions_install_path}"

            # cleanup the tarball artifacts
            for file in $(tar --list --file "task_linux_${_GOLANG_ARCH}.tar.gz"); do
                rm -f "${file}"
            done
            rm -fr completion
        popd || return
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_yq() {
    local install_path="${_LOCAL_BIN_DIR}/yq"
    local latest_release
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/yq"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    latest_release="$(
        curl -s 'https://api.github.com/repos/mikefarah/yq/tags' \
            | jq -r '.[] | select(.name | contains("Test") | not).name' \
            | head -1
    )"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(yq --version | awk '{ print $4 }')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        printf "Installing yq...\n"

        pushd /tmp/ || return
            wget -c "https://github.com/mikefarah/yq/releases/download/${latest_release}/yq_linux_${_GOLANG_ARCH}.tar.gz" -O - \
                | tar xz && cp "yq_linux_${_GOLANG_ARCH}" "${install_path}"
            ${install_path} completion bash > "${completions_install_path}"
        popd || return
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_ollama() {
    local install_path="${_LOCAL_BIN_DIR}/ollama"
    local latest_release
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/ollama"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    latest_release="$(
        curl -s 'https://api.github.com/repos/ollama/ollama/tags' \
            | jq -r '.[] | select(.name | contains("rc") | not).name' \
            | head -1
    )"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(ollama --version | grep "client version" | awk '{ print $5 }')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        printf "Installing ollama...\n"

        curl -L "https://ollama.com/download/ollama-linux-${_GOLANG_ARCH}" -o "${install_path}"
        chmod +x "${install_path}"

        # ollama systemd user unit
        fn_mkdir_if_needed ~/.config/systemd/user

        if [[ ! -f ~/.config/systemd/user/ollama.service ]]; then
            cat > ~/.config/systemd/user/ollama.service << EOF
[Unit]
Description=Ollama Service - User mode
After=network-online.target

[Service]
Type=simple
ExecStart=${install_path} serve
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF
            systemctl --user daemon-reload
            systemctl --user enable ollama.service || fn_log_error "${FUNCNAME[0]}: failed to enable ollama.service"
            systemctl --user start ollama.service || fn_log_error "${FUNCNAME[0]}: failed to start ollama.service"
       fi
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_charm() {
    if [[ "${1:-}" == "soft-serve" ]]; then
        # special case because soft-serve binary is called "soft"
        local install_path="${_LOCAL_BIN_DIR}/soft"
    else
        local install_path="${_LOCAL_BIN_DIR}/${1:-}"
    fi
    local latest_release
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/${1:-}"
    local manpage_install_path="${HOME}/.local/share/man/man1/${1:-}.1.gz"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    latest_release="$(curl -s "https://api.github.com/repos/charmbracelet/${1:-}/tags" | jq '.[0].name' | tr -d \")"
    latest_release_numerical_version="${latest_release#v*}"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(${1:-} --version | grep "client version" | awk '{ print $5 }')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        printf "Installing %s...\n" "${1:-}"

        pushd /tmp/ || return
            if [[ ${_GOLANG_ARCH} == "amd64" ]]; then
                charm_tarname="${1:-}_${latest_release_numerical_version}_Linux_x86_64.tar.gz"
            else
                charm_tarname="${1:-}_${latest_release_numerical_version}_Linux_${_GOLANG_ARCH}.tar.gz"
            fi
            wget -c "https://github.com/charmbracelet/${1:-}/releases/download/${latest_release}/${charm_tarname}"
            tar zxvf "${charm_tarname}"
            pushd "${charm_tarname%.tar.gz}" || return
                if [[ "${1:-}" == "soft-serve" ]]; then
                    # special case because soft-serve binary is called "soft"
                    cp "soft" "${install_path}"
                else
                    cp "${1:-}" "${install_path}"
                fi
                chmod +x "${install_path}"

                cp "completions/${1:-}.bash" "${completions_install_path}"
                cp "manpages/${1:-}.1.gz" "${manpage_install_path}"
            popd || return
            rm -fr "${charm_tarname%.tar.gz}"
            rm "${charm_tarname}"
        popd || return
    fi
    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
    if [[ ! -f ${completions_install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${completions_install_path}"
    fi
    if [[ ! -f ${manpage_install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${manpage_install_path}"
    fi
}

fn_local_install_charm_apps() {
    # charm apps
    local charm_pkglist
    charm_pkglist=(
        "glow"
        "soft-serve"
        "vhs"
        "wishlist"
        "crush"
    )
    for charm in "${charm_pkglist[@]}"; do
        fn_local_install_charm "${charm}"
    done
}

fn_local_install_k9s() {
    local install_path="${_LOCAL_BIN_DIR}/k9s"
    local latest_release
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/k9s"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    latest_release="$(curl -s 'https://api.github.com/repos/derailed/k9s/tags' | jq '.[0].name' | tr -d \")"
    latest_release_numerical_version="${latest_release#v*}"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(k9s version | grep "Version" | awk '{ print $2 }')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        printf "Installing k9s...\n"

        pushd /tmp/ || return
            k9s_tarname="k9s_Linux_${_GOLANG_ARCH}.tar.gz"
            wget -c "https://github.com/derailed/k9s/releases/download/${latest_release}/k9s_Linux_${_GOLANG_ARCH}.tar.gz"
            tar zxvf "${k9s_tarname}"
            cp "k9s" "${install_path}"
            chmod +x "${install_path}"
            "${install_path}" completion bash > "${completions_install_path}"
            rm "${k9s_tarname}"
        popd || return
    fi
    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_kubebuilder() {
    local install_path="${_LOCAL_BIN_DIR}/kubebuilder"
    local latest_release
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/kubebuilder"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    latest_release="$(
        curl -s 'https://api.github.com/repos/kubernetes-sigs/kubebuilder/tags'  \
            | jq -r '.[] | select(.name | contains("alpha") | not )| select(.name | contains("beta") | not ) | select(.name | contains("rc") | not).name' \
            | head -1 | tr -d \"
    )"
    latest_release_numerical_version="${latest_release#v*}"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(kubebuilder version | sed 's/.*KubeBuilderVersion:"\([^"]*\)".*/\1/')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release#v*}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        printf "Installing kubebuilder...\n"

        pushd /tmp/ || return
            wget -c "https://github.com/kubernetes-sigs/kubebuilder/releases/download/${latest_release}/kubebuilder_linux_${_GOLANG_ARCH}"
            mv "kubebuilder_linux_${_GOLANG_ARCH}" "kubebuilder"
            cp "kubebuilder" "${install_path}"
            chmod +x "${install_path}"
            "${install_path}" completion bash > "${completions_install_path}"
            rm "kubebuilder"
        popd || return
    fi
    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_operator_sdk() {
    local install_path="${_LOCAL_BIN_DIR}/operator-sdk"
    local latest_release
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/operator-sdk"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    latest_release="$(curl -s 'https://api.github.com/repos/operator-framework/operator-sdk/tags' | jq '.[0].name' | tr -d \")"
    latest_release_numerical_version="${latest_release#v*}"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(operator-sdk version | grep "Version" | awk '{ print $2 }')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        printf "Installing operator-sdk...\n"


        pushd /tmp/ || return
            wget -c "https://github.com/operator-framework/operator-sdk/releases/download/${latest_release}/operator-sdk_linux_${_GOLANG_ARCH}"
            cp "operator-sdk_linux_${_GOLANG_ARCH}" "${install_path}"
            chmod +x "${install_path}"
            "${install_path}" completion bash > "${completions_install_path}"
            rm "operator-sdk_linux_${_GOLANG_ARCH}" 
        popd || return
    fi
    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_syft() {
    local install_path="${_LOCAL_BIN_DIR}/syft"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/syft"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            rm "${install_path}" "${completions_install_path}"
        fi
    fi
    if [[ ! -f ${install_path} ]]; then
        curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ~/.local/bin/
    fi
    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    else
        "${install_path}" completion bash > "${completions_install_path}"
    fi
}

fn_local_install_grype() {
    local install_path="${_LOCAL_BIN_DIR}/grype"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/grype"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            rm "${install_path}" "${completions_install_path}"
        fi
    fi
    if [[ ! -f ${install_path} ]]; then
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b ~/.local/bin/
    fi
    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    else
        "${install_path}" completion bash > "${completions_install_path}"
    fi
}

fn_local_install_cosign() {
    local install_path="${_LOCAL_BIN_DIR}/cosign"
    local latest_release
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/cosign"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    latest_release="$(
        curl -s 'https://api.github.com/repos/sigstore/cosign/tags' | 
            jq '.[] | select(.name | contains("rc") | not).name' | head -1 | tr -d \"
    )"
    latest_release_numerical_version="${latest_release#v*}"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version="$(cosign version | awk '/GitVersion/{print$2}')"
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        printf "Installing cosign...\n"

        wget -O "${install_path}" "https://github.com/sigstore/cosign/releases/download/${latest_release}/cosign-linux-${_GOLANG_ARCH}"
        chmod +x "${install_path}"
        "${install_path}" completion bash > "${completions_install_path}"
    fi
    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_chtsh() {
    local install_path="${_LOCAL_BIN_DIR}/chtsh"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/chtsh"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            rm "${install_path}" "${completions_install_path}"
        fi
    fi
    if [[ ! -f ${install_path} ]]; then
        curl https://cht.sh/:cht.sh > "${install_path}"
    fi
    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_aws() {
    local install_path="${_LOCAL_BIN_DIR}/aws"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            rm "${install_path}"
        fi
    fi
    if [[ ! -f ${install_path} ]]; then
        pushd /tmp/ || return
            curl "https://awscli.amazonaws.com/awscli-exe-linux-${_MACHINE_ARCH}.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            ./aws/install --bin-dir "${_LOCAL_BIN_DIR}/" --install-dir "${HOME}/.local/aws-cli/"
            rm -fr ./aws
            rm -fr awscliv2.zip
        popd || return
    fi
    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_kustomize() {
    local install_path="${_LOCAL_BIN_DIR}/kustomize"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/kustomize"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    # kustomize tags alpha and stable, if it's alpha, use the latest stable - query with jq
    latest_release="$(curl -s 'https://api.github.com/repos/kubernetes-sigs/kustomize/releases' |
        jq -r '.[] | select(.name | contains("kustomize") ).name' | head -1 | awk -F/ '{ print $2 }')"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(kustomize version)
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    # kustomize_numerical_version="${latest_release#v*}"

    # kustomize install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing kustomize...\n"
        wget -c "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${latest_release}/kustomize_${latest_release}_linux_${_GOLANG_ARCH}.tar.gz"
        tar -zxvf "kustomize_${latest_release}_linux_${_GOLANG_ARCH}.tar.gz"
        cp ./kustomize "${install_path}"
        rm ./kustomize 
        rm "./kustomize_${latest_release}_linux_${_GOLANG_ARCH}.tar.gz"
        ${install_path} completion bash > "${completions_install_path}"
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_go_blueprint() {
    local install_path="${HOME}/go/bin/go-blueprint"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/go-blueprint"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    latest_release="$(curl -s 'https://api.github.com/repos/Melkeydev/go-blueprint/releases' | jq -r '.[].name' | head -1 )"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(go-blueprint version)
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    # go-blueprint_numerical_version="${latest_release#v*}"

    # go-blueprint install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing go-blueprint...\n"
        go install github.com/melkeydev/go-blueprint@latest
        ${install_path} completion bash > "${completions_install_path}"
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_shfmt() {
    local install_path="${HOME}/go/bin/shfmt"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    latest_release="$(curl -s 'https://api.github.com/repos/mvdan/sh/releases' | \
        jq '.[] | select(.tag_name | contains("beta") | not) | select(.tag_name | contains("alpha") | not).tag_name' | head -1 | tr -d \")"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(shfmt version)
            local uninstall_paths=("${install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    # shfmt install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing shfmt...\n"
        go install mvdan.cc/sh/v3/cmd/shfmt@latest
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_goose() {
    local install_path="${_LOCAL_BIN_DIR}/goose"
    fn_mkdir_if_needed "${_LOCAL_BIN_DIR}"
    if [[ ! -f ${install_path} ]]; then
        curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | CONFIGURE=false bash
    fi
    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_beads() {
    local install_path="${HOME}/go/bin/bd"
    local completions_install_path="${_LOCAL_COMPLETIONS_DIR}/bd"
    local latest_release
    local currently_installed_version
    fn_mkdir_if_needed "${_LOCAL_COMPLETIONS_DIR}"
    latest_release="$(curl -s 'https://api.github.com/repos/steveyegge/beads/releases' | jq -r '.[].name' | head -1 )"
    if [[ ${1:-} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(bd version | awk '{print $3}')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi


    # beads install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing ${install_path}...\n"
        go install github.com/steveyegge/beads/cmd/bd@latest
        ${install_path} completion bash > "${completions_install_path}"
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_uv_tool_install() {
    # uv install package list
    local uv_pkgs=(
        'glances[all]'
        "ptpython"
        "tox"
        "httpie"
        "flake8"
        "pep8"
        "pyflakes"
        "pylint"
        "black"
        "pipenv"
        "poetry"
        "tmuxp"
        "python-lsp-server"
        "tldr"
        "nodeenv"
        "ipython"
        "archey4"
        "bandit"
        "dool"
        "csvkit"
        "kfp"
        "jupyterlab"
        "nbconvert"
        "frogmouth"
        "llm"
        #"aider-chat"
        "pdm"
        "posting"
        "harlequin"
        "pyright"
    )
    
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        uv_pkgs+=(
            "rh-aws-saml-login"
        )
    fi

    if which uv > /dev/null 2>&1; then
        for pypkg in "${uv_pkgs[@]}";
        do
            # add special case for glances
            if [[ "${pypkg}" =~ glances* ]]; then
                if [[ ! -d ${HOME}/.local/share/uv/tools/glances ]]; then
                    uv tool install "${pypkg}" || fn_log_error "${FUNCNAME[0]}: failed to uv install ${pypkg}"
                fi
            else
                if [[ ! -d ${HOME}/.local/share/uv/tools/${pypkg} ]]; then
                    uv tool install "${pypkg}" || fn_log_error "${FUNCNAME[0]}: failed to uv install ${pypkg}"
                fi
            fi
        done

        # spec-kit wants to be installed from github ¯\_(ツ)_/¯
        if [[ ! -d ${HOME}/.local/share/uv/tools/specify-cli ]]; then
            uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
        fi
    fi
}

fn_update_local_installs() {

    if [[ "${ID}" == "debian" ]]; then
        fn_local_install_rustup update
        # NEOVIM STUB
        # fn_local_install_neovim update
        fn_local_install_ollama update
    fi
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        local el_major_version
        el_major_version=$(rpm -E %rhel)
        # NEOVIM STUB
        # if [[ "${el_major_version}" -lt 10 ]]; then
        #     fn_local_install_neovim update
        # fi
    fi

    fn_local_install_distrobox update
    fn_local_install_opa update
    fn_local_install_minikube update
    fn_local_install_kind update
    fn_local_install_kubectl update
    fn_local_install_kubebuilder update
    fn_local_install_terraform update
    fn_local_install_gh update
    fn_local_install_task update
    fn_local_install_yq update
    fn_local_install_syft update
    fn_local_install_cosign update
    fn_local_install_chtsh update
    #pipx upgrade-all
    uv tool upgrade --all
}
