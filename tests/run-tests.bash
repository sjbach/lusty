#!/bin/bash

export DISPLAY=
failures=

for dir in */; do
  cd $dir
  if ! expect -f expect; then
    echo "fail: $dir"
    failures="$failures $dir"
  fi
  cd ..
done >/dev/null

if [ "$failures" ]; then
  echo
  echo "Failing tests: $failures" >&2
  exit 1
fi

echo Success

