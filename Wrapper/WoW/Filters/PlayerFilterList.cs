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
            : base()
        {
            this.AllowFriendly = AllowFriendly;
            this.AllowHostile = AllowHostile;
        }


        public override bool FilterUnit(WoWUnit GameObject)
        {
            var Result = GameObject.ObjectType == LuaBox.EObjectType.Player;

            if (Result)
                DebugLog.Log("PlayerFilterList", $"Found Player {GameObject.Name}");

            if (Result && AllowFriendly && GameObject.Friend)
            {
                DebugLog.Log("PlayerFilterList", "Found Player F");
                return true;
            }

            if (Result && AllowHostile && GameObject.Hostile)
            {

                DebugLog.Log("PlayerFilterList", "Found Player H");
                return true;
            }

            return false;
        }
    }
}
