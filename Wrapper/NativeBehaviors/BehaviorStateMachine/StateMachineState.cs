using System;
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
            EntryTime = WoWAPI.GetTime();
        }




        public bool IsOutOfTime()
        {
            if (EntryTime == 0)
            {
                EntryTime = WoWAPI.GetTime();
            }

            if (!HasMaxStateTime)
                return false;

            //Console.WriteLine($"Out Of time Data: Current: {WoWAPI.GetTime()}   Entry: {EntryTime} Max: {MaxStateTime}");
            return WoWAPI.GetTime() - EntryTime > MaxStateTime;
        }

        public string StringRepr()
        {
            return this.GetType().Name +": "+ _StringRepr;
        }

        public void SetMaxStateTime(double Seconds)
        {
            MaxStateTime = Seconds;
            HasMaxStateTime = true;
        }

        public virtual string StringRepr()
        {
            return "StateMachineState";
        }

        public virtual bool Complete() { return true; }
        public virtual void Tick()
        { 
            if(EntryTime == 0)
            {
                EntryTime = WoWAPI.GetTime();
            }
        }
    }
}