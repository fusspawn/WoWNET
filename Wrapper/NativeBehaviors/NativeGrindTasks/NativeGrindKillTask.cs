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

            if (Distance > 5)
            {
                Console.WriteLine($"Getting Closer: {Distance} TaskLocation: {Task.TargetUnitOrObject.Position} Player: {ObjectManager.Instance.Player.Position}");
                LuaBox.Instance.Navigator.MoveTo(
                    Task.TargetUnitOrObject.Position.X, 
                    Task.TargetUnitOrObject.Position.Y,
                    Task.TargetUnitOrObject.Position.Z);
                return;
            }

            LuaBox.Instance.ObjectInteract(Task.TargetUnitOrObject.GUID);
            HasLooted = true;

            WoWAPI.After(() => {
                BroBotAPI.RegisterOnBlackList(Task.TargetUnitOrObject.GUID, 120);
            }, 3f);
            base.Tick();
        }
    }
}
