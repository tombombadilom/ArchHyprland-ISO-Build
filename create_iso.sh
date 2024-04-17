#!/usr/bin/env bash
# """
# This shell script code snippet is intended to build an archiso ISO
# and performs the following tasks:
# 1. Defines constants for various paths and packages.
# 2. Checks and installs packages if they are missing.
# 3. Copies necessary configuration files.
# 4. Cleans the system of unnecessary packages.
# 5. Adds the packages list to the custom archiso.
# 6. Backs up etc and user configs, excluding specific paths.
# 7. Creates custom scripts directory and populates it.
# 8. Ensures the destination directories exist.
# 9. Checks if environment variables are set properly.
# 10. Checks if the source file exists and performs the copy.
# 11. Copies calamares config files.
# 12. Checks for required packages in the package list.
# 13. Unzips and copies calamares files in archlive.
# 14. Finds and replaces in every file of the archlive path.
# 15. Copies pacman.conf file.
# 16. Defines an array of packages to be installed.
# 17. Creates a local repository directory and installs packages from the AUR.
# 18. Adds the local repository to pacman.conf.
# 19. Checks if mkarchiso is currently running.
# 20. Optionally, checks for a successful build by examining the last modified ISO file.
# """

# Define constants
export ARCHLIVE_PATH="$HOME/archlive"
export ARCHISO_PATH="$HOME/Documents/archiso"
export PACKAGES_TO_INSTALL=(archiso calamares syslinux memtest86+ memtest86+-efi)

CUSTOM_ARCHIVES_PATH="$ARCHLIVE_PATH/airootfs/root/custom_archives"
SCRIPTS_PATH="$ARCHLIVE_PATH/airootfs/root/scripts"
LIVEUSER_HOME="$ARCHLIVE_PATH/airootfs/home/liveuser"
ARCHISO_OUT="$ARCHISO_PATH/ISO"
PACMAN_CONF_PATH="$ARCHLIVE_PATH/pacman.conf"
ARCHLIVE_SOURCE="/usr/share/archiso/configs/releng/"
# Define local repository details
LOCAL_REPO_NAME="x86_64"
LOCAL_REPO_PATH="$HOME/$LOCAL_REPO_NAME"

git clone git@gitlab.archlinux.org:archlinux/archiso.git
cd archiso
# Check if $ARCHLIVE_PATH exists
if [ -d "$ARCHLIVE_PATH" ]; then
    # Prompt the user to ask if they want to erase it
    read -p "The directory $ARCHLIVE_PATH already exists. Do you want to erase it? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            # User wants to erase: remove the directory recursively
            sudo rm -rf "$ARCHLIVE_PATH"
            echo "Directory $ARCHLIVE_PATH has been removed."
            # Create the directory with necessary parents
            mkdir -p "$ARCHLIVE_PATH"
            sudo rsync -av "$ARCHLIVE_SOURCE" "$ARCHLIVE_PATH"
 
            sudo rm -rf "$ARCHISO_OUT"
            mkdir -p "$ARCHISO_OUT"
            echo "$ARCHLIVE_PATH directory is created."
            ;;
        *)
            # User does not want to erase or response is invalid: keep the existing directory and continue
            echo "Keeping the existing directory and continuing with the script."
            ;;
    esac
fi

# Function: Install missing packages
install_missing_packages() {
    sudo pacman -Sy --noconfirm --needed "${PACKAGES_TO_INSTALL[@]}"
}

# Function: Create local repository and add to pacman.conf
# Adjusted Function: Create local repository and add to pacman.conf
create_local_repository() {
    mkdir -p "$LOCAL_REPO_PATH"
    chown "$USER":"$USER" "$LOCAL_REPO_PATH"
    # Ensure the DB file exists or create it
    touch "$LOCAL_REPO_PATH/x86_64.db"  # Assuming your DB is named like this

    if ! grep -q "\[$LOCAL_REPO_NAME\]" "$PACMAN_CONF_PATH"; then
        echo "[$LOCAL_REPO_NAME]" | sudo tee -a "$PACMAN_CONF_PATH"
        echo "SigLevel = Optional TrustAll" | sudo tee -a "$PACMAN_CONF_PATH"
        echo "Server = file://$LOCAL_REPO_PATH" | sudo tee -a "$PACMAN_CONF_PATH"
    fi
}


# Function: Clean system of unnecessary packages (use with caution!)
clean_system() {
    yay -Rns "$(yay -Qtdq)" --noconfirm 
    yay -Sc --noconfirm
}
