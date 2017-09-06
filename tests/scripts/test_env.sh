#!/bin/sh
set -eu

if ! [ "$LLAMAS" = always ] ; then
  echo "Expected \$LLAMAS=always, got $LLAMAS"
  exit 1
fi

if ! [ "$ALPACAS" = sometimes ] ; then
  echo "Expected \$ALPACAS=sometimes, got $ALPACAS"
  exit 1
fi