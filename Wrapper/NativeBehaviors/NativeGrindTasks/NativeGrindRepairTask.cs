using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.Database;
using Wrapper.Helpers;
using Wrapper.NativeBehaviors.BehaviorStateMachine;
using Wrapper.WoW;

namespace Wrapper.NativeBehaviors.NativeGrindTasks
{

    public class NativeGrindRepairTask
        : StateMachineState
    {
        private bool HasRepaired = false;

        public NativeGrindRepairTask()
        {

        }

        public override bool Complete()
        {
            return HasRepaired || WoWAPI.UnitIsDeadOrGhost("player");
        }

        public override void Tick()
        {
            var NPC = WoWDatabase.GetClosestRepairNPC();
            
            if (NPC == null)
            {
                DebugLog.Log("BroBot", "Database has no repair NPC?!");
                return;

            }


            var NPCPosition = new WoW.Vector3(NPC.X, NPC.Y, NPC.Z);
            
            if(Vector3.Distance(ObjectManager.Instance.Player.Position, NPCPosition) > 5)
            {
                LuaBox.Instance.Navigator.MoveTo(NPC.X, NPC.Y, NPC.Z, 1, 4);
                _StringRepr = $"Moving To: {NPCPosition} to repair at npc: {NPC.Name}";
                return;
            }


            var NpcUnit = ObjectManager.FindNPCByObjectID(NPC.ObjectId);
            if(NpcUnit == null)
            {
                DebugLog.Log("BroBot", $"Could not find NPC with ID {NPC.ObjectId} Name: {NPC.Name} at location: {NPCPosition} ");
            }


            if(LuaHelper.GetGlobalFrom_G<WoWFrame>("MerchantRepairAllButton") != null
                && LuaHelper.GetGlobalFrom_G<WoWFrame>("MerchantRepairAllButton").IsShown())
            {
                LuaHelper.GetGlobalFrom_G<dynamic>("MerchantRepairAllButton").Click();
                HasRepaired = true;
            }


            NpcUnit.Interact();
            base.Tick();
        }
    }
}
