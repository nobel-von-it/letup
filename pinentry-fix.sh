#!/bin/bash
/usr/bin/pinentry-qt "$@" 2> >(grep -v "MESA: warning" >&2)
