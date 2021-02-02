using System;
using Wrapper.API;
using Wrapper.WoW;

namespace Wrapper
{
    public class Program
    {
        static BotBase Base = new PVPBotBase();
        
        public static void Main(string[] args)
        {
            LuaBox.Instance.LoadScript("NavigatorNightly");

            ObjectManager.Instance.Pulse();

            WoWAPI.NewTicker(() => {                
                ObjectManager.Instance.Pulse();
                Base.Pulse();
            }, 0.1f);
        }

        public static void DumpPlayers()
        {
            foreach (var player in ObjectManager.GetAllPlayers(100))
            {
                Console.WriteLine($"Found Player: {player.Name} Health: {player.Health}  HealthMax: {player.HealthMax} Position: {player.Position}");   
            }

            Console.WriteLine($"Found Player: {ObjectManager.Instance.Player.Name} Health: {ObjectManager.Instance.Player.Health}  HealthMax: {ObjectManager.Instance.Player.HealthMax} Position: {ObjectManager.Instance.Player.Position}");
        }

        public static void NavTest_MoveToTarget()
        {
            var TargetGUID = LuaBox.Instance.UnitTarget("player");
            if (TargetGUID == null)
            {
                Console.WriteLine("[NavTestFailed] Unable to find Target");
                return;
            }

            var TargetObject = ObjectManager.Instance.AllObjects[TargetGUID];
            if (TargetObject == null)
            {
                Console.WriteLine("[NavTestFailed] TargetGUID not present in ObjectManager");
                return;
            }

            Console.WriteLine($"[NavTest] Moving To: {TargetObject.Position}");
            LuaBox.Instance.Navigator.MoveTo(TargetObject.Position.X, TargetObject.Position.Y, TargetObject.Position.Z, 1, 2);
        }
    }
}
