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
        public int Reaction;


        public bool Friend { get { return Reaction > 4; } }
        public bool Hostile { get { return Reaction < 4; } }
        public bool Neutral { get { return Reaction == 4; } }


        public WoWUnit(string _GUID) 
            : base(_GUID)
        {
            Health = WoW.UnitHealth(GUID);
            HealthMax = WoW.UnitHealthMax(GUID);
            Reaction = WoW.UnitReaction(GUID);
        }

        public override void Update()
        {
            //Reaction May Change During Update
            Reaction = WoW.UnitReaction(GUID);



            base.Update();
        }
    }
}
