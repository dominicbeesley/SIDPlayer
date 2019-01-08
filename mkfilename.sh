#!/bin/bash
export MY_FILE="`readlink -f "$0"`"
export MY_DIR="`dirname "$MY_FILE"`"
shopt -s nullglob
source "$MY_DIR/sh/utils.sh"

SIDINF="$1"
BBCFN="$2"

BASENAME="${SIDINF%.*}"
BASEDIR="$(dirname "$BASENAME")"


NAME="$(printf "S.%-7.7s" $BBCFN)"
X=0
BBCFN2="$BBCFN"
while [ -e "$BASEDIR/$NAME" ]; do
  let X=$(( $X + 1 ));
  BBCFN2="$X$BBCFN"
  NAME="$(printf "S.%-7.7s" $BBCFN2)"
done;

touch "$BASEDIR/$NAME"

printf "%s FFFF19F8 FFFF19F8" $NAME > "$1";

source $BASENAME.vars; \
printf $'%-9.9s\x0d%-32s' $NAME "$SID_TIT" > $BASENAME.men
