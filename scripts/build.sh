#!/usr/bin/env bash
cd "$(dirname "$0")/.."
v -o wyr .
./wyr -s "$1"
if [ $? -eq 0 ]; then
	nasm -felf64 out.asm && ld out.o && ./a.out
fi
