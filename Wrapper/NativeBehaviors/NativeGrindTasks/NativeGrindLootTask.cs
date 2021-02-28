using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.Helpers;
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
            SetMaxStateTime(5);
        }

        public override bool Complete()
        {
            if (WoWAPI.UnitIsDeadOrGhost("player"))
                return true;
            return (!LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID)
                || HasLooted
                || ObjectManager.Instance.Player.IsInCombat || IsOutOfTime());
        }

        public override void Tick()
        {
            var Distance = Vector3.Distance(Task.TargetUnitOrObject.Position,
                ObjectManager.Instance.Player.Position);

            var TaskUnit = Task.TargetUnitOrObject as WoWUnit;
            TaskUnit.PlayerHasFought = true;
            Task.TargetUnitOrObject.Update();


            if (Distance > 5)
            {
                 _StringRepr = $"Getting Closer: {Distance} TaskLocation: {Task.TargetUnitOrObject.Position} Player: {ObjectManager.Instance.Player.Position}";
                LuaBox.Instance.Navigator.MoveTo(
                    Task.TargetUnitOrObject.Position.X, 
                    Task.TargetUnitOrObject.Position.Y,
                    Task.TargetUnitOrObject.Position.Z, 1, 4);
                return;
            }

     

            LuaBox.Instance.Navigator.Stop();
            LuaBox.Instance.ObjectInteract(Task.TargetUnitOrObject.GUID);
            HasLooted = true;

            WoWAPI.After(() => {
               Blacklist.AddToBlacklist(Task.TargetUnitOrObject.GUID, 120);
            }, 3f);
            base.Tick();
        }
    }
}
