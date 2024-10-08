﻿using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.Helpers;

namespace Wrapper.UI
{
    class SlashCommands
    {
        public static void RegisterSlashCommand(string command, Action Function)
        {
            LuaHelper.SetGlobalIn_G("SLASH_" + command, "/" + command);
            /*
             [[

                SlashCmdList[command] = Function;
             ]]
            */

            DebugLog.Log("BroBot", "Registed /" + command + " slash command");
        }
    }
}
