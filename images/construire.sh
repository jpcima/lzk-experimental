#!/bin/bash
set -e

# Construction de l'image LibraZiK dédiée à la construction
# note (1) : ce script doit être lancé depuis un sous-chemin de /home
# note (2) : pas d'utilisation de Dockerfile, car cela ne gère pas l'exécution privilégiée

if [ "$#" -ne 1 ]; then
    echo "Utilisation : $0 <architecture>"
    echo " * architecture : i386 ou amd64"
    exit 1
fi

# l'architecture est donnée sur la ligne de commande
architecture="$1"
# la distribution de Debian correspondant à LibraZiK-2
distribution=stretch

case "$(pwd)" in
    /home/*) ;;
    *) echo "Lancer ce script depuis un sous-dossier de /home."; exit 1;;
esac

# ceci sert à afficher un message coloré
msg() {
    printf " -- \033[36;1m"; echo "$@"; printf "\033[0m"
}

# on nomme l'image qu'on va bientôt créer
image_destination="librazik-2-automate:$architecture"
msg "image destination: $image_destination"
# on vérifie qu'elle n'existe pas déjà
if docker images | tail -n +2 | awk '{print $1 ":" $2}' | \
        egrep -q "^$image_destination\$"
then
    msg "veuillez d'abord supprimer l'image existante: $image_destination"
    exit 1
fi

# préparation du conteneur avec l'image debian
# on monte /home dans le conteneur
# on active le mode privilégié, car l'accès à /proc est requis
image="$architecture/debian:$distribution"
msg "récupération de l'image de base : $image"
docker pull "$image"
msg "lancement du conteneur"
conteneur=$(docker run --privileged -d -i -t -v /home:/home "$image" /bin/bash)
msg "nouveau conteneur : $conteneur"

# on supprimera le conteneur quand on aura fini
supprimer_conteneur() {
    msg "suppression du conteneur $conteneur"
    docker stop "$conteneur"
    docker rm "$conteneur"
}
trap supprimer_conteneur INT TERM EXIT

# cette fonction lance une commande dans le conteneur
# -w préservera le répertoire courant
# on travaillera dans /home, qui est en miroir entre l'hôte et le conteneur
dans_le_conteneur() {
    msg "exécution de la commande : $@"
    docker exec --privileged -w "$(pwd)" -i -t "$conteneur" "$@"
}

# on met à jour les sources de paquets Debian
dans_le_conteneur apt-get -y update
# on transforme la Debian en LibraZiK
dans_le_conteneur apt-get -y install gnupg curl
dans_le_conteneur curl -o /tmp/apt.deb http://download.tuxfamily.org/librazik/decepas/librazik-apt_2_all.deb
dans_le_conteneur curl -o /tmp/keyring.deb http://download.tuxfamily.org/librazik/decepas/librazik-keyring_2_all.deb
dans_le_conteneur dpkg -i /tmp/apt.deb /tmp/keyring.deb
dans_le_conteneur rm -f /tmp/apt.deb /tmp/keyring.deb
dans_le_conteneur rm -f /etc/apt/sources.list # suppressions des doublons apt-get
# on met à jour
dans_le_conteneur apt-get -y update
dans_le_conteneur apt-get -y upgrade

# on met les outils d'empaquetage
dans_le_conteneur apt-get -y install packaging-dev

# on configure pbuilder
dans_le_conteneur cp pbuilderrc.in /etc/pbuilderrc
dans_le_conteneur sed -i "s:@architecture@:$architecture:g" /etc/pbuilderrc
dans_le_conteneur sed -i "s:@distribution@:$distribution:g" /etc/pbuilderrc

# on crée le chroot de base
dans_le_conteneur pbuilder create

# on nettoye
dans_le_conteneur apt-get -y clean

# on conserve cette image en lui assignant une étiquette
msg "sauvegarde de l'image : $image_destination"
docker commit "$conteneur" "$image_destination"
