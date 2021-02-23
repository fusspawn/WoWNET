C:
cd C:\brobotc\WoWNET
set dir=C:\brobotc\Compiler\
set coredir=C:\brobotc\CoreSystem.Lua\
dotnet "%dir%CSharp.lua.Launcher.dll" -p -a -e -c -include %coredir% -s Wrapper -d out
