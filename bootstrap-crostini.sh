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
    "fuse"
)
for pkg in ${pkglist[@]}; do
    dpkg -s ${pkg} > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        printf "Installing %s...\n" ${pkg}
        sudo apt install -y ${pkg}
    fi
done

# golang
golang_version="1.20.7"
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

printf "Done!\n"
