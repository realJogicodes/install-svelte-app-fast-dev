#!/bin/bash

: <<COMMENT
Design Specs for the installation script 
* check if dependencies are installed
  - operating system supported?
  - git?
  - node?
  - unzip?
* ask for the name of the project
* asks for folder to install the project in
  ? default folder: subfolder of current directory
  ? ask user if that folder is fine
  ? if not, ask for a new folder to use
* git clone the repository into the chosen folder with the project name under subfolder frontend
* get pocketbase
  ? get appropriate user system architecture for pocketbase download
  ? ask user if supported version or bleeding edge (latest)
  ? needs to be in appropriate sub-folder /pocketbase
  ? unzip it (ensure unzip is available on CLI)
  ? how would we handle this if not installed? install it?
* clone the repository and install svelte-app-fast
* navigate to appropriate folder
* install dependencies 
  ? npm install
COMMENT

# Version configuration
SUPPORTED_POCKETBASE_VERSION="0.24.1"
NVM_VERSION="v0.40.1"

echo "Installing 🚀 SvelteAppFast"
echo "This script will get you started with SvelteAppFast in no time!"
echo "There are some dependencies that need to be installed, but we'll take care of that for you if you haven't got them already."
read -p "Do you want to proceed? (y/n): " proceed
if [[ $proceed != "y" ]]; then
  echo "Installation cancelled."
  exit 1
fi

# Check for dependencies
echo "🧪 Checking for dependencies..."

# ! CHECK THE OPERATING SYSTEM
echo "🧪 Detecting operating system..."

# First check if running in WSL or Windows
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "Running in Windows Subsystem for 🐧 Linux (WSL)"
    PACKAGE_MANAGER="apt"
    INSTALL_CMD="sudo apt-get install"
    # Ensure package list is up to date in WSL
    sudo apt-get update
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OS" == "Windows_NT" ]]; then
    echo "🪟 Windows detected. This script requires Windows Subsystem for Linux (WSL)"
    echo "Installation options:"
    echo "1. Install WSL (recommended):"
    echo "   Open PowerShell as Administrator and run:"
    echo "   wsl --install"
    echo "After installing WSL, please run this script again from within WSL."
    exit 1
# detect macOS
elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "🍎 macOS detected"
    PACKAGE_MANAGER="brew"
    INSTALL_CMD="brew install"
# detect Linux distributions
elif [[ "$(uname -s)" == "Linux" ]]; then
    echo "🐧 Linux detected"
    if [ -f /etc/debian_version ]; then
        echo "Debian/Ubuntu based distribution detected"
        PACKAGE_MANAGER="apt"
        INSTALL_CMD="sudo apt-get install"
    elif [ -f /etc/fedora-release ]; then
        echo "Fedora based distribution detected"
        PACKAGE_MANAGER="dnf"
        INSTALL_CMD="sudo dnf install"
    elif [ -f /etc/arch-release ]; then
        echo "Arch based distribution detected"
        PACKAGE_MANAGER="pacman"
        INSTALL_CMD="sudo pacman -S"
    else
        echo "Unknown Linux distribution"
        echo "This script may work or may not work. Proceed with caution."
        echo "Please ensure you have the following packages installed:"
        echo "- Git"
        echo "- Node.js v22 or higher"
        echo "- unzip"
        read -p "Do you want to proceed? (y/n): " proceed
        if [[ $proceed != "y" ]]; then
            echo "Installation cancelled."
            exit 1
        fi
    fi
else
    echo "❌ Unsupported operating system: ${OSTYPE}. This script only supports macOS, Linux and Windows via WSL."
    exit 1
fi

# ! CHECK FOR DEPENDENCIES

# Dependency unzip is needed for pocketbase
if ! command -v unzip &> /dev/null; then
    echo "❌ unzip could not be found, but is needed to install pocketbase."
    echo "Please install it using: ${INSTALL_CMD} unzip"
    exit 1
fi

# Dependency git is needed for cloning the repository
if ! command -v git &> /dev/null; then
    echo "❌ git could not be found, but is needed to clone the repository."
    echo "Please install it using: ${INSTALL_CMD} git"
    exit 1
fi

# Either cURL or wget is needed for downloading the PocketBase binary and/or nvm
if command -v curl &> /dev/null; then
    DOWNLOAD_CMD="curl -o-"
elif command -v wget &> /dev/null; then
    DOWNLOAD_CMD="wget -qO-"
else
    echo "❌ Neither cURL nor wget found. Please install either cURL or wget."
    exit 1
fi

# Dependency Node.js is needed for the app
# install it via nvm if not installed
if ! command -v node &> /dev/null; then
    read -p "❌ Node.js is not installed. Do you want to install it via node version manager? (y/n): " install_node
    if [[ $install_node == "y" ]]; then
        echo "✅ Installing nvm..."
        $DOWNLOAD_CMD https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash
        
        # Load nvm for current session
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        # Install latest LTS version of Node.js
        echo "✅ Installing Node.js LTS version..."
        nvm install --lts
        echo "✅ Enabling Node.js LTS version..."
        nvm use --lts
    else
        echo "❌ Node.js is required. Exiting."
        exit 1
    fi
fi

# Check Node.js version after potential nvm installation
NODE_VERSION=$(node -v || echo "")
if [[ -z "$NODE_VERSION" ]]; then
    echo "❌ Failed to get Node.js version. Please ensure Node.js is properly installed."
    exit 1
fi

# Extract version number and compare
NODE_VERSION_NUM=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
if [[ "$NODE_VERSION_NUM" -lt 22 ]]; then
    echo "❌ Node.js version 22 or higher is required"
    echo "Current version: $NODE_VERSION"
    echo
    echo "To upgrade Node.js:"
    if command -v nvm &> /dev/null; then
        echo "Since you have nvm installed, run:"
        echo "  nvm install 22"
        echo "  nvm use 22"
    else
        echo "Visit: https://nodejs.org/en/download/"
        echo "Or use a version manager like nvm: https://github.com/nvm-sh/nvm"
    fi
    exit 1
fi

echo "✅ Node.js version $NODE_VERSION detected"

# Function to get system architecture
get_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "armv7" ;;
        ppc64le) echo "ppc64le" ;;
        s390x) echo "s390x" ;;
        *) echo "unsupported" ;;
    esac
}

# Function to get system OS
get_os() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "linux"  # WSL uses Linux binaries
    else
        case "$(uname -s)" in
            Darwin*) echo "darwin" ;;
            Linux*) echo "linux" ;;
            MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
            *) echo "unsupported" ;;
        esac
    fi
}

# Function to get latest PocketBase version from GitHub
get_latest_version() {
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/pocketbase/pocketbase/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
    if [[ -z "$latest_version" ]]; then
        echo ""
    else
        echo "$latest_version"
    fi
}

# Function to compare version numbers
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# Prompt for project name and installation folder
read -p "🧐 Enter a name for your new project: " project_name
read -p "📂 Choose  an installation folder (default: ./${project_name}): " install_folder
install_folder=${install_folder:-./${project_name}}

# Confirm installation folder
read -p "❓ Install in ${install_folder}? (y/n): " confirm_folder
if [[ $confirm_folder != "y" ]]; then
    read -p "📂 Enter a new installation folder: " install_folder
fi

# Create installation directory if it doesn't exist
if [ ! -d "$install_folder" ]; then
    mkdir -p "$install_folder" || {
        echo "❌ Failed to create installation directory: $install_folder"
        exit 1
    }
fi

# Navigate to installation directory
cd "$install_folder" || {
    echo "❌ Failed to navigate to installation directory: $install_folder"
    exit 1
}

# Clone the repository
echo "🧬 Cloning SvelteAppFast repository..."
if [ -d "frontend" ]; then
    echo "🚨 The 'frontend' directory already exists"
    read -p "🗑️ Do you want to remove it and clone again? (y/n): " remove_frontend
    if [[ $remove_frontend == "y" ]]; then
        rm -rf frontend
    else
        echo "❌ Please remove or rename the existing 'frontend' directory and try again"
        exit 1
    fi
fi

git clone https://github.com/realJogicodes/svelte-app-fast.git frontend || {
    echo "❌ Failed to clone repository"
    exit 1
}

# Set up PocketBase
echo "💽 Setting up PocketBase..."
if [ ! -d "pocketbase" ]; then
    mkdir -p pocketbase || {
        echo "❌ Failed to create pocketbase directory"
        exit 1
    }
fi

cd pocketbase || {
    echo "❌ Failed to navigate to pocketbase directory"
    exit 1
} 

# Download and install PocketBase
OS=$(get_os)
ARCH=$(get_arch)

if [[ "$OS" == "unsupported" ]] || [[ "$ARCH" == "unsupported" ]]; then
    echo "❌ Error: Unsupported operating system or architecture"
    echo "❌ OS: $(uname -s), Architecture: $(uname -m)"
    exit 1
fi

POCKETBASE_FILE="pocketbase_${SUPPORTED_POCKETBASE_VERSION}_${OS}_${ARCH}.zip"
POCKETBASE_URL="https://github.com/pocketbase/pocketbase/releases/download/v${SUPPORTED_POCKETBASE_VERSION}/${POCKETBASE_FILE}"

echo "📥 Downloading PocketBase ${SUPPORTED_POCKETBASE_VERSION}..."
if [[ "$DOWNLOAD_CMD" == "curl -o-" ]]; then
    curl -L -o "$POCKETBASE_FILE" "$POCKETBASE_URL" || {
        echo "❌ Failed to download PocketBase"
        exit 1
    }
else
    wget -O "$POCKETBASE_FILE" "$POCKETBASE_URL" || {
        echo "❌ Failed to download PocketBase"
        exit 1
    }
fi

echo "📦 Extracting PocketBase..."
unzip -o "$POCKETBASE_FILE" || {
    echo "❌ Failed to extract PocketBase"
    exit 1
}
rm "$POCKETBASE_FILE"

# Make PocketBase executable
chmod +x pocketbase || {
    echo "❌ Failed to make PocketBase executable"
    exit 1
}

# Install frontend dependencies
cd ../frontend || {
    echo "❌ Failed to navigate to frontend directory"
    exit 1
}

echo "📥 Installing frontend dependencies..."
npm install || {
    echo "❌ Failed to install frontend dependencies"
    echo "👉 Please try running 'npm install' manually"
    exit 1
}

echo "🎉 Installation complete! Your SvelteAppFast project is ready 🎉"
echo
echo "To start the development server:"
echo "1. Start PocketBase in the terminal:"
echo "   cd $install_folder/pocketbase && ./pocketbase serve"
echo
echo "2. In a second terminal window or tab, start the frontend:"
echo "   cd $install_folder/frontend && npm run dev"
echo "🚀🚀🚀 Happy Hacking 🚀🚀🚀"
