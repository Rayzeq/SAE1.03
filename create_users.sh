#!/bin/bash

if [ "$EUID" != 0 ]; then
	sudo "$0" "$@"
	exit $?
fi

if (( $# != 1 )); then
	echo "Veuiller préciser un et un seul argument" >&2
	exit 1
fi

if [ ! -f "$1" ]; then
	echo "$1 n'est pas un fichier valide" >&2
	exit 2
fi

declare -A mois=( ["1"]="janvier" ["2"]="fevrier" ["3"]="mars" ["4"]="avril" ["5"]="mai" ["6"]="juin" ["7"]="juillet" ["8"]="aout" ["9"]="septembre" ["10"]="octobre" ["11"]="novembre" ["12"]="decembre")

IFS=$'\n'
for line in $(cat "$1"); do
	if (($(echo $line | fold -w1 | grep ":" | wc -l) != 4)); then
		echo "$1 n'est pas un fichier valide (une ligne n'a pas assez de champs)" >&2
		exit 3
	fi
	nom=$(echo $line | cut -d":" -f1)
	prenom=$(echo $line | cut -d":" -f2)
	(( annee=$(echo $line | cut -d":" -f3) ))
	numtel=$(echo $line | cut -d":" -f4)
	datenaiss=$(echo $line | cut -d":" -f5)

	if [ -z "$nom" ] || [ -z "$prenom" ] || [ -z "$annee" ] || [ -z "$numtel" ] || [ -z "$datenaiss" ]; then
		echo "Format de fichier invalide (Des champs sont manquants)" >&2
		exit 4
	fi

	if (( ${#numtel} < 10 )) then
		echo "Format de fichier invalide (Le numéro de téléphone est pas assez long)" >&2
		exit 5
	fi

	re='^[0-9]+$'
	if ! [[ $numtel =~ $re ]]; then
		echo "Format de fichier invalide (Le numéro de téléphone n'est pas valide)" >&2
		exit 6
	fi

	if (( $annee < 1 || $annee > 3 )); then
		echo "L'année doit être comprise en 1 et 3" >&2
		exit 7
	fi

	if (( $(echo $datenaiss | fold -w1 | grep "/" | wc -l) != 2 )); then
		echo "$1 n'est pas un fichier valide (la date de naissance doit contenir trois valeures)" >&2
		exit 8
	fi

	(( jour_naiss=$(echo $datenaiss | cut -d"/" -f1) ))
	(( mois_naiss=$(echo $datenaiss | cut -d"/" -f2) ))
	(( annee_naiss=$(echo $datenaiss | cut -d"/" -f3) ))

	if [ -z "$jour_naiss" ] || [ -z "$mois_naiss" ] || [ -z "$annee_naiss" ]; then
		echo "Date invalide" >&2
		exit 9
	fi

	if ( (( $annee_naiss % 4 != 0 )) && (( $annee_naiss % 400 != 0 )) ) && ( (( $mois_naiss == 2 )) && (( $jour_naiss >= 29 )) ); then
		echo "Date invalide" >&2
		exit 10
	fi

	if (( $jour_naiss < 1 || $jour_naiss > 31 )); then
		echo "Format de fichier invalide" >&2
		exit 11
	fi

	if (( $mois_naiss < 1 || $mois_naiss > 12 )); then
		echo "Format de fichier invalide" >&2
		exit 12
	fi

	username="$(echo ${prenom:0:1} | tr "[a-z]" "[A-Z]")_$nom"

	lettre_nom=$(echo $nom | fold -w1 | shuf -n1 | tr "[a-z]" "[A-Z]")
	lettre_prenom=$(echo $nom | fold -w1 | shuf -n1 | tr "[A-Z]" "[a-z]")
	spec=$(echo "$^%*:;.,?#~[|@]+*-\\/=)(_&)}\!" | fold -w1 | shuf -n1)
	password="$lettre_nom$lettre_prenom${numtel:2:1}${spec}${mois[$mois_naiss]:0:1}"

	(( count = 0 ))
	originalUsername=$username
	cat "/etc/passwd" | grep "^$username:"
	while (( $? != 1 )); do
		(( count = count + 1 ))
		username="$originalUsername$count"
		cat "/etc/passwd" | grep "^$username:"
	done

	useradd -K UMASK=0077 -g "A$annee" -m -b "/home/A$annee" "$username"
	if (( $? != 0 )); then
		echo "Erreur lors de la création de l'utilisateur $username"
		exit 14
	fi
	echo "$username:$password" | chpasswd
	echo "$nom:$prenom:$username:$password" >> /root/A$annee.password
done