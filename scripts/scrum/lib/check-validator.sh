#!/usr/bin/env bash
# check-validator.sh — probe JSON Schema validator availability.
# Echoes runner key on stdout; exits 1 with E_NO_VALIDATOR on stderr if none.
# Preference: ajv-cli (via npx) > check-jsonschema > jsonschema (deprecated) > python jsonschema module.
set -euo pipefail

if command -v npx >/dev/null 2>&1; then
  echo "ajv"
  exit 0
fi
if command -v check-jsonschema >/dev/null 2>&1; then
  echo "check-jsonschema"
  exit 0
fi
if command -v jsonschema >/dev/null 2>&1; then
  # Deprecated upstream but functional. Still use it.
  echo "jsonschema-cli"
  exit 0
fi
if python3 -c "import jsonschema" 2>/dev/null; then
  echo "python"
  exit 0
fi
echo "[scrum-tool] E_NO_VALIDATOR: install one of: 'npm i -g ajv-cli' or 'pipx install check-jsonschema' or 'pip install jsonschema'" >&2
exit 1
