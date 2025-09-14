#!/bin/bash
set -euo pipefail
PASS="$1"
SRC="$2"
DEST="$3"

openssl aes-128-cbc -pass pass:"$PASS" -in "$SRC" -out "$DEST"
