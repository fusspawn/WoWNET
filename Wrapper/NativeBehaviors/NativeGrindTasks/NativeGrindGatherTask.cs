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
            if (WoWAPI.UnitIsDeadOrGhost("player"))
                return true;
/*
           Console.WriteLine("In Gather Complete");
           Console.WriteLine($"Object Exists: {LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID)}");
           Console.WriteLine($"GatherAndNotCasting: {(HasGathered && !ObjectManager.Instance.Player.IsCasting && !ObjectManager.Instance.Player.IsChanneling)}");
           Console.WriteLine($"InCombat: {WoWAPI.UnitAffectingCombat("player")}");
           Console.WriteLine($"Out Of Time: {IsOutOfTime()}");
*/
            return (!LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID) 
                && Vector3.Distance(Task.TargetUnitOrObject.Position, ObjectManager.Instance.Player.Position) < 300) // Some paths are really long. dont remove it unless you've been dragged really far away
                || (HasGathered && !ObjectManager.Instance.Player.IsCasting && !ObjectManager.Instance.Player.IsChanneling) 
                || WoWAPI.UnitAffectingCombat("player") 
                || IsOutOfTime();
        }

        public override void Tick()
        {
            //BroBotAPI.BroBotDebugMessage("NativeGatherTask", "In Gather Tick");
            var Distance = Vector3.Distance(Task.TargetUnitOrObject.Position,
                ObjectManager.Instance.Player.Position);


            if (Distance > 5)
            {
                BroBotAPI.BroBotDebugMessage("NativeGatherTask",$"Getting Closer: {Distance} TaskLocation: {Task.TargetUnitOrObject.Position} Player: {ObjectManager.Instance.Player.Position}");
                LuaBox.Instance.Navigator.MoveTo(Task.TargetUnitOrObject.Position.X, Task.TargetUnitOrObject.Position.Y, Task.
                    TargetUnitOrObject.Position.Z);
                return;
            }

            BroBotAPI.BroBotDebugMessage("NativeGatherTask", "Interacting");

            LuaBox.Instance.Navigator.Stop();
           

            if (ObjectManager.Instance.Player.IsCasting
                || ObjectManager.Instance.Player.IsChanneling)
            {
                Console.WriteLine($"Blacklisting Gather Node");
                BroBotAPI.RegisterOnBlackList(Task.TargetUnitOrObject.GUID, 120);
                HasGathered = true;
            }
            else {
                LuaBox.Instance.ObjectInteract(Task.TargetUnitOrObject.GUID);
            }

            HasGathered = true;
            base.Tick();
        }
    }
}
