using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.Helpers;
using Wrapper.WoW;

namespace Wrapper.NativeBehaviors.NativeGrindTasks
{
    public class NativeGrindKillTask 
        : BehaviorStateMachine.StateMachineState {
        private NativeGrindSmartObjective.SmartObjectiveTask Task;
        private double LastCombatCheck = 0;

        public NativeGrindKillTask(NativeGrindSmartObjective.SmartObjectiveTask Task)
        {
            this.Task = Task;
            SetMaxStateTime(120);
        }

        public override bool Complete()
        {
            if (IsOutOfTime())
            {
                Console.WriteLine("IsOutOfTime");
                return true;
            }

            if (WoWAPI.UnitIsDeadOrGhost("player"))
            {

                Console.WriteLine("IsGhost?!");
                return true;
            }

            /*
            if (!WoWAPI.UnitAffectingCombat("player"))
                return true;
            */

            if (!LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID))
            {

                Console.WriteLine("!ObjectExists");
                return true;
            }
            

            /*
            NativeGrindBaseState.SmartObjective.Update();
            if (NativeGrindBaseState.SmartObjective.GetNextTask() != Task)
            {
                return true;
            }
            */


            return
                (!LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID)
                ||  WoWAPI.UnitIsDeadOrGhost(Task.TargetUnitOrObject.GUID)
              /*  || !WoWAPI.UnitAffectingCombat("player") */
                || IsOutOfTime()); 
        }

        public override void Tick()
        {
            if (LastCombatCheck == 0)
                LastCombatCheck = Program.CurrentTime;

          
            if(WoWAPI.GetTime() - LastCombatCheck > 0.5)
            {
                NativeGrindBaseState.SmartObjective.Update();
                var NextTask = NativeGrindBaseState.SmartObjective.GetNextTask();

                if (NextTask != null && NextTask.TaskType == NativeGrindSmartObjective.SmartObjectiveTaskType.Kill && NextTask.TargetUnitOrObject.GUID != Task.TargetUnitOrObject.GUID)
                {
                    Task = NextTask;
                    Console.WriteLine("Reassigning Kill Task to better target");
                }

                LastCombatCheck =Program.CurrentTime;
            }

            Console.WriteLine("In Combat Task");
            var Distance = Vector3.Distance(Task.TargetUnitOrObject.Position,
                ObjectManager.Instance.Player.Position);
            var CombatRange = 5;
            /*
              [[
                --local xy = AngleTo("Target", "Player")
                --__LB__.SetPlayerAngles(xy)
             ]] 
             */

            (Task.TargetUnitOrObject as WoWUnit).PlayerHasFought = true;

            if (Distance > CombatRange)
            {
                _StringRepr = $"Getting Closer: {Distance} TaskLocation: {Task.TargetUnitOrObject.Position} Player: {ObjectManager.Instance.Player.Position}";
                LuaBox.Instance.Navigator.MoveTo(Task.TargetUnitOrObject.Position.X, Task.TargetUnitOrObject.Position.Y, Task.TargetUnitOrObject.Position.Z);
                return;
            }
            else
            {
                /*
                [[
                     if IsMounted() then
                        Dismount()
                     end
                ]]*/

                _StringRepr = "Killing mob: " + Task.TargetUnitOrObject.Name + " has fought: " + (Task.TargetUnitOrObject as WoWUnit).PlayerHasFought;
                LuaBox.Instance.Navigator.Stop();
                WoWAPI.TargetUnit(Task.TargetUnitOrObject.GUID);
                LuaBox.Instance.ObjectInteract(Task.TargetUnitOrObject.GUID);

                WoWAPI.RunMacroText("/startattack");
                WoWAPI.StartAttack();
                var TaskUnit = Task.TargetUnitOrObject as WoWUnit;
                TaskUnit.PlayerHasFought = true;
            }

            base.Tick();
        }
    }
}
