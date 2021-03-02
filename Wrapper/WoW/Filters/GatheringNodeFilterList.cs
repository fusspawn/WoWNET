using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.WoW.Filters
{
    public class GatheringNodeFilterList
        : ObjectManagerFilteredList
    {
        public bool RequireProfessions = false;

        public GatheringNodeFilterList(bool OnlyViableProfessions = false)
            : base()
        {
            RequireProfessions = OnlyViableProfessions;
        }

        public override bool FilterGameObject(WoWGameObject GameObject)
        {
            return (GameObject.IsHerb || GameObject.IsOre) 
                && (!RequireProfessions || ObjectManager.Instance.Player.HasRequiredSkillToHarvest(GameObject));
        }
    }
}
