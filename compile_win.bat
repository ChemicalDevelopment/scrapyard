.\compilers\NESASM3_win.exe .\src\scrapyard.asm

del .\src\scrapyard.fns
del .\src\scrapyard.fns
move .\src\scrapyard.nes .\out\scrapyard.nes

fceux .\out\scrapyard.nes

pause