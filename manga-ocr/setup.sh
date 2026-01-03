#!/bin/bash

echo "Creating virtual environment"
python3 -m venv .venv

echo "Installing dependencies"
pip install -r requirements.txt

echo "Activating virtual environment"
source .venv/bin/activate
