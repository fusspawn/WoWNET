C:
cd c:\brobotc\WoWNET
set dir=c:\brobotc\Compiler\
set coredir=c:\brobotc\CoreSystem.Lua\
dotnet "%dir%CSharp.lua.Launcher.dll" -p -a -e -c -include %coredir% -s Wrapper -d out
