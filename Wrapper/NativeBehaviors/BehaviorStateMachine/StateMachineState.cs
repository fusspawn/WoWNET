using System;
using System.Collections.Generic;
using Wrapper.API;

namespace Wrapper.NativeBehaviors.BehaviorStateMachine
{
    public class StateMachineState
    {
        public double EntryTime = 0;
        public double MaxStateTime = 0;
        public bool HasMaxStateTime = false;
        protected string _StringRepr = "";

        public void ResetMaxStateTime()
        {
            EntryTime =Program.CurrentTime;
        }




        public bool IsOutOfTime()
        {
            if (EntryTime == 0)
            {
                EntryTime = Program.CurrentTime;
            }

            if (!HasMaxStateTime)
                return false;

            //Console.WriteLine($"Out Of time Data: Current: {WoWAPI.GetTime()}   Entry: {EntryTime} Max: {MaxStateTime}");
            return Program.CurrentTime - EntryTime > MaxStateTime;
        }

        public string StringRepr()
        {
            return this.GetType().Name +": "+ _StringRepr;
        }

        public Dictionary<string, object> DebugDump()
        {
            return new Dictionary<string, object>();
        }

        public void SetMaxStateTime(double Seconds)
        {
            MaxStateTime = Seconds;
            HasMaxStateTime = true;
        }

        public virtual bool Complete() { return true; }
        public virtual void Tick()
        { 
            if(EntryTime == 0)
            {
                EntryTime =Program.CurrentTime;
            }
        }
    }
}