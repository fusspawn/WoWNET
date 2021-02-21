using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.WoW;

namespace Wrapper.NativeBehaviors.NativeGrindTasks
{
    public class NativeGrindGatherTask 
        : BehaviorStateMachine.StateMachineState {
        private NativeGrindSmartObjective.SmartObjectiveTask Task;
        private bool HasGathered;

        public NativeGrindGatherTask(NativeGrindSmartObjective.SmartObjectiveTask Task) {
            this.Task = Task;
            SetMaxStateTime(120);
        }

        public override bool Complete()
        {
/*
            Console.WriteLine("In Gather Complete");
            Console.WriteLine($"Object Exists: {LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID)}");
            Console.WriteLine($"GatherAndNotCasting: {(HasGathered && !ObjectManager.Instance.Player.IsCasting && !ObjectManager.Instance.Player.IsChanneling)}");
            Console.WriteLine($"InCombat: {WoWAPI.UnitAffectingCombat("player")}");
            Console.WriteLine($"Out Of Time: {IsOutOfTime()}");
*/
            return (!LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID)) 
                || (HasGathered && !ObjectManager.Instance.Player.IsCasting && !ObjectManager.Instance.Player.IsChanneling) 
                || WoWAPI.UnitAffectingCombat("player") || IsOutOfTime();
        }

        public override void Tick()
        {
            Console.WriteLine("In Gather Tick");
            var Distance = Vector3.Distance(Task.TargetUnitOrObject.Position,
                ObjectManager.Instance.Player.Position);


            if (Distance > 5)
            {
                Console.WriteLine($"Getting Closer: {Distance} TaskLocation: {Task.TargetUnitOrObject.Position} Player: {ObjectManager.Instance.Player.Position}");
                LuaBox.Instance.Navigator.MoveTo(Task.TargetUnitOrObject.Position.X, Task.TargetUnitOrObject.Position.Y, Task.
                    TargetUnitOrObject.Position.Z);
                return;
            }

            Console.WriteLine("Interacting");
            LuaBox.Instance.ObjectInteract(Task.TargetUnitOrObject.GUID);
            WoWAPI.After(() => {
                BroBotAPI.RegisterOnBlackList(Task.TargetUnitOrObject.GUID, 120);
            }, 3f);


            HasGathered = true;
            base.Tick();
        }
    }
}
