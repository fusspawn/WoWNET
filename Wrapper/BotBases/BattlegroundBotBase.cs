using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.Helpers;
using Wrapper.WoW;
using Wrapper.WoW.Filters;
using static Wrapper.StdUI;

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


        private BattleGroundUIContainer UIContainer;
        private NativeGrindBotBase NativeGrindInstance;
        private WoWFrame EventTrackerFrame;



        public class BattleGroundUIContainer
        {
            public StdUI.StdUiFrame Container;
            public StdUI.StdUiLabel BGLabel;
            public StdUiDropdown SelectedBGS;
            public StdUiDropdown SelectedRoles;
            public StdUiCheckBox GrindWhenWaiting;
        }

        public class BattleGroundUIConfigOptions
        {
            
        }

        public override void BuildConfig(StdUI.StdUiFrame Container)
        {
            if (UIContainer != null)
            {
                Program.MainUI.SetConfigPanel(UIContainer.Container);
                return; //Already created. Just set and continue;
            }

            UIContainer = new BattleGroundUIContainer();
            UIContainer.Container = Program.MainUI.StdUI.Frame(Container, Container.GetWidth(), Container.GetHeight() - 150, null);
            Program.MainUI.StdUI.GlueTop(UIContainer.Container, Container, 0, -100, "TOP");

            UIContainer.BGLabel = Program.MainUI.StdUI.Label(UIContainer.Container, "~== Native BG Config ==~", 18, null, Container.GetWidth() - 10, 25);
            Program.MainUI.StdUI.GlueTop(UIContainer.BGLabel, UIContainer.Container, 50, 0, "TOP");

            StdUiDropdown.StdUiDropdownItems[] Options = null;
            /*[[
                  local Options = { 
                        {text="wsg", value=0},
                        {text="av", value=1}, 
                        {text="abs", value=2}
                            }
            ]]*/
            UIContainer.SelectedBGS = Program.MainUI.StdUI.Dropdown(UIContainer.Container, 200, 25, Options, null, true, false);
            UIContainer.SelectedBGS.SetOptions(Options);
            UIContainer.SelectedBGS.SetPlaceholder("~-- Please Select a BG --~");
            Program.MainUI.StdUI.GlueTop(UIContainer.SelectedBGS, UIContainer.Container, 0, -40, "TOP");

            StdUiDropdown.StdUiDropdownItems[] OptionsRoles = null;
            /*[[
                  local OptionsRoles = { 
                        {text="tank", value=0},
                        {text="healer", value=1}, 
                        {text="dps", value=2}
                            }
            ]]*/
            UIContainer.SelectedRoles = Program.MainUI.StdUI.Dropdown(UIContainer.Container, 200, 25, OptionsRoles, null, true, false);
            UIContainer.SelectedRoles.SetOptions(OptionsRoles);
            UIContainer.SelectedRoles.SetPlaceholder("~-- Please Select a Role --~");
            Program.MainUI.StdUI.GlueTop(UIContainer.SelectedRoles, UIContainer.Container, 0, -90, "TOP");


            UIContainer.GrindWhenWaiting = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Grind Whilst Waiting", 200, 25);
            UIContainer.GrindWhenWaiting.SetChecked(false);
            Program.MainUI.StdUI.GlueTop(UIContainer.GrindWhenWaiting, UIContainer.Container, 0, -130, "TOP");

        }

        public PVPBotBase()
        {
            Players = new PlayerFilterList(true, true);
            SmartTarget = new SmartTargetPVP(Players);
            SmartMove = new SmartMovePVP(Players);

            if(EventTrackerFrame == null)
            {
                CreateEventTrackerFrame();
            }

        }

        private void CreateEventTrackerFrame()
        {
            /*
               BaseBG.EventFrame = CreateFrame("Frame")
                BaseBG.EventFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
                BaseBG.EventFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
                BaseBG.EventFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
                BaseBG.EventFrame:SetScript("OnEvent", function(self, event, msg, ...) 
                    --print("BaseBG Message: " .. tostring(msg))
                    if string.find(msg:lower(), "begun") then
                        print("detected start - Starting BG")
                        BaseBG.HasStarted = true
                    end
                end)
            */
            EventTrackerFrame = WoWAPI.CreateFrame<WoWFrame>("Frame");
            EventTrackerFrame.RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL");
            EventTrackerFrame.RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE");
            EventTrackerFrame.RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE");
            EventTrackerFrame.SetScript<Action<object, string, string>>("OnEvent", (self, _event, message) => {
                var CString = new string(message);
                
                if(CString.ToLower().Contains("begun"))
                {
                    HasBGStart = true;
                }
            });

            DebugLog.Log("BGBot", "Created Pvp Event Tracker Frame");
        }

        public override void Pulse()
        {
            if (ObjectManager.Instance.Player == null
                || !LuaBox.Instance.IsNavLoaded())
            {
                DebugLog.Log("BroBot", "Waiting on Player to spawn in ObjectManager");
                return;
            }


            if (WoWAPI.IsInInstance())
            {
                RunBattleGroundLogic();
            }
            else
            {
                HasBGStart = false;
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


            if(UIContainer.GrindWhenWaiting.GetChecked())
            {
                if (NativeGrindInstance == null)
                    NativeGrindInstance = new NativeGrindBotBase();

                NativeGrindInstance.Pulse();
            }
        }

        private void RunBattleGroundLogic()
        {

            if(LuaHelper.GetGlobalFrom_G<WoWFrame>("TimerTrackerTimer1StatusBar") 
                != null)
            {

            }


            DebugLog.Log("BGBot", "In Battleground");

            SmartMove.Pulse();
            SmartTarget.Pulse();

            var BestMoveScored = SmartMove.GetBestUnit();
            var BestTargetScored = SmartTarget.GetBestUnit();
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
                //DebugLog.Log("BroBot", "BestTarget: " + BestTarget.Name);
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

            
            if (BestMoveScored != null)
            {
                var BestMove = BestMoveScored.Player;

                // We need to do something to start.
                LastDestination = BestMove.Position;

                if (LastDestination != null
                    && Vector3.Distance(ObjectManager.Instance.Player.Position, LastDestination.Value) > 10)
                {
                    //LuaBox.Instance.Navigator.AllowMounting(Vector3.Distance(ObjectManager.Instance.Player.Position, LastDestination.Value) > 20);
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
