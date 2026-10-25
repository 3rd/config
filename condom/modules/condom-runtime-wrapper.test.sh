#!/usr/bin/env bash
set -euo pipefail

source_file=$1
scratch_dir=$(mktemp -d "${TMPDIR:-/tmp}/condom-runtime-wrapper.XXXXXXXX")
trap 'rm -rf -- "${scratch_dir:?}"' EXIT
runtime_binary="$scratch_dir/condom"
launcher="$scratch_dir/launcher"
compiler=${CC:-cc}

"$compiler" -std=c11 -Wall -Wextra -Werror \
  "-DCONDOM_BINARY=\"$runtime_binary\"" \
  "$source_file" -o "$launcher"

"$compiler" -x c - -o "$runtime_binary" <<'C'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    const char *value = getenv("CONDOM_WRAPPER_TEST");
    if (argc != 2 || value == NULL || strcmp(value, "preserved") != 0) {
        return 1;
    }

    printf("%s\n%s\n", argv[0], argv[1]);
    return 23;
}
C

status=0
CONDOM_WRAPPER_TEST=preserved "$launcher" 'argument with spaces' > "$scratch_dir/output" || status=$?
test "$status" -eq 23
printf '%s\n' "$runtime_binary" 'argument with spaces' > "$scratch_dir/expected"
cmp "$scratch_dir/expected" "$scratch_dir/output"

"$compiler" -x c - -o "$runtime_binary" <<'C'
int main(void) {
    return 0;
}
C

"$launcher"

printf '#!/bin/sh\nexit 0\n' > "$runtime_binary"
if "$launcher" 2> "$scratch_dir/error"; then
  exit 1
fi
grep -Fq 'refusing to execute a non-ELF Condom binary' "$scratch_dir/error"

printf '\177EL' > "$runtime_binary"
if "$launcher" 2> "$scratch_dir/error"; then
  exit 1
fi
grep -Fq 'refusing to execute a non-ELF Condom binary' "$scratch_dir/error"

rm "$runtime_binary"
if "$launcher" 2> "$scratch_dir/error"; then
  exit 1
fi
grep -Fq "$runtime_binary" "$scratch_dir/error"
