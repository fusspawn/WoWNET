using System;
using System.Collections.Generic;
using System.Linq;
using Wrapper.API;
using Wrapper.BotBases;
using Wrapper.Helpers;
using Wrapper.NativeBehaviors.BehaviorStateMachine;
using Wrapper.NativeBehaviors.NativeGrindTasks;
using Wrapper.WoW;
using Wrapper.WoW.Filters;

namespace Wrapper.NativeBehaviors
{
    public class NativeGrindBaseState
        : StateMachineState
    {
        public static NativeGrindSmartObjective SmartObjective
            = new NativeGrindSmartObjective();

        public override bool Complete()
        {
            return false; //Base Grind. Should Never Complete. Stack Should Never Go Empty!
        }

        public override void Tick()
        {
            if (WoWAPI.UnitIsDeadOrGhost("player") && (NativeGrindBotBase.StateMachine.States.Peek().GetType().Name
                != typeof(NativeGrindCorpseRunTask).Name))
            {
                NativeGrindBotBase.StateMachine.States.Push(new NativeGrindCorpseRunTask());
                return;
            }


            if (ObjectManager.Instance.Player.GetDurability() < 30 && (NativeGrindBotBase.StateMachine.States.Peek().GetType().Name
                != typeof(NativeGrindRepairTask).Name))
            {
                NativeGrindBotBase.StateMachine.States.Push(new NativeGrindRepairTask());
                return;
            }


            var NextObjective = SmartObjective.GetNextTask();

            if (NextObjective != null)
            {
                switch (NextObjective.TaskType)
                {
                    case NativeGrindSmartObjective.SmartObjectiveTaskType.Gather:
                        NativeGrindBotBase.StateMachine.States.Push(new NativeGrindTasks.NativeGrindGatherTask(NextObjective));
                        break;
                    case NativeGrindSmartObjective.SmartObjectiveTaskType.Loot:
                        NativeGrindBotBase.StateMachine.States.Push(new NativeGrindTasks.NativeGrindLootTask(NextObjective));
                        break;
                    case NativeGrindSmartObjective.SmartObjectiveTaskType.Kill:
                        NativeGrindBotBase.StateMachine.States.Push(new NativeGrindTasks.NativeGrindKillTask(NextObjective));
                        break;
                }

             //   DebugLog.Log("BroBot", "Pushed a task of Type: " + NextObjective.TaskType);
            }
            else
            {
                NativeGrindBotBase.StateMachine.States.Push(new NativeGrindTasks.NativeGrindSearchForNode(SmartObjective));
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
        public double LastUpdateTime = Program.CurrentTime;
        public float BASE_SCORE = 200;

        public GatheringNodeFilterList GatheringNodes;
        public UnitFilterList Units;
        public DeadUnitsFilterList DeadUnits;
        public PlayerFilterList Players;

        public NativeGrindSmartObjective()
        {
            GatheringNodes = new GatheringNodeFilterList(true);
            Units = new UnitFilterList(true, false);
            DeadUnits = new DeadUnitsFilterList();
            Players = new PlayerFilterList(true, true);
        }

        public void Update()
        {
            if(Program.CurrentTime - LastUpdateTime < 1.5)
            {
                return;
            }

            LastUpdateTime = Program.CurrentTime;


            ObjectManager.Instance.Pulse();
            Tasks.Clear();

            //DebugLog.Log("BroBot", $"Units: {Units.GetUnits().Count} Gather: {GatheringNodes.GetObjects().Count} AllObjects: {ObjectManager.Instance.AllObjects.Count}");


            if (!ObjectManager.Instance.Player.IsInCombat || !NativeGrindBotBase.ConfigOptions.AllowSelfDefense)
            {

                if (NativeGrindBotBase.ConfigOptions.AllowGather)
                {
                    foreach (var GameObject in
                        GatheringNodes.GetObjects().Where(x => !Blacklist.IsOnBlackList(x.Value.GUID)))
                    {
                        double score = 25;
                        score = score + (BASE_SCORE - Vector3.Distance(GameObject.Value.Position, ObjectManager.Instance.Player.Position));


                        Tasks.Add(new SmartObjectiveTask()
                        {
                            Score = score,
                            TargetUnitOrObject = GameObject.Value,
                            TaskType = SmartObjectiveTaskType.Gather
                        });
                    }
                }


                foreach (var Unit in DeadUnits.GetUnits().Where(x => !Blacklist.IsOnBlackList(x.Value.GUID)))
                {
                    var AllowSkinning = NativeGrindBotBase.ConfigOptions.AllowSkin; // Default to true if BroBot doesnt Exist

                    if ((LuaBox.Instance.UnitIsLootable(Unit.Value.GUID)
                            || (LuaBox.Instance.UnitHasFlag(Unit.Value.GUID, LuaBox.EUnitFlags.Skinnable)
                            && AllowSkinning)))
                    {

                        double score = 0;
                        score = score + (BASE_SCORE - Vector3.Distance(Unit.Value.Position,
                            ObjectManager.Instance.Player.Position));

                        Tasks.Add(new SmartObjectiveTask()
                        {
                            Score = score,
                            TargetUnitOrObject = Unit.Value,
                            TaskType = SmartObjectiveTaskType.Loot
                        });

                    }
                }
            }

            foreach (var Unit in Units.GetUnits().Where(x => !Blacklist.IsOnBlackList(x.Value.GUID)))
            {
                var _Unit = Unit.Value as WoWUnit;

                if (WoWAPI.UnitIsDeadOrGhost(Unit.Value.GUID) 
                    || (_Unit.Reaction > (NativeGrindBotBase.ConfigOptions.AllowPullingYellows ? 4 : 3)
                    && !_Unit.IsTargettingMeOrPet)
                    || !_Unit.Attackable)
                {
                    DebugLog.Log("SmartObjective", $"Skipping {Unit.Value.GUID} Its dead or shit reaction");
                    continue;
                }

                if (WoWAPI.UnitIsTrivial(Unit.Value.GUID)
                    || WoWAPI.UnitCreatureType(Unit.Value.GUID) == "Critter")
                {

                    if (!WoWAPI.UnitAffectingCombat(Unit.Value.GUID) 
                        || !NativeGrindBotBase.ConfigOptions.AllowSelfDefense)
                    {

                         DebugLog.Log("SmartObjective", $"Skipping {Unit.Value.GUID} Its Trivial or a Critter");
                        continue;
                    }
                }

                DebugLog.Log("SmartObjective", "Found Valid Combat Target");

                double score = 0;
                score = score + (BASE_SCORE - Vector3.Distance(Unit.Value.Position,
                    ObjectManager.Instance.Player.Position)) + 0.25;

                if (/*WoWAPI.UnitAffectingCombat(_Unit.GUID) && */
                     _Unit.IsTargettingMeOrPet
                    && NativeGrindBotBase.ConfigOptions.AllowSelfDefense)
                {
                    DebugLog.Log("SmartObjective", $"Found In Combat Unit {_Unit.GUID}");
                    score = score + 500;
                }
                else
                {
                    
                    if (!NativeGrindBotBase.ConfigOptions.AllowPullingMobs)
                    {
                        DebugLog.Log("SmartObjective", $"Skipping {Unit.Value.GUID} AllowPull Is off");
                        //dont pull this one if allow pulling is off.
                        continue;
                    }
                    
                }


                if (_Unit.IsBossOrElite && NativeGrindBotBase.ConfigOptions.IgnoreElitesAndBosses && !WoWAPI.UnitAffectingCombat(_Unit.GUID))
                {
                    DebugLog.Log("SmartObjective", $"Skipping Elite Unit {_Unit.GUID}");
                    continue;
                }

                
                if(Math.Abs(Unit.Value.Position.Z -  ObjectManager.Instance.Player.Position.Z) > 20)
                {
                    score = score - 500;
                }

               

                if (Players.GetUnits().Any(x =>
                {
                    if (x.Value.GUID == ObjectManager.Instance.Player.GUID)
                        return false;

                    var PlayerNear = WoW.Vector3.Distance(Unit.Value.Position, x.Value.Position) < 50;
                   

                    return PlayerNear
                            && !_Unit.IsTargettingMeOrPet;
                })) {
                    score = score - 200; // Was to close to another player. Move away
                }

                Tasks.Add(new SmartObjectiveTask()
                {
                    Score = score,
                    TargetUnitOrObject = Unit.Value,
                    TaskType = SmartObjectiveTaskType.Kill
                });
            }

        }

        public SmartObjectiveTask PreviousTask;
        public SmartObjectiveTask GetNextTask(bool _Update =true)
        {
            if(_Update)
                this.Update();

            if (Tasks.Count == 0)
            {
                return null;
            }

            var NextTask = Tasks.OrderByDescending(x => x.Score).First();

            if (NextTask.Score < 0)
                return null;


            return NextTask;
        }
    }
}