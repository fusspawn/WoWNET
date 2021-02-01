using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;

namespace Wrapper.ObjectManager
{
    public class WoWUnit 
        : WoWGameObject
    {

        public int Health;
        public int HealthMax;
        public int Level;


        public WoWUnit(string _GUID) 
            : base(_GUID)
        {
            Health = WoW.UnitHealth(_GUID);
            HealthMax = WoW.UnitHealthMax(_GUID);
        }

        public override void Update()
        {
            base.Update();
        }
    }
}
