using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.Helpers;
using Wrapper.WoW;

namespace Wrapper
{
    public class BotBase
    {
        public virtual void Pulse()
        {

        }
    }

    public class PVPBotBase
        : BotBase
    {
        SmartTargetPVP SmartTarget;
        SmartMovePVP SmartMove;
        Vector3 LastDestination;
        bool HasBGStart = false;

        public PVPBotBase()
        {
            SmartTarget = new SmartTargetPVP();
            SmartMove = new SmartMovePVP();
        }

        public override void Pulse()
        {
            if (ObjectManager.Instance.Player == null
                || !LuaBox.Instance.IsNavLoaded())
            {
                Console.WriteLine("Waiting on Player to spawn in ObjectManager");
                return;
            }


            if (WoWAPI.IsInInstance())
            {
                RunBattleGroundLogic();
            }
            else
            {
                RunQueueLogic();
            }

            base.Pulse();
        }

        private void RunQueueLogic()
        {

            if (WoWAPI.GetBattlefieldStatus(1) != "queued") {
                WoWAPI.JoinBattlefield(32, true, false);
            }

            if (WoWAPI.GetBattlefieldStatus(1) == "confirm") {
                WoWAPI.AcceptBattlefieldPort(1, 1);
                WoWAPI.StaticPopup_Hide("CONFIRM_BATTLEFIELD_ENTRY");
            }
        }

        private void RunBattleGroundLogic()
        {
            // Console.WriteLine("In Battleground");



            SmartMove.Pulse();
            SmartTarget.Pulse();



            var BestMove = SmartMove.GetBestUnit();
            var BestTarget = SmartTarget.GetBestUnit();


            if( WoWAPI.UnitIsDeadOrGhost("player")) {
                WoWAPI.RepopMe();
            }


            if (ObjectManager.Instance.Player.IsCasting || ObjectManager.Instance.Player.IsChanneling)
            {
                return;
            }

            if (BestTarget != null)
            {
                //Console.WriteLine("BestTarget: " + BestTarget.Name);
                if (ObjectManager.Instance.Player.TargetGUID 
                    != BestTarget.TargetGUID)
                {
                    BestTarget.Target();
                    WoWAPI.RunMacroText("/startattack");
                }

                if(Vector3.Distance(ObjectManager.Instance.Player.Position, BestTarget.Position) > 25 || !BestTarget.LineOfSight)
                {
                    LuaBox.Instance.Navigator.MoveTo(BestTarget.Position.X, BestTarget.Position.Y, BestTarget.Position.Z, 1, 15);
                    return;
                } 
                else
                {
                    LuaBox.Instance.Navigator.Stop();
                }
            
                //--Rotation?!
            }


            if (BestMove != null)
            {
                //Console.WriteLine("BestTarget: " + BestMove.Name);
                LastDestination = BestMove.Position;
                
                if (Vector3.Distance(ObjectManager.Instance.Player.Position, LastDestination) > 15)
                {
                    LuaBox.Instance.Navigator.MoveTo(LastDestination.X, LastDestination.Y, LastDestination.Z);
                }
                else
                {
                    LuaBox.Instance.Navigator.Stop();
                }
            }
        }

        private void Rotation()
        {

        }
    }
}