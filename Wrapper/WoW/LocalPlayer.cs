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
                    Console.WriteLine("[BroBot] Left Combat");
                    IsInCombat = false;
                } 
                else if(_event == "PLAYER_REGEN_DISABLED")
                {
                    Console.WriteLine("[BroBot] Entered Combat");
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

        public void FacePosition(Vector3 Pos)
        {
            var Pitch = LuaBox.Instance.ObjectPitch("player");
            var Angle =  Math.Atan2(Pos.Y - this.Position.Y, Pos.X - this.Position.X);
            Angle =(Math.PI / 180) * Angle;        
            LuaBox.Instance.SetPlayerAngles(Angle, Pitch);
        }
    }
}
