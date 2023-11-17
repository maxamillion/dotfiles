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


# docker - because podman doesn't work in crostini/termina
dpkg -l docker-ce > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    sudo apt install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    printf "Adding user to docker group...\n"
    sudo groupadd docker
    sudo usermod -aG docker $USER
fi

# rootless distrobox
if [[ ! -f ${HOME}/.local/bin/distrobox ]]; then
    curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
fi

# nodejs LTS
NODE_MAJOR=18
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

# ssh-agent systemd user unit
mkdir_if_needed ~/.config/systemd/user

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

# random dev stuff
pkglist=(
    "apt-file"
    "vim-nox"
    "python3"
    "python3-pip"
    "python3-venv"
    "python3-q"
    "python3-ipython"
    "python-is-python3"
    "git"
    "tig"
    "tmux"
    "htop"
    "iotop"
    "strace"
    "ltrace"
    "tree"
    "pipx"
    "virtualenvwrapper"
    "libonig-dev"
    "firefox-esr"
    "debian-goodies"
    "flatpak"
)
for pkg in ${pkglist[@]}; do
    dpkg -l ${pkg} > /dev/null 2>&1
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

# k8s stuff
k8s_arch=$(dpkg --print-architecture)
# minikube install
if [[ ! -f ${HOME}/.local/bin/minikube ]]; then
    printf "Installing minikube...\n"
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${k8s_arch}
    chmod +x ./minikube-linux-${k8s_arch}
    sudo mv ./minikube-linux-${k8s_arch} ${HOME}/.local/bin/minikube
fi

# kind install
if [[ ! -f ${HOME}/.local/bin/kind ]]; then
    printf "Installing kind...\n"
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-${k8s_arch}
    chmod +x ./kind
    mv ./kind ${HOME}/.local/bin/kind
fi


# kubectl install
if [[ ! -f ${HOME}/.local/bin/kubectl ]]; then
    printf "Installing kubectl...\n"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${k8s_arch}/kubectl"
    chmod +x ./kubectl
    sudo mv ./kubectl ${HOME}/.local/bin/kubectl
fi

# terraform
if [[ ! -f /usr/bin/terraform ]]; then
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform
fi

# pipx install pypkglist 
pypkglist=(
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
)
for pypkg in ${pypkglist[@]};
do
    if [[ ! -d ${HOME}/.local/pipx/venvs/${pypkg} ]]; then
        pipx install ${pypkg}
    fi
done

printf "Done!\n"
