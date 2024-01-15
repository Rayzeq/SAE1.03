#!/bin/bash

# On vérifie si le script est lancé en tant que root
if [ "$EUID" != 0 ]; then
	# Si ce n'est pas cas, on le relance avec sudo, et on retourne le nouveau code de retour
	sudo "$0" "$@"
	exit $?
fi

# On vérifie si le script est lancé avec un et un seul argument
if (( $# != 1 )); then
	echo "Veuiller préciser un et un seul argument" >&2
	exit 1
fi

# On vérifie si le fichier existe bien
if [ ! -f "$1" ]; then
	echo "$1 n'est pas un fichier valide" >&2
	exit 2
fi

# On créer un tableau associatif qui contient les mois
declare -A mois=( ["1"]="janvier" ["2"]="fevrier" ["3"]="mars" ["4"]="avril" ["5"]="mai" ["6"]="juin" ["7"]="juillet" ["8"]="aout" ["9"]="septembre" ["10"]="octobre" ["11"]="novembre" ["12"]="decembre")

# IFS contient le caractère qu'utilisera le for comme séparateur
# on souhaite séparer le fichier en lignes donc on utilise '\n'
IFS=$'\n'
for line in $(cat "$1"); do
	# On vérifie si la ligne contient bien 5 champs.
	# Pour cela on met chaque charactère sur une ligne différente, on grep le résultat
	# puis on compte le nombre de lignes données par grep
	if (( $(echo $line | fold -w1 | grep ":" | wc -l) != 4 )); then
		echo "$1 n'est pas un fichier valide (une ligne n'a pas assez de champs)" >&2
		exit 3
	fi

	# On enlève les espaces et tabulations
	line=$(echo $line | tr -d '[:blank:]')

	# On vérifie que la ligne ne contient pas de caractères spéciaux
	if echo $line | grep -q "[^a-zA-Z0-9:/-]"; then
		echo "$1 n'est pas un fichier valide (une ligne contient des caractères invalides)" >&2
		exit 4
	fi

	# On récupère les différents champs
	nom=$(echo $line | cut -d":" -f1)
	prenom=$(echo $line | cut -d":" -f2)
	(( annee=$(echo $line | cut -d":" -f3) ))
	numtel=$(echo $line | cut -d":" -f4)
	datenaiss=$(echo $line | cut -d":" -f5)

	# On vérifie que les champs ne sont pas vides
	if [ -z "$nom" ] || [ -z "$prenom" ] || [ -z "$annee" ] || [ -z "$numtel" ] || [ -z "$datenaiss" ]; then
		echo "Format de fichier invalide (Des champs sont manquants)" >&2
		exit 5
	fi

	# On vérifie que le numéro de téléphone est valide (plus de 10 caractères, et uniquement des chiffres)
	if (( ${#numtel} < 10 )) then
		echo "Format de fichier invalide (Le numéro de téléphone est pas assez long)" >&2
		exit 6
	fi
	re='^[0-9]+$'
	if ! [[ $numtel =~ $re ]]; then
		echo "Format de fichier invalide (Le numéro de téléphone n'est pas valide)" >&2
		exit 7
	fi

	# On vérifie que l'année est valide
	if (( $annee < 1 || $annee > 3 )); then
		echo "L'année doit être comprise en 1 et 3" >&2
		exit 8
	fi

	# On vérifie que la date de naissance contient bien trois champs
	if (( $(echo $datenaiss | fold -w1 | grep "/" | wc -l) != 2 )); then
		echo "$1 n'est pas un fichier valide (la date de naissance doit contenir trois valeurs)" >&2
		exit 9
	fi

	# On récupère les champs de la date de naissance
	(( jour_naiss=$(echo $datenaiss | cut -d"/" -f1) ))
	(( mois_naiss=$(echo $datenaiss | cut -d"/" -f2) ))
	(( annee_naiss=$(echo $datenaiss | cut -d"/" -f3) ))

	# On vérifie que les champs ne sont pas vides
	if [ -z "$jour_naiss" ] || [ -z "$mois_naiss" ] || [ -z "$annee_naiss" ]; then
		echo "Date invalide" >&2
		exit 10
	fi

	# On vérifie que la date de naissance est une date valide
	if ( (( $annee_naiss % 4 != 0 )) && (( $annee_naiss % 400 != 0 )) ) && ( (( $mois_naiss == 2 )) && (( $jour_naiss >= 29 )) ); then
		echo "Date invalide" >&2
		exit 11
	fi
	if (( $jour_naiss < 1 || $jour_naiss > 31 )); then
		echo "Format de fichier invalide" >&2
		exit 12
	fi
	if (( $mois_naiss < 1 || $mois_naiss > 12 )); then
		echo "Format de fichier invalide" >&2
		exit 13
	fi

	# On créer le nom d'utilisateur
	username="$(echo ${prenom:0:1} | tr "[a-z]" "[A-Z]")_$nom"

	# On créer le mot de passe
	# Pour choisir des caractères aléatoires, on met chaque caractère sur une ligne,
	# puis on utilise shuf pour sélectionner une seule ligne aléatoirement
	lettre_nom=$(echo $nom | fold -w1 | shuf -n1 | tr "[a-z]" "[A-Z]")
	lettre_prenom=$(echo $nom | fold -w1 | shuf -n1 | tr "[A-Z]" "[a-z]")
	spec=$(echo "$^%*:;.,?#~[|@]+*-\\/=)(_&)}\!" | fold -w1 | shuf -n1)
	password="$lettre_nom$lettre_prenom${numtel:2:1}${spec}${mois[$mois_naiss]:0:1}"

	# On vérifie si le nom d'utilisateur existe déjà en vérifiant dans /etc/passwd.
	# S'il existe déjà on ajoute un chiffre (1, 2, 3, ...) à la fin du nom d'utilisateur
	(( count = 0 ))
	originalUsername=$username
	while cat "/etc/passwd" | grep -q "^$username:"; do
		(( count = count + 1 ))
		username="$originalUsername$count"
	done

	# On créer l'utilisateur en spécifiant le umask qui va être utilisé pour le home,
	# le groupe, le dossier ou placer le home, on met bash comme shell par défaut,
	# car celui de xfce est dash
	useradd -K UMASK=0077 -g "A$annee" -m -b "/home/A$annee" -s /bin/bash "$username"
	if (( $? != 0 )); then
		echo "Erreur lors de la création de l'utilisateur $username"
		exit 14
	fi
	# On met le mot de passe que l'on a généré
	echo "$username:$password" | chpasswd
	# Puis on ajoute l'utilisateur dans le fichier
	echo "$nom:$prenom:$username:$password" >> /root/A$annee.password
done