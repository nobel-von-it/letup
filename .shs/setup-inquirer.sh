#!/usr/bin/env bash

PWD=$(dirname $(realpath "$0"))

install() {
    yay -S python-inquirer
}

PYTHON_TEST="import inquirer"

if python -c "$PYTHON_TEST" >/dev/null 2>&1; then
    echo "inquirer is already installed"
    exit 0
fi

if command -v yay >/dev/null 2>&1; then
    install
else
    echo "yay is not installed"
    "$PWD"/setup-yay.sh
    install
fi
