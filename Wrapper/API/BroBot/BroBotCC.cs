using System;

namespace Wrapper.API
{
    public class BroBotCC
    {
        public string Class = "Unknown";
        public string Name = "Unknown";

        public virtual void Rotation() { }
    }

    public class PersistentData
    {
        public double range = 5;
        public string Author = "CBot";
    }

    public class HunterCCTest

    {
        public string Class = "HUNTER";
        public string Name = "CHunter";
        public PersistentData PersistentData;

        public HunterCCTest()
        {
            this.PersistentData = new PersistentData();
            this.PersistentData.range = 5;
            this.PersistentData.Author = "CBot";

            this.Class = "HUNTER";
            this.Name = "CHunter";
        }

        public void Rotation()
        {
            Console.WriteLine("c#s in your rotation. ");
        }
    }
}