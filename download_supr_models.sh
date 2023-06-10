#!/bin/bash
urle () { [[ "${1}" ]] || return 1; local LANG=C i x; for (( i = 0; i < ${#1}; i++ )); do x="${1:i:1}"; [[ "${x}" == [a-zA-Z0-9.~-] ]] && echo -n "${x}" || printf '%%%02X' "'${x}"; done; echo; }

read -p "Username:" username
read -p "Password:" password
username=$(urle $username)
password=$(urle $password)

wget --post-data "username=$username&password=$password" 'https://download.is.tue.mpg.de/download.php?domain=supr&resume=1&sfile=male/body/SUPR_male.npz' -O 'SUPR_male.npz' --no-check-certificate --continue
wget --post-data "username=$username&password=$password" 'https://download.is.tue.mpg.de/download.php?domain=supr&resume=1&sfile=female/body/SUPR_female.npz' -O 'SUPR_female.npz' --no-check-certificate --continue
wget --post-data "username=$username&password=$password" 'https://download.is.tue.mpg.de/download.php?domain=supr&resume=1&sfile=generic/body/SUPR_neutral.npz' -O 'SUPR_neutral.npz' --no-check-certificate --continue