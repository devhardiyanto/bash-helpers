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

PHP_VERSIONS=("7.4" "8.0" "8.1" "8.2" "8.3" "8.4")
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

source "$HOME/.nvm/nvm.sh"

for nv in "lts/*" "20" "22"; do
    if nvm ls "$nv" | grep -q "N/A"; then
        nvm install $nv || fail "Failed to install Node.js $nv"
        success "Node.js $nv installed"
    else
        skip "Node.js $nv already installed"
    fi
done

# ========== MySQL ==========
step "D. Install MySQL"
if dpkg -s mysql-server &>/dev/null; then
    skip "MySQL already installed"
else
    sudo apt install -y mysql-server || fail "Failed to install MySQL"
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY ''; FLUSH PRIVILEGES;"
    sudo sed -i 's/^bind-address\s*=.*/bind-address = 127.0.0.1/' /etc/mysql/mysql.conf.d/mysqld.cnf
    sudo systemctl restart mysql
    success "MySQL installed & root user tanpa sudo"
fi

# ========== PostgreSQL 14 & 16 ==========
step "E. Install PostgreSQL 14 & 16 (multi-version)"
PG_REPO_FILE="/etc/apt/sources.list.d/pgdg.list"
if [ ! -f "$PG_REPO_FILE" ]; then
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > $PG_REPO_FILE' || fail "Failed to add PostgreSQL repo"
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /usr/share/keyrings/postgresql.gpg
    sudo apt-key add /usr/share/keyrings/postgresql.gpg
    sudo apt update
else
    skip "PostgreSQL repo already added"
fi

for pgv in 14 16; do
    if dpkg -s postgresql-$pgv &>/dev/null; then
        skip "PostgreSQL $pgv already installed"
    else
        sudo apt install -y postgresql-$pgv postgresql-client-$pgv || fail "Failed to install PostgreSQL $pgv"
        sudo sed -i "s/^#*local\s\+all\s\+postgres\s\+peer/local all postgres trust/" /etc/postgresql/$pgv/main/pg_hba.conf
        sudo systemctl restart postgresql
        success "PostgreSQL $pgv installed & configured"
    fi
done

# Alias for PostgreSQL version switch
if ! grep -q "# PostgreSQL 14" ~/.bashrc; then
    echo "# PostgreSQL 14" >> ~/.bashrc
    echo "alias pg14='sudo systemctl stop postgresql@16-main; sudo systemctl start postgresql@14-main'" >> ~/.bashrc
    echo "# PostgreSQL 16" >> ~/.bashrc
    echo "alias pg16='sudo systemctl stop postgresql@14-main; sudo systemctl start postgresql@16-main'" >> ~/.bashrc
    success "PostgreSQL version switch alias added"
else
    skip "PostgreSQL version switch alias already in .bashrc"
fi

# ========== MongoDB ==========
step "F. Install MongoDB"

MONGO_VERSION=7.0
UBUNTU_CODENAME=$(lsb_release -cs)
MONGO_OK_DISTROS="jammy focal bullseye buster"
MONGO_REPO_DISTRO="$UBUNTU_CODENAME"

# Cek apakah codename support
if [[ "$MONGO_OK_DISTROS" == *"$UBUNTU_CODENAME"* ]]; then
    log "MongoDB repo tersedia untuk $UBUNTU_CODENAME"
elif [[ "$UBUNTU_CODENAME" == "noble" ]]; then
    log "MongoDB repo belum tersedia untuk noble, fallback ke jammy (22.04)"
    MONGO_REPO_DISTRO="jammy"
else
    fail "MongoDB repo belum tersedia untuk distro $UBUNTU_CODENAME. Lihat https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/"
fi

if dpkg -s mongodb-org &>/dev/null; then
    skip "MongoDB already installed"
else
    # Remove legacy keyring & repo if exist
    sudo rm -f /etc/apt/sources.list.d/mongodb-org-*.list
    sudo rm -f /usr/share/keyrings/mongodb-server-*.gpg

    curl -fsSL https://www.mongodb.org/static/pgp/server-${MONGO_VERSION}.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-${MONGO_VERSION}.gpg
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${MONGO_VERSION}.gpg ] https://repo.mongodb.org/apt/ubuntu ${MONGO_REPO_DISTRO}/mongodb-org/${MONGO_VERSION} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-${MONGO_VERSION}.list
    sudo apt update
    if sudo apt install -y mongodb-org; then
        sudo systemctl enable --now mongod || fail "Failed to start mongod"
        sudo usermod -aG $(whoami) mongodb || skip "Cannot add user to mongodb group (may not exist)"
        success "MongoDB installed"
    else
        fail "Failed to install MongoDB. Cek log di atas, atau install manual sesuai https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/"
    fi
fi

# ========== Summary ==========
echo " "
step "SUMMARY INSTALLED VERSIONS:"
php -v | head -n 1
node -v
npm -v
mysql --version
psql --version
mongod --version | head -n 1

log "=== Setup Selesai ==="
success "Semua environment berhasil diinstall"

echo -e "\n\e[1;33mNOTE:\e[0m"
echo "- Alias PHP switch: php74, php80, php81, php82, php83, php84"
echo "- Alias PostgreSQL switch: pg14, pg16"
echo "- Untuk update alias, jalankan: source ~/.bashrc"

exit 0
