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

            if (WoWAPI.UnitAffectingCombat("player"))
            {
                Console.WriteLine("Was in combat?");
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

                Console.WriteLine("Pushed a task of Type: " + NextObjective.TaskType);
            }
            else
            {
                Console.WriteLine("update was null");
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

        public NativeGrindSmartObjective()
        {
        }

        public void Update()
        {

            //ObjectManager.Instance.Pulse();

            var CurrentTime = Program.CurrentTime;

            /*
             * if (CurrentTime - LastUpdateTime < 1)
            {
                return;
            }
            */

            LastUpdateTime = CurrentTime;
            Tasks.Clear();


            var AllowGather = true; // Default to true if BroBot doesnt Exist

            if (!ObjectManager.Instance.Player.IsInCombat)
            {

                if (NativeGrindBotBase.ConfigOptions.AllowGather)
                {
                    foreach (var GameObject in
                        ObjectManager.Instance.AllObjects.Where(x => x.Value.IsHerb || x.Value.IsOre).Where(x => !Blacklist.IsOnBlackList(x.Value.GUID)
                                && ObjectManager.Instance.Player.HasRequiredSkillToHarvest(x.Value)))
                    {
                        double score = 0;
                        score = 5;
                        score = score + (200 - Vector3.Distance(GameObject.Value.Position, ObjectManager.Instance.Player.Position));

                        if (score > 0)
                        {
                            //  Console.WriteLine("Found Gathering Objective");

                            Tasks.Add(new SmartObjectiveTask()
                            {
                                Score = score,
                                TargetUnitOrObject = GameObject.Value,
                                TaskType = SmartObjectiveTaskType.Gather
                            });
                        }
                        else
                        {
                            // Console.WriteLine("Gathering Objective Was To Low Scored");
                        }
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
                        score = score + (200 - Vector3.Distance(Unit.Value.Position,
                            ObjectManager.Instance.Player.Position));

                        if (score > 0)
                        {

                            // Console.WriteLine("Found LootOrSkin Objective");

                            Tasks.Add(new SmartObjectiveTask()
                            {
                                Score = score,
                                TargetUnitOrObject = Unit.Value,
                                TaskType = SmartObjectiveTaskType.Loot
                            });
                        }
                        else
                        {

                            // Console.WriteLine("Potential LootOrSkin Objective was to low scored");
                        }
                    }
                }

            }

            foreach (var Unit in ObjectManager.Instance.AllObjects.Where(x => x.Value.ObjectType == LuaBox.EObjectType.Unit
                     && x.Value.ObjectType != LuaBox.EObjectType.Player).Where(x => !Blacklist.IsOnBlackList(x.Value.GUID)))
            {
                var _Unit = Unit.Value as WoWUnit;

                if (WoWAPI.UnitIsDeadOrGhost(Unit.Value.GUID) || _Unit.Reaction > 4)
                {
                   // Console.WriteLine($"Skipping {Unit.Value.Name} Its dead or shit reaction");
                    continue;
                }

                if (WoWAPI.UnitIsTrivial(Unit.Value.GUID)
                    || WoWAPI.UnitCreatureType(Unit.Value.GUID) == "Critter")
                {

                  //  Console.WriteLine($"Skipping {Unit.Value.Name} Its Trivial or a Critter");
                    continue;
                }

               // Console.WriteLine("Found Valid Combat Target");

                double score = 0;
                score = score + (200 - Vector3.Distance(Unit.Value.Position,
                    ObjectManager.Instance.Player.Position));


                



                if (WoWAPI.UnitAffectingCombat(_Unit.GUID))
                {
                    
                 //   Console.WriteLine("Found Combat Unit");
                    score = score + 500;
                } 
                else
                {
                    if(!NativeGrindBotBase.ConfigOptions.AllowPullingMobs)
                    {
                        //dont pull this one if allow pulling is off.
                        continue;
                    }
                }


                if (Math.Abs(ObjectManager.Instance.Player.Position.Z - _Unit.Position.Z) > 5)
                {
                    score = score - 500; // things higher than us can be fucky
                }

                if(_Unit.LineOfSight == false)
                {
                    score = score - 200;
                }

                //score = score + ((8 - _Unit.Reaction) * 10);

                if (score > 0)
                {
                  //  Console.WriteLine("Found Combat Objective");

                    Tasks.Add(new SmartObjectiveTask()
                    {
                        Score = score,
                        TargetUnitOrObject = Unit.Value,
                        TaskType = SmartObjectiveTaskType.Kill
                    });
                }
            }

        }

        public SmartObjectiveTask GetNextTask() { 
            this.Update();

            return Tasks.Count > 0 ? Tasks[0] : null;
         }
    }
}