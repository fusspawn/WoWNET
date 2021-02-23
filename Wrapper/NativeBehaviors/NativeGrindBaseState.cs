using System;
using System.Collections.Generic;
using System.Linq;
using Wrapper.API;
using Wrapper.Helpers;
using Wrapper.NativeBehaviors.BehaviorStateMachine;
using Wrapper.WoW;

namespace Wrapper.NativeBehaviors
{
    public class NativeGrindBaseState
        : StateMachineState
    {
        private NativeGrindSmartObjective SmartObjective
            = new NativeGrindSmartObjective();

        public override bool Complete()
        {
            return false; //Base Grind. Should Never Complete. Stack Should Never Go Empty!
        }

        public override void Tick()
        {

            SmartObjective.Update();
            var NextObjective = SmartObjective.GetNextTask();

            if (NextObjective != null)
            {
                switch (NextObjective.TaskType)
                {
                    case NativeGrindSmartObjective.SmartObjectiveTaskType.Gather:
                        NativeGrind.StateMachine.States.Push(new NativeGrindTasks.NativeGrindGatherTask(NextObjective));
                        break;
                    case NativeGrindSmartObjective.SmartObjectiveTaskType.Loot:
                        NativeGrind.StateMachine.States.Push(new NativeGrindTasks.NativeGrindLootTask(NextObjective));
                        break;
                    case NativeGrindSmartObjective.SmartObjectiveTaskType.Kill:
                        NativeGrind.StateMachine.States.Push(new NativeGrindTasks.NativeGrindKillTask(NextObjective));
                        break;
                }
            }
            else
            {
                NativeGrind.StateMachine.States.Push(new NativeGrindTasks.NativeGrindSearchForNode(SmartObjective));
            }

            base.Tick();
        }
    }


    public class NativeGrindSmartObjective
    {

        #region InternalTypes 
        public enum SmartObjectiveTaskType
        {
            Kill,
            Gather,
            Loot,

            //Following Do Nothing Right Now
            Repair,
            Vendor,
            GuildBank
        }

        public class SmartObjectiveTask
        {
            public SmartObjectiveTaskType TaskType;
            public WoW.WoWGameObject TargetUnitOrObject;
            public double Score;
        }
        #endregion


        public List<SmartObjectiveTask> Tasks = new List<SmartObjectiveTask>();
        public double LastUpdateTime = WoWAPI.GetTime();

        public NativeGrindSmartObjective()
        {
        }

        public void Update()
        {

            ObjectManager.Instance.Pulse();

            var CurrentTime = WoWAPI.GetTime();
            if (CurrentTime - LastUpdateTime < 1)
            {
                return;
            }

            Console.WriteLine("Updating Smart Objective");
            LastUpdateTime = CurrentTime;
            Tasks.Clear();

            if (!WoWAPI.UnitAffectingCombat("player"))
            {

                if (LuaHelper.GetGlobalFrom_G_Namespace<bool>(new string[] { "BroBot", "UI", "CoreConfig", "PersistentData", "AllowGathering" }))
                {

                    foreach (var GameObject in
                        ObjectManager.Instance.AllObjects.Where(x => x.Value.IsHerb || x.Value.IsOre).Where(x => !BroBotAPI.UnitIsOnBlackList(x.Value.GUID)
                                && ObjectManager.Instance.Player.HasRequiredSkillToHarvest(x.Value)))
                    {
                        double score = 0;
                        score = 5;
                        score = score + (200 - Vector3.Distance(GameObject.Value.Position, ObjectManager.Instance.Player.Position));

                        if (score > 0)
                        {
                            Console.WriteLine("Found Gathering Objective");

                            Tasks.Add(new SmartObjectiveTask()
                            {
                                Score = score,
                                TargetUnitOrObject = GameObject.Value,
                                TaskType = SmartObjectiveTaskType.Gather
                            });
                        }
                        else
                        {
                            Console.WriteLine("Gathering Objective Was To Low Scored");
                        }
                    }
                }


                foreach (var Unit in ObjectManager.Instance.AllObjects.Where(x => x.Value.ObjectType == LuaBox.EObjectType.Unit
                     && x.Value.ObjectType != LuaBox.EObjectType.Player).Where(x => !BroBotAPI.UnitIsOnBlackList(x.Value.GUID)))
                {
                    if (!WoWAPI.UnitIsDeadOrGhost(Unit.Value.GUID))
                        continue;

                    if ((Unit.Value as WoWUnit).PlayerHasFought
                            && (LuaBox.Instance.UnitIsLootable(Unit.Value.GUID)
                            || (LuaBox.Instance.UnitHasFlag(Unit.Value.GUID, LuaBox.EUnitFlags.Skinnable)
                            && LuaHelper.GetGlobalFrom_G_Namespace<bool>(new string[] { "BroBot", "UI", "CoreConfig", "PersistentData", "AllowSkinning" }))))
                    {

                        double score = 0;
                        score = score + (200 - Vector3.Distance(Unit.Value.Position,
                            ObjectManager.Instance.Player.Position));

                        if (score > 0)
                        {

                            Console.WriteLine("Found LootOrSkin Objective");

                            Tasks.Add(new SmartObjectiveTask()
                            {
                                Score = score,
                                TargetUnitOrObject = Unit.Value,
                                TaskType = SmartObjectiveTaskType.Loot
                            });
                        }
                        else
                        {

                            Console.WriteLine("Potential LootOrSkin Objective was to low scored");
                        }
                    }
                }
            }

            
            foreach (var Unit in ObjectManager.Instance.AllObjects.Where(x => x.Value.ObjectType == LuaBox.EObjectType.Unit
                     && x.Value.ObjectType != LuaBox.EObjectType.Player).Where(x => !BroBotAPI.UnitIsOnBlackList(x.Value.GUID)))
            {
                var _Unit = Unit.Value as WoWUnit;
                if (WoWAPI.UnitIsDeadOrGhost(Unit.Value.GUID) || _Unit.Reaction >= 4)
                    continue;

                if (WoWAPI.UnitIsTrivial(Unit.Value.GUID)
                    || WoWAPI.UnitCreatureType(Unit.Value.GUID) == "Critter")
                {
                    continue;
                }

                double score = 0;
                score = score + (200 - Vector3.Distance(Unit.Value.Position,
                    ObjectManager.Instance.Player.Position));
                score = score + ((8 - _Unit.Reaction) * 10);

                if (score > 0)
                {
                    Console.WriteLine("Found Combat Objective");
                    Tasks.Add(new SmartObjectiveTask()
                    {
                        Score = score,
                        TargetUnitOrObject = Unit.Value,
                        TaskType = SmartObjectiveTaskType.Kill
                    });
                }
            }
            
        }

        public SmartObjectiveTask GetNextTask() => Tasks.Count > 0 ? Tasks[0] : null;
    }
}