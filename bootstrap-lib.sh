#!/bin/bash
#
# Basic library functions for my dotfiles
#

_MACHINE_ARCH=$(uname -m)

# pipx install pypkglist 
_PIPX_PACKAGE_LIST=(
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
    "bpytop"
    "python-lsp-server"
    "tldr"
    "nodeenv"
    "ipython"
)

if [[ ${_MACHINE_ARCH} == "x86_64" ]]; then
    _GOLANG_ARCH="amd64"
fi
if [[ ${_MACHINE_ARCH} == "aarch64" ]]; then
    _GOLANG_ARCH="arm64"
fi
#
# Ensure the needed dirs exist
fn_mkdir_if_needed() {
    if [[ ! -d "${1}" ]]; then
        mkdir -p "${1}"
    fi
}

fn_system_install_chrome() {
    # Chrome is stilly and special because $reasons 
    if ! rpm -q google-chrome-stable &>/dev/null; then
        sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
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
    source /etc/os-release
    # Use Billings' COPR
    if [[ "${ID}" == "rhel" ]] || [[ "${ID}" == "redhat" ]]; then
        sudo tee /etc/yum.repos.d/billings-csb.repo &>/dev/null << "EOF"
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
        mv "${2}" "${2}.old$(date +%Y%m%d)"
    fi
    if [[ ! -f ${2} ]] && [[ ! -L ${2} ]]; then
        printf "Symlinking: %s -> %s\n" "$1" "$2"
        if [[ ! -d "$(dirname "${2}")" ]]; then
            mkdir -p "$(dirname "${2}")"
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
            rm -f "${uninstall_paths[@]}"
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
}

fn_system_install_tailscale() {
    source /etc/os-release
    if [[ "${ID}" == "debian" ]]; then 
        # tailscale
        if ! dpkg -l tailscale > /dev/null 2>&1; then
            curl -fsSL "https://pkgs.tailscale.com/stable/debian/${VERSION_CODENAME}.noarmor.gpg" | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
            curl -fsSL "https://pkgs.tailscale.com/stable/debian/${VERSION_CODENAME}.tailscale-keyring.list" | sudo tee /etc/apt/sources.list.d/tailscale.list
            sudo apt update
            sudo apt install -y tailscale
        fi
    fi
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        if ! rpm -q tailscale &>/dev/null; then
            local rhel_major_version
            rhel_major_version=$(rpm -E %rhel)
            sudo dnf config-manager --add-repo "https://pkgs.tailscale.com/stable/rhel/${rhel_major_version}/tailscale.repo"
            sudo dnf install -y tailscale
            sudo systemctl enable --now tailscaled
        fi
    fi

}

fn_system_install_packages() {
    # accept a list of packages and install them
    
    source /etc/os-release

    local pending_install_pkgs=()
    for pkg in "${@}"; do
        if [[ "${ID}" == "debian" ]]; then 
            if ! dpkg -s "${pkg}" | grep "Status: install ok installed" > /dev/null 2>&1; then
                pending_install_pkgs+=("${pkg}")
            fi
        fi
    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
            if ! rpm -q "${pkg}" &>/dev/null; then
                pending_install_pkgs+=("${pkg}")
            fi
        fi
    done
    if [[ -n "${pending_install_pkgs[*]}" ]]; then
        printf "Installing packages... %s\n" "${pending_install_pkgs[@]}"
        if [[ "${ID}" == "debian" ]]; then 
            sudo apt install "${pending_install_pkgs[@]}"
        fi
        if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
            # intentionally want word splitting so don't quote
            sudo dnf install -y --allowerasing "${pending_install_pkgs[@]}"
        fi
    fi
}

fn_flathub_install() {
    local flatpak_pkgs
    flatpak_pkgs=(
        "hu.irl.cameractrls"
        "com.slack.Slack"
        "im.riot.Riot"
        "com.irccloud.desktop"
        "org.onlyoffice.desktopeditors"
    )
    if ! flatpak remotes | grep flathub &>/dev/null; then
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
    for flatpak_pkg in "${flatpak_pkgs[@]}"; do
        if ! flatpak list | grep "${flatpak_pkg}" &>/dev/null; then
            flatpak install --user -y flathub "${flatpak_pkg}"
        fi
    done
}

fn_system_gnome_settings() {
    # key remap because fuck the capslock key
    local current_xkb_options
    local new_xkb_options
    current_xkb_options=$(dconf read /org/gnome/desktop/input-sources/xkb-options 2>/dev/null)
    if [[ -z "${current_xkb_options}" ]] || [[ "${current_xkb_options}" == "@as []" ]]; then
        # if current_xkb_options is empty, set it
        new_xkb_options="['caps:escape']"
    else
        # if current_xkb_options is empty, modify it
        new_xkb_options=${current_xkb_options//\[/\[\'caps:escape\', }
    fi
    if ! [[ "${current_xkb_options}" =~ "caps:escape" ]]; then
        dconf write /org/gnome/desktop/input-sources/xkb-options "${new_xkb_options}"
    fi

    # set alt-tab behavior for sanity
    gsettings set org.gnome.desktop.wm.keybindings switch-applications "[]"
    gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "[]"
    gsettings set org.gnome.desktop.wm.keybindings switch-windows "['<Alt>Tab']"
    gsettings set org.gnome.desktop.wm.keybindings switch-windows-backward "['<Shift><Alt>Tab']"

}

fn_system_setup_crostini() {
    fn_system_install_tailscale

    # nodejs LTS
    NODE_MAJOR=20
    if ! dpkg -l nodejs | grep ${NODE_MAJOR}\. > /dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
        sudo apt update
        sudo apt install -y nodejs
    fi

    # random dev stuff
    local pkglist
    pkglist=(
        "vim-nox"
        "apt-file"
        "python3"
        "python3-pip"
        "python3-venv"
        "python3-q"
        "python3-pylsp"
        "python-is-python3"
        "git"
        "tig"
        "tmux"
        "htop"
        "iotop"
        "strace"
        "tree"
        "pipx"
        "virtualenvwrapper"
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
    )
    fn_system_install_packages "${pkglist[@]}"

    # golang
    golang_version="1.22.0"
    if dpkg -l golang > /dev/null 2>&1; then
        sudo apt remove -y golang 
    fi

    if ! go version | grep "$golang_version" > /dev/null 2>&1; then
        sudo rm -fr /usr/local/go
    fi
    if [[ ! -d /usr/local/go ]]; then
        printf "Installing golang...\n"
        sudo curl -o "/usr/local/go-${golang_version}.tar.gz" "https://dl.google.com/go/go${golang_version}.linux-$(dpkg --print-architecture).tar.gz"
        sudo tar -zxvf /usr/local/go-${golang_version}.tar.gz --directory=/usr/local/
        sudo rm /usr/local/go-${golang_version}.tar.gz
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

    # install ollama.ai
    if [[ ! -f /usr/local/bin/ollama ]]; then
        printf "Installing ollama...\n"
        curl https://ollama.ai/install.sh | sh

        # don't actually start it until I want to use it
        sudo systemctl disable ollama.service
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
    elif [[ -f "${vscode_local_file_path}" ]]; then
        printf "Removing local vscode desktop file...\n"
        rm "${vscode_local_file_path}"
    fi
}

fn_system_install_epel(){
    # Install EPEL
    if ! rpm -q epel-release &>/dev/null; then
        if [[ -f /etc/centos-release ]]; then
            sudo dnf config-manager --enable crb
            sudo dnf -y install epel-release
        else
            sudo subscription-manager repos --enable "codeready-builder-for-rhel-${rhel_major_version}-$(arch)-rpms"
            sudo dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${rhel_major_version}.noarch.rpm"
        fi
    fi

}

fn_system_setup_el() {
    local rhel_major_version
    rhel_major_version="$(rpm -E %rhel)"

    # Setup for RHEL and CentOS Stream
    fn_mkdir_if_needed ~/.local/bin/

    fn_system_install_epel

    # Tailscale
    fn_system_install_tailscale

    # random dev stuff
    local rhel_pkglist
    rhel_pkglist=(
        "vim-enhanced"
        "python3"
        "python3-pip"
        "python3.12"
        "python3.12-pip"
        "nodejs"
        "npm"
        "git"
        "tig"
        "tmux"
        "htop"
        "iotop"
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
        "ninja-build"
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
        "epson-inkjet-printer-escpr"
        "epson-inkjet-printer-escpr2"
    )
    fn_system_install_packages "${rhel_pkglist[@]}"

    fn_system_install_chrome

    fn_system_polkit_libvirt_nonroot_user

    fn_flathub_install

    # virtualenvwrapper
    if ! pip list | grep virtualenvwrapper &>/dev/null; then
        pip install --user virtualenvwrapper
    fi

    fn_system_gnome_settings

}

fn_local_user_ssh_agent() {
    # ssh-agent systemd user unit
    fn_mkdir_if_needed ~/.config/systemd/user

    if [[ ! -f ~/.config/systemd/user/ssh-agent.service ]]; then
        cat > ~/.config/systemd/user/ssh-agent.service << "EOF"
[Unit]
Description=SSH key agent

[Service]
Type=simple
Environment=SSH_AUTH_SOCK=%t/ssh-agent.socket
ExecStart=/usr/bin/ssh-agent -D -a $SSH_AUTH_SOCK

[Install]
WantedBy=default.target
EOF
        systemctl --user enable ssh-agent
    fi
}

fn_local_install_distrobox() {
    local install_path="${HOME}/.local/bin/distrobox"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/89luca89/distrobox/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        currently_installed_version=$(distrobox version | awk -F: '/^distrobox/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
        local uninstall_paths=("${install_path}" "${install_path}-*")
        fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    if [[ ! -f ${install_path} ]]; then
        curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
    fi
}

fn_local_install_opa() {
    local install_path="${HOME}/.local/bin/opa"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/open-policy-agent/opa/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        currently_installed_version=$(opa version | awk -F: '/^Version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
        local uninstall_paths=("${install_path}")
        fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "v${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    if [[ ! -f ${install_path} ]]; then
        if [[ ${_MACHINE_ARCH} == "x86_64" ]]; then
            curl -L -o "${install_path}" "https://openpolicyagent.org/downloads/${latest_release}/opa_linux_amd64_static"
        fi  
        if [[ ${_MACHINE_ARCH} == "aarch64" ]]; then
            curl -L -o "${install_path}" "https://openpolicyagent.org/downloads/${latest_release}/opa_linux_arm64_static"
        fi  
        chmod +x "${install_path}"
    fi
}

fn_local_install_minikube() {
    local install_path="${HOME}/.local/bin/minikube"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/kubernetes/minikube/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        currently_installed_version=$(minikube version | awk -F: '/^minikube version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
        local uninstall_paths=("${install_path}")
        fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    # minikube install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing minikube...\n"
        curl -LO "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${_GOLANG_ARCH}"
        chmod +x "./minikube-linux-${_GOLANG_ARCH}"
        mv "./minikube-linux-${_GOLANG_ARCH}" "${install_path}"
    fi
}

fn_local_install_kind() {
    local install_path="${HOME}/.local/bin/kind"
    local latest_release
    local currently_installed_version
    # kind tags alpha and stable, if it's alpha, use the latest stable - query with jq
    latest_release="$(curl -s 'https://api.github.com/repos/kubernetes-sigs/kind/tags' | jq -r '.[] | select(.name | contains("alpha") | not ).name' | head -1)"
    if [[ ${1} == "update" ]]; then
        currently_installed_version=$(kind version | awk '/^kind/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
        local uninstall_paths=("${install_path}")
        fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    kind_numerical_version="${latest_release#v*}"

    # kind install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing kind...\n"
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${latest_release}/kind-linux-${_GOLANG_ARCH}"
        chmod +x ./kind
        mv ./kind "${install_path}"
    fi
}

fn_local_install_kubectl() {
    local install_path="${HOME}/.local/bin/kubectl"
    local latest_release
    local currently_installed_version

    latest_release=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    if [[ ${1} == "update" ]]; then
        currently_installed_version=$(kubectl version 2>/dev/null | awk -F: '/^Client Version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
        local uninstall_paths=("${install_path}")
        fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    # kubectl install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing kubectl...\n"
        curl -LO "https://dl.k8s.io/release/${latest_release}/bin/linux/${_GOLANG_ARCH}/kubectl"
        chmod +x ./kubectl
        mv ./kubectl "${install_path}"
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
        currently_installed_version=$(terraform version | awk '/^Terraform/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
        local uninstall_paths=("${install_path}")
        fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
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
}

fn_local_install_rustup() {
    local install_path="${HOME}/.cargo/bin/rustup"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/rust-lang/rustup/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        currently_installed_version=$(rustup --version 2>/dev/null| awk '/^rustup/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
        local uninstall_paths=("${install_path}")
        fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    if [[ ! -f ${install_path} ]]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    fi
}

fn_local_install_gh() {
    local install_path="${HOME}/.local/bin/gh"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/cli/cli/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        currently_installed_version=$(gh version| awk '/^gh version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $3 }')
        local uninstall_paths=("${install_path}")
        fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "v${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    local gh_numerical_version="${latest_release#v*}"
    if [[ ! -f ${install_path} ]]; then
        printf "Installing gh...\n"
        curl -Lo /tmp/gh.tar.gz "https://github.com/cli/cli/releases/download/${latest_release}/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}.tar.gz"
        tar -zxvf /tmp/gh.tar.gz -C /tmp/
        cp "/tmp/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}/bin/gh" "${install_path}"
        cp "/tmp/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}/share/man/man1/*" "${HOME}/.local/share/man/man1/"
    fi
}

fn_local_install_neovim() {
    local install_path="${HOME}/.local/bin/nvim"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/neovim/neovim/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        currently_installed_version=$(nvim --version| awk '/^NVIM/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
        local uninstall_paths=("${install_path}")
        fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
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
}

fn_local_install_task() {
    local install_path="${HOME}/.local/bin/task"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/task"
    local latest_release
    latest_release="$(curl -s 'https://api.github.com/repos/go-task/task/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        currently_installed_version=$(nvim --version| awk '/^NVIM/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
        local uninstall_paths=("${install_path}" "${completions_install_path}")
        fn_rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
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
}


fn_local_pipx_packages_install() {
    if which pipx > /dev/null 2>&1; then
        for pypkg in "${_PIPX_PACKAGE_LIST[@]}";
        do
            if [[ ! -d ${HOME}/.local/pipx/venvs/${pypkg} ]]; then
                pipx install "${pypkg}"
            fi
        done
    fi
}

fn_update_local_installs() {

    if [[ "${ID}" == "debian" ]]; then
        fn_local_install_rustup update
    fi

    fn_local_install_distrobox update
    fn_local_install_opa update
    fn_local_install_minikube update
    fn_local_install_kind update
    fn_local_install_kubectl update
    fn_local_install_terraform update
    fn_local_install_gh update
    fn_local_install_neovim update
    fn_local_install_task update
    pipx upgrade-all
}
