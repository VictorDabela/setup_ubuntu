#!/bin/bash
# ==============================================================================
# Script de Setup de Ambiente CLI - Ubuntu 24.04 (Noble Numbat)
# Versão Final - Edição Dotfiles com Stow
# ==============================================================================
set -e

# --- Variáveis de Configuração ---
export TZ=America/Sao_Paulo
UBUNTU_RELEASE_NAME=$(lsb_release -cs)
APT_PACKAGES=(
    # Essenciais e Build
    stow build-essential curl wget git gnupg software-properties-common apt-transport-https ca-certificates
    # Dependências de build para pyenv
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
    # Shell, Terminal e Utilitários
    zsh vim neovim jq tree unzip
    # Ferramentas de Desenvolvimento
    python3-pip python3-venv python3-all-dev postgresql-client redis-tools pipx
    # Ferramentas CLI Modernas e Monitores
    bat eza fd-find ripgrep zoxide btop
)
PIPX_PACKAGES=(pipenv uv pre-commit)
PYTHON_VERSIONS_TO_INSTALL=(3.12.3 3.10.13)
PYTHON_GLOBAL_VERSION=3.12.3

# --- Funções de Instalação ---
install_base_packages() {
    echo "📦 Instalando pacotes base do APT..."
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
    sudo apt-get clean
    sudo apt-get update
    sudo apt-get install -y "${APT_PACKAGES[@]}"
}

install_nvm_and_nodejs() {
    echo "📦 Instalando NVM (Node Version Manager), Node.js (LTS) e Yarn..."

    # Instala o NVM
    curl -o- -L https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

    # Carrega o NVM no ambiente atual do script para poder usá-lo imediatamente
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    echo "    - Instalando a versão LTS mais recente do Node.js..."
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'

    echo "    - Instalando Yarn globalmente via npm..."
    npm install -g yarn

    echo "    - Versões instaladas:"
    node -v
    npm -v
    yarn -v
}

install_pyenv_and_python_versions() {
    echo "🐍 Instalando pyenv e versões do Python..."
    if [ ! -d "$HOME/.pyenv" ]; then
        curl https://pyenv.run | bash
    fi
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    for version in "${PYTHON_VERSIONS_TO_INSTALL[@]}"; do
        if ! pyenv versions --bare | grep -q "^${version}$"; then
            echo "    - Instalando Python ${version}..."
            pyenv install "$version"
        else
            echo "    - Python ${version} já está instalado."
        fi
    done
    echo "    - Definindo Python global padrão como ${PYTHON_GLOBAL_VERSION}"
    pyenv global "$PYTHON_GLOBAL_VERSION"
}

install_aws_tools() {
    echo "📦 Instalando ferramentas da AWS (AWS CLI, SAM CLI)..."
    TEMP_AWS_DIR=$(mktemp -d)
    cd "$TEMP_AWS_DIR"
    echo "    - Baixando e instalando AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    echo "    - Baixando e instalando AWS SAM CLI..."
    wget -q "https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip" -O "sam.zip"
    unzip -q sam.zip -d sam-installation
    sudo ./sam-installation/install
    cd - > /dev/null
    rm -rf "$TEMP_AWS_DIR"
}

add_custom_repos_and_install() {
    echo "📦 Adicionando repositórios de CLI de terceiros..."
    sudo install -m 0755 -d /etc/apt/keyrings

    # Microsoft
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ ${UBUNTU_RELEASE_NAME} main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod ${UBUNTU_RELEASE_NAME} main" | sudo tee /etc/apt/sources.list.d/microsoft-prod.list

    # GitHub CLI
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list

    # Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

    # HashiCorp (Terraform)
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

    # Kubernetes (kubectl)
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    echo "🔄 Atualizando listas de pacotes..."
    sudo apt-get update

    echo "📦 Instalando pacotes de repositórios customizados..."
    CUSTOM_APT_PACKAGES=(
        code powershell azure-cli gh
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        terraform kubectl dotnet-sdk-8.0
    )
    sudo apt-get install -y "${CUSTOM_APT_PACKAGES[@]}"
}

install_extra_binaries() {
    echo "📦 Instalando binários extras (k9s)..."
    TEMP_BIN_DIR=$(mktemp -d)
    cd "$TEMP_BIN_DIR"
    echo "    - Baixando e instalando k9s..."
    wget -qO k9s.tar.gz "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz"
    tar -xzf k9s.tar.gz
    sudo install k9s /usr/local/bin
    cd - > /dev/null
    rm -rf "$TEMP_BIN_DIR"
}

install_pipx_packages() {
    echo "🐍 Instalando ferramentas Python CLI com pipx..."
    export PATH="$PATH:$HOME/.local/bin"
    for pkg in "${PIPX_PACKAGES[@]}"; do
        pipx install "$pkg"
    done
}

# --- Configuração ---
stow_dotfiles() {
    echo "🔗 Gerenciando dotfiles com Stow..."

    # Descobre o caminho absoluto para a raiz do repositório (a pasta acima de 'scripts')
    local SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    local REPO_ROOT=$( dirname "$SCRIPT_DIR" )

    echo "    - Linkando zsh..."
    # A flag -d diz ao stow onde está a pasta com os 'pacotes' (zsh, etc.)
    # A flag -t diz para onde os links devem ser criados (nossa home)
    stow --dir=$REPO_ROOT --target=$HOME -R zsh
}


configure_system() {
    echo "⚙️  Configurando o sistema..."
    sudo groupadd -f docker
    sudo usermod -aG docker "$(whoami)"

    echo "    - Configurando Git..."
    git config --global user.name "Tester"
    git config --global user.email "tester@example.com"
    git config --global init.defaultBranch main
}

configure_zsh() {
    echo "👽 Configurando Zsh, Oh My Zsh e plugins..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    OMZ_CUSTOM_PLUGINS="$HOME/.oh-my-zsh/custom/plugins"
    mkdir -p "$OMZ_CUSTOM_PLUGINS"

    if [ ! -d "$OMZ_CUSTOM_PLUGINS/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$OMZ_CUSTOM_PLUGINS/zsh-autosuggestions"
    fi
    if [ ! -d "$OMZ_CUSTOM_PLUGINS/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$OMZ_CUSTOM_PLUGINS/zsh-syntax-highlighting"
    fi

    if [[ "$SHELL" != */zsh ]]; then
        echo "    - Definindo Zsh como shell padrão..."
        sudo chsh -s "$(which zsh)" "$(whoami)"
    fi
}

cleanup() {
    echo "🧹 Limpando o sistema..."
    sudo apt-get autoremove -y
    sudo apt-get clean
}

# --- Execução Principal ---
main() {
    echo "🚀 Iniciando setup do ambiente CLI (Edição Dotfiles)..."
    install_base_packages
    install_pyenv_and_python_versions
    install_nvm_and_nodejs
    install_aws_tools
    add_custom_repos_and_install
    install_extra_binaries
    install_pipx_packages
    stow_dotfiles
    configure_system
    configure_zsh
    cleanup
    echo "✅ Setup CLI concluído com sucesso!"
}

main