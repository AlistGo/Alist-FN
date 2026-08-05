#!/usr/bin/env bash

set -Eeuo pipefail

[[ "${1:-}" == "build" ]]
test -f manifest
test -f config/privilege
test -f config/resource
test -x cmd/main
test -x app/bin/alist
test -f ICON.PNG
test -f ICON_256.PNG
tar -czf AlistFN-test.fpk manifest config cmd app wizard licenses ICON.PNG ICON_256.PNG

