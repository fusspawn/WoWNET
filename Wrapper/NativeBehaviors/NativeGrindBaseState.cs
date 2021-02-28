using System;
using System.Collections.Generic;
using System.Linq;
using Wrapper.API;
using Wrapper.BotBases;
using Wrapper.Helpers;
using Wrapper.NativeBehaviors.BehaviorStateMachine;
using Wrapper.NativeBehaviors.NativeGrindTasks;
using Wrapper.WoW;

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

             //   Console.WriteLine("Pushed a task of Type: " + NextObjective.TaskType);
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

        public NativeGrindSmartObjective()
        {
        }

        public void Update()
        {
            if(Program.CurrentTime - LastUpdateTime < 1)
            {
                return;
            }

            LastUpdateTime = Program.CurrentTime;


            ObjectManager.Instance.Pulse();
            Tasks.Clear();


            if (!ObjectManager.Instance.Player.IsInCombat || !NativeGrindBotBase.ConfigOptions.AllowSelfDefense)
            {

                if (NativeGrindBotBase.ConfigOptions.AllowGather)
                {
                    foreach (var GameObject in
                        ObjectManager.Instance.AllObjects.Where(x => x.Value.IsHerb || x.Value.IsOre).Where(x => !Blacklist.IsOnBlackList(x.Value.GUID)
                                && ObjectManager.Instance.Player.HasRequiredSkillToHarvest(x.Value)))
                    {
                        double score = 0;
                        score = score + (BASE_SCORE - Vector3.Distance(GameObject.Value.Position, ObjectManager.Instance.Player.Position));


                        Tasks.Add(new SmartObjectiveTask()
                        {
                            Score = score,
                            TargetUnitOrObject = GameObject.Value,
                            TaskType = SmartObjectiveTaskType.Gather
                        });
                    }
                }


                foreach (var Unit in ObjectManager.Instance.AllObjects.Where(x => x.Value.ObjectType == LuaBox.EObjectType.Unit
                     && x.Value.ObjectType != LuaBox.EObjectType.Player).Where(x => !Blacklist.IsOnBlackList(x.Value.GUID)))
                {
                    if (!WoWAPI.UnitIsDeadOrGhost(Unit.Value.GUID))
                        continue;

                    var AllowSkinning = NativeGrindBotBase.ConfigOptions.AllowSkin; // Default to true if BroBot doesnt Exist

                    if ((Unit.Value as WoWUnit).PlayerHasFought
                            && (LuaBox.Instance.UnitIsLootable(Unit.Value.GUID)
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

            foreach (var Unit in ObjectManager.Instance.AllObjects.Where(x => x.Value.ObjectType == LuaBox.EObjectType.Unit
                     && x.Value.ObjectType != LuaBox.EObjectType.Player).Where(x => !Blacklist.IsOnBlackList(x.Value.GUID)))
            {
                var _Unit = Unit.Value as WoWUnit;

                if (WoWAPI.UnitIsDeadOrGhost(Unit.Value.GUID) 
                    || _Unit.Reaction > (NativeGrindBotBase.ConfigOptions.AllowPullingYellows ? 4 : 3) 
                    || !_Unit.Attackable)
                {
                    //Console.WriteLine($"Skipping {Unit.Value.Name} Its dead or shit reaction");
                    continue;
                }

                if (WoWAPI.UnitIsTrivial(Unit.Value.GUID)
                    || WoWAPI.UnitCreatureType(Unit.Value.GUID) == "Critter")
                {

                    // Console.WriteLine($"Skipping {Unit.Value.Name} Its Trivial or a Critter");
                    continue;
                }

                // Console.WriteLine("Found Valid Combat Target");

                double score = 0;
                score = score + (BASE_SCORE - Vector3.Distance(Unit.Value.Position,
                    ObjectManager.Instance.Player.Position)) + 0.25;

                if (WoWAPI.UnitAffectingCombat(_Unit.GUID)
                    && _Unit.TargetGUID == ObjectManager.Instance.Player.GUID)
                {
                    Console.WriteLine("Found In Combat Unit");
                    score = score + 500;
                }
                else
                {
                    
                    if (!NativeGrindBotBase.ConfigOptions.AllowPullingMobs)
                    {
                        //Console.WriteLine($"Skipping {Unit.Value.Name} AllowPull Is off");
                        //dont pull this one if allow pulling is off.
                        continue;
                    }
                    
                }


                if (_Unit.IsBossOrElite && NativeGrindBotBase.ConfigOptions.IgnoreElitesAndBosses && !WoWAPI.UnitAffectingCombat(_Unit.GUID))
                {
                    continue;
                }

                
                if(Math.Abs(Unit.Value.Position.Z -  ObjectManager.Instance.Player.Position.Z) > 20)
                {
                    score = score - 500;
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