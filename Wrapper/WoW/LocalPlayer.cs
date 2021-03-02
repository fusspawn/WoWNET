using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.Database;

namespace Wrapper.WoW
{
    public class LocalPlayer
        : WoWPlayer
    {

        private WoWFrame CombatTrackingFrame;
        public bool IsInCombat = false;


        public LocalPlayer()
            : base("player")
        {
            CreateCombatTrackingFrame();
        }

        private void CreateCombatTrackingFrame()
        {
            CombatTrackingFrame = WoWAPI.CreateFrame<WoWFrame>("Frame");
            CombatTrackingFrame.RegisterEvent("PLAYER_REGEN_DISABLED");
            CombatTrackingFrame.RegisterEvent("PLAYER_REGEN_ENABLED");
            CombatTrackingFrame.RegisterEvent("PLAYER_DEAD");

            CombatTrackingFrame.SetScript<Action<WoWFrame, string>>("OnEvent", (self, _event) => {
                if(_event == "PLAYER_REGEN_ENABLED")
                {
                    DebugLog.Log("BroBot", "[BroBot] Left Combat");
                    IsInCombat = false;
                } 
                else if(_event == "PLAYER_REGEN_DISABLED")
                {
                    DebugLog.Log("BroBot", "[BroBot] Entered Combat");
                    IsInCombat = true;
                }
                else if (_event == "PLAYER_DIED")
                {
                    WoWDatabase.InsertDeathSpotIfRequired(ObjectManager.Instance.Player.Position);
                }
            });
        }

        public override void Update()
        {
            base.Update();
        }

        /*
         * function GameObject:PlayerHasRequiredSkills()
    if self.Ore then
        local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
        if prof1 then
            local name = select(11, GetProfessionInfo(prof1))
            local senderarg = { (" "):split(name) }
            if senderarg[2] == "Mining" then
                return true
            else
                local name = select(11, GetProfessionInfo(prof2))
                local senderarg = { (" "):split(name) }
                return senderarg[2] == "Mining"
            end
        end
    end

    if self.Herb then
        local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
        if prof1 then
            local name = select(11, GetProfessionInfo(prof1))
            local senderarg = { (" "):split(name) }
             if senderarg[2] == "Herbalism" then
                return true
             else
                local name = select(11, GetProfessionInfo(prof2))
                local senderarg = { (" "):split(name) }
                return senderarg[2] == "Herbalism"
             end
        end
    end
    return false
end
         */
        public bool HasRequiredSkillToHarvest(WoWGameObject Object)
        {
            var IsOre = Object.IsOre;
            var IsHerb = Object.IsHerb;

            if (IsOre)
            {
                /*
                 [[
                    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
                    if prof1 then
                        local name = select(11, GetProfessionInfo(prof1))
                        local senderarg = { (" "):split(name) }
                        if senderarg[2] == "Mining" then
                            return true
                        else
                            local name = select(11, GetProfessionInfo(prof2))
                            local senderarg = { (" "):split(name) }
                            return senderarg[2] == "Mining"
                        end
                    end
                ]]
                */
            }


            if (IsHerb)
            {
                /*
                 [[
                    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
                    if prof1 then
                        local name = select(11, GetProfessionInfo(prof1))
                        local senderarg = { (" "):split(name) }
                        if senderarg[2] == "Herbalism" then
                            return true
                        else
                        local name = select(11, GetProfessionInfo(prof2))
                            local senderarg = { (" "):split(name) }
                            return senderarg[2] == "Herbalism"
                        end
                    end
                ]]
                */
            }

            return false;

        }


        public bool HasProfession(string Name)
        {
            /*
             [[
                local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
                if prof1 then
                    local name = select(11, GetProfessionInfo(prof1))
                    local senderarg = { (" "):split(name) }
                    if senderarg[2] == Name then
                        return true
                    else
                    local name = select(11, GetProfessionInfo(prof2))
                        local senderarg = { (" "):split(name) }
                        return senderarg[2] == Name
                    end
                end
            ]]
            */

            return false;
        }

        public double GetDurability()
        {
            /*[[
             
                if 1==1 then
                    
                    local slots = {
	                    "SecondaryHandSlot",
	                    "MainHandSlot",
	                    "FeetSlot",
	                    "LegsSlot",
	                    "HandsSlot",
	                    "WristSlot",
	                    "WaistSlot",
	                    "ChestSlot",
	                    "ShoulderSlot",
	                    "HeadSlot"
                    }


                    local totalDurability = 100
                    for _, value in pairs(slots) do
                        local slot = GetInventorySlotInfo(value)
                        local current, max = GetInventoryItemDurability(slot)
                        if current then
                            if ((current / max) * 100) < totalDurability then
                                totalDurability = (current / max) * 100
                            end
                        end
                    end

                    return totalDurability
                end
            ]]*/

            return -1f;
        }

        public void FaceUnit(WoWGameObject targetUnitOrObject)
        {
            var PlayerPos = ObjectManager.Instance.Player.Position;
            var ObjectPos = targetUnitOrObject.Position;

            /*[[
                local X1,Y1,Z1 = PlayerPos.X, PlayerPos.Y, PlayerPos.Z
	            local X2,Y2,Z2 = ObjectPos.X, ObjectPos.Y, ObjectPos.Z

                local angle = math.atan2(Y2 - Y1, X2 - X1) % (math.pi * 2),
		            math.atan((Z1 - Z2) / math.sqrt(math.pow(X1 - X2, 2) + math.pow(Y1 - Y2, 2))) % math.pi
		         lb.SetPlayerAngles(angle)
            ]]*/
        }
    }
}
