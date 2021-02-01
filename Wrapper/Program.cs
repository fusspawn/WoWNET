using System;
using Wrapper.API;
using Wrapper.ObjectManager;

namespace Wrapper
{
    class Program
    {
        
        static void Main(string[] args)
        {
            ObjectManager.ObjectManager.Instance.Pulse();

            Console.WriteLine("Creating Ticker");
            WoW.NewTicker(() => {
                Console.WriteLine("Pulsing OM");
                ObjectManager.ObjectManager.Instance.Pulse();
            }, 0.1f);
            Console.WriteLine("Done With Ticker");
        }

    }
}
