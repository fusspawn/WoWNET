using System;
using Wrapper.API;
using Wrapper.Helpers;
using Wrapper.UI;
using Wrapper.WoW;

namespace Wrapper
{
    public class Program
    {
        public static BotBase Base = null;
        public static Tracker Tracker = new Tracker();
        static bool ThrowWowErrors = true;
        public static double CurrentTime = 0f;
        public static bool IsRunning = false;
        public static BotMainUI MainUI;

        public static void Main(string[] args)
        {
            Console.WriteLine("BroBot V2 Loading");
            LuaBox.Instance.LoadScript("NavigatorNightly");
            LuaBox.Instance.LoadScript("AntiAFK");
            LuaBox.Instance.LoadScript("LibDrawNightly");

            StdUI.Init();
            LibJson.Init();
            ObjectManager.Instance.Pulse();

            Console.WriteLine("BroBot V2 Loaded Libs");

            Program.MainUI = new BotMainUI();

            WoWAPI.NewTicker(() =>
            {
                if (!ThrowWowErrors)
                {
                    try
                    {
                        CurrentTime = WoWAPI.GetTime();
                        ObjectManager.Instance.Pulse();
                        
                        if (Program.IsRunning)
                        {
                            if (Base != null) { Base.Pulse(); }
                            Tracker.Pulse();
                        }
                    }
                    catch (Exception E)
                    {
                        Console.WriteLine("Exception in mainBot Thread: " + E.Message + " StackTrace: "  + WoWAPI.DebugStack());
                        NativeErrorLoggerUI.Instance.AddErrorMessage(E.Message, WoWAPI.DebugStack());
                    }
                }
                else
                {
                    ObjectManager.Instance.Pulse();

                    if (Program.IsRunning)
                    {
                        if (Base != null) { Base.Pulse(); }

                       Tracker.Pulse();
                    }
                }

            }, 0.2f);

            WoWAPI.NewTicker(() =>
            {
                Program.CurrentTime = WoWAPI.GetTime();

                if(Program.Base != null && Program.IsRunning)
                {
                    Program.Base.DrawDebug();
                }

            }, 0);
         }
    }
}
