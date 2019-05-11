# Fabrique un paquet à partir d'un dossier source, situé dans paquets/,
# contenant le dossier debian/ mais pas nécessairement le contenu d'archive.
#
# Exemple: make -f "`pwd`/outils/construire-paquet.mk" -C paquets/setbfree



###### Init ######

# chemin de la racine, déterminé à partir du Makefile
racine = $(abspath $(dir $(firstword $(MAKEFILE_LIST)))/..)
# vérification du chemin
$(if $(filter $(racine)/paquets/%,$(CURDIR)),,\
  $(error Ce Makefile doit être lancé depuis un dossier de paquet))



###### Règles ######

# récupération des infos de paquet
include /usr/share/dpkg/pkg-info.mk

# cible par défaut
all: package

# empaquetage avec pbuilder
package: unpack
	pdebuild

# extraction de l'archive source
unpack: get-orig-source
	tar -x --strip-components=1 -f \
	    $(firstword $(wildcard ../$(DEB_SOURCE)_$(DEB_VERSION_UPSTREAM).orig.tar*))

# fabrication de l'archive source (http://wiki.debian.org/onlyjob/get-orig-source)
get-orig-source:  $(info I: $(DEB_SOURCE)_$(DEB_VERSION_UPSTREAM))
	@echo "# Downloading..."
	uscan --noconf --verbose --rename --destdir=$(CURDIR)/.. --check-dirname-level=0 --force-download --download-version $(DEB_VERSION_UPSTREAM) $(abspath debian)

# liste des cibles abstraites
.PHONY: all package unpack get-orig-source
