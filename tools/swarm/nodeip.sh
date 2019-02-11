#!/bin/bash


if docker node ls > /dev/null 2>&1; then
  for NODE in $(docker node ls --format '{{.Hostname}}'); 
  do echo -e "${NODE} - $(docker node inspect --format '{{.Status.Addr}}' "${NODE}")"; done
else
  echo 'this is a standalone node'
fi
