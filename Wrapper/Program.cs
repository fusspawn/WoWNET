using System;
using Wrapper.API;

namespace Wrapper
{
    class Program
    {
        
        static void Main(string[] args)
        {
            var lb = new LuaBox();

           foreach(var GUID in lb.GetObjects(100))
            {
                Console.WriteLine($"Found GUID: {GUID}");
            }
        }
    }
}
