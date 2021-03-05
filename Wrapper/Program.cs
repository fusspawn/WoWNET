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
        public static Tracker Tracker;
        static bool ThrowWowErrors = true;
        public static double CurrentTime = 0f;
        public static bool IsRunning = false;
        public static BotMainUI MainUI;
        public static UnitViewer UnitViewer;
        public static bool IsDeveloperMode = false;

        public static void EnableDevMode()
        {
            if (Program.UnitViewer.UIContainer.MainFrame != null)
            {
                Program.UnitViewer.UIContainer.MainFrame.Show();
                Program.MainUI.UIContainer.ToggleUnitViewer.Show();
            }

        
            if(Tracker.MainUIFrame != null)
            {
                Tracker.MainUIFrame.Show();
            }
        }


        public static void Main(string[] args)
        {
            DebugLog.Log("BroBot", "BroBot V2 Loading");
            LuaBox.Instance.LoadScript("NavigatorNightly");
            LuaBox.Instance.LoadScript("AntiAFK");
            LuaBox.Instance.LoadScript("LibDrawNightly");

            StdUI.Init();
            LibJson.Init();
            ObjectManager.Instance.Pulse();

            DebugLog.Log("BroBot", "BroBot V2 Loaded Libs");

            Program.MainUI = new BotMainUI();
            Program.UnitViewer = new UnitViewer();
            Program.UnitViewer.UIContainer.MainFrame.Hide();

            Tracker = new Tracker();
            Tracker.MainUIFrame.Hide();

            WoWAPI.NewTicker(() =>
            {
                if (!ThrowWowErrors)
                {
                    try
                    {
                        CurrentTime = WoWAPI.GetTime();
                        ObjectManager.Instance.Pulse();
                        UnitViewer.UpdateUI();


                        if (Program.IsRunning)
                        {
                            if (Base != null) { Base.Pulse(); }
                            Tracker.Pulse();
                        }
                    }
                    catch (Exception E)
                    {
                        var DebugStack = WoWAPI.DebugStack();
                        /*
                          [[
                                if DLAPI then DLAPI.DebugLog("ObjectManagerError", E.Message + " StackTrace: " + DebugStack) end                          
                          ]]
                        */

                        DebugLog.Log("BotExceptions", "Exception in mainBot Thread: " + E.Message + " StackTrace: "  + DebugStack);


                        NativeErrorLoggerUI.Instance.AddErrorMessage(E.Message, WoWAPI.DebugStack());
                    }
                }
                else
                {
                    ObjectManager.Instance.Pulse();
                    UnitViewer.UpdateUI();
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
