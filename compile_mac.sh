#!/bin/sh

./compilers/nesasm_mac ./src/scrapyard.asm

rm src/scrapyard.fns
mv src/scrapyard.nes out/


