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
)

if [[ ${_MACHINE_ARCH} == "x86_64" ]]; then
    _GOLANG_ARCH="amd64"
fi
if [[ ${_MACHINE_ARCH} == "aarch64" ]]; then
    _GOLANG_ARCH="arm64"
fi
#
# Ensure the needed dirs exist
mkdir_if_needed() {
    if [[ ! -d $1 ]]; then
        mkdir -p $1
    fi
}

# Symlink the conf files
symlink_if_needed() {
    if [[ ! -f $2 ]] && [[ ! -L $2 ]]; then
        printf "Symlinking: %s -> %s\n" "$1" "$2"
        if [[ ! -d $(dirname $2) ]]; then
            mkdir -p $(dirname $2)
        fi
        ln -s $1 $2
    fi
    if [[ -f $2 ]] && [[ ! -L $2 ]]; then
        printf "File found: %s\n" "$2"
    fi
}

local_user_ssh_agent() {
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
}

local_install_distrobox() {
    local install_path="${HOME}/.local/bin/distrobox"
    if [[ ${1} == "update" ]]; then
        rm -f ${install_path}
    fi

    if [[ ! -f ${install_path} ]]; then
        curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
    fi
}

local_install_opa() {
    local install_path="${HOME}/.local/bin/opa"
    if [[ ${1} == "update" ]]; then
        rm -f ${install_path}
    fi

    local opa_version="$(curl -s 'https://api.github.com/repos/open-policy-agent/opa/tags' | jq -r '.[0].name')"
    if [[ ! -f ${install_path} ]]; then
        if [[ ${_MACHINE_ARCH} == "x86_64" ]]; then
            curl -L -o ${install_path} https://openpolicyagent.org/downloads/${opa_version}/opa_linux_amd64_static
        fi  
        if [[ ${_MACHINE_ARCH} == "aarch64" ]]; then
            curl -L -o ${install_path} https://openpolicyagent.org/downloads/${opa_version}/opa_linux_arm64_static
        fi  
        chmod +x ${install_path}
    fi
}

local_install_minikube() {
    local install_path="${HOME}/.local/bin/minikube"
    if [[ ${1} == "update" ]]; then
        rm -f ${install_path}
    fi

    # minikube install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing minikube...\n"
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${_GOLANG_ARCH}
        chmod +x ./minikube-linux-${_GOLANG_ARCH}
        sudo mv ./minikube-linux-${_GOLANG_ARCH} ${install_path}
    fi
}

local_install_kind() {
    local install_path="${HOME}/.local/bin/kind"
    if [[ ${1} == "update" ]]; then
        rm -f ${install_path}
    fi

    local kind_version="$(curl -s 'https://api.github.com/repos/kubernetes-sigs/kind/tags' | jq -r '.[0].name')"
    if [[ ${kind_version} =~ "alpha" ]]; then
        # kind tags alpha and stable, if it's alpha, use the latest stable
        local kind_version="$(curl -s 'https://api.github.com/repos/kubernetes-sigs/kind/tags' | jq -r '.[1].name')"
    fi
    kind_numerical_version="${kind_version#v*}"

    # kind install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing kind...\n"
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${kind_version}/kind-linux-${_GOLANG_ARCH}"
        chmod +x ./kind
        mv ./kind ${install_path}
    fi
}

local_install_kubectl() {
    local install_path="${HOME}/.local/bin/kubectl"
    if [[ ${1} == "update" ]]; then
        rm -f ${install_path}
    fi

    # kubectl install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing kubectl...\n"
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${_GOLANG_ARCH}/kubectl"
        chmod +x ./kubectl
        sudo mv ./kubectl ${install_path}
    fi
}

local_install_terraform() {
    local install_path="${HOME}/.local/bin/terraform"
    if [[ ${1} == "update" ]]; then
        rm -f ${install_path}
    fi

    local terraform_vprefix_version="$(curl -s 'https://api.github.com/repos/hashicorp/terraform/tags' | jq -r '.[0].name')"
    local terraform_version="${terraform_vprefix_version#v*}"
    if [[ ! -f ${install_path} ]]; then
        printf "Installing terraform...\n"
        printf "curl -Lo ${install_path} https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_${_GOLANG_ARCH}.zip\n"
        pushd /tmp/
            rm -f terraform terraform.zip # just to make sure the zip command doesn't complain
            curl -Lo terraform.zip \
                https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_${_GOLANG_ARCH}.zip
            unzip terraform.zip
            cp terraform ${install_path}
        popd
        chmod +x ${install_path}
    fi
}

local_install_rustup() {
    local install_path="${HOME}/.cargo/bin/rustup"
    if [[ ${1} == "update" ]]; then
        rm -f ${install_path}
    fi

    if [[ ! -f ${install_path} ]]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    fi
}

local_install_gh() {
    local install_path="${HOME}/.local/bin/gh"
    if [[ ${1} == "update" ]]; then
        rm -f ${install_path}
    fi

    local gh_version="$(curl -s 'https://api.github.com/repos/cli/cli/tags' | jq -r '.[0].name')"
    local gh_numerical_version="${gh_version#v*}"
    if [[ ! -f ${install_path} ]]; then
        printf "Installing gh...\n"
        curl -Lo /tmp/gh.tar.gz https://github.com/cli/cli/releases/download/${gh_version}/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}.tar.gz
        tar -zxvf /tmp/gh.tar.gz -C /tmp/
        cp /tmp/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}/bin/gh ${install_path}
        cp /tmp/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}/share/man/man1/* ${HOME}/.local/share/man/man1/
    fi
}

local_pipx_packages_install() {
    if which pipx > /dev/null 2>&1; then
        for pypkg in ${_PIPX_PACKAGE_LIST[@]};
        do
            if [[ ! -d ${HOME}/.local/pipx/venvs/${pypkg} ]]; then
                pipx install ${pypkg}
            fi
        done
    fi
}

update_local_installs() {
    local_install_distrobox update
    local_install_opa update
    local_install_minikube update
    local_install_kind update
    local_install_kubectl update
    local_install_terraform update
    local_install_rustup update
    local_install_gh update
    pipx upgrade-all
}
