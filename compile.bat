rem Compile first
ca65 src/scrapyard.asm -g -o objdir/scrapyard.o
if %errorlevel% neq 0 exit /b %errorlevel%

rem Link it
ld65 -o scrapyard.nes -C rom.cfg objdir/scrapyard.o -m objdir/scrapyard.map.txt -Ln objdir/scrapyard.labels.txt --dbgfile objdir/scrapyard.nes.dbg
if %errorlevel% neq 0 exit /b %errorlevel%

fceux scrapyard.nes

