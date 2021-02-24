using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.WoW;

namespace Wrapper.NativeBehaviors.NativeGrindTasks
{
    public class NativeGrindKillTask 
        : BehaviorStateMachine.StateMachineState {
        private NativeGrindSmartObjective.SmartObjectiveTask Task;

        public NativeGrindKillTask(NativeGrindSmartObjective.SmartObjectiveTask Task)
        {
            this.Task = Task;
            SetMaxStateTime(120);
        }

        public override bool Complete()
        {
            if (WoWAPI.UnitIsDeadOrGhost("player"))
                return true;

            return
                (!LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID)
                ||  WoWAPI.UnitIsDeadOrGhost(Task.TargetUnitOrObject.GUID)
              /*  || !WoWAPI.UnitAffectingCombat("player") */
                || IsOutOfTime()); 
        }

        public override void Tick()
        {
          
            Console.WriteLine("In Combat Task");

            var Distance = Vector3.Distance(Task.TargetUnitOrObject.Position,
                ObjectManager.Instance.Player.Position);

            var CombatRange = BroBotAPI.GetPlayersRange();
                /*
                  [[
                   -- local xy = AngleTo("Target", "Player")
                    --__LB__.SetPlayerAngles(xy)
                 ]] 
                 */


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
                LuaBox.Instance.UnitTarget(Task.TargetUnitOrObject.GUID);
                WoWAPI.StartAttack();
                var TaskUnit = Task.TargetUnitOrObject as WoWUnit;
                TaskUnit.PlayerHasFought = true;
            }

            base.Tick();
        }
    }
}
