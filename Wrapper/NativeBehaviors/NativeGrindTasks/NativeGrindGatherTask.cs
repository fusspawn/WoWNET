using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.Helpers;
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
            if (WoWAPI.UnitIsDeadOrGhost("player"))
                return true;

           Console.WriteLine("In Gather Complete");
           Console.WriteLine($"Object Exists: {LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID)}");
           Console.WriteLine($"GatherAndNotCasting: {(HasGathered && !ObjectManager.Instance.Player.IsCasting && !ObjectManager.Instance.Player.IsChanneling)}");
           Console.WriteLine($"InCombat: {WoWAPI.UnitAffectingCombat("player")}");
           Console.WriteLine($"Out Of Time: {IsOutOfTime()}");
           Console.WriteLine($"BlackList: {Blacklist.IsOnBlackList(Task.TargetUnitOrObject.GUID)}");

            return (!LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID)
                && Vector3.Distance(Task.TargetUnitOrObject.Position, ObjectManager.Instance.Player.Position) < 300) // Some paths are really long. dont remove it unless you've been dragged really far away
                || (HasGathered && !ObjectManager.Instance.Player.IsCasting && !ObjectManager.Instance.Player.IsChanneling)
                || ObjectManager.Instance.Player.IsInCombat
                || IsOutOfTime();
        }


        public override void Tick()
        {
            Task.TargetUnitOrObject.Update();

            var Distance = Vector3.Distance(Task.TargetUnitOrObject.Position,
                    ObjectManager.Instance.Player.Position);

            if (Distance > 5)
            {
                SetMaxStateTime(60 * 5); // Can spend at MAX 5 mins trying to get to the target node;
                _StringRepr = $"NativeGatherTask Getting Closer: {(int)Distance} TaskLocation: {Task.TargetUnitOrObject.Position} Player: {ObjectManager.Instance.Player.Position}";
                LuaBox.Instance.Navigator.MoveTo(Task.TargetUnitOrObject.Position.X, Task.TargetUnitOrObject.Position.Y, Task.
                    TargetUnitOrObject.Position.Z);
                return;
            }

            _StringRepr = "Interacting";
            LuaBox.Instance.Navigator.Stop();
            SetMaxStateTime(5); // If we spend more than 5 seconds doing this. Just bail. If its still valid the object manager will reassign

            if (ObjectManager.Instance.Player.IsCasting
                || ObjectManager.Instance.Player.IsChanneling)
            {
                Console.WriteLine($"Blacklisting Gather Node");
                Blacklist.AddToBlacklist(Task.TargetUnitOrObject.GUID, 120);
                HasGathered = true;
            }
            else {
                LuaBox.Instance.ObjectInteract(Task.TargetUnitOrObject.GUID);
                Blacklist.AddToBlacklist(Task.TargetUnitOrObject.GUID, 120);
                //HasGathered = true;
            }

            base.Tick();
        }
    }
}
