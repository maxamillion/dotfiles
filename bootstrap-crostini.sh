#!/bin/bash
source ./bootstrap-lib.sh
source /etc/os-release

# tailscale
dpkg -l tailscale > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    curl -fsSL https://pkgs.tailscale.com/stable/debian/${VERSION_CODENAME}.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/debian/${VERSION_CODENAME}.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
    sudo apt update
    sudo apt install -y tailscale
fi

# nodejs LTS
NODE_MAJOR=20
dpkg -l nodejs | grep ${NODE_MAJOR}\. > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    sudo apt update
    sudo apt install -y nodejs
fi

# random dev stuff
pkglist=(
    "vim-nox"
    "apt-file"
    "python3"
    "python3-pip"
    "python3-venv"
    "python3-q"
    "python3-ipython"
    "python3-pylsp"
    "python-is-python3"
    "ipython3"
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
)
pending_install_pkgs=""
for pkg in ${pkglist[@]}; do
    dpkg -s ${pkg} | grep "Status: install ok installed" > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        pending_install_pkgs+=" ${pkg}"
    fi
done
if [[ -n "${pending_install_pkgs}" ]]; then
    printf "Installing packages... %s\n" "${pending_install_pkgs}"
    sudo apt install ${pending_install_pkgs}
fi

# golang
golang_version="1.22.0"
dpkg -l golang > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    sudo apt remove -y golang 
fi
go version | grep "$golang_version" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
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

# local user ssh agent
local_user_ssh_agent

# rustup
local_install_rustup

# k8s stuff
local_install_minikube
local_install_kind
local_install_kubectl

# terraform
local_install_terraform

# pipx
local_pipx_packages_install

# rootless distrobox
local_install_distrobox

# OPA
local_install_opa

# GH cli
local_install_gh

# Neovim
local_install_neovim_appimage

# Task
local_install_task

# Force wayland for firefox-esr
firefox_esr_desktop_file_path="/usr/share/applications/firefox-esr.desktop"
firefox_esr_desktop_local_path="${HOME}/.local/share/applications/firefox-esr.desktop"
if [[ -f ${firefox_esr_desktop_file_path} ]]; then 
    if [[ ! -f ${firefox_esr_desktop_local_path} ]]; then
        printf "Forcing wayland for firefox-esr...\n"
        cp ${firefox_esr_desktop_file_path} ${firefox_esr_desktop_local_path}
        sed -i \
            's|Exec=/usr/lib/firefox-esr/firefox-esr %u|Exec=env MOZ_ENABLE_WAYLAND=1 /usr/lib/firefox-esr/firefox-esr %u|' \
            ${firefox_esr_desktop_local_path}
    fi
elif [[ -f ${firefox_esr_desktop_local_path} ]]; then
    printf "Removing local firefox-esr desktop file...\n"
    rm ${firefox_esr_desktop_local_path}
fi

vscode_desktop_file_path="/usr/share/applications/code.desktop"
vscode_local_file_path="${HOME}/.local/share/applications/code.desktop"
if [[ -f ${vscode_desktop_file_path} ]]; then
    if [[ ! -f ${vscode_local_file_path} ]]; then
        printf "Forcing wayland for vscode...\n"
        cp ${vscode_desktop_file_path} ${vscode_local_file_path}
        sed -i \
            's|Exec=/usr/share/code/code|Exec=/usr/share/code/code --enable-features=UseOzonePlatform --ozone-platform=wayland|g' \
            ${vscode_local_file_path}
    fi
elif [[ -f ${vscode_local_file_path} ]]; then
    printf "Removing local vscode desktop file...\n"
    rm ${vscode_local_file_path}
fi


printf "Done!\n"
