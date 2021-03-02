using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;

namespace Wrapper.WoW.Filters
{
    public class UnitFilterList
        : ObjectManagerFilteredList
    {

        private bool AllowCritter = false;
        private bool AllowTrivial = false;


        public UnitFilterList(bool AllowTrivial = false, bool AllowCritter = false)
        {
            this.AllowCritter = AllowCritter;
            this.AllowTrivial = AllowTrivial;
        }


        public override bool FilterUnit(WoWUnit GameObject)
        {
            if(!AllowCritter)
            {
               if (WoWAPI.UnitCreatureType(GameObject.GUID) == "Critter")
                {
                    return false;
                }
            }

            if (!AllowTrivial)
            {
                if (WoWAPI.UnitIsTrivial(GameObject.GUID))
                    return false;
            }

            var Result = GameObject.ObjectType == LuaBox.EObjectType.Unit
                     && GameObject.ObjectType != LuaBox.EObjectType.Player;

           // Console.WriteLine($"{GameObject.Name}: {Result}");
            return Result;
        }
    }
}
