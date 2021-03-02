﻿using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;

namespace Wrapper.WoW.Filters
{
    public class PlayerFilterList
        : ObjectManagerFilteredList
    {

        private bool AllowFriendly = true;
        private bool AllowHostile = true;


        public PlayerFilterList(
            bool AllowFriendly = true,
            bool AllowHostile = true)
        {
            this.AllowFriendly = AllowFriendly;
            this.AllowHostile = AllowHostile;
        }


        public override bool FilterUnit(WoWUnit GameObject)
        {

            var Result = GameObject.ObjectType == LuaBox.EObjectType.Player;

            if (Result && AllowFriendly && GameObject.Friend)
            {
                return true;
            }

            if (Result && AllowHostile && GameObject.Hostile)
            {
                return true;
            }

            return false;
        }
    }
}
