using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.API
{
    public class DebugLog
    {
        public static void Log(string Object = "BroBot", string Message="", bool Print=false)
        {
            /*
                [[
                                if DLAPI then DLAPI.DebugLog(Object, Message) else print("[" .. Object .. "]: " .. Message) end                          
                ]]
            */

            if (Print)
                Console.WriteLine("BroBot", Message);
        }
    }
}
