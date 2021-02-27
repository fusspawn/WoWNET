using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;

namespace Wrapper.Helpers
{
    public static class Blacklist
    {
        public static Dictionary<string, double> BlackListEntrys
            = new Dictionary<string, double>();

        public static bool IsOnBlackList(string GUID)
        {
            if (!BlackListEntrys.ContainsKey(GUID))
                return false;

            if (BlackListEntrys[GUID] > Program.CurrentTime)
                return true;

            BlackListEntrys.Remove(GUID);
            return false;
        }


        public static void AddToBlacklist(string GUID, double NumSeconds)
        {
            BlackListEntrys[GUID] = Program.CurrentTime + NumSeconds;
        }
    }
}
