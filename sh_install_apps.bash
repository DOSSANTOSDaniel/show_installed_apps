#!/bin/bash

### Usage
#./sh_install_apps.bash
#
### Description
#Ce script permet de récupérer des informations sur les paquets et les applications installées sur un système.
#
### Fonctionnement
#- Affiche la date.
#- Affiche certaines informations sur la machine.
#- Liste des paquets installés et description en utilisant la commande dpkg.
#- Liste les applications du système (applications qui sont dans le $PATH) et affiche une brève description.
#- Liste les applications flatpak et affiche une brève description.
#- Liste les applications snap et affiche une brève description.
#- Liste les applications installées par pacstall et affiche une brève description.
#
#- Un document sera créé à la fin de la récupération de toutes ces données, ce document est horodaté et sera enregistré dans le dossier dans lequel le script a été lancé.
#- Ce script est uniquement compatible avec les distributions de la famille Debian.

#Variables
WORK_DIR="$(pwd)"
DATE_LOG_FILE="$(date +%H-%M-%S-%A_%d_%B_%Y)"
NAME_LOG_FILE="${WORK_DIR}/installed_apps_${DATE_LOG_FILE}.txt"
IP_ADDR="$(hostname -I 2> /dev/null || ip -brief address | awk '/UP/ {print $3}')"
BIN_PATH="$PATH"
MAN_PKGS='manpages manpages-fr manpages-fr-extra'

#Fonctions
banner() {
  echo -e "\n Informations sur la machine "
  echo "------------------------------------"
  echo "Host : $HOSTNAME"
  echo "IP : $IP_ADDR"
  echo "User : $USERNAME"
}

titlepkg() {
  echo -e "\n Liste des applications $1 !"
  echo "==================================================================="
}

endscript() {
 xdg-open $NAME_LOG_FILE
}

cat <<'EOF'
 ___                      _        _                   
/ __| ___  __ _  _ _  __ | |_     /_\   _ __  _ __  ___
\__ \/ -_)/ _` || '_|/ _|| ' \   / _ \ | '_ \| '_ \(_-<
|___/\___|\__,_||_|  \__||_||_| /_/ \_\| .__/| .__//__/
                                       |_|   |_|       
EOF

echo -e "\n Enregistrement du fichier : $NAME_LOG_FILE en cours ... \n"

exec 2>&1 1>$NAME_LOG_FILE

echo -e "\n Date : $(date +%c)"

case "$OSTYPE" in
  linux*) if [[ -f /etc/os-release ]]
	  then
            banner
            echo "OS : $(cat /etc/os-release | grep "^PRETTY_NAME" | cut -d '=' -f2)"
	    echo "Kernel : $(uname -r)"
          elif [[ -f /etc/debian_version ]] # Ancienne distribution de la famille Debian
          then
            banner
            echo "OS : $(cat /etc/debian_version)"
	    echo "Kernel : $(uname -r)"
          elif [[ -f /etc/issue ]]
          then
            banner
            echo "OS : $(cat /etc/issue)"
	    echo "Kernel : $(uname -r)"
          else
            echo "Système d'exploitation non pris en charge !"
            exit 1
	  fi
	  ;;
       *) echo "Système d'exploitation non pris en charge $OSTYPE !"
          exit 1
	  ;;
esac

# Dependencies
for manapp in $MAN_PKGS
do
  if ! (dpkg --list | grep -w "^ii  $manapp " > /dev/null 2>&1)
  then
    echo "Installation de $manapp !"
    sudo apt-get install $manapp -yq
  fi
done

if ! [[ -e /usr/bin/yq ]]
then
  echo "Installation de yq !"
  sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
fi

# DPKG
echo -e "\n Liste des paquets par dpkg !"
echo ':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
if [[ $(command -v dpkg 2> /dev/null) ]]
then
  dpkg-query --list | tail -n +6 | awk '{print "=----- "$2" -----="; for(i=5;i<=NF;i++) printf $i" "; print "\n"}'
else
  echo "Le système n'utilise pas la commande dpkg !"
  exit 1
fi

# Apt
titlepkg 'du système'
for dir_bin in ${BIN_PATH//:/ }
do
  if [[ $dir_bin =~ ^/snap/* ]]
  then
    continue
  fi
  echo -e "\n Recherche d'applications dans le dossier $dir_bin !"
  echo -e "======================================================================== \n"
  for bin_file in $(ls -R $dir_bin | grep -v ":$")
  do
    whatis --locale=fr $bin_file 2> /dev/null || echo "$bin_file (X) Pas de description !"
    echo -e "------------------------------------------------------------------------ \n"
  done
done

# Flatpak
titlepkg flatpak 
if [[ $(dpkg -s flatpak 2> /dev/null) && $(command -v flatpak 2> /dev/null) ]]
then
  for flatapp in $(flatpak list --app | awk -F '\t' '{print $2"/x86_64/"$4}')
  do
    echo -e "\n =----- $flatapp -----="; flatpak info $flatapp | grep ' - '
  done
else
  echo "Le système n'utilise pas la commande flatpak !"
fi

# Snap
titlepkg snap
if [[ $(dpkg -s snapd 2> /dev/null) && $(command -v snap 2> /dev/null) ]]
then
  for snapapp in $(snap list | awk '{print $1}' | tail -n +2)
  do
    echo -e "\n =----- $snapapp -----="
    snap info $snapapp | yq '(.summary, .description)'
  done
else
  echo "Le système n'utilise pas la commande snap !"
fi

# Pacstall
titlepkg pacstall
if [[ $(dpkg -s pacstall 2> /dev/null) || $(command -v pacstall 2> /dev/null) ]]
then
  for pacapp in $(pacstall --list | awk '{print $1}')
  do
    echo -e "\n =----- $pacapp -----="
    pacstall --query-info $pacapp | grep 'description' | cut -d ':' -f2
  done
else
  echo "Le système n'utilise pas la commande pacstall !"
fi

trap endscript EXIT
