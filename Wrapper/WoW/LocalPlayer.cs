using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;

namespace Wrapper.WoW
{
    public class LocalPlayer
        : WoWPlayer
    {
        public LocalPlayer()
            : base("player")
        {
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
    }
}
