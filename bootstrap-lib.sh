#!/bin/bash
#
# Basic library functions for my dotfiles
#

_ERRORS=()

_MACHINE_ARCH=$(uname -m)

if [[ ${_MACHINE_ARCH} == "x86_64" ]]; then
    _GOLANG_ARCH="amd64"
fi
if [[ ${_MACHINE_ARCH} == "aarch64" ]]; then
    _GOLANG_ARCH="arm64"
fi

fn_check_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
    fi

    if [[ -z "${TERMUX_VERSION}" ]]; then
        export ID="Termux"
    fi

}

fn_log_error() {
    _ERRORS+=("${@}")
}

fn_print_errors() {
    if [[ -n "${_ERRORS[*]}" ]]; then
        printf "\n\nERRORS:\n"
        for error in "${_ERRORS[@]}"; do
            printf "%s\n" "${error}"
        done
    fi
}

# Ensure the needed dirs exist
fn_mkdir_if_needed() {
    if [[ ! -d "${1}" ]]; then
        mkdir -p "${1}"
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

fn_setup_rhel_csb() {
    fn_check_distro
    local repofile="/etc/yum.repos.d/billings-csb.repo"
    # Use Billings' COPR
    if [[ "${ID}" == "rhel" ]] || [[ "${ID}" == "redhat" ]]; then
        sudo tee ${repofile} &>/dev/null << "EOF"
[copr:copr.devel.redhat.com:jbilling:unoffical-rhel9]
name=Copr repo for unoffical-rhel9 owned by jbilling
baseurl=https://coprbe.devel.redhat.com/results/jbilling/unoffical-rhel9/rhel-9-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=0
gpgkey=https://coprbe.devel.redhat.com/results/jbilling/unoffical-rhel9/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF
    fi
    if ! [[ -f ${repofile} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to setup copr"
    fi
#     if [[ "${ID}" == "rhel" ]] || [[ "${ID}" == "redhat" ]]; then
#       sudo tee /etc/yum.repos.d/redhat-csb.repo &>/dev/null << EOF
# [rhel-csb]
# name=RHEL CSB packages
# baseurl=http://hdn.corp.redhat.com/rhel8-csb
# enabled=1
# gpgcheck=1
# gpgkey=http://hdn.corp.redhat.com/rhel8-csb/RPM-GPG-KEY-helpdesk
# skip_if_unavailable=yes
# includepkgs=redhat-internal-*,oneplay-gstreamer-codecs-pack,zoom,ffmpeg-libs,xvidcore
# EOF
    # fi
}

# Symlink the conf files
fn_symlink_if_needed() {
    if [[ -f ${2} ]] && [[ ! -L ${2} ]]; then
        printf "File found: %s ... backing up\n" "$2"
        # if the destination file exists and isn't a symlink, back it up
        mv "${2}" "${2}.old$(date +%Y%m%d)" || fn_log_error "${FUNCNAME[0]}: failed to back up ${2}"
    fi
    if [[ ! -f ${2} ]] && [[ ! -L ${2} ]]; then
        printf "Symlinking: %s -> %s\n" "$1" "$2"
        if [[ ! -d "$(dirname "${2}")" ]]; then
            mkdir -p "$(dirname "${2}")" || fn_log_error "${FUNCNAME[0]}: failed to mkdir $(dirname "${2}")"
        fi
        ln -s "${1}" "${2}"
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

    if [[ -f ${1} ]]; then
        if [[ ${2} != "${3}" ]]; then
            rm -f "${uninstall_paths[@]}" || fn_log_error "${FUNCNAME[0]}: failed to rm ${1}"
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
        if ! dpkg -l tailscale > /dev/null 2>&1; then
            curl -fsSL "https://pkgs.tailscale.com/stable/debian/${VERSION_CODENAME}.noarmor.gpg" | sudo tee ${tailscale_keyring} >/dev/null
            if ! [[ -f ${tailscale_keyring} ]]; then
                fn_log_error "${FUNCNAME[0]}: failed to download ${tailscale_keyring}"
            fi

            curl -fsSL "https://pkgs.tailscale.com/stable/debian/${VERSION_CODENAME}.tailscale-keyring.list" | sudo tee ${tailscale_aptlist}
            if ! [[ -f ${tailscale_aptlist} ]]; then
                fn_log_error "${FUNCNAME[0]}: failed to download ${tailscale_aptlist}"
            fi

            sudo apt update
            sudo apt install -y tailscale || fn_log_error "${FUNCNAME[0]}: failed to install tailscale"
        fi
    fi
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        if ! rpm -q tailscale &>/dev/null; then
            local el_major_version
            el_major_version=$(rpm -E %rhel)
            # sudo dnf config-manager --add-repo "https://pkgs.tailscale.com/stable/rhel/${el_major_version}/tailscale.repo"
            sudo dnf config-manager addrepo "https://pkgs.tailscale.com/stable/rhel/${el_major_version}/tailscale.repo"
            sudo dnf install -y tailscale || fn_log_error "${FUNCNAME[0]}: failed to install tailscale"
            sudo systemctl enable --now tailscaled || fn_log_error "${FUNCNAME[0]}: failed to enable tailscale.service"
        fi
    fi
    if [[ "${ID}" == "fedora" ]]; then
        if ! rpm -q tailscale &>/dev/null; then
            # sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo
            sudo dnf config-manager addrepo https://pkgs.tailscale.com/stable/fedora/tailscale.repo
            sudo dnf install -y tailscale || fn_log_error "${FUNCNAME[0]}: failed to install tailscale"
            sudo systemctl enable --now tailscaled || fn_log_error "${FUNCNAME[0]}: failed to enable tailscale.service"
        fi
    fi

}

fn_system_install_command_line_assistant() {
    fn_check_distro
    local pkg_name="command-line-assistant"
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" || ${ID} == "fedora" ]]; then
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

    local pending_install_pkgs=()
    for pkg in "${@}"; do
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
        if [[ "${ID}" == "pkg" ]]; then 
            pkg install -y "${pending_install_pkgs[@]}" || fn_log_error "${FUNCNAME[0]}: failed to install packages: ${pending_install_pkgs[*]}"
        fi
        if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" || "${ID}" == "fedora" ]]; then
            # intentionally want word splitting so don't quote
            sudo dnf install -y --allowerasing "${pending_install_pkgs[@]}" || fn_log_error "${FUNCNAME[0]}: failed to install packages: ${pending_install_pkgs[*]}"
        fi
    fi
}

fn_flatpak_overrides() {
    # Chrome
    local chrome_override_file="${HOME}/.local/share/flatpak/overrides/com.google.Chrome"
    fn_mkdir_if_needed "$(dirname "${chrome_override_file}")"
    cat > "${chrome_override_file}" << "EOF"
[Context]
filesystems=~/.local/share/icons/;~/.local/share/applications/
EOF
    if ! [[ -f "${chrome_override_file}" ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to create flatpak override file: ${chrome_override_file}"
    fi


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
            "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
            "$(. /etc/os-release && echo "${VERSION_CODENAME}")" stable" | \
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
        "python-venv"
        "python-pylsp"
        "uv"
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
        "fd"
        "shellcheck"
        "ripgrep"
        "git-crypt"
        "rlwrap"
        "mosh"
        "golang"
        "openssh"
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
    # Setup for Fedora/RHEL/CentOS-Stream
    #
    fn_mkdir_if_needed ~/.local/bin/
    fn_mkdir_if_needed ~/.local/share/bash-completion/completions/

    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        fn_system_install_epel
    fi

    # Tailscale
    fn_system_install_tailscale

    # RHEL Lightspeed / command-line-assistant
    fn_system_install_command_line_assistant

    # random dev stuff
    local fedora_el_pkglist
    fedora_el_pkglist=(
        "vim-enhanced"
        "python3"
        "python3-pip"
        "uv"
        "nodejs"
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
        "fd-find"
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
    )

    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        fedora_el_pkglist+=(
            "python3.12"
            "python3.12-pip"
            "iotop"
            "npm"
        )
    fi
    if [[ "${ID}" == "fedora" ]]; then
        fedora_el_pkglist+=(
            "iotop-c"
            "nodejs-npm"
            "python3-devel"
            "python3-torch"
            "python3-ramalama"
            "fedpkg"
            "ninja-build"
            "neovim"
            "fedora-review"
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
    sudo usermod "${USER}" -a -G mock

    fn_system_install_packages "${fedora_el_pkglist[@]}"

    fn_system_polkit_libvirt_nonroot_user

    fn_flathub_install

    fn_system_gnome_settings
}

fn_local_install_virtualenvwrapper(){
    # virtualenvwrapper
    if ! pip list | grep virtualenvwrapper &>/dev/null; then
        pip install --user virtualenvwrapper || fn_log_error "${FUNCNAME[0]}: failed to install virtualenvwrapper"
    fi
}

fn_local_install_claude_code() {
    npm install --prefix ~/.local/ @anthropic-ai/claude-code
    if ! [[ -f ~/.local/node_modules/.bin/claude ]]; then
        fn_log_error "Claude Code npm install failed"
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
ExecStart=/usr/bin/ssh-agent -D -a $SSH_AUTH_SOCK

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
    local install_path="${HOME}/.local/bin/distrobox"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/89luca89/distrobox/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/opa"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/open-policy-agent/opa/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/minikube"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/minikube"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/kubernetes/minikube/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/kind"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/kind"
    local latest_release
    local currently_installed_version
    # kind tags alpha and stable, if it's alpha, use the latest stable - query with jq
    latest_release="$(curl -s 'https://api.github.com/repos/kubernetes-sigs/kind/tags' | jq -r '.[] | select(.name | contains("alpha") | not ).name' | head -1)"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/helm"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/helm"
    local latest_release
    local currently_installed_version
    # helm tags alpha and stable, if it's alpha, use the latest stable - query with jq
    latest_release="$(curl -s 'https://api.github.com/repos/helm/helm/tags' | jq -r '.[] | select(.name | contains("rc") | not ).name' | head -1)"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/kubectl"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/kubectl"
    local latest_release
    local currently_installed_version

    latest_release=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(kubectl version 2>/dev/null | awk -F: '/^Client Version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    # kubectl install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing kubectl...\n"
        curl -LO "https://dl.k8s.io/release/${latest_release}/bin/linux/${_GOLANG_ARCH}/kubectl"
        chmod +x ./kubectl
        cp ./kubectl "${install_path}"
        rm ./kubectl
        ${install_path} completion bash > "${completions_install_path}"
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_rosa() {
    local install_path="${HOME}/.local/bin/rosa"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/rosa"
    local latest_release
    local currently_installed_version

    latest_release=$(curl -s 'https://api.github.com/repos/openshift/rosa/tags' | jq -r '.[] | select(.name | contains("-rc") | not).name' | head -1)
    latest_numerical_version="${latest_release#v*}"
    if [[ ${1} == "update" ]]; then
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
                printf "ERROR: Unsupported ROSA architecture: ${_MACHINE_ARCH}\n"
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
    local install_path="${HOME}/.local/bin/terraform"
    local latest_release
    local currently_installed_version

    # terraform tags alpha, beta, and rc ... don't get those
    latest_release="$(
        curl -s 'https://api.github.com/repos/hashicorp/terraform/tags' \
            | jq -r '.[] | select(.name | contains("alpha") | not )| select(.name | contains("beta") | not ) | select(.name | contains("rc") | not).name' \
            | head -1 \
    )"

    if [[ ${1} == "update" ]]; then
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

    latest_release="$(curl -s 'https://api.github.com/repos/rust-lang/rustup/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(rustup --version 2>/dev/null| awk '/^rustup/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            local uninstall_paths=("${install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    fi

    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_gh() {
    local install_path="${HOME}/.local/bin/gh"
    local latest_release
    local currently_installed_version
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/gh"

    latest_release="$(curl -s 'https://api.github.com/repos/cli/cli/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/nvim"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/neovim/neovim/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
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

fn_local_install_task() {
    local install_path="${HOME}/.local/bin/task"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/task"
    local latest_release
    latest_release="$(curl -s 'https://api.github.com/repos/go-task/task/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(nvim --version| awk '/^NVIM/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
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
    local install_path="${HOME}/.local/bin/yq"
    local latest_release
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/yq"
    latest_release="$(
        curl -s 'https://api.github.com/repos/mikefarah/yq/tags' \
            | jq -r '.[] | select(.name | contains("Test") | not).name' \
            | head -1
    )"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/ollama"
    local latest_release
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/ollama"
    latest_release="$(
        curl -s 'https://api.github.com/repos/ollama/ollama/tags' \
            | jq -r '.[] | select(.name | contains("rc") | not).name' \
            | head -1
    )"
    if [[ ${1} == "update" ]]; then
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
    if [[ "${1}" == "soft-serve" ]]; then
        # special case because soft-serve binary is called "soft"
        local install_path="${HOME}/.local/bin/soft"
    else
        local install_path="${HOME}/.local/bin/${1}"
    fi
    local latest_release
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/${1}"
    local manpage_install_path="${HOME}/.local/share/man/man1/${1}.1.gz"
    latest_release="$(curl -s "https://api.github.com/repos/charmbracelet/${1}/tags" | jq '.[0].name' | tr -d '"')"
    latest_release_numerical_version="${latest_release#v*}"
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            currently_installed_version=$(${1} --version | grep "client version" | awk '{ print $5 }')
            local uninstall_paths=("${install_path}" "${completions_install_path}")
            fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        printf "Installing ${1}...\n"


        pushd /tmp/ || return
            if [[ ${_GOLANG_ARCH} == "amd64" ]]; then
                charm_tarname="${1}_${latest_release_numerical_version}_Linux_x86_64.tar.gz"
            else
                charm_tarname="${1}_${latest_release_numerical_version}_Linux_${_GOLANG_ARCH}.tar.gz"
            fi
            wget -c "https://github.com/charmbracelet/${1}/releases/download/${latest_release}/${charm_tarname}"
            tar zxvf "${charm_tarname}"
            pushd "${charm_tarname%.tar.gz}" || return
                if [[ "${1}" == "soft-serve" ]]; then
                    # special case because soft-serve binary is called "soft"
                    cp "soft" "${install_path}"
                else
                    cp "${1}" "${install_path}"
                fi
                chmod +x "${install_path}"

                cp "completions/${1}.bash" "${completions_install_path}"
                cp "manpages/${1}.1.gz" "${manpage_install_path}"
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
    )
    for charm in "${charm_pkglist[@]}"; do
        fn_local_install_charm "${charm}"
    done
}

fn_local_install_k9s() {
    local install_path="${HOME}/.local/bin/k9s"
    local latest_release
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/k9s"
    latest_release="$(curl -s 'https://api.github.com/repos/derailed/k9s/tags' | jq '.[0].name' | tr -d '"')"
    latest_release_numerical_version="${latest_release#v*}"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/kubebuilder"
    local latest_release
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/kubebuilder"
    latest_release="$(
        curl -s 'https://api.github.com/repos/kubernetes-sigs/kubebuilder/tags'  \
            | jq -r '.[] | select(.name | contains("alpha") | not )| select(.name | contains("beta") | not ) | select(.name | contains("rc") | not).name' \
            | head -1 | tr -d '"'
    )"
    latest_release_numerical_version="${latest_release#v*}"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/operator-sdk"
    local latest_release
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/operator-sdk"
    latest_release="$(curl -s 'https://api.github.com/repos/operator-framework/operator-sdk/tags' | jq '.[0].name' | tr -d '"')"
    latest_release_numerical_version="${latest_release#v*}"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/syft"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/syft"
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            rm ${install_path} ${completions_install_path}
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
    local install_path="${HOME}/.local/bin/grype"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/grype"
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            rm ${install_path} ${completions_install_path}
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
    local install_path="${HOME}/.local/bin/cosign"
    local latest_release
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/cosign"
    latest_release="$(
        curl -s 'https://api.github.com/repos/sigstore/cosign/tags' | 
            jq '.[] | select(.name | contains("rc") | not).name' | head -1 | tr -d '"'
    )"
    latest_release_numerical_version="${latest_release#v*}"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/chtsh"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/chtsh"
    if [[ ${1} == "update" ]]; then
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
    local install_path="${HOME}/.local/bin/aws"
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            rm "${install_path}"
        fi
    fi
    if [[ ! -f ${install_path} ]]; then
        pushd /tmp/ || return
            curl "https://awscli.amazonaws.com/awscli-exe-linux-${_MACHINE_ARCH}.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            ./aws/install --bin-dir "${HOME}/.local/bin/" --install-dir "${HOME}/.local/aws-cli/"
            rm -fr ./aws
            rm -fr awscliv2.zip
        popd || return
    fi
    if [[ ! -f ${install_path} ]]; then
        fn_log_error "${FUNCNAME[0]}: failed to install ${install_path}"
    fi
}

fn_local_install_kustomize() {
    local install_path="${HOME}/.local/bin/kustomize"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/kustomize"
    local latest_release
    local currently_installed_version
    # kustomize tags alpha and stable, if it's alpha, use the latest stable - query with jq
    latest_release="$(curl -s 'https://api.github.com/repos/kubernetes-sigs/kustomize/releases' |
        jq -r '.[] | select(.name | contains("kustomize") ).name' | head -1 | awk -F/ '{ print $2 }')"
    if [[ ${1} == "update" ]]; then
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
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/go-blueprint"
    local latest_release
    local currently_installed_version
    latest_release="$(curl -s 'https://api.github.com/repos/Melkeydev/go-blueprint/releases' | jq -r '.[].name' | head -1 )"
    if [[ ${1} == "update" ]]; then
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

fn_local_install_goose() {
    local install_path="${HOME}/.local/bin/goose"
    if [[ ! -f ${install_path} ]]; then
        curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | CONFIGURE=false bash
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
        "aider-chat"
        "pdm"
        "posting"
        "harlequin"
    )

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
    fi
}

fn_update_local_installs() {

    if [[ "${ID}" == "debian" ]]; then
        fn_local_install_rustup update
        fn_local_install_neovim update
        fn_local_install_ollama update
    fi
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        fn_local_install_neovim update
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
    pipx upgrade-all
}
