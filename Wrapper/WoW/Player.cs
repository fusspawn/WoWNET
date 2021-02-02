using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;

namespace Wrapper.WoW
{
    public class WoWPlayer
        : WoWUnit
    {
        public WoWPlayer(string _GUID) 
            : base(_GUID)
        {
        }

        public override void Update()
        {
            base.Update();
        }
    }
}
