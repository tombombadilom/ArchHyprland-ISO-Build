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

# Define local repository details
LOCAL_REPO_NAME="x86_64"
LOCAL_REPO_PATH="$HOME/$LOCAL_REPO_NAME"

# Function: Install missing packages
install_missing_packages() {
    sudo pacman -Sy --noconfirm --needed "${PACKAGES_TO_INSTALL[@]}"
}
# Function: Create local repository and add to pacman.conf
create_local_repository() {
    mkdir -p "$LOCAL_REPO_PATH"
    chown "$USER":"$USER" "$LOCAL_REPO_PATH"

    # Ajouter le dépôt local au pacman.conf de l'archiso
    if ! grep -q "^\[$local_repo_name\]" "$ARCHLIVE_PATH/pacman.conf"; then
        echo "Adding local repository to pacman.conf"
        sudo tee -a "$ARCHLIVE_PATH/pacman.conf" > /dev/null <<EOL
[$local_repo_name]
SigLevel = Optional TrustAll
Server = file://$local_repo_path
EOL
    fi
}

# Function: Clean system of unnecessary packages (optional, use with caution!)
clean_system() {
    yay -Rns $(yay -Qtdq) --noconfirm 
    yay -Sc --noconfirm
}
copy_config_files() {
    # Copy the necessary configuration files
    cp -r /usr/share/archiso/configs/releng/* "$ARCHLIVE_PATH"
    sudo cp /etc/pacman.conf $ARCHLIVE_PATH/pacman.conf
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
    # Create an array of path to be excluded from tar
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
    yay -Qqe > "$ARCHLIVE_PATH/packages.x86_64"
    cp "$ARCHLIVE_PATH/packages.x86_64" "$ARCHLIVE_PATH/$LOCAL_REPO_NAME/airootfs/"

    # Add code here to backup etc and user configs...
    sudo tar -czvf "$ARCHLIVE_PATH/etc_backup.tar.gz" -C /etc/ --exclude-caches-all --exclude-vcs
    tar -czvf "$ARCHLIVE_PATH/user_configs.tar.gz" "$HOME/.config/" --exclude={"$HOME/.config/variety","$HOME/.local/share/TelegramDesktop/tdata/user_data"}

}

# Function: Create local repository and add to pacman.conf
create_local_repository() {
    mkdir -p "$LOCAL_REPO_PATH"
    chown "$USER":"$USER" "$LOCAL_REPO_PATH"

    if ! grep -q "\[$LOCAL_REPO_NAME\]" "$PACMAN_CONF_PATH"; then
        cat <<EOF | sudo tee -a "$PACMAN_CONF_PATH"
[$LOCAL_REPO_NAME]
SigLevel = Optional TrustAll
Server = file://$LOCAL_REPO_PATH
EOF
    fi
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
mkdir -p $ARCHISO_OUT

# Step 6: Build ISO (make sure to customize mkarchiso command according to your needs)
sudo mkarchiso -v -w "$ARCHLIVE_PATH" -o "$ARCHISO_OUT" "$ARCHLIVE_PATH"


# Define the path to the profile's package list
# package_list="$ARCHLIVE_PATH/packages.x86_64"
# # Packages to check for
# packages=("syslinux" "memtest86+" "memtest86+-efi")


# # Function to check if a given package is in the package list
# check_package() {
#     local package=$1
#     if grep -Fxq "$package" "$package_list"; then
#         echo -e "\e[32mFOUND: $package\e[0m"
#     else
#         echo -e "\e[31mMISSING: $package\e[0m"
#     fi
# }

# # Check if each package is present in the package list
# echo "Checking for required packages in the package list..."
# for package in "${packages[@]}"; do
#     check_package "$package"
# done

# # unzip and copy calamares files in archlive 
# tar -xzvf  $ARCHISO_PATH/calam/etc-calamares.tar.gz $ARCHLIVE_PATH/airootfs/etc
# tar -xzvf  $ARCHISO_PATH/calam-archives/usr_calamares.tar.gz $ARCHLIVE_PATH/airootfs/usr
# tar -xzvf  $ARCHISO_PATH/calam-archives/usr_icons.tar.gz $ARCHLIVE_PATH/airootfs/usr

# find and replace in every files of the $ARCHLIVE_PATH parch by arch 
#find "$ARCHLIVE_PATH" -type f -exec sed -i 's/parch/arch/g' {} +

# sudo cp /etc/pacman.conf $ARCHLIVE_PATH/pacman.conf

# declare -a packages=(
#     "adw-gtk3-git"
#     "adwaita-qt5-git"
#     "adwaita-qt6-git"
#     "anyrun-git"
#     "blackbox-terminal"
#     "brave-bin"
#     "calamares"
#     "extension-manager"
#     "glpaper-hg"
#     "gnome-arch"
#     "gojq"
#     "gradience-git"
#     "hack-nerd-fonts"
#     "hypridle-git"
#     "hyprland-git"
#     "hyprlock-git"
#     "hyprpicker-git"
#     "hyprshade"
#     "hyprshot"
#     "jan-bin"
#     "neofetch-git"
#     "nwg-look-bin"
#     "arch-branding"
#     "arch-emoji-ios"
#     "arch-gdm-config"
#     "arch-gnome-backgrounds"
#     "arch-grub"
#     "arch-pacman"
#     "arch-pantheon"
#     "arch-plymouth"
#     "archlinux-quickstart"
#     "paru"
#     "python-materialyoucolor-git"
#     "qmplay2"
#     "swww"
#     "text-engine"
#     "ttf-material-symbols-variable-git"
#     "ttf-readex-pro"
#     "typora"
#     "vazirmatn-fonts"
#     "wlogout"
#     "xdg-desktop-portal-hyprland-git"
#     "yay"
# )

# # Définir le chemin de ton répertoire local pour archiso
# local_repo_path="$ARCHLIVE_PATH/airootfs/root/x86_64"

# # Création du répertoire s'il n'existe pas
# sudo mkdir -p $local_repo_path
# sudo chown -R $USER:$USER $local_repo_path
# # Log file pour suivre le progrès
# progress_log="$ARCHLIVE_PATH/install_progress.log"

# # Vérifier où l'installation s'est arrêtée la dernière fois
# if [[ -f "$progress_log" ]]; then
#     readarray -t installed_packages < "$progress_log"
# else
#     installed_packages=()
# fi

# # Vérifier les packages déjà téléchargés dans le répertoire local_repo_path et marquer comme installés
# for package in "${packages[@]}"; do
#     tarball_name=$(find "$local_repo_path" -name "${package}*.pkg.tar.gz")
#     if [[ -n $tarball_name ]]; then
#         # Package déjà téléchargé, le marquer comme installé
#         if ! [[ " ${installed_packages[*]} " =~ " ${package} " ]]; then
#             installed_packages+=("$package")
#             echo "$package" >> "$progress_log"
#         fi
#     fi
# done

# # Fonction pour vérifier si un paquet a déjà été installé
# # Function to check if a package is already installed in the local repo
# package_installed() {
#     grep -Fxq "$1" "$progress_log" && return 0 || return 1
# }

# # Ensure local repo directory exists
# mkdir -p "$local_repo_path"

# # Ensure progress log file exists
# touch "$progress_log"

# # Loop to clone, build, and copy each package
# for pkg in "${packages[@]}"; do
#     if package_installed "$pkg"; then
#         echo "Le paquet $pkg est déjà installé. Passage au suivant."
#         continue
#     fi
    
#     echo "Traitement du paquet: $pkg"
    
#     # Clone the AUR repository
#     if ! git clone "https://aur.archlinux.org/$pkg.git"; then
#         echo "Erreur lors du clonage de $pkg"
#         exit 1
#     fi

#     # Move into the repository directory
#     cd "$pkg" || exit

#     # Build the package
#     if ! makepkg -sci --noconfirm; then
#         echo "Échec de la construction du paquet $pkg"
#         exit 1
#     fi
    
#     # Copy the package files to the local repository path
#     if ! cp *.pkg.tar.zst "$local_repo_path"; then
#         echo "Échec de la copie du paquet $pkg vers $local_repo_path"
#         exit 1
#     fi
#     # Add it to your local repository
#     repo-add "$local_repo/$pkg.db.tar.gz" *.pkg.tar.zst

#     # Cleanup
#     cd .. || exit
#     rm -rf "$pkg"

#    # Add the package to the list of installed packages in the progress log
#     echo "$pkg" >> "$progress_log"

#     echo "Le paquet $pkg a été ajouté au répertoire local avec succès."
# done

# echo "Tous les paquets ont été traités et ajoutés au répertoire local."
# Define local repository details
# local_repo_name='x86_64'

# # Define the path to the archiso profile's pacman.conf
# ARCHISO_PACMAN_CONF="$ARCHLIVE_PATH/pacman.conf"

# # Function to extract and append repositories to archiso pacman.conf
# append_repositories() {
#     # Use a temporary file to store new entries before appending them
#     local temp_conf="$(mktemp)"
    
#     # Read main pacman.conf and included files within /etc/pacman.d/* (if they exist)
#     for file in /etc/pacman.conf /etc/pacman.d/*; do
#         if [[ -f $file ]]; then
#             while IFS= read -r line || [[ -n "$line" ]]; do
#                 # Check if the line contains a repository definition
#                 if [[ "$line" =~ ^\[* ]]; then
#                     # Extracting repository name
#                     repo_name=$(echo $line | sed 's/\[\(.*\)\]/\1/')
#                     # Avoid adding duplicate entries
#                     if ! grep -q "^\[$repo_name\]" "$ARCHISO_PACMAN_CONF"; then
#                         # Append the repository name to the temp_conf
#                         echo "$line" >> "$temp_conf"
#                         # Read the next line for the server or include directive
#                         read -r next_line
#                         echo "$next_line" >> "$temp_conf"
#                     fi
#                 fi
#             done < "$file"
#         fi
#     done
    
#     if [ -s "$temp_conf" ]; then
#         # If the temp_conf file has content, append it to ARCHISO_PACMAN_CONF with sudo
#         sudo bash -c "cat '$temp_conf' >> '$ARCHISO_PACMAN_CONF'"
#     fi

#     # Remove the temporary file
#     rm "$temp_conf"
# }

# # Backup the original archiso pacman.conf file using sudo
# sudo cp "$ARCHISO_PACMAN_CONF" "${ARCHISO_PACMAN_CONF}.bak"

# # Call the function to append repositories
# append_repositories

# echo "Repositories have been appended to your archiso pacman.conf."

# # Add local repository to pacman.conf if it's not already there
# if ! grep -q "^\[$local_repo_name\]" "$ARCHLIVE_PATH/pacman.conf"; then
#     echo "Adding local repository to pacman.conf"
#     sudo tee -a "$ARCHLIVE_PATH/pacman.conf" > /dev/null <<EOL

# [$local_repo_name]
# SigLevel = Optional TrustAll
# Server = file://$local_repo_path
# EOL
# fi

# # Check if mkarchiso is currently running
# if pgrep -x "mkarchiso" > /dev/null; then
#     echo -e "\e[33mThe 'mkarchiso' process is currently running...\e[0m"
# else
#     echo "The 'mkarchiso' process is not currently running."

#     # Optionally, check for a successful build by examining the last modified ISO file
#     iso_files=($(find $ARCHISO_OUT -maxdepth 1 -name "*.iso" -type f -printf '%T+ %p\n' | sort -r))
#     if [ "${#iso_files[@]}" -gt 0 ]; then
#         # The most recently modified ISO file will be at the top
#         latest_iso=${iso_files[0]##* }
#         echo -e "\e[32mThe latest ISO built was on ${latest_iso}\e[0m"
#     else
#         echo -e "\e[31mNo ISO files found in output directory.\e[0m"
#         # Build the ISO
#         # Make sure both directories exist or mkarchiso will give an error
#         mkdir -p "$ARCHLIVE_PATH"
#         mkdir -p "$ARCHISO_OUT"
#         sudo mkarchiso -v -w "$ARCHLIVE_PATH" -o "$ARCHISO_OUT" "$ARCHLIVE_PATH"

#         exit 1
#     fi
# fi
