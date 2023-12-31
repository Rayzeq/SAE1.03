#!/bin/bash

if [ "$EUID" != 0 ]; then
	sudo "$0" "$@"
	exit $?
fi

if (( $# != 1 )); then
	echo "Veuiller préciser un et un seul argument"
	exit 1
fi

if [ ! -f "$1" ]; then
	echo "$1 n'est pas un fichier valide"
	exit 1
fi

declare -A mois=( ["1"]="janvier" ["2"]="fevrier" ["3"]="mars" ["4"]="avril" ["5"]="mai" ["6"]="juin" ["7"]="juillet" ["8"]="aout" ["9"]="septembre" ["10"]="octobre" ["11"]="novembre" ["12"]="decembre")

local IFS=$'\n'
for line in $(cat "$1"); do
	nom=$(echo $line | cut -d":" -f1)
	prenom=$(echo $line | cut -d":" -f2)
	((annee=$(echo $line | cut -d":" -f3)))
	numtel=$(echo $line | cut -d":" -f4)
	datenaiss=$(echo $line | cut -d":" -f5)

	if [ -z "$nom" ] || [ -z "$prenom" ] || [ -z "$annee" ] || [ -z "$numtel" ] || [ -z "$datenaiss" ]; then
		echo "Format de fichier invalide (des champs sont manquants)"
		exit 1
	fi

	if (( $annee < 1 || $annee > 3 )); then
		echo "L'année doit être comprise en 1 et 3"
		exit 1
	fi

	((jour_naiss=($(echo $datenaiss | cut -d"/" -f1))))
	((mois_naiss=$(echo $datenaiss | cut -d"/" -f2)))
	((annee_naiss=$(echo $datenaiss | cut -d"/" -f3)))

	if [ -z "$jour_naiss" ] || [ -z "$mois_naiss" ] || [ -z "$annee_naiss" ]; then
		echo "Date invalide"
		exit 1
	fi

	if (( $jour_naiss < 1 || $jour_naiss > 31 )); then
		echo "Format de fichier invalide"
		exit 1
	fi
	if (( $mois_naiss < 1 || $mois_naiss > 12 )); then
		echo "Format de fichier invalide"
		exit 1
	fi

	username="$(echo ${prenom:0:1} | tr "[a-z]" "[A-Z]")_$nom"

	lettre_nom=$(echo $nom | fold -w1 | shuf -n1 | tr "[a-z]" "[A-Z]")
	lettre_prenom=$(echo $nom | fold -w1 | shuf -n1 | tr "[A-Z]" "[a-z]")
	spec=$(echo "$^%*:;.,?#~[|@]+*-\\/=)(_&)}\!" | fold -w1 | shuf -n1)
	password="$lettre_nom$lettre_prenom${numtel:2:1}${spec}${mois[$mois_naiss]:0:1}"

	useradd -g "A$annee" -m -b "/home/A$annee" "$username"
	echo "$username:$password" | chpasswd
	if (( $? != 0 )); then
		echo "Erreur lors de la création de l'utilisateur $username"
		exit 1
	fi
	echo "$nom:$prenom:$username:$password" >> /root/A$annee.password
done