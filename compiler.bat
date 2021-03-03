D:
cd D:\WoWNet\WoWNET
set dir=D:\WoWNet\Compiler\
set coredir=D:\WoWNet\CoreSystem.Lua\
dotnet "%dir%CSharp.lua.Launcher.dll" -p -a -e -c -include %coredir% -s Wrapper -d out
