using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Wrapper.API;
using Wrapper.Helpers;
using Wrapper.NativeBehaviors.BehaviorStateMachine;
using static Wrapper.StdUI;

namespace Wrapper.UI
{
    public class Tracker :
        BotBase
    {

        StdUI _StdUI;
        public StdUiFrame MainUIFrame;
        public StdUiLabel TaskLabel;
        public StdUiLabel StateStack;

        public Tracker()
        {
            if (MainUIFrame == null)
            {
                _StdUI = Program.MainUI.StdUI;
                MainUIFrame = _StdUI.Window(LuaHelper.GetGlobalFrom_G<WoWFrame>("UIParent"), 500, 600, "BroBot Tracker");
                MainUIFrame.SetPoint("CENTER", 0, 0);
                MainUIFrame.Show();

                TaskLabel = _StdUI.Label(MainUIFrame, "", 12, null, 500, 25);
                _StdUI.GlueTop(TaskLabel, MainUIFrame, 0, -50, "TOP");

                StateStack = _StdUI.Label(MainUIFrame, "", 12, null, 500, 300);
                _StdUI.GlueTop(StateStack, MainUIFrame, 0, -100, "TOP");
            }
        }

        public override void Pulse()
        {
          
        }

        public void UpdateStack(Stack<StateMachineState> States)
        {
            if (MainUIFrame.IsShown())
            {
                var returnstring = "";

                foreach (var state in States.Skip(1))
                {
                    returnstring += state.StringRepr() + "\n";
                }

                StateStack.SetText(returnstring);
            }
        }
    }
}