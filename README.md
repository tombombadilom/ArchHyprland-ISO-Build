
# Configuration d'ISO personnalisé Arch Linux

Ce guide détaille le script utilisé pour préparer un environnement Arch Linux personnalisé destiné à la création d'une image ISO.

## Configuration des Chemins

```bash
export ARCHLIVE_PATH="/home/tom/archlive"
CUSTOM_ARCHIVES_PATH="$ARCHLIVE_PATH/airootfs/root/custom_archives"
SCRIPTS_PATH="$ARCHLIVE_PATH/airootfs/root/scripts"
LIVEUSER_HOME="$ARCHLIVE_PATH/airootfs/home/liveuser"
ARCHISO_PATH="/home/tom/Documents/archiso"
export ARCHISO_OUT="$ARCHISO_PATH/ISO"
```

## Installation des Paquets Nécessaires

Le script vérifie et installe `archiso` et `calamares` si nécessaire.

```bash
install_package_if_missing() {
  for package in "${PACKAGES_TO_INSTALL[@]}"; do
    if ! yay -Qi "$package" &>/dev/null; then
      echo "Installing $package."
      yay -S --noconfirm --needed "$package"
    else
      echo "$package is already installed and up to date."
    fi
  done
}
```

## Préparation de l'Environnement

Copie et configuration des fichiers nécessaires pour la création de l'ISO.

```bash
cp -r /usr/share/archiso/configs/releng/* "$ARCHLIVE_PATH"
sudo cp /etc/pacman.conf $ARCHLIVE_PATH/pacman.conf
yay -Rns $(yay -Qtdq) --noconfirm
yay -Sc --noconfirm
yay -Qqe > "$ARCHLIVE_PATH/packages.x86_64"
cp "$ARCHLIVE_PATH/packages.x86_64" "$ARCHLIVE_PATH/airootfs/"
```

## Sauvegarde des Configurations

Création de sauvegardes tar.gz de configurations système et utilisateur, en excluant certains chemins.

```bash
tar -czvf "$CUSTOM_ARCHIVES_PATH/etc_backup.tar.gz" -C /etc/
IGNORE=()
for exclude in "${excludes[@]}"; do
  IGNORE+=(--exclude="${exclude}")
done
tar -czvf "$CUSTOM_ARCHIVES_PATH/user_configs.tar.gz" "${IGNORE[@]}" ~/.config ~/.local
```

## Configuration des Scripts Utilisateur

Mise en place de scripts personnalisés pour l'environnement live.

```bash
mkdir -p "$SCRIPTS_PATH"
echo '#!/usr/bin/env bash
yay -Sy --noconfirm git
...
' > "$SCRIPTS_PATH/customize.sh"
chmod +x "$SCRIPTS_PATH/customize.sh"
echo "exec calamares" > "$LIVEUSER_HOME/.xinitrc"
```

## Vérifications et Copie des Fichiers

Le script vérifie l'existence et la configuration correcte des variables et chemins avant de procéder.

```bash
if [ -z "${ARCHISO_PATH}" ] || [ -z "${ARCHLIVE_PATH}" ]; then
    echo "Environment variables DOCUMENTS_PATH and/or ARCHLIVE_PATH are not set properly."
    exit 1
fi
cp "${ARCHISO_PATH}/os-release" "${ARCHLIVE_PATH}/etc/os-release"
```

## Conclusion

Ce script facilite la préparation d'une image ISO Arch Linux avec un environnement personnalisé, incluant des sauvegardes, des scripts, et l'installation de logiciels nécessaires.
