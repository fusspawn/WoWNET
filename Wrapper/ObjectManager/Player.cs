using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;

namespace Wrapper.ObjectManager
{
    public class WoWPlayer
        : WoWGameObject
    {

        public int Health;
        public int HealthMax;


        public WoWPlayer(string _GUID) 
            : base(_GUID)
        {
            Health = WoW.UnitHealth(_GUID);
            HealthMax = WoW.UnitHealthMax(_GUID);
        }
    }
}
