using System;
using System.Collections.Generic;
using System.Linq;
using Wrapper.API;
using Wrapper.Database;
using Wrapper.Helpers;
using Wrapper.NativeBehaviors.BehaviorStateMachine;
using Wrapper.WoW;

namespace Wrapper.NativeBehaviors.NativeGrindTasks
{
    public class NativeGrindCorpseRunTask
        : StateMachineState
    {

       

        public NativeGrindCorpseRunTask()
        {
          
        }


        public override bool Complete()
        {
            return !WoWAPI.UnitIsDeadOrGhost("player");
        }


        public override void Tick()
        {

            if (WoWAPI.UnitIsDead("player") && !WoWAPI.UnitIsGhost("player"))
            {
                WoWAPI.RepopMe();
                return;
            }

            var CorpsePos = new Vector3();
            LuaBox.Instance.GetPlayerCorpsePosition(out CorpsePos.X, out CorpsePos.Y, out CorpsePos.Z);


            if(Vector3.Distance(ObjectManager.Instance.Player.Position, CorpsePos) > 28)
            {
                LuaBox.Instance.Navigator.MoveTo(CorpsePos.X, CorpsePos.Y, CorpsePos.Z, 1, 1);
                return;
            }

            LuaBox.Instance.Navigator.Stop();

            /*
             [[                    
                RetrieveCorpse();
             ]]
            */

            base.Tick();
        }
    }
}