using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.WoW;

namespace Wrapper.NativeBehaviors.NativeGrindTasks
{
    public class NativeGrindLootTask 
        : BehaviorStateMachine.StateMachineState {
        private NativeGrindSmartObjective.SmartObjectiveTask Task;
        private bool HasLooted;

        public NativeGrindLootTask(NativeGrindSmartObjective.SmartObjectiveTask Task)
        {
            this.Task = Task;
            SetMaxStateTime(120);
        }

        public override bool Complete()
        {
            return (!LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID)
                || HasLooted
                || WoWAPI.UnitAffectingCombat("player") || IsOutOfTime());
        }


        public override void Tick()
        {
            var Distance = Vector3.Distance(Task.TargetUnitOrObject.Position,
                ObjectManager.Instance.Player.Position);

            var TaskUnit = Task.TargetUnitOrObject as WoWUnit;
            TaskUnit.PlayerHasFought = true;

            if (Distance > 5)
            {
                _StringRepr = $"Getting Closer: {(int)Distance} TaskLocation: {Task.TargetUnitOrObject.Position} Player: {ObjectManager.Instance.Player.Position}";
                LuaBox.Instance.Navigator.MoveTo(
                    Task.TargetUnitOrObject.Position.X, 
                    Task.TargetUnitOrObject.Position.Y,
                    Task.TargetUnitOrObject.Position.Z);
                return;
            }

            /* 
            [[
                    local xy = AngleTo("Target", "Player")
                    __LB__.SetPlayerAngles(xy)
            ]] 
            */


            LuaBox.Instance.Navigator.Stop();
            LuaBox.Instance.ObjectInteract(Task.TargetUnitOrObject.GUID);
            _StringRepr = "Killing Unit " + Task.TargetUnitOrObject.Name;
            HasLooted = true;

            WoWAPI.After(() => {
                BroBotAPI.RegisterOnBlackList(Task.TargetUnitOrObject.GUID, 120);
            }, 3f);
            base.Tick();
        }
    }
}
