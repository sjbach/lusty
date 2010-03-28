#!/bin/bash

failures=

for dir in */; do
  cd $dir
  #rm -f success fail
  if ! expect -f expect; then
    failures="$failures $dir"
  fi
  cd ..
  #ls $dir/success >/dev/null
done >/dev/null

if [ "$failures" ]; then
  echo "Failing tests: $failures" >&2
  exit 1
fi

echo Success

