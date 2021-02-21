using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.API
{
    public interface stub_class_please_ignore {
        public virtual void Run() { }
        public virtual bool Exit()
        {
            return false;
        }
    }

    public class BroBotBehavior
        : stub_class_please_ignore
    {
        public string name = "BroBotBehavior";
        public string author = "Fusspawn";
        public bool showInGUI = true;
        public bool canHaveChildren = false;
        public int death_count = 0;
        public int kill_count = 0;
        public bool skip_default_logic = true; //c# has no default logic
        public bool skip_spell_avoidance = true; //not even sure this exists now?!
        public BroBotBehavior[] children = new BroBotBehavior[0];
        public BehaviorPersistentData PersistentData = new BehaviorPersistentData();
        

        public BroBotBehavior()
           
        {
            name = "BroBotBehavior";
            author = "Fusspawn";
            showInGUI = true;
            canHaveChildren = false;
       
             skip_default_logic = true; //c# has no default logic
             skip_spell_avoidance = true; //not even sure this exists now?!
             children = new BroBotBehavior[0];
             PersistentData = new BehaviorPersistentData();
            PersistentData.enabled = true;
                PersistentData.minfood = 0;
            PersistentData.minfoodbuy = 0;

            PersistentData.minwater = 0;
            PersistentData.minwaterbuy = 0;
         }


        public bool Exit()
        {
            return false;
        }

        public void Run()
            => Console.WriteLine("Fucking Single Line Run Magics");
    }

    public class BehaviorPersistentData
    {
        public bool enabled;
        public int minwater = 0;
        public int minfood = 0;
        public int minwaterbuy = 0;
        public int minfoodbuy = 0;
    }
}
