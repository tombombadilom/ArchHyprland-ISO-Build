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
export ARCHLIVE_PATH="/home/tom/archlive"
export ARCHISO_PATH="/home/tom/Documents/archiso"
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


# Check if $ARCHLIVE_PATH exists
if [ -d "$ARCHLIVE_PATH" ]; then
    # Prompt the user to ask if they want to erase it
    read -p "The directory "$ARCHLIVE_PATH" already exists. Do you want to erase it? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            # User wants to erase: remove the directory recursively
            sudo rm -rf "$ARCHLIVE_PATH"
            echo "Directory "$ARCHLIVE_PATH" has been removed."
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
    yay -Rns $(yay -Qtdq) --noconfirm 
    yay -Sc --noconfirm
}
copy_config_files() {
    # Copy the necessary configuration files
    sudo cp "/etc/pacman.conf" "$ARCHLIVE_PATH/pacman.conf"
    # Extraction des configurations de Calamares dans /etc
    sudo tar -xzf "$ARCHISO_PATH/calam/etc-calamares.tar.gz" -C "$ARCHLIVE_PATH/airootfs/etc"

    # Extraction des fichiers Calamares dans /usr
    sudo tar -xzf "$ARCHISO_PATH/calam-archives/usr_calamares.tar.gz" -C "$ARCHLIVE_PATH/airootfs/usr"

    # Extraction des icônes dans /usr
    sudo tar -xzf "$ARCHISO_PATH/calam-archives/usr_icons.tar.gz" -C "$ARCHLIVE_PATH/airootfs/usr"
}

# Function: Backup configurations (customize paths as needed)
backup_configs() {
    # Paths to exclude
    excludes=(
    "$HOME/.config/variety"
    "$HOME/.local/share/TelegramDesktop/tdata/user_data"
    "$HOME/.local/share"
    "$HOME/.config/Typora"
    "$HOME/.config/evolution"
    "$HOME/.config/Code - OSS"
    "$HOME/.config/BraveSoftware"
    )
   # Create an array of paths to be excluded from tar
   IGNORE=()
   for exclude in "${excludes[@]}"; do
       IGNORE+=(--exclude="${exclude}")
   done
   
   ## Create custom scripts directory and populate it
   mkdir -p "$SCRIPTS_PATH"
   echo '#!/usr/bin/env bash
   yay -Sy --noconfirm git
   ...
   ' > "$SCRIPTS_PATH/customize.sh"
   chmod +x "$SCRIPTS_PATH/customize.sh"
   
    mkdir -p "$LIVEUSER_HOME"
    echo "exec calamares" > "$LIVEUSER_HOME/.xinitrc"
    # Ensure the directories exists and have the correct permissions
    mkdir -p "$CUSTOM_ARCHIVES_PATH"
    sudo chmod 755 "$CUSTOM_ARCHIVES_PATH"
    sudo find "$CUSTOM_ARCHIVES_PATH" -type f -exec chmod 644 {} \;

    # Ensure the destination directories exist
    mkdir -p "${ARCHLIVE_PATH}/etc" || { echo "Failed to create directory structure at ${ARCHLIVE_PATH}/etc"; exit 1; }

    # Check if the environment variables are correctly set by verifying they are not empty
    if [ -z "${ARCHISO_PATH}" ] || [ -z "${ARCHLIVE_PATH}" ]; then
        echo "Environment variables DOCUMENTS_PATH and/or ARCHLIVE_PATH are not set properly."
        exit 1
    fi

    # Check if the source file exists
    if [ ! -f "${ARCHISO_PATH}/os-release" ]; then
        echo "The source file ${ARCHISO_PATH}/os-release does not exist."
        exit 1
    fi

    # Perform the copy, optionally using sudo for permissions issues
    cp "${ARCHISO_PATH}/os-release" "${ARCHLIVE_PATH}/etc/os-release" || {
        echo "Failed to copy the file to ${ARCHLIVE_PATH}/etc/os-release"
        exit 1
    }
     # Check if the source file exists
    if [ ! -f "${ARCHISO_PATH}/etc" ]; then
        echo "The source file ${ARCHISO_PATH}/$LOCAL_REPO_NAME/airootfs/etc does not exist."
        mkdir -p "${ARCHISO_PATH}/$LOCAL_REPO_NAME/airootfs/etc"
        echo "Directory ${ARCHISO_PATH}/$LOCAL_REPO_NAME/airootfs/etc created"
    fi
    
    # Check if the source file exists
    if [ ! -f "${ARCHISO_PATH}/$LOCAL_REPO_NAME/airootfs/etc/iptables" ]; then
        echo "The source file ${ARCHISO_PATH}/$LOCAL_REPO_NAME/airootfs/etc/iptables does not exist."
        sudo cp -r /etc/iptables "$ARCHLIVE_PATH/$LOCAL_REPO_NAME/airootfs/etc"
        sudo chown -R $USER:$USER "$ARCHLIVE_PATH/$LOCAL_REPO_NAME"
    fi

    # Perform the copy, optionally using sudo for permissions issues
    cp "${ARCHISO_PATH}/os-release" "${ARCHLIVE_PATH}/$LOCAL_REPO_NAME/airootfs/etc/os-release" || {
        echo "Failed to copy the file to ${ARCHLIVE_PATH}/$LOCAL_REPO_NAME/airootfs/etc/os-release"
        exit 1
    }
    echo "os-release copied successfully."

   
    # Add the packages list to the custom archiso
    yay -Qqe > "$ARCHLIVE_PATH/$LOCAL_REPO_NAME/airootfs/packages.x86_64"
    cp "$ARCHLIVE_PATH/packages.x86_64" "$ARCHLIVE_PATH/$LOCAL_REPO_NAME/airootfs/"

    # Add code here to backup etc and user configs...
    sudo tar -czvf "$ARCHLIVE_PATH/etc_backup.tar.gz" -C /etc/ --exclude-caches-all --exclude-vcs
    tar -czvf "$ARCHLIVE_PATH/user_configs.tar.gz" "$HOME/.config/" --exclude={"$HOME/.config/variety","$HOME/.local/share/TelegramDesktop/tdata/user_data"}

}

clean_iptables(){
    sudo mv ${ARCHLIVE_PATH}/$LOCAL_REPO_NAME/airootfs/etc/iptables/empty.rules{,.bak}
    sudo mv ${ARCHLIVE_PATH}/$LOCAL_REPO_NAME/airootfs/etc/iptables/simple_firewall.rules{,.bak}
    sudo pacman -Syu --overwrite ${ARCHLIVE_PATH}/$LOCAL_REPO_NAME/airootfs/etc/iptables/*
}
# Step 1 clean system 
clean_system

# Step 2 install required packages
install_missing_packages

# Step 3: Copy configuration files
copy_config_files

# Step 4: Create and configure local repository
create_local_repository

# Step 5 clean unwanted firewall iptables
clean_iptables


# Step 6: Build ISO (make sure to customize mkarchiso command according to your needs)
sudo mkarchiso -v -w "$ARCHLIVE_PATH" -o "$ARCHISO_OUT" "$ARCHLIVE_PATH"