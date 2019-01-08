#!/bin/bash
export MY_FILE="`readlink -f "$0"`"
export MY_DIR="`dirname "$MY_FILE"`"
shopt -s nullglob
source "$MY_DIR/sh/utils.sh"

SRC_DIR="$1"
DEST_SSD="$2"

PATH=$PATH:$MY_DIR/ripsid:$MY_DIR/sidreloc-1.0-dom

bold "copy sids from $1 to $2"

dfs form -80 "$2"
checkstat "Formatting ssd"

INTER="$MY_DIR/inter"

ensuredir "$INTER"

delcheck "$INTER" "*.sid"
delcheck "$INTER" "*.brk"
delcheck "$INTER" "*.bbc"
delcheck "$INTER" "*.inf"
delcheck "$INTER" "*.s"
delcheck "$INTER" "menu.m"

n=0
for x in "$1"/*.sid; do
  s="`basename "$x"`"
  sx="${s%.*}"
  bbsx="${sx//[^a-zA-Z0-9]/}"
  bbsx="${bbsx^^}"
  sidrelocBRK  --z 20-60 --page 1A --sid-dest-address FC20 "$x" "$INTER/$s" >"$INTER/$sx.brk" 
  x=$?
  if [[ $x -ne 0 ]]; then
    warn "error relocating sid ($x) $s -- skipping"
    continue
  fi
  ripsidBRK "$INTER/$s" "$INTER/$sx.bbc" "$INTER/$sx.brk" 2>"$INTER/$sx.inf"
  x=$?
  if [[ $x -ne 0 ]]; then
    warn "error ripping sid ($x) $s -- skipping"
    cat "$INTER/$sx.inf"
    continue
  fi
  
  da65 -S 0x19F8 --comments 4 "$INTER/$sx.bbc" > "$INTER/$sx.s"
  checkstat "dissasembly"
  
  source "$INTER/$sx.inf"
  cat "$INTER/$sx.inf"
  
  #if [[ "$SID_LOAD" != "1a00" ]]; then
  #  warn "Bad load $SID_LOAD : $s - skipping"
  #  continue;
  #fi
  #if [[ "$SID_INIT" != "1000" ]]; then
  #  warn "Bad init $SID_INIT : $s - skipping"
  #  continue;
  #fi
  #if [[ "$SID_PLAY" != "1003" ]]; then
  #  warn "Bad play $SID_PLAY $s - skipping"
  #  continue;
  #fi

  bbcfn="`printf "S.%02x%-5.5s" "$n" "$bbsx"`"
  
  echo -e -n "`printf $'S.%02x%-5.5s\x0d' "$n" "$bbsx"$'\x0d'`" >>$INTER/menu.m
  printf "%-32s" "$SID_TIT" >> "$INTER/menu.m"
  
  dfs add -l 0x19F8 -e 0x1A00 -f "$bbcfn" "$2" "$INTER/$sx.bbc"
  checkstat "Error adding file $sx to ssd"
  
  n=$((n + 1))
  if [[ $n -gt 26 ]]; then
    break;
  fi
done;

printf "\\x$(printf "%x" $n)" >$INTER/menu.m2
cat $INTER/menu.m >>$INTER/menu.m2

dfs add -l 0x6000 -e 0x6000 -f "sidplay" "$2" "sidplayer/sidpl.bbc"
dfs add -l 0x6000 -e 0x6000 -f "sidpelk" "$2" "sidplayer/sidpelk.bbc"
dfs add -l 0x7C00 -e 0x0000 -f "M.MENU" "$2" "$INTER/menu.m2"

echo -e "MO.7\r*SIDPLAY\r" > $INTER/\!boot
dfs add -f "!BOOT" "$2" "$INTER/\!boot"
dfs opt4 -3 "$2"
dfs title "$2" "Sidplay"

echo $n files written
dfs info "$2"