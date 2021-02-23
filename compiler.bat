D:
cd D:\WoWNET\WoWNET
set dir=D:\WoWNET\Compiler\
set coredir=D:\WoWNET\CoreSystem.Lua\
dotnet "%dir%CSharp.lua.Launcher.dll" -p -a -e -c -include %coredir% -s Wrapper -d out
