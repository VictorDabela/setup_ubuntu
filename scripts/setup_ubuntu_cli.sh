#!/bin/bash
# ==============================================================================
# Script de Setup de Ambiente de Desenvolvimento - Ubuntu 24.04 (Noble Numbat)
# v25 - Adicionado NeoVim
# ==============================================================================
set -e

# --- Variáveis de Configuração ---
export TZ=America/Sao_Paulo
UBUNTU_RELEASE_NAME=$(lsb_release -cs)
APT_PACKAGES=(
    build-essential curl wget git gnupg software-properties-common apt-transport-https ca-certificates
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
    zsh vim neovim jq tree unzip
    python3-pip python3-venv python3-all-dev postgresql-client redis-tools pipx
    flameshot gnome-boxes gnome-tweaks qbittorrent
    bat eza fd-find ripgrep zoxide btop
)
PIPX_PACKAGES=(pipenv uv docker-compose pre-commit)
PYTHON_VERSIONS_TO_INSTALL=(3.12.3 3.10.13)
PYTHON_GLOBAL_VERSION=3.12.3
FLATPAKS=(com.slack.Slack com.getpostman.Postman md.obsidian.Obsidian)
VSCODE_EXTENSIONS=()

# --- Funções de Instalação ---
install_base_packages() {
    echo "📦 Instalando pacotes base do APT..."
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

    # Pré-aceita a licença das fontes da Microsoft para modo não-interativo
    echo "ttf-mscorefonts-installer ttf-mscorefonts-installer/accepted-mscorefonts-eula select true" | sudo debconf-set-selections

    sudo apt-get update
    sudo apt-get install -y "${APT_PACKAGES[@]}"
}

install_nvm_and_nodejs() {
    echo "📦 Instalando NVM (Node Version Manager), Node.js (LTS) e Yarn..."

    # Instala o NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

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

add_custom_repos_and_install() {
    echo "📦 Adicionando repositórios de terceiros..."
    sudo install -m 0755 -d /etc/apt/keyrings

    # ... (outros repositórios permanecem iguais)
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ ${UBUNTU_RELEASE_NAME} main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod ${UBUNTU_RELEASE_NAME} main" | sudo tee /etc/apt/sources.list.d/microsoft-prod.list
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
    curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin4-archieve-keyring.gpg
    sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/pgadmin4-archieve-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    curl -1sLf 'https://packages.konghq.com/public/insomnia/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/insomnia.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/insomnia.gpg] https://packages.konghq.com/public/insomnia/deb/ ubuntu-$(lsb_release -cs) non-free" | sudo tee /etc/apt/sources.list.d/insomnia.list

    echo "🔄 Atualizando listas de pacotes..."
    sudo apt-get update

    echo "📦 Instalando pacotes de repositórios customizados..."
    CUSTOM_APT_PACKAGES=(
        insomnia google-chrome-stable code powershell azure-cli brave-browser gh spotify-client teams-for-linux dotnet-sdk-8.0 pgadmin4-desktop
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        terraform kubectl
    )
    sudo apt-get install -y "${CUSTOM_APT_PACKAGES[@]}"
}

install_extra_binaries() {
    echo "📦 Instalando binários extras (k9s)..."
    TEMP_BIN_DIR=$(mktemp -d); cd "$TEMP_BIN_DIR"
    echo "    - Baixando e instalando k9s..."; wget -qO k9s.tar.gz "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz"; tar -xzf k9s.tar.gz; sudo install k9s /usr/local/bin
    cd - > /dev/null && rm -rf "$TEMP_BIN_DIR"
}

install_pipx_packages() {
    echo "🐍 Instalando ferramentas Python CLI com pipx..."
    export PATH="$PATH:$HOME/.local/bin"
    for pkg in "${PIPX_PACKAGES[@]}"; do
        pipx install "$pkg"
    done
}

# --- Configuração ---
configure_system() {
    echo "⚙️  Configurando o sistema..."
    sudo groupadd -f docker
    sudo usermod -aG docker "$USER"

    echo "    - Configurando Git (PREENCHA AQUI!)..."
    git config --global user.name "Tester"
    git config --global user.email "tester@example.com"
    git config --global init.defaultBranch main
}

configure_zsh() {
    echo "👽 Configurando Zsh, Oh My Zsh e plugins..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; fi
    OMZ_CUSTOM_PLUGINS="$HOME/.oh-my-zsh/custom/plugins" && OMZ_CUSTOM_THEMES="$HOME/.oh-my-zsh/custom/themes"
    mkdir -p "$OMZ_CUSTOM_PLUGINS" && mkdir -p "$OMZ_CUSTOM_THEMES"
    if [ ! -d "$OMZ_CUSTOM_PLUGINS/zsh-autosuggestions" ]; then git clone https://github.com/zsh-users/zsh-autosuggestions "$OMZ_CUSTOM_PLUGINS/zsh-autosuggestions"; fi
    if [ ! -d "$OMZ_CUSTOM_PLUGINS/zsh-syntax-highlighting" ]; then git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$OMZ_CUSTOM_PLUGINS/zsh-syntax-highlighting"; fi
    if [ -f "./.zshrc" ]; then [ -f "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$HOME/.zshrc.omz-default-bak"; cp "./.zshrc" "$HOME/.zshrc"; fi
    if [[ "$SHELL" != */zsh ]]; then sudo chsh -s "$(which zsh)" "$USER"; fi
}

cleanup() {
    echo "🧹 Limpando o sistema..."
    sudo apt-get autoremove -y
    sudo apt-get clean
}

# --- Execução Principal ---
main() {
    echo "🚀 Iniciando setup do ambiente CLI v17..."
    install_base_packages
    install_pyenv_and_python_versions
    install_nvm_and_nodejs
    install_aws_tools
    add_custom_repos_and_install
    install_extra_binaries
    install_pipx_packages
    configure_system
    configure_zsh
    cleanup
    echo "✅ Setup CLI concluído com sucesso!"
}

main