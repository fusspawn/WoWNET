using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.Helpers;
using Wrapper.WoW;
using Wrapper.WoW.Filters;

namespace Wrapper.BotBases
{
    public class PVPBotBase
        : BotBase
    {
        SmartTargetPVP SmartTarget;
        SmartMovePVP SmartMove;
        PlayerFilterList Players;

        Vector3? LastDestination;
        bool HasBGStart = false;

        float MinScoreJumpToSwap = 100;
        float LastMoveScore = 0;
        string LastMoveGUID = "";



        public PVPBotBase()
        {
            Players = new PlayerFilterList(true, true);
            SmartTarget = new SmartTargetPVP(Players);
            SmartMove = new SmartMovePVP(Players);
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

            if (WoWAPI.GetBattlefieldStatus(1) != "queued")
            {
                WoWAPI.JoinBattlefield(32, true, false);
            }

            if (WoWAPI.GetBattlefieldStatus(1) == "confirm")
            {
                WoWAPI.AcceptBattlefieldPort(1, 1);
                WoWAPI.StaticPopup_Hide("CONFIRM_BATTLEFIELD_ENTRY");
            }

            if (WoWAPI.GetItemCount("Crate of Battlefield Goods") > 1)
            {
                WoWAPI.UseItemByName("Crate of Battlefield Goods");
            }
        }

        private void RunBattleGroundLogic()
        {
            // Console.WriteLine("In Battleground");

            SmartMove.Pulse();
            SmartTarget.Pulse();

            var BestMoveScored = SmartMove.GetBestUnit();
            var BestTargetScored = SmartTarget.GetBestUnit();

            var BestMove = BestMoveScored.Player;
            WoWPlayer BestTarget = BestTargetScored;



            if (WoWAPI.UnitIsDeadOrGhost("player"))
            {
                if (!WoWAPI.UnitIsGhost("player"))
                {
                    WoWAPI.RepopMe();
                }

                LuaBox.Instance.Navigator.Stop();
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

                if ((Vector3.Distance(ObjectManager.Instance.Player.Position, BestTarget.Position) > 25
                    || !BestTarget.LineOfSight)
                    && !(ObjectManager.Instance.Player.IsCasting
                    || ObjectManager.Instance.Player.IsChanneling))
                {
                    LuaBox.Instance.Navigator.AllowMounting(false);
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
                if (!LastDestination.HasValue || Vector3.Distance(BestMove.Position, LastDestination.Value) > 25)
                {

                    if (BestMove.GUID != LastMoveGUID)
                    {
                        if (Math.Abs(BestMoveScored.Score - LastMoveScore) < 250) // Big Jump. Probally should giveup the chase.
                        {
                            //Dont update task lets not just spam around in the middle.
                        }
                    }
                    else
                    {

                        // Same Target Keep Going
                        LastMoveScore = BestMoveScored.Score;
                        LastMoveGUID = BestMove.GUID;
                        LastDestination = BestMove.Position;

                    }
                }
                else
                {
                    // We need to do something to start.
                    LastMoveScore = BestMoveScored.Score;
                    LastMoveGUID = BestMove.GUID;
                    LastDestination = BestMove.Position;
                }

                if (Vector3.Distance(ObjectManager.Instance.Player.Position, LastDestination.Value) > 15)
                {
                    LuaBox.Instance.Navigator.AllowMounting(Vector3.Distance(ObjectManager.Instance.Player.Position, LastDestination.Value) > 20);
                    LuaBox.Instance.Navigator.MoveTo(LastDestination.Value.X, LastDestination.Value.Y, LastDestination.Value.Z);
                }
                else
                {
                    LuaBox.Instance.Navigator.Stop();
                }
            }
        }
    }
}
