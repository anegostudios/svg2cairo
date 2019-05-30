@echo off
cd bin/
svg2cairoxml ../%1 %1.xml
lua cairoxml2cairo.lua -f cs %1.xml ../%1.cs
del %1.xml
cd ..