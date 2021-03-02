using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Wrapper.API;
using Wrapper.BotBases;
using Wrapper.Database;
using Wrapper.Helpers;
using Wrapper.NativeBehaviors;
using Wrapper.WoW;
using static Wrapper.StdUI;
using static Wrapper.StdUI.StdUiFrame;

namespace Wrapper
{
    public class BotBase
    {

        public virtual void Pulse()
        {
        }

        public virtual void BuildConfig(StdUiFrame Container)
        {
            Program.MainUI.SetConfigPanel(null);
        }

        public virtual void DrawDebug() { }
    }


    public class DataLoggerBase :
        BotBase
    {
        public static DataLoggerBaseUI UIData;
        private delegate void OnClickDelegate();

        public class DataLoggerBaseUI
        {
            public StdUiFrame MainUIFrame;
            public StdUiCheckBox EnabledCheckBox;
            public StdUiCheckBox RecordNPCS;
            public StdUiCheckBox RecordGameObjects;
            public StdUiInputFrame RangeEditBox;
            public StdUiLabel NeedsSaveText;

            public StdUiLabel MapIdText;
            public StdUiLabel NumberOfHerbsText;
            public StdUiLabel NumberOrOresText;
            public StdUiLabel NumberOfVendorsText;
            public StdUiLabel NumberOfRepairText;
            public StdUiLabel NumberOfFlightMasters;
            public StdUiLabel NumberOfInnKeepers;
            public StdUiLabel NumberOfMailBoxes;
            public StdUiButton ScanCurrentArea;

            //Hunter Only Scanner
            public StdUiCheckBox HunterScanMode;
            public StdUiInputFrame HunterGridRangeEntry;
            public StdUiInputFrame HunterScanGridHeightOffsetEntry;
            public StdUiInputFrame HunterScanGridMaxHorizontalRangeBeforeReset;
            public StdUiLabel NumberOfManualScanNodes;
            public StdUiButton ResetManualScanNodes;

            public StdUiInputFrame ProfileNameBox;
            public StdUiButton ProfileSaveButton;
            public StdUiButton ProfileLoadButton;

            //NativeGrind 
            public StdUiCheckBox NativeGrindEnabledCheckBox;
            public StdUiDropdown BotBaseSelector;
            internal StdUiLabel NumberOfFishingSpots;
        }

        public DataLoggerBase()
        {

        }


        public override void Pulse()
        {
            StdUI _StdUI;
            bool IsHunter = (WoWAPI.UnitClass("player") == "HUNTER");

            if (UIData == null)
            {
                _StdUI = new LibStub().GetNewInstance<StdUI>("StdUi");

                #region UIConfigData
                /*
                   
                          local BroBotBlueSolid = {r=0.12156862745, g=0.21176470588, b=0.41176470588, a=1}
                          local BroBotBlueAlpha = {r=0.12156862745, g=0.21176470588, b=0.41176470588, a=0.8}


                          _StdUI.config = {
                               font        = {
                                  -- family    = font,
                                   size      = 12,
                                   titleSize = 18,
                                   effect    = 'NONE',
                                   strata    = 'OVERLAY',
                                   color     = {
                                       normal   = { r = 1, g = 1, b = 1, a = 1 },
                                       disabled = { r = 0.55, g = 0.55, b = 0.55, a = 1 },
                                       header   = { r = 1, g = 1, b = 1, a = 1 },
                                   },

                               },

                               backdrop = {
                                   texture        = "Interface\\Buttons\\WHITE8X8",
                                   panel          = BroBotBlueAlpha,
                                   slider         = BroBotBlueAlpha,

                                   highlight      = { r = 0.0, g = 0.0, b = 0.5, a = 0.5 },
                                   button         = BroBotBlueSolid,
                                   buttonDisabled = { r = 0.15, g = 0.15, b = 0.15, a = 1 },

                                   border         = { r = 1, g = 1, b = 1, a = 0.25 },
                                   borderDisabled = { r = 0.00, g = 0.00, b = 0.50, a = 1 }
                               },

                               progressBar = {
                                   color = { r = 0, g = 0.9, b = 1, a = 0.5 },
                               },

                               highlight   = {
                                   color = BroBotBlueSolid,
                                   blank = { r = 0, g = 0, b = 0, a = 0 }
                               },

                               dialog      = {
                                   width  = 400,
                                   height = 100,
                                   button = {
                                       width  = 100,
                                       height = 20,
                                       margin = 5
                                   }
                               },

                               tooltip     = {
                                   padding = 10
                               }
                           };

                   
                   */
                #endregion

                UIData = new DataLoggerBaseUI();
                UIData.MainUIFrame = _StdUI.Window(LuaHelper.GetGlobalFrom_G<WoWFrame>("UIParent"), 500, 600, "BroBot Data Logger");
                UIData.MainUIFrame.SetPoint("CENTER", 0, 0);
                UIData.MainUIFrame.Show();

                UIData.EnabledCheckBox = _StdUI.Checkbox(UIData.MainUIFrame, "Enable Recording", 150, 25);
                _StdUI.GlueTop(UIData.EnabledCheckBox, UIData.MainUIFrame, -140, -50, "TOP");

                UIData.RecordNPCS = _StdUI.Checkbox(UIData.MainUIFrame, "Record NPCS", 150, 25);
                _StdUI.GlueTop(UIData.RecordNPCS, UIData.MainUIFrame, -140, -80, "TOP");

                UIData.RecordGameObjects = _StdUI.Checkbox(UIData.MainUIFrame, "Record GameObjects", 150, 25);
                _StdUI.GlueTop(UIData.RecordGameObjects, UIData.MainUIFrame, -140, -110, "TOP");

                UIData.RangeEditBox = _StdUI.NumericBox(UIData.MainUIFrame, 150, 25, "175", null);
                UIData.RangeEditBox.SetValue(175);

                _StdUI.GlueTop(UIData.RangeEditBox, UIData.MainUIFrame, -140, -160, "TOP");
                var label = _StdUI.AddLabel(UIData.MainUIFrame, UIData.RangeEditBox, "Local Scan Range (200 max)", "TOP", null);

                UIData.NeedsSaveText = _StdUI.Label(UIData.MainUIFrame, "Needs To Save: " + WoWDatabase.HasDirtyMaps, 12, null, 150, 25);
                _StdUI.GlueTop(UIData.NeedsSaveText, UIData.MainUIFrame, -140, -190, "TOP");

                UIData.MapIdText = _StdUI.Label(UIData.MainUIFrame, "MapId: " + LuaBox.Instance.GetMapId(), 12, null, 150, 25);
                UIData.NumberOfHerbsText = _StdUI.Label(UIData.MainUIFrame, "Herb Nodes: " + WoWDatabase.GetAllHerbLocations().Count, 12, null, 150, 25);
                UIData.NumberOrOresText = _StdUI.Label(UIData.MainUIFrame, "Ore Nodes: " + WoWDatabase.GetAllOreLocations().Count, 12, null, 150, 25);
                UIData.NumberOfVendorsText = _StdUI.Label(UIData.MainUIFrame, "Vendors: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).Vendors.Count, 12, null, 150, 25);
                UIData.NumberOfRepairText = _StdUI.Label(UIData.MainUIFrame, "Repair: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).Repair.Count, 12, null, 150, 25);
                UIData.NumberOfFlightMasters = _StdUI.Label(UIData.MainUIFrame, "FlightMasters: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).FlightMaster.Count, 12, null, 150, 25);
                UIData.NumberOfInnKeepers = _StdUI.Label(UIData.MainUIFrame, "InnKeepers: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).InnKeepers.Count, 12, null, 150, 25);
                UIData.NumberOfMailBoxes = _StdUI.Label(UIData.MainUIFrame, "MailBoxes: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).MailBoxes.Count, 12, null, 150, 25);

                UIData.NumberOfFishingSpots = _StdUI.Label(UIData.MainUIFrame, "Fishing Spots: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).Nodes.Where(x => x.NodeType == NodeType.FishingHole).ToList().Count, 12, null, 150, 25);

                UIData.ScanCurrentArea = _StdUI.HighlightButton(UIData.MainUIFrame, 150, 25, "Scan Current Area");
                UIData.ScanCurrentArea.SetScript<Action>("OnClick", () =>
                {
                    foreach (var unit in ObjectManager.Instance.AllObjects.Where(x => x.Value.ObjectType == LuaBox.EObjectType.Unit))
                    {
                        WoWDatabase.InsertNpcIfRequired(unit.Value as WoWUnit);
                    }

                    foreach (var unit in ObjectManager.Instance.AllObjects.Where(x => x.Value.ObjectType == LuaBox.EObjectType.GameObject))
                    {
                        WoWDatabase.InsertNodeIfRequired(unit.Value);
                    }
                });

                _StdUI.GlueTop(UIData.ScanCurrentArea, UIData.MainUIFrame, -140, -230, "TOP");



                if (IsHunter)
                {
                    UIData.HunterScanMode = _StdUI.Checkbox(UIData.MainUIFrame, "Hunter Scan Mode", 150, 25);
                    _StdUI.GlueTop(UIData.HunterScanMode, UIData.MainUIFrame, -140, -260, "TOP");

                    UIData.HunterGridRangeEntry = _StdUI.NumericBox(UIData.MainUIFrame, 150, 25, "175", null);
                    UIData.HunterGridRangeEntry.SetValue(175);
                    _StdUI.GlueTop(UIData.HunterGridRangeEntry, UIData.MainUIFrame, -140, -310, "TOP");
                    _StdUI.AddLabel(UIData.MainUIFrame, UIData.HunterGridRangeEntry, "Scan Grid Size (175 is good)", "TOP", null);

                    UIData.HunterScanGridHeightOffsetEntry = _StdUI.NumericBox(UIData.MainUIFrame, 150, 25, "0", null);
                    UIData.HunterScanGridHeightOffsetEntry.SetValue(0);
                    _StdUI.GlueTop(UIData.HunterScanGridHeightOffsetEntry, UIData.MainUIFrame, -140, -360, "TOP");
                    _StdUI.AddLabel(UIData.MainUIFrame, UIData.HunterScanGridHeightOffsetEntry, "Hunter Scan Height Offset", "TOP", null);

                    UIData.HunterScanGridMaxHorizontalRangeBeforeReset = _StdUI.NumericBox(UIData.MainUIFrame, 150, 25, "7500", null);
                    UIData.HunterScanGridMaxHorizontalRangeBeforeReset.SetValue(7500);
                    _StdUI.GlueTop(UIData.HunterScanGridMaxHorizontalRangeBeforeReset, UIData.MainUIFrame, -140, -400, "TOP");
                    _StdUI.AddLabel(UIData.MainUIFrame, UIData.HunterScanGridMaxHorizontalRangeBeforeReset, "Hunter Scan Max Horizontal Range", "TOP", null);


                    UIData.NumberOfManualScanNodes = _StdUI.Label(UIData.MainUIFrame, "Manual Scan Nodes Count: " + ManualScanLocations.Count, 12, null, 150, 25);
                    _StdUI.GlueTop(UIData.NumberOfManualScanNodes, UIData.MainUIFrame, -140, -430, "TOP");


                   
                }

                UIData.ResetManualScanNodes = _StdUI.HighlightButton(UIData.MainUIFrame, 150, 25, "Reset Manual Scan Nodes");
                UIData.ResetManualScanNodes.SetScript<Action>("OnClick", () =>
                {
                    ManualScanLocations.Clear();
                });

                _StdUI.GlueTop(UIData.ResetManualScanNodes, UIData.MainUIFrame, -140, -460, "TOP");

                UIData.ProfileNameBox = _StdUI.EditBox(UIData.MainUIFrame, 150, 25, "", null);
                _StdUI.AddLabel(UIData.MainUIFrame, UIData.ProfileNameBox, "Profile Name", "TOP", null);
                _StdUI.GlueTop(UIData.ProfileNameBox, UIData.MainUIFrame, -140, -490, "TOP");

                var DataBaseProfileFolder = $"{LuaBox.Instance.GetBaseDirectory()}\\BroBot\\Database\\Profiles\\";
                if (!LuaBox.Instance.DirectoryExists(DataBaseProfileFolder))
                    LuaBox.Instance.CreateDirectory(DataBaseProfileFolder);


                UIData.ProfileSaveButton = _StdUI.HighlightButton(UIData.MainUIFrame, 150, 25, "Save Profile");
                UIData.ProfileSaveButton.SetScript<Action>("OnClick", () =>
                {
                    LuaBox.Instance.WriteFile(DataBaseProfileFolder + UIData.ProfileNameBox.GetValue<string>() + ".json", LibJson.Serialize(ManualScanLocations), false);
                });

                _StdUI.GlueTop(UIData.ProfileSaveButton, UIData.MainUIFrame, -140, -520, "TOP");



                UIData.ProfileLoadButton = _StdUI.HighlightButton(UIData.MainUIFrame, 150, 25, "Load Profile");
                UIData.ProfileLoadButton.SetScript<Action>("OnClick", () =>
                {
                    if (!LuaBox.Instance.FileExists(DataBaseProfileFolder + UIData.ProfileNameBox.GetValue<string>() + ".json"))
                    {
                        DebugLog.Log("BroBot", "Dont be a retard. file is missing");
                        return;
                    }

                    var TempList = LibJson.Deserialize<List<Vector3>>(
                        LuaBox.Instance.ReadFile(DataBaseProfileFolder + UIData.ProfileNameBox.GetValue<string>() + ".json")
                    );


                    ManualScanLocations.Clear();

                    foreach (var point in TempList)
                    {
                        ManualScanLocations.Add(new Vector3(point.X, point.Y, point.Z));
                    }

                    DebugLog.Log("BroBot", "Restored: " + ManualScanLocations.Count + " points");
                });

                _StdUI.GlueTop(UIData.ProfileLoadButton, UIData.MainUIFrame, -140, -550, "TOP");



                _StdUI.GlueTop(UIData.MapIdText, UIData.MainUIFrame, 75, -50, "TOP");
                _StdUI.GlueTop(UIData.NumberOfHerbsText, UIData.MainUIFrame, 75, -80, "TOP");
                _StdUI.GlueTop(UIData.NumberOrOresText, UIData.MainUIFrame, 75, -110, "TOP");
                _StdUI.GlueTop(UIData.NumberOfVendorsText, UIData.MainUIFrame, 75, -140, "TOP");
                _StdUI.GlueTop(UIData.NumberOfRepairText, UIData.MainUIFrame, 75, -170, "TOP");

                _StdUI.GlueTop(UIData.NumberOfFlightMasters, UIData.MainUIFrame, 75, -200, "TOP");
                _StdUI.GlueTop(UIData.NumberOfInnKeepers, UIData.MainUIFrame, 75, -230, "TOP");
                _StdUI.GlueTop(UIData.NumberOfMailBoxes, UIData.MainUIFrame, 75, -260, "TOP");
                _StdUI.GlueTop(UIData.NumberOfFishingSpots, UIData.MainUIFrame, 75, -290, "TOP");

                UIData.NativeGrindEnabledCheckBox = _StdUI.Checkbox(UIData.MainUIFrame, "Pulse SmartGrind", 150, 25);
                _StdUI.GlueTop(UIData.NativeGrindEnabledCheckBox, UIData.MainUIFrame, 75, -320, "TOP");

                StdUiDropdown.StdUiDropdownItems[] Options = null;


                /*[[
                  local Options = { 
                        {text="BGBot", value=1}, 
                        {text="GrindBot", value=2}
                    }
                  ]]*/

                UIData.BotBaseSelector = _StdUI.Dropdown(UIData.MainUIFrame, 150, 25, Options, 2, false, false);

                UIData.BotBaseSelector.SetOptions(Options);
                UIData.BotBaseSelector.SetPlaceholder("~-- Please Select a BotBase --~");
                UIData.BotBaseSelector.OnValueChanged += (self, values) =>
                {
                    var Value = UIData.BotBaseSelector.GetValue<int>();
                    if (Value == 1) { 
                        DebugLog.Log("BroBot", "Switching to PVP Bot base");    
                        Program.Base = new PVPBotBase();
                    } 
                    else if(Value == 2)
                    {
                        DebugLog.Log("BroBot", "Switching to Grind Bot base");
                        Program.Base = new NativeGrindBotBase();
                    }
                };
                _StdUI.GlueTop(UIData.BotBaseSelector, UIData.MainUIFrame, 75, -380, "TOP");    

                WoWAPI.NewTicker(() =>
                {

                    UIData.NumberOfManualScanNodes.SetText("Manual Scan Nodes Count: " + ManualScanLocations.Count);
                  
                    if (UIData.HunterScanMode != null
                        && UIData.HunterScanMode.GetValue<bool>() 
                        && IsHunter)
                    {
                        HandleHunterLogic();
                    }

                    if (UIData.NativeGrindEnabledCheckBox.GetValue<bool>())
                    {
                        SmartGrind.Pulse();
                    }

                }, 0.25f);

                WoWAPI.NewTicker(() =>
                {
                    var colorstring = WoWDatabase.HasDirtyMaps ? "|cFFFF0000" : "|cFF00FF00";
                    UIData.NeedsSaveText.SetText("Needs To Save: " + colorstring + WoWDatabase.HasDirtyMaps);
                    UIData.MapIdText.SetText("MapId: " + LuaBox.Instance.GetMapId());
                    UIData.NumberOfHerbsText.SetText("Herb Nodes: " + WoWDatabase.GetAllHerbLocations().Count);
                    UIData.NumberOrOresText.SetText("Ore Nodes: " + WoWDatabase.GetAllOreLocations().Count);
                    UIData.NumberOfVendorsText.SetText("Vendors: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).Vendors.Count);
                    UIData.NumberOfRepairText.SetText("Repair: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).Repair.Count);
                    UIData.NumberOfFlightMasters.SetText("FlightMasters: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).FlightMaster.Count);
                    UIData.NumberOfMailBoxes.SetText("MailBoxes: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).MailBoxes.Count);
                    UIData.NumberOfInnKeepers.SetText("InnKeepers: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).InnKeepers.Count);
                    UIData.NumberOfFishingSpots.SetText("Fishing Spots: " + WoWDatabase.GetMapDatabase(LuaBox.Instance.GetMapId()).Nodes.Where(x => x.NodeType == NodeType.FishingHole).ToList().Count);
                }, 2f);


                WoWAPI.NewTicker(() =>
                {
                    

                    HandleMapClicks();
                }, 0);


                ObjectManager.Instance.OnNewUnit += (Unit) =>
                {
                    if (UIData.EnabledCheckBox.GetValue<bool>()
                        && UIData.RecordNPCS.GetValue<bool>())
                    {
                        WoWDatabase.InsertNpcIfRequired(Unit);
                    }
                };

                ObjectManager.Instance.OnNewGameObject += (GameObject) =>
                {
                    if (UIData.EnabledCheckBox.GetValue<bool>()
                       && UIData.RecordGameObjects.GetValue<bool>())
                    {
                        WoWDatabase.InsertNodeIfRequired(GameObject);
                    }
                };
            }


            base.Pulse();
        }

        private NativeGrindBotBase SmartGrind = new NativeGrindBotBase();
        private double LastHandledTime = Program.CurrentTime;

        private void HandleMapClicks()
        {
            double X = 0;
            double Y = 0;
            bool WasClicked = false;
            /*
             [[
                if WorldMapFrame:IsVisible() and IsControlKeyDown() and IsMouseButtonDown("LeftButton") then
                    local x, y = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
                    local continentID, worldPosition = C_Map.GetWorldPosFromMapPos(WorldMapFrame: GetMapID(), CreateVector2D(x, y))
                    local WX, WY = worldPosition:GetXY()
                    --print(WX.."/"..WY)
                    WasClicked = true;
                    X = WX;
                    Y = WY;
                end
            ]]
            */

            if(WasClicked && WoWAPI.GetTime() - LastHandledTime > 1)
            {
                LastHandledTime = Program.CurrentTime;
                Vector3? HitPos = LuaBox.Instance.RaycastPosition(X, Y, 10000, X, Y, -10000, (int)LuaBox.ERaycastFlags.Collision);
                if(!HitPos.HasValue)
                {
                    DebugLog.Log("BroBot", $"Unable to add accurate scan point at: {X} / {Y} because Raycast failed to hit anything doing something crazy");
                    double StartHeight = ObjectManager.Instance.Player.Position.Z;

                    for(double i = StartHeight - 2000; i < StartHeight + 2000; i += 500)
                    {
                        DebugLog.Log("BroBot", $"adding rough scan point at: {X} / {Y} / {i}");
                        ManualScanLocations.Add(new WoW.Vector3(X,Y,i));
                    }
                } 
                else
                {
                    DebugLog.Log("BroBot", $"adding manual scan point at: {X} / {Y} / {HitPos.Value.Z}");
                    ManualScanLocations.Add(HitPos.Value);
                }
            }
        }

        private int CastIndex = 1;
        private int HunterScanGridRange = 175;
        private int HunterScanGridHeightOffset = 0;
        private int HunterScanGridMaxHorizontalRange = 7500;
        private double CastTimeStamp =Program.CurrentTime;
        private List<Vector3> ManualScanLocations = new List<Vector3>();

        private void HandleHunterLogic()
        {
            HunterScanGridRange = int.Parse(UIData.HunterGridRangeEntry.GetValue<string>());
            HunterScanGridHeightOffset = int.Parse(UIData.HunterScanGridHeightOffsetEntry.GetValue<string>());
            HunterScanGridMaxHorizontalRange = int.Parse(UIData.HunterScanGridMaxHorizontalRangeBeforeReset.GetValue<string>());
            DebugLog.Log("BroBot", "Handling Hunter Logics");

            if (!ObjectManager.Instance.Player.IsChanneling
                && !ObjectManager.Instance.Player.IsCasting)
            {
                if (!WoWAPI.IsUsableSpell("Eagle Eye"))
                {
                    DebugLog.Log("BroBot", "Wants To Cast Eagle Eye but IsUsableSpell is false");
                    return;
                }

                if (!LuaBox.Instance.IsAoEPending())
                {
                    WoWAPI.CastSpellByName("Eagle Eye", null);
                    DebugLog.Log("BroBot", "Casting Eagle Eye");
                    return;
                }

                CastIndex++;

                var CastLocation = GetNextCastLocation();


                if (ManualScanLocations.Count == 0)
                {
                    if (WoW.Vector3.Distance(ObjectManager.Instance.Player.Position, CastLocation)
                        > HunterScanGridMaxHorizontalRange)
                    {
                        DebugLog.Log("BroBot", "Reached Max Range - Reset And Move Up");
                        CastIndex = 1;
                        UIData.HunterScanGridHeightOffsetEntry.SetValue(HunterScanGridMaxHorizontalRange + 175);
                        return;
                    }
                }


                 LuaBox.Instance.ClickPosition(CastLocation.X, CastLocation.Y, CastLocation.Z, false);
                 DebugLog.Log("BroBot", "Clicking At Cast Location");
                 CastTimeStamp =Program.CurrentTime;
              
            }
            else
            {
                if (WoWAPI.GetTime() - CastTimeStamp > 5)
                {
                    DebugLog.Log("BroBot", "Have been chilling a bit. Recast");
                    WoWAPI.MoveForwardStart();
                    WoWAPI.MoveForwardStop();
                    return;
                } else
                {
                    DebugLog.Log("BroBot", $"Waiting {10 - (WoWAPI.GetTime() - CastTimeStamp)} more seconds for shit to load");
                }
            }
        }

        private WoW.Vector3 GetNextCastLocation()
        {
            if(ManualScanLocations.Count == 0)
            {
                System.Numerics.Vector2 SpiralOffset = Spiral(CastIndex);
                SpiralOffset = System.Numerics.Vector2.Multiply(SpiralOffset, HunterScanGridRange);

                return new WoW.Vector3(ObjectManager.Instance.Player.Position.X + SpiralOffset.X,
                    ObjectManager.Instance.Player.Position.Y + SpiralOffset.Y, ObjectManager.Instance.Player.Position.Z + HunterScanGridHeightOffset);

            } 
            else
            {
                if(ManualScanLocations.Count <= CastIndex)
                {
                    CastIndex = 0;
                    DebugLog.Log("BroBot", "Completed Map Scan. Reset");
                }

                return ManualScanLocations[CastIndex];
            }
        }

        System.Numerics.Vector2 Spiral(int n)
        {

            var k = (float)Math.Ceiling((Math.Sqrt(n) - 1) / 2);
            var t = 2 * k + 1;
            var m = (float)Math.Pow(t, 2);
            t = t - 1;

            if (n >= m - t) { return new System.Numerics.Vector2(k - (m - n), (float)-k); } else { m = m - t; }
            if (n >= m - t) { return new System.Numerics.Vector2(-k, -k + (m - n)); } else { m = m - t; }
            if (n >= m - t) { return new System.Numerics.Vector2(-k + (m - n), k); } else { return new System.Numerics.Vector2(k, k - (m - n - t)); }
        }
    }
}