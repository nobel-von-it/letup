#!/bin/bash

VENV_DIR=".venv"

if [ ! -f "requirements.txt" ]; then
    echo "ERROR: requirements.txt not found!"
    exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment $VENV_DIR..."
    python -m venv "$VENV_DIR"
else
    echo "Virtual environment $VENV_DIR already exists."
fi

echo "Updating pip and installing requirements..."
source "$VENV_DIR/bin/activate"

pip install --upgrade pip
pip install -r requirements.txt
