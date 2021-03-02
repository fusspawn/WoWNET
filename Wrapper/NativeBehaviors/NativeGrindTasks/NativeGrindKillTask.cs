using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.BotBases;
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
            SetMaxStateTime(5);
        }

        public override bool Complete()
        {
            if (IsOutOfTime())
            {
               
                return true;
            }

            if (WoWAPI.UnitIsDeadOrGhost("player"))
            {
                return true;
            }

            var NextTask = NativeGrindBaseState.SmartObjective.GetNextTask(true);
            if (NextTask != null && NextTask.TaskType != NativeGrindSmartObjective.SmartObjectiveTaskType.Kill)
            {
               return true;
            }

            /*
            if (!WoWAPI.UnitAffectingCombat("player"))
                return true;
            */

            if (!LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID))
            {
                return true;
            }

            if (WoWAPI.UnitIsDead(Task.TargetUnitOrObject.GUID))
            {
                return true;
            } 

            if(Blacklist.IsOnBlackList(Task.TargetUnitOrObject.GUID))
            {
                return true;
            }

            return false;
        }

        private double LastFaceDirection = Program.CurrentTime;

        public override void Tick()
        {
            if (LastCombatCheck == 0)
                LastCombatCheck = Program.CurrentTime;

          
            /*
            if(WoWAPI.GetTime() - LastCombatCheck > 2.5)
            {
                NativeGrindBaseState.SmartObjective.Update();

                var NextTask = NativeGrindBaseState.SmartObjective.GetNextTask();

                if (NextTask != null && NextTask.TaskType == NativeGrindSmartObjective.SmartObjectiveTaskType.Kill 
                        && NextTask.TargetUnitOrObject.GUID != Task.TargetUnitOrObject.GUID)
                {
                    Task = NextTask;
                    DebugLog.Log("BroBot", "Reassigning Kill Task to better target");
                }

                LastCombatCheck = Program.CurrentTime;
            }
            */

            //DebugLog.Log("BroBot", "In Combat Task");
            Task.TargetUnitOrObject.Update();
            var TaskUnit = Task.TargetUnitOrObject as WoWUnit;

            /*
            if(TaskUnit.UnitIsFlying() 
                && (TaskUnit.TargetGUID != ObjectManager.Instance.Player.GUID))
            {
                Blacklist.AddToBlacklist(TaskUnit.GUID, 5);
                return;
            }
            */

            bool IsReachable = true;
            
            /*
            [[
                if not __LB__.NavMgr_IsReachable(TaskUnit.Position.X, TaskUnit.Position.Y, TaskUnit.Position.Z) then
                    IsReachable = false;
                end                    
            ]]
            */

            if(!IsReachable)
            {
                Blacklist.AddToBlacklist(TaskUnit.GUID, 20);
            }

            var Distance = Vector3.Distance(Task.TargetUnitOrObject.Position,
                ObjectManager.Instance.Player.Position);
            var CombatRange = NativeGrindBotBase.ConfigOptions.CombatRange;

           

            if (Distance > CombatRange || !(Task.TargetUnitOrObject as WoWUnit).LineOfSight)
            {
                //DebugLog.Log("BroBot", "Getting Closer");
                _StringRepr = $"Getting Closer: {Distance} TaskLocation: {Task.TargetUnitOrObject.Position}";
                LuaBox.Instance.Navigator.MoveTo(Task.TargetUnitOrObject.Position.X, Task.TargetUnitOrObject.Position.Y, Task.TargetUnitOrObject.Position.Z, 1, CombatRange - 1 );


                return;
            }
            else
            {
                (Task.TargetUnitOrObject as WoWUnit).PlayerHasFought = true;

                /*
                [[
                     if IsMounted() then
                        Dismount()
                     end
                ]]
                */

                _StringRepr = "Killing mob: " + Task.TargetUnitOrObject.Name;                
                LuaBox.Instance.Navigator.Stop();



                if (ObjectManager.Instance.Player.TargetGUID != Task.TargetUnitOrObject.GUID)
                {
                    DebugLog.Log("BroBot", "Target");
                    WoWAPI.TargetUnit(Task.TargetUnitOrObject.GUID);
                }

                //LuaBox.Instance.ObjectInteract(Task.TargetUnitOrObject.GUID);
                
                if (!WoWAPI.UnitAffectingCombat("player"))
                {
                    DebugLog.Log("BroBot", "StartAttack");
                    WoWAPI.InteractUnit(Task.TargetUnitOrObject.GUID);
                    WoWAPI.StartAttack();
                }

                //WoWAPI.StartAttack();
                if (Program.CurrentTime - LastFaceDirection > 1)
                {
                    LastFaceDirection = Program.CurrentTime;
                    WoWAPI.InteractUnit(Task.TargetUnitOrObject.GUID);
                    ObjectManager.Instance.Player.FacePosition(Task.TargetUnitOrObject.Position);
                }
            }

            base.Tick();
        }
    }
}
