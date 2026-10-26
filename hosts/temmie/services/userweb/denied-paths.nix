{ ... }:
{
  services.pvv-userweb.deniedDirectories = [
    # Version control

    "\\.git"
    "\\.hg"
    "\\.svn"
    "\\.ssh"
    "\\.bzr"
    "\\.venv"
    "\\.env"
    "\\.jj"
    "\\.pijul"
    "\\.sl"
    "_darcs"
    "CVS"
    "RCS"
    "SCCS"
    "BitKeeper"

    # Misc

    "\\.aws"
    "\\.azure"
    "\\.cargo"
    "\\.chef"
    "\\.circleci"
    "\\.claude"
    "\\.composer"
    "\\.continue"
    "\\.cursor"
    "\\.dbeaver"
    "\\.devcontainer"
    "\\.digitalocean"
    "\\.docker"
    "\\.gcp"
    "\\.gem"
    "\\.github"
    "\\.heroku"
    "\\.idea"
    "\\.ipython"
    "\\.jupyter"
    "\\.keys"
    "\\.kube"
    "\\.m2"
    "\\.netlify"
    "\\.npm"
    "\\.nuget"
    "\\.oci"
    "\\.op"
    "\\.prisma"
    "\\.putty"
    "\\.registry"
    "\\.streamlit"
    "\\.terraform"
    "\\.vercel"
    "\\.vscode"
    "\\.vscode-server"

    "\\.cache"
    "\\.config"
    "\\.gnupg"
    "\\.irssi"
    "\\.mozilla"
    "\\.password-store"
    "\\.purple"
    "\\.thunderbird"
    "\\.weechat"

    "vendor/htmlawed"
    "vendor/phpunit"

    "__pycache__"

    # Backup and temporary dirs

    "\\.Trash(-[0-9]+)?"

    ".*\\.bak"
    ".*\\.bak.*"
    ".*\\.bkp"
    ".*\\.bkp.*"
    ".*\\.backup"
    ".*\\.backup.*"
  ];

  services.pvv-userweb.deniedFiles = [
    # Version control

    # .git
    # .git-credentials
    # .gitignore
    # .gitmodules
    # .gitkeep
    # .gitattributes
    # .gitconfig
    # .gitlab-ci.yml
    ".git*"
    ".fslckout"
    "_FOSSIL_"

    # Logs

    "*.log"
    "error_log"

    # Modules and libraries

    "*.inc"
    "*.pm"

    # Configuration and history files

    ".*_history"
    ".zhistory"
    ".histfile"
    ".netrc"
    ".my.cnf"
    ".pypirc"
    ".s3cfg"
    ".fetchmailrc"
    ".muttrc"

    "Dockerfile"
    "docker-compose.y*ml"
    ".travis.yml"
    "composer.json"
    "composer.lock"
    "package.json"
    "web.config"
    "wp-config.txt"
    ".npmrc"

    # Keys and secrets

    ".env*"
    "*.env"

    "auth.json"
    "credentials"
    "*htpasswd*"
    ".pgpass"
    "secrets.json"
    "secrets.y*ml"

    "id_rsa"
    "id_dsa"
    "id_ecdsa"
    "id_ed25519"

    "*.pem"
    "*.key"
    "*.ppk"
    "*.p12"
    "*.pfx"
    "*.jks"
    "*.keystore"
    "*.kdbx"
    "*.ovpn"
    "*.tfstate"
    "*.tfvars"

    # Database files and SQL dumps/scripts

    "*.db"
    "*.db-journal"
    "*.db-shm"
    "*.db-wal"
    "*.sql"
    "*.sql.*"
    "*.sqlitedb"
    "*.sqlite"
    "*.sqlite3"
    "*.sqlite-journal"
    "*.sqlite-shm"
    "*.sqlite-wal"
    "*.sqlite3-journal"
    "*.sqlite3-shm"
    "*.sqlite3-wal"
    "*.mdb"
    "*.accdb"

    # Backup and temporary files

    "*.bak"
    "*.bak*"
    "*.bkp"
    "*.bkp*"
    "*.backup"
    "*.backup*"
    "*.back"
    "*.bk"

    "*.old"
    "*.orig"
    "*.save"
    "*.tmp"
    "*.rej"

    ".DS_Store"
    "*.swp"
    "*.swo"
    "*.swn"
    "*~"
    "#*#"

    "sess_*"
    ".nfs*"
    "core"
    "core.[0-9]*"

    # Lock files

    "*.lck"
    "*.lock"
    "LCK..*"
  ];
}
