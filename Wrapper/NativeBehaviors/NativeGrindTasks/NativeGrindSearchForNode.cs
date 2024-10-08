﻿using System;
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

        public override void DebugRender()
        {
            if (TargetNode == null)
                return;

            var Purple = new LibDraw.LibDrawColor()
            {
                R = 1,
                G = 0,
                B = 1,
                A = 1,
            };

            var Pos = new Vector3(TargetNode.X, TargetNode.Y, TargetNode.Z);
            LibDraw.Circle(Pos, 2, 1, Purple);
            LibDraw.Text("Dest: Last Seen At Location: " + TargetNode.Name, Pos - new WoW.Vector3(0,0,-0.25), 12, Purple, null);
        }

        public override bool Complete()
        {
            if (WoWAPI.UnitIsDeadOrGhost("player"))
                return true;

            var IsInCombat = ObjectManager.Instance.Player.IsInCombat;
            var NextTask = ObjectiveScanner.GetNextTask();


            if (ObjectManager.Instance.Player.IsInCombat)
            {
                DebugLog.Log("SearchForNode", "Switching to Combat?!");
                return true;
            }
            if (NextTask != null)
            {
                DebugLog.Log("SearchForNode", "Next Task Is: " + NextTask.TaskType);
                return true;
            }
        
            return false;
        }

        public override void Tick()
        {
            ObjectiveScanner.Update();

            _StringRepr = "Searching for new node";

            if (TargetNode == null)
            {

                var AllowGather =  true; // Default to true if BroBot doesnt Exist

                

                var Player = ObjectManager.Instance.Player;
                var PlayerPosition = Player.Position;
                var KnowsHerbalism = Player.HasProfession("Herbalism");
                var KnowsMining = Player.HasProfession("Mining");
                var AllNodes = (from p in WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).Nodes
                                where
                                    ((p.NodeType == NodeType.Herb && KnowsHerbalism)
                                    || (p.NodeType == NodeType.Ore && KnowsMining))
                                    && Vector3.Distance(new Vector3(p.X, p.Y, p.Z), PlayerPosition) > 50
                                    && Vector3.Distance(new Vector3(p.X, p.Y, p.Z), PlayerPosition) < 1000
                                    && !WoWDatabase.IsConsideredDeathSpot(p.X, p.Y, p.Z)
                                select p).ToList();


                if (AllNodes.Count > 0)
                {
                    TargetNode = AllNodes[new Random().Next(0, AllNodes.Count - 1)];
                    bool IsReachable = true;

                    /*
                    [[
                        if not __LB__.NavMgr_IsReachable(this.TargetNode.X, this.TargetNode.Y, this.TargetNode.Z) then
                            IsReachable = false;
                        end                    
                    ]]
                    */

                    if (!IsReachable)
                    {
                        DebugLog.Log("SearchForNode", "Intended Destination wasnt reachable reject it");
                        return;
                    }

                    _StringRepr = $"Moving to new destination: {(int)TargetNode.X} / {(int)TargetNode.Y} / {(int)TargetNode.Z}";
                }
                else
                {
                    DebugLog.Log("SearchForNode", "Unable to find a valid node in the database? Has the map been scanned?!");
                    return;
                }
            }

            _StringRepr = "Moving To TargetNode";
            LuaBox.Instance.Navigator.MoveTo(TargetNode.X, TargetNode.Y, TargetNode.Z);

            if (Vector3.Distance(new Vector3(TargetNode.X, TargetNode.Y, TargetNode.Z), ObjectManager.Instance.Player.Position) < 10)
            {
                DebugLog.Log("SearchForNode", "Got to target node with nothing to do. Lets give this one up and grab another");
                TargetNode = null;
            }
            
            base.Tick();
        }
    }
}