using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.NativeBehaviors.BehaviorStateMachine;
using Wrapper.WoW;

namespace Wrapper.NativeBehaviors
{
    public class NativeGrind 
    {
        public string name = "NativeGrind";
        public string author = "Fusspawn";
        public bool showInGUI = true;
        public bool canHaveChildren = false;
        public int death_count = 0;
        public int kill_count = 0;
        public bool skip_default_logic = true; //c# has no default logic
        public bool skip_spell_avoidance = true; //not even sure this exists now?!
        public BroBotBehavior[] children = new BroBotBehavior[0];
        public static StateMachine StateMachine;


        public BehaviorPersistentData PersistentData = new BehaviorPersistentData();

        public NativeGrind()
        {
            name = "NativeGrind";
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
            StateMachine = new StateMachine();
            StateMachine.States.Push(new NativeGrindBaseState());
        }

        public double LastRun = WoWAPI.GetTime();
        public void Run() {

            if (WoWAPI.GetTime() - LastRun > 0.5)
            {
                LastRun = WoWAPI.GetTime();
                //ObjectManager.Instance.Pulse();
                StateMachine.Run();
            }
        }

        public bool Exit() { return false; }
    }
}
