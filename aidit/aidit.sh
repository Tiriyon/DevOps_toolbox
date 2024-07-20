#!/usr/bin/env bash
RED='\033[0;31m' # Red
NC='\033[0m'

# Image dir
mkdir -p "IMAGES"

# Spinner

msg() {
  echo -e "$*" >/dev/tty 2>&1
}

error() {
  msg "${RED}$*${NC}"
  print_usage
}

spinner() {
  local pid="${1}"
  local delay=0.1
  local message="${2}"
  local spin_chars=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
  local i=0

  # Hide cursor
  printf "\e[?25l"

  while kill -0 "${pid}" 2>/dev/null; do
    printf "\r%s %s" "$message" "${spin_chars[i]}"
    i=$(((i + 1) % ${#spin_chars[@]}))
    sleep $delay
  done

  # Restore cursor
  printf "\e[?25h"
  printf "\r\033[K" # Clear the line
}

# Function to print usage message and exit
print_usage() {
  msg "Usage: ${0} [-f <image_list_file>] [-d <image_directory>] [-r <repository>] <image_entry>"
  exit 1
}

push_image() {
  if [[ -z "${1}" || -z "${2}" ]]; then
    error "Error: Image entry or repository not provided."
  fi

  local ENTRY="${1}"
  local REPO="${2}"

  echo "Pushing image to ${REPO}: ${ENTRY}"

  # Run skopeo copy silently and use spinner
  skopeo copy --all --dest-no-creds --dest-tls-verify=false "dir://${PWD}/IMAGES/${ENTRY}" "docker://${REPO}/${ENTRY}" >/dev/null &
  SPINNER_PID="${!}"

  # Start the spinner
  spinner ${SPINNER_PID} "Pushing image: ${ENTRY}"

  # Wait for skopeo to finish
  wait "${SPINNER_PID}"
  printf "\r\033[K" # Clear the line
}

# Function to push images from a directory
push_images_from_directory() {
  if [[ -z "$1" || -z "$2" ]]; then
    error "Error: Image directory or repository not provided."
  fi

  local DIR="${1}"
  local REPO="${2}"

  echo "Pushing images from directory ${DIR} to repository ${REPO}"

  # Find all subdirectories in the specified directory
  find "${DIR}" -mindepth 1 -type d | while read -r SUBDIR; do
    # Calculate the relative path from the specified directory
    RELATIVE_PATH=$(realpath --relative-to="${DIR}" "${SUBDIR}")

    # Check if the directory contains image manifest files
    if [[ -f "${SUBDIR}/manifest.json" ]]; then
      # Push the images in the subdirectory to the repository
      push_image "${RELATIVE_PATH}" "${REPO}"
    else
      msg "Skipping directory ${RELATIVE_PATH}: No image manifest files found."
    fi
  done
}

# Function to copy a single image
copy_image() {
  if [[ -z "${1}" ]]; then
    error "Error: Image entry not provided."
  fi

    local ENTRY=${1}
    local REPO
    local IMAGE
    local IMAGE_DIR
    ##################################################################
    # IFS='/' read -r -a parts <<< "$ENTRY"
    # REPO="${parts[0]}"
    # IMAGE="$(IFS=/ ; echo "${parts[@]:1}")"
    # IMAGE="$(echo "$IMAGE" | sed  'sD\ D/Dg')"
    # Not entirely sure what you tried to do here,
    # but if I got it right, this code should do it much better and safer
    REPO="$(echo "${ENTRY}" | cut -d/ -f1)"
    IMAGE="$(echo "${ENTRY}" | cut -d/ -f2- | tr ' ' '/')"
    IMAGE_DIR="$(echo "${IMAGE}"| cut -d: -f1)" ; echo "${IMAGE_DIR}"
    ##################################################################
    mkdir -p "IMAGES/${IMAGE_DIR}"
    msg "Copying image from ${REPO}: ${IMAGE}"

  # Run skopeo copy silently and use spinner
  skopeo copy --src-no-creds --src-tls-verify=false "docker://${ENTRY}" "dir://${PWD}/IMAGES/${IMAGE}" >/dev/null &
  SPINNER_PID="${!}"

  # Start the spinner
  spinner ${SPINNER_PID} "Copying image: ${IMAGE}"

  # Wait for skopeo to finish
  wait ${SPINNER_PID}
  printf "\r\033[K" # Clear the line
}

# Function to copy images from a file
copy_images_from_file() {
  if [[ -z "${1}" ]]; then
    error "Error: Image list file not provided."
  fi

  local FILE="${1}"
  local line

  while IFS= read -r line; do
    copy_image "${line}"
  done <"${FILE}"
}

# Main script execution
while getopts ":d:r:f:" opt; do
  case ${opt} in
  d)
    DIR_ARG=${OPTARG}
    ;;
  r)
    REPO_ARG=${OPTARG}
    ;;
  f)
    FILE_ARG=${OPTARG}
    ;;
  \?)
    echo "Error: Invalid option: -${OPTARG}" >&2
    print_usage
    ;;
  :)
    echo "Error: Option -${OPTARG} requires an argument." >&2
    print_usage
    ;;
  esac
done

# Check if both DIR_ARG and REPO_ARG are provided for pushing images
if [[ -n "${DIR_ARG}" && -n "${REPO_ARG}" ]]; then
  push_images_from_directory "${DIR_ARG}" "${REPO_ARG}"
fi

# Check if FILE_ARG is provided for copying images from a file
if [[ -n "${FILE_ARG}" ]]; then
  copy_images_from_file "${FILE_ARG}"
fi

# If no flag is present and ENTRY is provided, copy the single image specified
shift $((OPTIND - 1))
ENTRY="${1}"

if [[ -n "${ENTRY}" ]]; then
  copy_image "${ENTRY}"
fi

# Return cursor to screen
printf "\e[?25h"
