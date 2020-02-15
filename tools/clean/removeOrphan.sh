#!/bin/bash

sudo pacman -Rsn $(sudo pacman -Qtdq)

exit 
