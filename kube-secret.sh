#!/usr/bin/env bash

function info () {
  echo -e "\033[32mINFO: $*\033[0m"
}

function error () {
  echo -e "\033[31mERROR: $*\033[0m"
}

function help {
  info "USAGE: ${0} <command> <secretname> <keyname> <keyvalue>"
  info "Available commands :"
  info "read : Read one secret or all available secrets. – ${0} <command> <secretname> [<keyname>]"
  info "edit : write one secret. – ${0} <command> <secretname> <keyname> <keyvalue>"
  exit 1
}

if [ $# -lt 2 ]; then
  help
fi

COMMAND=$1
SECRET=$2

if [ "$COMMAND" == "read" ]; then
  SECRET_JSON="$(kubectl get --ignore-not-found secret "$SECRET" -o json)"
  if [ -z "$SECRET_JSON" ]; then
    error "No match for given secret $SECRET"
    exit 1
  fi
  if [ -n "$3" ]; then
    OUTPUT="$(echo "$SECRET_JSON" | jq -r '.data | keys[] as $k | "\($k): \(.[$k] | @base64d)"' | grep "$3")"
    if [ -z "$OUTPUT" ]; then
      error "No match for given key name $3"
      exit 1
    fi
    echo "$OUTPUT"
  else
    echo "$SECRET_JSON" | jq -r '.data | keys[] as $k | "\($k): \(.[$k] | @base64d)"'
  fi
  exit 0
fi

if [ "$COMMAND" == "edit" ]; then
  SECRET_JSON="$(kubectl get --ignore-not-found secret "$SECRET" -o json)"
  if [ -z "$SECRET_JSON" ]; then
    error "No match for given secret $SECRET"
    exit 1
  fi
  if [ -z "$3" ]; then
    error "No key given for secret"
    help
  fi
  if [ -z "$4" ]; then
    error "No value given for key (this script doesn't support key deletion yet"
    help
  fi
  EXISTING="$(echo "$SECRET_JSON" | jq -r '.data | keys[] as $k | "\($k): \(.[$k] | @base64d)"' | grep "$3")"
  if [ -n "$EXISTING" ]; then
    read -pr "Key $3 already has a value, do you want to overwrite ? (Y/n)" answer
    case ${answer:0:1} in
        y|Y )
            echo "Cowardly dumping old value and overwriting value for key $3"
            echo "$SECRET_JSON" | jq -r '.data | keys[] as $k | "\($k): \(.[$k] | @base64d)"' | grep "$3"
        ;;
        * )
            echo "Not overwriting, exiting"
            exit 0
        ;;
    esac
  fi
  VALUE="$(echo -n "$4" | base64)"
  kubectl get secret "$SECRET" -o json | jq --arg VALUE "$VALUE" --arg KEY "$3" '.data[$KEY]=$VALUE' | kubectl apply -f -
  exit 0
fi
error "This command does not exist"
help
