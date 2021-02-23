using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.NativeBehaviors.BehaviorStateMachine
{
    public class StateMachine
    {
        public Stack<StateMachineState> States 
            = new Stack<StateMachineState>();
        
        public void Run()
        {
            if(States.Count > 0)
            {
                if (States.Peek().Complete())
                {
                    States.Pop();
                    States.Peek().ResetMaxStateTime();
                }

                States.Peek().Tick();
            }
        }
    }
}
