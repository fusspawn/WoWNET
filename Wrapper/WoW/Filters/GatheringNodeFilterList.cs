using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;

namespace Wrapper.WoW.Filters
{
    public class GatheringNodeFilterList
        : ObjectManagerFilteredList
    {
        public bool RequireProfessions = false;

        public GatheringNodeFilterList(bool OnlyViableProfessions = false)
         
        {
            RequireProfessions = OnlyViableProfessions;
            DebugLog.Log("GatheringNodeFilter", "Gathering Node filter created with only Professions: " + OnlyViableProfessions);
        }

        public override bool FilterGameObject(WoWGameObject GameObject)
        {
            var IsHerbOrOre = (GameObject.IsHerb || GameObject.IsOre);
            if (!IsHerbOrOre)
                return false;

            if (!RequireProfessions)
            {
                Console.WriteLine("Require Professions Was False");
                return true;
            }
            
            var HasProfession = ObjectManager.Instance.Player.HasRequiredSkillToHarvest(GameObject);
            if(HasProfession)
            {
                DebugLog.Log("GatheringNodeFilter", "Found Filter with Profession: " + GameObject.Name + " Herb: " + GameObject.IsHerb + " Ore " + GameObject.IsOre);
            }
            return HasProfession;
        }
    }
}
