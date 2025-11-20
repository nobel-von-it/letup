#!/bin/bash

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

install -D -m 755 $(realpath "./pcma") "$LOCAL_BIN"
