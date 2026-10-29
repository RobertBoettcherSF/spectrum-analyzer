#!/bin/sh
# Runs GNATprove on the SPARK subset and keeps the summary in
# proof/gnatprove.out (committed, and shown by the live page).
set -e
cd "$(dirname "$0")"
if ! command -v gnatprove >/dev/null 2>&1; then
  if [ -x "$HOME/ada-fsf/gnatprove/bin/gnatprove" ]; then
    export PATH="$HOME/ada-fsf/gnat/bin:$HOME/ada-fsf/gnatprove/bin:$PATH"
  fi
fi
command -v gnatprove >/dev/null 2>&1 || {
  echo "gnatprove not on PATH (GNAT FSF 16 from alire-project/GNAT-FSF-builds)"
  exit 1
}
# --counterexamples=off does not change what is proved. It only skips the
# extra search for a counterexample after a check already succeeded.
gnatprove -P spectrum.gpr -j0 --mode=all --level=2 --timeout=60 \
  --report=all --checks-as-errors=on --counterexamples=off
mkdir -p proof
cp obj/native/gnatprove/gnatprove.out proof/gnatprove.out
gnatprove --version | head -1 > proof/version.txt
echo "proof log: proof/gnatprove.out"
