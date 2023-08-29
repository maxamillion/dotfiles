#!/bin/bash
source ./bootstrap-lib.sh

# tailscale
dpkg -l tailscale > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
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
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
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
dpkg -l nodejs | grep 18\. > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - &&\
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
    "vim-nox"
    "python3"
    "python3-pip"
    "python3-venv"
    "python3-q"
    "git"
    "tmux"
    "htop"
    "strace"
    "pipx"
    "virtualenvwrapper"
    "qemu-system"
    "libvirt-clients"
    "libvirt-daemon-system"
)
for pkg in ${pkglist[@]}; do
    dpkg -l ${pkg} > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        printf "Installing %s...\n" ${pkg}
        sudo apt install -y ${pkg}
        if [[ "${pkg}" == "libvirt-daemon-system" ]]; then
            printf "Adding user to libvirt group...\n"
            sudo usermod -aG libvirt $USER
            # Configure qemu to allow dynamic ownership for minikube
            sudo sed -i 's/\#dynamic_ownership\ \=\ 1/dynamic_ownership\ \=\ 0/' /etc/libvirt/qemu.conf
            sudo sed -i 's/\#remember_owner\ \=\ 1/remember_owner\ \=\ 0/' /etc/libvirt/qemu.conf
            sudo sed -i 's/\#user\ \=\ "libvirt-qemu"/user\ \=\ "root"/' /etc/libvirt/qemu.conf
            sudo sed -i 's/\#group\ \=\ "libvirt-qemu"/group\ \=\ "root"/' /etc/libvirt/qemu.conf
        fi
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
# For AMD64 / x86_64
if [[ $(uname -m) = x86_64 ]]; then
    k8s_arch=amd64
fi
# For ARM64
if [[ $(uname -m) = aarch64 ]]; then
    k8s_arch=arm64
fi

# minikube install
if [[ ! -f ${HOME}/.local/bin/minikube ]]; then
    printf "Installing minikube...\n"
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${k8s_arch}
    chmod +x ./minikube-linux-${k8s_arch}
    sudo mv ./minikube-linux-${k8s_arch} ${HOME}/.local/bin/minikube
fi

# kubectl install
if [[ ! -f ${HOME}/.local/bin/kubectl ]]; then
    printf "Installing kubectl...\n"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${k8s_arch}/kubectl"
    chmod +x ./kubectl
    sudo mv ./kubectl ${HOME}/.local/bin/kubectl
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
