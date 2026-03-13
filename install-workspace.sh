#!/bin/bash

set -e  # stop script kalau ada error (fail fast)

LOGFILE="install_dev_env.log"
touch $LOGFILE

log() {
    echo -e "\e[1;34m$1\e[0m"
    echo "[`date`] $1" >> $LOGFILE
}

success() {
    echo -e "\e[1;32m[SUCCESS]\e[0m $1"
    echo "[SUCCESS] $1" >> $LOGFILE
}

fail() {
    echo -e "\e[1;31m[FAILED]\e[0m $1"
    echo "[FAILED] $1" >> $LOGFILE
    exit 1
}

skip() {
    echo -e "\e[1;33m[SKIP]\e[0m $1"
    echo "[SKIP] $1" >> $LOGFILE
}

step() {
    log "=== $1 ==="
}

# ========== General Tools ==========
step "A. Update package index & install tools"
GENERAL_PKGS="git curl wget unzip build-essential nano vim software-properties-common lsb-release ca-certificates apt-transport-https gnupg2"
for pkg in $GENERAL_PKGS; do
    if dpkg -s $pkg &>/dev/null; then
        skip "$pkg already installed"
    else
        sudo apt install -y $pkg || fail "Failed to install $pkg"
        success "$pkg installed"
    fi
done

# ========== PHP & Extensions ==========
step "B. Install PHP Multi Version + Extensions"
if ! grep -q "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    sudo add-apt-repository ppa:ondrej/php -y || fail "Failed to add PHP repo"
    sudo apt update
else
    skip "Ondrej PHP repo already added"
fi

PHP_VERSIONS=("8.0" "8.1" "8.2" "8.3" "8.4" "8.5")
PHP_MODULES=(cli fpm dom common mysql zip gd mbstring curl xml bcmath tokenizer xmlrpc pgsql)

for ver in "${PHP_VERSIONS[@]}"; do
    if dpkg -s php$ver &>/dev/null; then
        skip "PHP $ver already installed"
    else
        sudo apt install -y php$ver libapache2-mod-php$ver || fail "Failed to install php$ver"
        EXTENSIONS=""
        for mod in "${PHP_MODULES[@]}"; do
            EXTENSIONS="$EXTENSIONS php$ver-$mod"
        done
        sudo apt install -y $EXTENSIONS || fail "Failed to install PHP $ver extensions"
        success "PHP $ver & extensions installed"
    fi
done

# Alias php version switcher
if ! grep -q "# PHP Switcher Alias" ~/.bashrc; then
    echo "# PHP Switcher Alias" >> ~/.bashrc
    for ver in "${PHP_VERSIONS[@]}"; do
        echo "alias php${ver//./}='sudo update-alternatives --set php /usr/bin/php$ver && php -v'" >> ~/.bashrc
    done
    success "PHP switcher alias added"
else
    skip "PHP switcher alias already in .bashrc"
fi

# ========== NVM & Node.js ==========
step "C. Install NVM, Node.js (LTS, 20, 22)"
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    skip "NVM already installed"
else
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash || fail "Failed to install NVM"
    source "$HOME/.nvm/nvm.sh"
    success "NVM installed"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

for nv in "lts/*" "20" "22"; do
    if nvm ls "$nv" | grep -q "N/A"; then
        nvm install $nv || fail "Failed to install Node.js $nv"
        success "Node.js $nv installed"
    else
        skip "Node.js $nv already installed"
    fi
done

# ========== Go (Golang) ==========
step "D. Install Go (Golang)"
GO_VERSION="1.22.1" # Bisa diubah kalau ada versi yang lebih baru
if command -v go &> /dev/null; then
    skip "Go already installed"
else
    wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -O /tmp/go.tar.gz || fail "Failed to download Go"
    sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf /tmp/go.tar.gz || fail "Failed to extract Go"
    
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
    fi
    success "Go $GO_VERSION installed"
fi

# ========== Summary ==========
echo " "
step "SUMMARY INSTALLED VERSIONS:"
php -v | head -n 1
node -v
npm -v
/usr/local/go/bin/go version

log "=== Setup Workspace Selesai ==="
success "Lingkungan Coding berhasil diinstall murni tanpa membebani Docker!"

echo -e "\n\e[1;33mNOTE:\e[0m"
echo "- Alias PHP switch: php80, php81, php82, php83, php84"
echo "- Silakan jalankan 'source ~/.bashrc' setelah ini agar NVM dan Go terbaca."
exit 0
