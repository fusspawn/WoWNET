using System;
using Wrapper.API;
using Wrapper.Helpers;
using Wrapper.WoW;

namespace Wrapper
{
    public class Program
    {
        static BotBase Base = new DataLoggerBase();
        static bool ThrowWowErrors = true;


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
                        //Console.WriteLine("New Ticker");
                    }
                    catch (Exception E)
                    {
                        Console.WriteLine("Exception in mainBot Thread: " + E.Message + " StackTrace: "  + WoWAPI.DebugStack());

                    }
                }
                else
                {
                    ObjectManager.Instance.Pulse();
                    Base.Pulse();
                }

            }, 0.1f);




            WoWAPI.After(() =>
            {
                if (LuaHelper.GetGlobal<dynamic>("BroBot") == null)
                {
                    Console.WriteLine("Wont load brobot cc's brobot disabled");
                    return;
                }

                //Console.WriteLine("Attempting to Register C# CC");
                //BroBotAPI.registerFighter("CHunter", new HunterCCTest());
                //Console.WriteLine("Has Registered Fighter");


                Console.WriteLine("Attempting to Register Native Behavior");
                //BroBotAPI.registerBehavior("BroBotBehavior", new BroBotBehavior());
                //BroBotAPI.registerBehavior("NativeGrind", new NativeBehaviors.NativeGrind());
                Console.WriteLine("Registered Native Behaviors");

            }, 5);
         }
    }
}
