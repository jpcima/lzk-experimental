#!/bin/bash

# Construit les paquets dont les sources ont été modifiées dans le commit donné.
# Exemple: construire-paquets-commit.sh HEAD

set -e

if [ "$#" -ne 1 ]; then
    echo "Nécessite 1 argument: <id-commit>"
    exit 1
fi

# se placer à la racine
cd "$(dirname "$0")/.."

# extraire les dossiers de paquets du commit
git diff-tree --no-commit-id --name-only -r "$1" | \
    egrep -o '^paquets/[^/]+/' | sort | uniq | \
while read dossier; do
    if [ -d "$dossier" ]; then
        make -f "$(pwd)"/outils/construire-paquet.mk -C "$dossier"
    fi
done
