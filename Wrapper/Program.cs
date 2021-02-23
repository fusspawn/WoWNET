using System;
using Wrapper.API;
using Wrapper.Helpers;
using Wrapper.UI;
using Wrapper.WoW;

namespace Wrapper
{
    public class Program
    {
        static BotBase Base = new DataLoggerBase();
        public static Tracker Tracker = new Tracker();
        static bool ThrowWowErrors = false;


        public static void Main(string[] args)
        {
            LuaBox.Instance.LoadScript("NavigatorNightly");
            LuaBox.Instance.LoadScript("AntiAFK");
            LuaBox.Instance.LoadScript("LibDrawNightly");
            StdUI.Init();
            LibJson.Init();

            Console.WriteLine("Pulsed OM");
            ObjectManager.Instance.Pulse();

            Console.WriteLine("Pulsed OM Complete");
            WoWAPI.NewTicker(() =>
            {
                if (!ThrowWowErrors)
                {
                    try
                    {
                        ObjectManager.Instance.Pulse();
                        Base.Pulse();
                        Tracker.Pulse();
                        //Console.WriteLine("New Ticker");
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
                    Base.Pulse();
                    Tracker.Pulse();
                }

            }, 0.2f);




            WoWAPI.After(() =>
            {
                if (LuaHelper.GetGlobalFrom_G<dynamic>("BroBot") == null)
                {
                    Console.WriteLine("Wont load brobot cc's brobot disabled");
                    return;
                }

                //Console.WriteLine("Attempting to Register C# CC");
                //BroBotAPI.registerFighter("CHunter", new HunterCCTest());
                //Console.WriteLine("Has Registered Fighter");


                Console.WriteLine("Attempting to Register Native Behavior");
                //BroBotAPI.registerBehavior("BroBotBehavior", new BroBotBehavior());
                BroBotAPI.registerBehavior("NativeGrind", new NativeBehaviors.NativeGrind());
                Console.WriteLine("Registered Native Behaviors");

            }, 2.5f);
         }
    }
}
