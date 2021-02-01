using System;
using Wrapper.API;
using Wrapper.ObjectManager;

namespace Wrapper
{
    public class Program
    {
        
        public static void Main(string[] args)
        {
            ObjectManager.ObjectManager.Instance.Pulse();

            WoW.NewTicker(() => {                
                ObjectManager.ObjectManager.Instance.Pulse();
            }, 0.1f);
        }

        public static void DumpPlayers()
        {
            foreach (var player in ObjectManager.ObjectManager.GetAllPlayers(100))
            {
                Console.WriteLine($"Found Player: {player.Name} Health: {player.Health}  HealthMax: {player.HealthMax}");
            }            
        }
    }
}
