using System;
using System.Collections.Generic;
using System.Linq;
using Wrapper.API;
using Wrapper.Database;
using Wrapper.Helpers;
using Wrapper.NativeBehaviors.BehaviorStateMachine;
using Wrapper.WoW;

namespace Wrapper.NativeBehaviors.NativeGrindTasks
{
    public class NativeGrindSearchForNode
        : StateMachineState
    {

        private NativeGrindSmartObjective ObjectiveScanner;
        private NodeLocationInfo TargetNode;

        public NativeGrindSearchForNode(NativeGrindSmartObjective SmartObjective)
        {
            this.ObjectiveScanner = SmartObjective;
        }


        public override bool Complete()
        {
            if (WoWAPI.UnitIsDeadOrGhost("player"))
                return true;
            return ObjectiveScanner.GetNextTask() != null
                || WoWAPI.UnitAffectingCombat("player");
        }


        public override void Tick()
        {
            ObjectiveScanner.Update();

            if (TargetNode == null)
            {

                var AllowGather = LuaHelper.GetGlobalFrom_G_Namespace<bool>(new string[]
                {
                    "BroBot", "UI", "CoreConfig",
                    "PersistentData", "AllowGathering"
                });

                var Player = ObjectManager.Instance.Player;
                var PlayerPosition = Player.Position;
                var KnowsHerbalism = Player.HasProfession("Herbalism");
                var KnowsMining = Player.HasProfession("Mining");
                var AllNodes = (from p in WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).Nodes
                                where
                                    ((p.NodeType == NodeType.Herb && KnowsHerbalism)
                                    || (p.NodeType == NodeType.Ore && KnowsMining))
                                    && Vector3.Distance(new Vector3(p.X, p.Y, p.Z), PlayerPosition) > 100
                                select p).ToList();

                if (AllNodes.Count > 0)
                {
                    TargetNode = AllNodes[new Random().Next(0, AllNodes.Count - 1)];
                    Console.WriteLine("Found new Destination: " + TargetNode.X + " / " + TargetNode.Y + " / " + TargetNode.Z);
                }
                else
                {
                    Console.WriteLine("Unable to find a valid node in the database? Has the map been scanned?!");
                    return;
                }
            }



            BroBotAPI.BroBotDebugMessage("RandomNodePositionFinder", "Moving To TargetNode");
            LuaBox.Instance.Navigator.MoveTo(TargetNode.X, TargetNode.Y, TargetNode.Z);

            if (Vector3.Distance(new Vector3(TargetNode.X, TargetNode.Y, TargetNode.Z), ObjectManager.Instance.Player.Position) < 10)
            {
                Console.WriteLine("Got to target node with nothing to do. Lets give this one up and grab another");
                TargetNode = null;
            }
            
            base.Tick();
        }
    }
}