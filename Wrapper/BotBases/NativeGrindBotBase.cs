using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.NativeBehaviors;
using Wrapper.NativeBehaviors.BehaviorStateMachine;
using Wrapper.WoW;

namespace Wrapper.BotBases
{
    public class NativeGrindBotBase 
        : BotBase
    {
        public string name = "NativeGrind";
        public string author = "Fusspawn";
        public static StateMachine StateMachine;

        public NativeGrindBotBase()
        {
            name = "NativeGrind";
            StateMachine = new StateMachine();
            StateMachine.States.Push(new NativeGrindBaseState());
        }

        public double LastRun = Program.CurrentTime;
        public override void Pulse() { 
                StateMachine.Run();
        }

        public override void BuildConfig(StdUI.StdUiFrame Container)
        {
            base.BuildConfig(Container);
        }
    }
}
