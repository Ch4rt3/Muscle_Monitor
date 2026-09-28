#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export PATH="$project_dir/tool/apple_clt:$PATH"
cd "$project_dir"
exec flutter test "$@"
