#!/usr/bin/bash

CURRENT_DIR=$(dirname $(realpath "$0"))
VENV=$CURRENT_DIR/.venv

source $VENV/bin/activate

$VENV/bin/python $CURRENT_DIR/main.py


