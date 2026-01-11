#!/usr/bin/bash

PWD=$(dirname $(realpath "$0"))
VENV=$PWD/.venv

# because of bash
source $VENV/bin/activate

$VENV/bin/python $PWD/main.py


