#!/bin/bash
# ==============================================================================
# Script de Setup de Ambiente de Desenvolvimento - Ubuntu 24.04 (Noble Numbat)
# Versão Final - Edição Dotfiles com Stow
# ==============================================================================
set -e

# --- Variáveis de Configuração ---
# Define o fuso horário para modo não-interativo
export TZ=America/Sao_Paulo

UBUNTU_RELEASE_NAME=$(lsb_release -cs)
APT_PACKAGES=(
    # Essenciais e Build
    stow build-essential curl wget git gnupg software-properties-common apt-transport-https ca-certificates ubuntu-restricted-extras
    # Dependências de build para pyenv
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
    # Shell, Terminal e Utilitários
    zsh vim neovim jq tree unzip # <-- ADICIONADO AQUI
    # Ferramentas de Desenvolvimento
    python3-pip python3-venv python3-all-dev postgresql-client redis-tools pipx
    # Aplicações GUI
    flameshot gnome-boxes gnome-tweaks qbittorrent slimbookbattery synaptic ubuntu-cleaner indicator-stickynotes
    # Ferramentas CLI Modernas e Monitores
    bat eza fd-find ripgrep zoxide btop
)
PIPX_PACKAGES=(pipenv uv pre-commit)
PYTHON_VERSIONS_TO_INSTALL=(3.12.3 3.10.13)
PYTHON_GLOBAL_VERSION=3.12.3
FLATPAKS=()
VSCODE_EXTENSIONS=()

# --- Funções de Instalação ---
install_base_packages() {
    echo "📦 Instalando pacotes base do APT..."
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone

    sudo apt-get clean

    # Pré-aceita a licença das fontes da Microsoft para modo não-interativo
    echo "ttf-mscorefonts-installer ttf-mscorefonts-installer/accepted-mscorefonts-eula select true" | sudo debconf-set-selections

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

install_custom_themes() {
    echo "🎨 Instalando temas customizados (Numix Icon Theme)..."
    sudo add-apt-repository -y ppa:numix/ppa
    sudo apt-get update
    sudo apt-get install -y numix-icon-theme-circle
}

add_custom_repos_and_install() {
    echo "📦 Adicionando repositórios de terceiros..."
    sudo install -m 0755 -d /etc/apt/keyrings

    # Google Chrome
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list

     # Microsoft (VS Code, PowerShell, .NET, Azure CLI, Teams)
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ ${UBUNTU_RELEASE_NAME} main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod ${UBUNTU_RELEASE_NAME} main" | sudo tee /etc/apt/sources.list.d/microsoft-prod.list

    # Brave Browser
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list

    # GitHub CLI
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list

    # Spotify
    curl -sS https://download.spotify.com/debian/pubkey_7A3A762FAFD4A51F.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
    echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list

    # PGAdmin4
    curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin4-archieve-keyring.gpg
    sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/pgadmin4-archieve-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'

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

    # Insomnia
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

install_deb_packages() {
    echo "📦 Instalando pacotes .deb..."
    TEMP_DEB_DIR=$(mktemp -d)
    cd "$TEMP_DEB_DIR"

    echo "    - Baixando e instalando Hyper..."
    wget -qO hyper.deb "https://releases.hyper.is/download/deb"
    sudo dpkg -i hyper.deb

    echo "    - Baixando e instalando Discord..."
    wget -qO discord.deb "https://discord.com/api/download?platform=linux&format=deb"
    sudo dpkg -i discord.deb

    echo "    - Baixando e instalando TeamViewer..."
    wget -qO teamviewer.deb "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"
    sudo dpkg -i teamviewer.deb

    echo "    - Baixando e instalando Zoom..."
    wget -qO zoom.deb "https://zoom.us/client/latest/zoom_amd64.deb"
    sudo dpkg -i zoom.deb

    echo "    - Corrigindo possíveis dependências quebradas..."
    sudo apt-get install -f -y

    cd - > /dev/null
    rm -rf "$TEMP_DEB_DIR"
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

install_flatpaks() {
    echo "💿 Instalando pacotes Flatpak..."
    sudo apt-get install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    for app in "${FLATPAKS[@]}"; do
        flatpak install -y flathub "$app"
    done
}

install_vscode_extensions() {
    echo "💻 Verificando extensões do VS Code..."
    if command -v code &> /dev/null && [ ${#VSCODE_EXTENSIONS[@]} -gt 0 ]; then
        for ext in "${VSCODE_EXTENSIONS[@]}"; do
            code --install-extension "$ext"
        done
    else
        echo "⚠️  Lista de extensões vazia ou VS Code não encontrado. Pulei a instalação."
    fi
}

install_nerd_fonts() {
    echo "🔤 Instalando Nerd Fonts (FiraCode)..."
    local fonts_dir="$HOME/.local/share/fonts"
    if [ ! -d "$fonts_dir/FiraCode" ]; then
        mkdir -p "$fonts_dir"
        cd "$fonts_dir"
        wget -q -O FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip
        unzip -q FiraCode.zip -d FiraCode
        rm FiraCode.zip
        fc-cache -f -v
        cd - > /dev/null
        echo "    - Fonte FiraCode Nerd Font instalada!"
    else
        echo "    - Fonte FiraCode Nerd Font já parece estar instalada."
    fi
}

install_pipx_packages() {
    echo "🐍 Instalando ferramentas Python CLI com pipx..."
    export PATH="$PATH:$HOME/.local/bin"
    for pkg in "${PIPX_PACKAGES[@]}"; do
        pipx install "$pkg"
    done
}

stow_dotfiles() {
    echo "🔗 Gerenciando dotfiles com Stow..."

    local SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    local REPO_ROOT=$( dirname "$SCRIPT_DIR" )

    echo "    - Linkando zsh..."
    stow --dir=$REPO_ROOT --target=$HOME -R zsh

    echo "    - Linkando hyper..."
    stow --dir=$REPO_ROOT --target=$HOME -R hyper
}

# --- Configuração ---
configure_apps() {
    echo "📲 Configurando arquivos de aplicativos (Insomnia)..."
    # A lógica do Insomnia permanece, mas com o caminho corrigido
    if [ -f "../insomnia_config.tar.gz" ]; then
        echo "    - Backup do Insomnia encontrado. Restaurando..."
        mkdir -p "$HOME/.config"
        tar -xzf "../insomnia_config.tar.gz" -C "$HOME/.config/"
    fi
}

configure_system() {
    echo "⚙️  Configurando o sistema e atalhos..."
    sudo groupadd -f docker
    sudo usermod -aG docker "$(whoami)"

    echo "    - Configurando Git (PREENCHA AQUI!)..."
    git config --global user.name "Seu Nome"
    git config --global user.email "seu-email@exemplo.com"
    git config --global init.defaultBranch main

    echo "    - Aplicando temas visuais..."
    THEME_GTK="Yaru-dark"
    THEME_ICONS="Numix-Circle"
    THEME_CURSOR="Yaru"
    gsettings set org.gnome.desktop.interface gtk-theme "$THEME_GTK"
    gsettings set org.gnome.desktop.interface icon-theme "$THEME_ICONS"
    gsettings set org.gnome.desktop.interface cursor-theme "$THEME_CURSOR"

    echo "    - Definindo Hyper como terminal padrão..."
    sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/hyper 50
    sudo update-alternatives --set x-terminal-emulator /usr/bin/hyper


    echo "    - Configurando atalhos de teclado..."
    # Configura o Flameshot para a tecla Print Screen
    local CUSTOM_KEYBINDING_PATH_FLAMESHOT="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
    gsettings set org.gnome.settings-daemon.plugins.media-keys screenshot '[]'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_FLAMESHOT} name 'Flameshot'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_FLAMESHOT} command 'flameshot gui'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_FLAMESHOT} binding 'Print'

    # --- ADICIONADO AQUI ---
    # Configura o Hyper para a tecla Super+T
    local CUSTOM_KEYBINDING_PATH_TERM="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_TERM} name 'Abrir Terminal'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_TERM} command 'hyper'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_TERM} binding '<Super>t'

    # Adiciona os dois atalhos customizados à lista de atalhos ativos
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['${CUSTOM_KEYBINDING_PATH_FLAMESHOT}', '${CUSTOM_KEYBINDING_PATH_TERM}']"
}

configure_zsh() {
    echo "👽 Configurando Zsh, Oh My Zsh e plugins..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    OMZ_CUSTOM_PLUGINS="$HOME/.oh-my-zsh/custom/plugins"
    OMZ_CUSTOM_THEMES="$HOME/.oh-my-zsh/custom/themes"
    mkdir -p "$OMZ_CUSTOM_PLUGINS"
    mkdir -p "$OMZ_CUSTOM_THEMES"

    if [ ! -d "$OMZ_CUSTOM_PLUGINS/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$OMZ_CUSTOM_PLUGINS/zsh-autosuggestions"
    fi
    if [ ! -d "$OMZ_CUSTOM_PLUGINS/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$OMZ_CUSTOM_PLUGINS/zsh-syntax-highlighting"
    fi

    if [ ! -d "$OMZ_CUSTOM_THEMES/spaceship-prompt" ]; then
        git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$OMZ_CUSTOM_THEMES/spaceship-prompt" --depth=1
    fi
    if [ ! -d "$OMZ_CUSTOM_THEMES/powerlevel10k" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$OMZ_CUSTOM_THEMES/powerlevel10k"
    fi

    # if [ -f "./.zshrc" ]; then
    #     [ -f "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$HOME/.zshrc.omz-default-bak"
    #     cp "./.zshrc" "$HOME/.zshrc"
    # fi

    if [[ "$SHELL" != */zsh ]]; then
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
    echo "🚀 Iniciando setup do ambiente de desenvolvimento v17..."
    install_base_packages
    install_pyenv_and_python_versions
    install_nvm_and_nodejs
    install_aws_tools
    install_custom_themes
    add_custom_repos_and_install
    install_deb_packages
    install_extra_binaries
    install_flatpaks
    install_vscode_extensions
    install_nerd_fonts
    install_pipx_packages
    stow_dotfiles
    configure_apps
    configure_system
    configure_zsh
    cleanup

    echo "✅ Setup concluído com sucesso!"
    echo "---"
    echo "⚠️  CHECKLIST DE AÇÕES PÓS-INSTALAÇÃO ⚠️"
    echo ""
    echo "   1. REINICIE A SESSÃO: Faça logout/login (ou reinicie o computador) para aplicar todas as mudanças."
    echo ""
    echo "   2. CONFIGURE O TERMINAL: Abra o Hyper e mude a fonte para 'FiraCode Nerd Font Mono'."
    echo ""
    echo "   3. CONFIGURE O ZSH: Abra seu ~/.zshrc e verifique/adicione as linhas para pyenv, zoxide e plugins."
    echo ""
    echo "   4. TESTE O DOCKER: Abra um novo terminal e rode 'docker run hello-world'."
    echo ""
    echo "   5. INSTALE EXTENSÕES DO GNOME: Vá para https://extensions.gnome.org/ e instale 'Forge'."
    echo ""
    echo "   6. LOGINS E SINCRONIZAÇÃO: Faça login no Chrome/Brave, VS Code, e autentique suas CLIs (gh, az, aws)."
    echo ""
    echo "---"
    echo "💡 LEMBRETE DE FLUXO DE TRABALHO PYTHON COM PYENV 💡"
    echo ""
    echo "   # Para projetos novos (usando o Python global padrão, ex: 3.12.3):"
    echo "   cd meu-projeto-novo/"
    echo "   pipenv install # ou uv venv"
    echo ""
    echo "   # Para projetos legados (exigindo uma versão específica, ex: 3.10.13):"
    echo "   cd meu-projeto-legado/"
    echo "   pyenv local 3.10.13  # Isso cria o arquivo .python-version"
    echo "   pipenv install # ou uv venv (agora usará o Python 3.10)"
    echo "---"
    echo "💡 DICA NEOVIM: Para começar a configurar seu NeoVim, crie o arquivo ~/.config/nvim/init.lua"
}

main