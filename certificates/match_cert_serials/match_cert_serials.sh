#!/bin/bash

# Set verbosity level: 1 for normal, 2 for detailed
verbosity=1

# Function to control verbosity
verbose() {
  if [ "$verbosity" -ge "$1" ]; then
    echo -e "$2"
  fi
}

for cert in $(ls | grep "pem"); do
  serial=$(openssl x509 -in "$cert" -noout -serial | cut -d'=' -f2 | tr '[:lower:]' '[:upper:]')
  match_found=false
  for known_serial in "083BE056904246B1A1756AC95991C74A" "02742EAA17CA8E21C717BB1FFCFD0CA0" "0B9E93A35CC32981279A82EFD7C62338"; do
    verbose 2 "Matching $cert with serial $serial against known serial $known_serial..."
    if [[ "$serial" == "$known_serial" ]]; then
      echo -e "Matching $cert with serial $serial: \e[32mMATCH\e[0m"
      match_found=true
      break
    fi
  done
  if [ "$match_found" = false ]; then
    echo -e "Matching $cert with serial $serial: \e[31mNO MATCH\e[0m"
  fi
done