#!/bin/bash

# Exit script on any error
set -e

echo "Updating system and installing dependencies..."
sudo apt update
sudo apt install -y curl xz-utils git

echo "Downloading and running Nix installer..."
curl -L https://nixos.org/nix/install | sh

echo "Adding Nix to the shell environment..."
# Source the Nix profile for the current shell session
. /home/$USER/.nix-profile/etc/profile.d/nix.sh

# Add to .bashrc for future sessions (or .zshrc if you use Zsh)
if [[ "$SHELL" == *"zsh"* ]]; then
    echo ". /home/$USER/.nix-profile/etc/profile.d/nix.sh" >> ~/.zshrc
elif [[ "$SHELL" == *"bash"* ]]; then
    echo ". /home/$USER/.nix-profile/etc/profile.d/nix.sh" >> ~/.bashrc
else
    echo "Shell not detected. You may need to manually source Nix in your shell configuration."
fi

echo "Installing Docker and Caddy using Nix configuration..."
if [[ ! -f default.nix ]]; then
    echo "default.nix file not found! Please create it in the same directory as this script."
    exit 1
fi

# Build and install the tools environment
nix-env -i -f default.nix

echo "Verifying installations..."
docker --version
caddy version

echo "Nix installation complete with Docker and Caddy installed globally."
