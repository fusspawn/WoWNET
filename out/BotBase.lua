-- Generated by CSharp.lua Compiler
local System = System
local Linq = System.Linq.Enumerable
local SystemNumerics = System.Numerics
local Wrapper
local WrapperDatabase
local WrapperHelpers
local WrapperWoW
System.import(function (out)
  Wrapper = out.Wrapper
  WrapperDatabase = Wrapper.Database
  WrapperHelpers = Wrapper.Helpers
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper", function (namespace)
  namespace.class("BotBase", function (namespace)
    local Pulse
    Pulse = function (this)
    end
    return {
      Pulse = Pulse,
      __metadata__ = function (out)
        return {
          methods = {
            { "Pulse", 0x6, Pulse }
          },
          class = { 0x6 }
        }
      end
    }
  end)


  namespace.class("DataLoggerBase", function (namespace)
    local Pulse, HandleHunterLogic, Spiral, class, __ctor__
    namespace.class("DataLoggerBaseUI", function (namespace)
      return {
        __metadata__ = function (out)
          return {
            fields = {
              { "EnabledCheckBox", 0x6, out.Wrapper.StdUI.StdUiCheckBox },
              { "HunterGridRangeEntry", 0x6, out.Wrapper.StdUI.StdUiInputFrame },
              { "HunterScanGridHeightOffsetEntry", 0x6, out.Wrapper.StdUI.StdUiInputFrame },
              { "HunterScanGridMaxHorizontalRangeBeforeReset", 0x6, out.Wrapper.StdUI.StdUiInputFrame },
              { "HunterScanMode", 0x6, out.Wrapper.StdUI.StdUiCheckBox },
              { "MainUIFrame", 0x6, out.Wrapper.StdUI.StdUiFrame },
              { "MapIdText", 0x6, out.Wrapper.StdUI.StdUiLabel },
              { "NeedsSaveText", 0x6, out.Wrapper.StdUI.StdUiLabel },
              { "NumberOfFlightMasters", 0x6, out.Wrapper.StdUI.StdUiLabel },
              { "NumberOfHerbsText", 0x6, out.Wrapper.StdUI.StdUiLabel },
              { "NumberOfInnKeepers", 0x6, out.Wrapper.StdUI.StdUiLabel },
              { "NumberOfMailBoxes", 0x6, out.Wrapper.StdUI.StdUiLabel },
              { "NumberOfRepairText", 0x6, out.Wrapper.StdUI.StdUiLabel },
              { "NumberOfVendorsText", 0x6, out.Wrapper.StdUI.StdUiLabel },
              { "NumberOrOresText", 0x6, out.Wrapper.StdUI.StdUiLabel },
              { "RangeEditBox", 0x6, out.Wrapper.StdUI.StdUiInputFrame },
              { "RecordGameObjects", 0x6, out.Wrapper.StdUI.StdUiCheckBox },
              { "RecordNPCS", 0x6, out.Wrapper.StdUI.StdUiCheckBox },
              { "ScanCurrentArea", 0x6, out.Wrapper.StdUI.StdUiButton }
            },
            class = { 0x6 }
          }
        end
      }
    end)
    __ctor__ = function (this)
      this.CastTimeStamp = GetTime()
    end
    Pulse = function (this)
      local _StdUI


      if class.UIData == nil then
        _StdUI = LibStub("StdUi"):NewInstance()

        --#region UIConfigData
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
        --#endregion

        class.UIData = class.DataLoggerBaseUI()
        class.UIData.MainUIFrame = _StdUI:Window(_G["UIParent"], 500, 400, "BroBot Data Logger")
        class.UIData.MainUIFrame:SetPoint("CENTER", 0, 0)
        class.UIData.MainUIFrame:Show()

        class.UIData.EnabledCheckBox = _StdUI:Checkbox(class.UIData.MainUIFrame, "Enable Recording", 150, 25)
        _StdUI:GlueTop(class.UIData.EnabledCheckBox, class.UIData.MainUIFrame, - 140, - 50, "TOP")

        class.UIData.RecordNPCS = _StdUI:Checkbox(class.UIData.MainUIFrame, "Record NPCS", 150, 25)
        _StdUI:GlueTop(class.UIData.RecordNPCS, class.UIData.MainUIFrame, - 140, - 80, "TOP")

        class.UIData.RecordGameObjects = _StdUI:Checkbox(class.UIData.MainUIFrame, "Record GameObjects", 150, 25)
        _StdUI:GlueTop(class.UIData.RecordGameObjects, class.UIData.MainUIFrame, - 140, - 110, "TOP")

        class.UIData.RangeEditBox = _StdUI:NumericBox(class.UIData.MainUIFrame, 150, 25, "175")
        class.UIData.RangeEditBox:SetValue(175)

        _StdUI:GlueTop(class.UIData.RangeEditBox, class.UIData.MainUIFrame, - 140, - 160, "TOP")
        local label = _StdUI:AddLabel(class.UIData.MainUIFrame, class.UIData.RangeEditBox, "Local Scan Range (200 max)", "TOP")

        class.UIData.NeedsSaveText = _StdUI:Label(class.UIData.MainUIFrame, "Needs To Save: " .. System.toString(WrapperDatabase.WoWDatabase.getHasDirtyMaps()), 12, nil, 150, 25)
        _StdUI:GlueTop(class.UIData.NeedsSaveText, class.UIData.MainUIFrame, - 140, - 190, "TOP")

        class.UIData.MapIdText = _StdUI:Label(class.UIData.MainUIFrame, "MapId: " ..  __LB__.GetMapId(), 12, nil, 150, 25)
        class.UIData.NumberOfHerbsText = _StdUI:Label(class.UIData.MainUIFrame, "Herb Nodes: " .. #WrapperDatabase.WoWDatabase.GetAllHerbLocations(), 12, nil, 150, 25)
        class.UIData.NumberOrOresText = _StdUI:Label(class.UIData.MainUIFrame, "Ore Nodes: " .. #WrapperDatabase.WoWDatabase.GetAllOreLocations(), 12, nil, 150, 25)
        class.UIData.NumberOfVendorsText = _StdUI:Label(class.UIData.MainUIFrame, "Vendors: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).Vendors, 12, nil, 150, 25)
        class.UIData.NumberOfRepairText = _StdUI:Label(class.UIData.MainUIFrame, "Repair: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).Repair, 12, nil, 150, 25)
        class.UIData.NumberOfFlightMasters = _StdUI:Label(class.UIData.MainUIFrame, "FlightMasters: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).FlightMaster, 12, nil, 150, 25)
        class.UIData.NumberOfInnKeepers = _StdUI:Label(class.UIData.MainUIFrame, "InnKeepers: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).InnKeepers, 12, nil, 150, 25)
        class.UIData.NumberOfMailBoxes = _StdUI:Label(class.UIData.MainUIFrame, "MailBoxes: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).MailBoxes, 12, nil, 150, 25)


        class.UIData.ScanCurrentArea = _StdUI:HighlightButton(class.UIData.MainUIFrame, 150, 25, "Scan Current Area")
        class.UIData.ScanCurrentArea:SetScript("OnClick", function ()
          for _, unit in System.each(Linq.Where(WrapperWoW.ObjectManager.getInstance().AllObjects, function (x)
            return x.Value.ObjectType == 5 --[[EObjectType.Unit]]
          end)) do
            WrapperDatabase.WoWDatabase.InsertNpcIfRequired(System.as(unit.Value, WrapperWoW.WoWUnit))
          end

          for _, unit in System.each(Linq.Where(WrapperWoW.ObjectManager.getInstance().AllObjects, function (x)
            return x.Value.ObjectType == 8 --[[EObjectType.GameObject]]
          end)) do
            WrapperDatabase.WoWDatabase.InsertNodeIfRequired(unit.Value)
          end
        end, System.Delegate)

        _StdUI:GlueTop(class.UIData.ScanCurrentArea, class.UIData.MainUIFrame, - 140, - 230, "TOP")



        if select(2,__LB__.UnitTagHandler(UnitClass, "player")) == "HUNTER" then
          class.UIData.HunterScanMode = _StdUI:Checkbox(class.UIData.MainUIFrame, "Hunter Scan Mode", 150, 25)
          _StdUI:GlueTop(class.UIData.HunterScanMode, class.UIData.MainUIFrame, - 140, - 260, "TOP")

          class.UIData.HunterGridRangeEntry = _StdUI:NumericBox(class.UIData.MainUIFrame, 150, 25, "175")
          class.UIData.HunterGridRangeEntry:SetValue(175)
          _StdUI:GlueTop(class.UIData.HunterGridRangeEntry, class.UIData.MainUIFrame, - 140, - 310, "TOP")
          _StdUI:AddLabel(class.UIData.MainUIFrame, class.UIData.HunterGridRangeEntry, "Scan Grid Size (175 is good)", "TOP")

          class.UIData.HunterScanGridHeightOffsetEntry = _StdUI:NumericBox(class.UIData.MainUIFrame, 150, 25, "0")
          class.UIData.HunterScanGridHeightOffsetEntry:SetValue(0)
          _StdUI:GlueTop(class.UIData.HunterScanGridHeightOffsetEntry, class.UIData.MainUIFrame, - 140, - 360, "TOP")
          _StdUI:AddLabel(class.UIData.MainUIFrame, class.UIData.HunterScanGridHeightOffsetEntry, "Hunter Scan Height Offset", "TOP")

          class.UIData.HunterScanGridMaxHorizontalRangeBeforeReset = _StdUI:NumericBox(class.UIData.MainUIFrame, 150, 25, "7500")
          class.UIData.HunterScanGridMaxHorizontalRangeBeforeReset:SetValue(7500)
          _StdUI:GlueTop(class.UIData.HunterScanGridMaxHorizontalRangeBeforeReset, class.UIData.MainUIFrame, - 140, - 400, "TOP")
          _StdUI:AddLabel(class.UIData.MainUIFrame, class.UIData.HunterScanGridMaxHorizontalRangeBeforeReset, "Hunter Scan Max Horizontal Range", "TOP")
        end

        _StdUI:GlueTop(class.UIData.MapIdText, class.UIData.MainUIFrame, 75, - 50, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOfHerbsText, class.UIData.MainUIFrame, 75, - 80, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOrOresText, class.UIData.MainUIFrame, 75, - 110, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOfVendorsText, class.UIData.MainUIFrame, 75, - 140, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOfRepairText, class.UIData.MainUIFrame, 75, - 170, "TOP")

        _StdUI:GlueTop(class.UIData.NumberOfFlightMasters, class.UIData.MainUIFrame, 75, - 200, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOfInnKeepers, class.UIData.MainUIFrame, 75, - 230, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOfMailBoxes, class.UIData.MainUIFrame, 75, - 260, "TOP")



        C_Timer.NewTicker(1.5, function ()
          local colorstring = WrapperDatabase.WoWDatabase.getHasDirtyMaps() and "|cFFFF0000" or "|cFF00FF00"
          class.UIData.NeedsSaveText:SetText("Needs To Save: " .. System.toString(colorstring) .. System.toString(WrapperDatabase.WoWDatabase.getHasDirtyMaps()))
          class.UIData.MapIdText:SetText("MapId: " ..  __LB__.GetMapId())
          class.UIData.NumberOfHerbsText:SetText("Herb Nodes: " .. #WrapperDatabase.WoWDatabase.GetAllHerbLocations())
          class.UIData.NumberOrOresText:SetText("Ore Nodes: " .. #WrapperDatabase.WoWDatabase.GetAllOreLocations())
          class.UIData.NumberOfVendorsText:SetText("Vendors: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).Vendors)
          class.UIData.NumberOfRepairText:SetText("Repair: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).Repair)
          class.UIData.NumberOfFlightMasters:SetText("FlightMasters: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).FlightMaster)
          class.UIData.NumberOfMailBoxes:SetText("MailBoxes: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).MailBoxes)
          class.UIData.NumberOfInnKeepers:SetText("InnKeepers: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).InnKeepers)


          --   Console.WriteLine("New Ticker");

          if class.UIData.HunterScanMode ~= nil and class.UIData.HunterScanMode:GetValue(System.Boolean) then
            HandleHunterLogic(this)
          end
        end)

        WrapperWoW.ObjectManager.getInstance().OnNewUnit = System.DelegateCombine(WrapperWoW.ObjectManager.getInstance().OnNewUnit, function (Unit)
          if class.UIData.EnabledCheckBox:GetValue(System.Boolean) and class.UIData.RecordNPCS:GetValue(System.Boolean) then
            WrapperDatabase.WoWDatabase.InsertNpcIfRequired(Unit)
          end
        end)

        WrapperWoW.ObjectManager.getInstance().OnNewGameObject = System.DelegateCombine(WrapperWoW.ObjectManager.getInstance().OnNewGameObject, function (GameObject)
          if class.UIData.EnabledCheckBox:GetValue(System.Boolean) and class.UIData.RecordGameObjects:GetValue(System.Boolean) then
            WrapperDatabase.WoWDatabase.InsertNodeIfRequired(GameObject)
          end
        end)
      end


      Wrapper.BotBase.Pulse(this)
    end
    HandleHunterLogic = function (this)
      this.HunterScanGridRange = System.Int32.Parse(class.UIData.HunterGridRangeEntry:GetValue(System.String))
      this.HunterScanGridHeightOffset = System.Int32.Parse(class.UIData.HunterScanGridHeightOffsetEntry:GetValue(System.String))
      this.HunterScanGridMaxHorizontalRange = System.Int32.Parse(class.UIData.HunterScanGridMaxHorizontalRangeBeforeReset:GetValue(System.String))
      System.Console.WriteLine("Handling Hunter Logics")

      if not WrapperWoW.ObjectManager.getInstance().Player:getIsChanneling() and not WrapperWoW.ObjectManager.getInstance().Player:getIsCasting() then
        if not IsUsableSpell("Eagle Eye") then
          System.Console.WriteLine("Wants To Cast Eagle Eye but IsUsableSpell is false")
          return
        end

        if not  __LB__.IsAoEPending() then
          __LB__.UnitTagHandler(CastSpellByName, "Eagle Eye", nil)
          System.Console.WriteLine("Casting Eagle Eye")
          return
        end

        local SpiralOffset = Spiral(this, this.CastIndex)
        this.CastIndex = this.CastIndex + 1
        SpiralOffset = SystemNumerics.Vector2.Multiply(SpiralOffset, this.HunterScanGridRange)

        local CastLocation = WrapperWoW.Vector3(WrapperWoW.ObjectManager.getInstance().Player.Position.X + SpiralOffset.X, WrapperWoW.ObjectManager.getInstance().Player.Position.Y + SpiralOffset.Y, WrapperWoW.ObjectManager.getInstance().Player.Position.Z + this.HunterScanGridHeightOffset)

        if WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, CastLocation:__clone__()) > this.HunterScanGridMaxHorizontalRange then
          System.Console.WriteLine("Reached Max Range - Reset And Move Up")
          this.CastIndex = 1
          class.UIData.HunterScanGridHeightOffsetEntry:SetValue(this.HunterScanGridMaxHorizontalRange + 175)
          return
        end

        __LB__.ClickPosition(CastLocation.X, CastLocation.Y, CastLocation.Z, false)
        System.Console.WriteLine("Clicking At Cast Location")
        this.CastTimeStamp = GetTime()
      else
        if GetTime() - this.CastTimeStamp > 10 then
          System.Console.WriteLine("Have been chilling a bit. Recast")
          MoveForwardStart()
          MoveForwardStop()
          return
        else
          System.Console.WriteLine("Waiting " .. 10 - (GetTime() - this.CastTimeStamp) .. " more seconds for shit to load")
        end
      end
    end
    Spiral = function (this, n)
      local k = System.ToSingle(math.Ceiling((math.Sqrt(n) - 1) / 2))
      local t = 2 * k + 1
      local m = System.ToSingle(math.Pow(t, 2))
      t = t - 1

      if n >= m - t then
        return SystemNumerics.Vector2(k - (m - n), - k)
      else
        m = m - t
      end
      if n >= m - t then
        return SystemNumerics.Vector2(- k, - k + (m - n))
      else
        m = m - t
      end
      if n >= m - t then
        return SystemNumerics.Vector2(- k + (m - n), k)
      else
        return SystemNumerics.Vector2(k, k - (m - n - t))
      end
    end
    class = {
      base = function (out)
        return {
          out.Wrapper.BotBase
        }
      end,
      Pulse = Pulse,
      CastIndex = 1,
      HunterScanGridRange = 175,
      HunterScanGridHeightOffset = 0,
      HunterScanGridMaxHorizontalRange = 7500,
      __ctor__ = __ctor__,
      __metadata__ = function (out)
        return {
          fields = {
            { "CastIndex", 0x1, System.Int32 },
            { "CastTimeStamp", 0x1, System.Double },
            { "HunterScanGridHeightOffset", 0x1, System.Int32 },
            { "HunterScanGridMaxHorizontalRange", 0x1, System.Int32 },
            { "HunterScanGridRange", 0x1, System.Int32 },
            { "UIData", 0xE, class.DataLoggerBaseUI }
          },
          methods = {
            { ".ctor", 0x6, nil },
            { "HandleHunterLogic", 0x1, HandleHunterLogic },
            { "Pulse", 0x6, Pulse },
            { "Spiral", 0x181, Spiral, System.Int32, System.Numerics.Vector2 }
          },
          class = { 0x6 }
        }
      end
    }
    return class
  end)




  namespace.class("PVPBotBase", function (namespace)
    local Pulse, RunQueueLogic, RunBattleGroundLogic, Rotation, __ctor__
    __ctor__ = function (this)
      this.LastDestination = System.default(WrapperWoW.Vector3)
      this.SmartTarget = WrapperHelpers.SmartTargetPVP()
      this.SmartMove = WrapperHelpers.SmartMovePVP()
    end
    Pulse = function (this)
      if WrapperWoW.ObjectManager.getInstance().Player == nil or not (__LB__.Navigator ~= nil) then
        System.Console.WriteLine("Waiting on Player to spawn in ObjectManager")
        return
      end


      if IsInInstance() then
        RunBattleGroundLogic(this)
      else
        RunQueueLogic(this)
      end

      Wrapper.BotBase.Pulse(this)
    end
    RunQueueLogic = function (this)
      if GetBattlefieldStatus(1) ~= "queued" then
        JoinBattlefield(32, true, false)
      end

      if GetBattlefieldStatus(1) == "confirm" then
        AcceptBattlefieldPort(1, 1)
        StaticPopup_Hide("CONFIRM_BATTLEFIELD_ENTRY")
      end

      if GetItemCount("Crate of Battlefield Goods") > 1 then
        UseItemByName("Crate of Battlefield Goods")
      end
    end
    RunBattleGroundLogic = function (this)
      -- Console.WriteLine("In Battleground");

      this.SmartMove:Pulse()
      this.SmartTarget:Pulse()

      local BestMoveScored = this.SmartMove:GetBestUnit()
      local BestTargetScored = this.SmartTarget:GetBestUnit()

      local BestMove = BestMoveScored.Player
      local BestTarget = BestTargetScored



      if __LB__.UnitTagHandler(UnitIsDeadOrGhost, "player") then
        if not __LB__.UnitTagHandler(UnitIsGhost, "player") then
          RepopMe()
        end

        __LB__.Navigator.Stop()
        return
      end


      if BestTarget ~= nil then
        --Console.WriteLine("BestTarget: " + BestTarget.Name);
        if WrapperWoW.ObjectManager.getInstance().Player.TargetGUID ~= BestTarget.TargetGUID then
          BestTarget:Target()
          RunMacroText("/startattack")
        end

        if (WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, BestTarget.Position) > 25 or not BestTarget.LineOfSight) and not (WrapperWoW.ObjectManager.getInstance().Player:getIsCasting() or WrapperWoW.ObjectManager.getInstance().Player:getIsChanneling()) then
          __LB__.Navigator.AllowMounting(false)
          __LB__.Navigator.MoveTo(BestTarget.Position.X, BestTarget.Position.Y, BestTarget.Position.Z, 1, 15)
          return
        else
          __LB__.Navigator.Stop()
        end

        ----Rotation?!
      end


      if BestMove ~= nil then
        if WrapperWoW.Vector3.op_Equality(this.LastDestination, nil) or WrapperWoW.Vector3.Distance(BestMove.Position, this.LastDestination:__clone__()) > 25 then
          if BestMove.GUID ~= this.LastMoveGUID then
            if math.Abs(BestMoveScored.Score - this.LastMoveScore) < 250 then
              --Dont update task lets not just spam around in the middle.
            end
          else
            -- Same Target Keep Going
            this.LastMoveScore = BestMoveScored.Score
            this.LastMoveGUID = BestMove.GUID
            this.LastDestination = BestMove.Position:__clone__()
          end
        else
          -- We need to do something to start.
          this.LastMoveScore = BestMoveScored.Score
          this.LastMoveGUID = BestMove.GUID
          this.LastDestination = BestMove.Position:__clone__()
        end

        if WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, this.LastDestination:__clone__()) > 15 then
          __LB__.Navigator.AllowMounting(WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, this.LastDestination:__clone__()) > 40)
          __LB__.Navigator.MoveTo(this.LastDestination.X, this.LastDestination.Y, this.LastDestination.Z, 1, 1)
        else
          __LB__.Navigator.Stop()
        end
      end
    end
    Rotation = function (this)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.BotBase
        }
      end,
      HasBGStart = false,
      MinScoreJumpToSwap = 100,
      LastMoveScore = 0,
      LastMoveGUID = "",
      Pulse = Pulse,
      __ctor__ = __ctor__,
      __metadata__ = function (out)
        return {
          fields = {
            { "HasBGStart", 0x1, System.Boolean },
            { "LastDestination", 0x1, out.Wrapper.WoW.Vector3 },
            { "LastMoveGUID", 0x1, System.String },
            { "LastMoveScore", 0x1, System.Single },
            { "MinScoreJumpToSwap", 0x1, System.Single },
            { "SmartMove", 0x1, out.Wrapper.Helpers.SmartMovePVP },
            { "SmartTarget", 0x1, out.Wrapper.Helpers.SmartTargetPVP }
          },
          methods = {
            { ".ctor", 0x6, nil },
            { "Pulse", 0x6, Pulse },
            { "Rotation", 0x1, Rotation },
            { "RunBattleGroundLogic", 0x1, RunBattleGroundLogic },
            { "RunQueueLogic", 0x1, RunQueueLogic }
          },
          class = { 0x6 }
        }
      end
    }
  end)

  namespace.class("CameraFaceTarget", function (namespace)
    local Pulse
    Pulse = function (this)
      local CurrentFacing, CurrentPitch
      CurrentFacing, CurrentPitch =  __LB__.GetCameraAngles()

      Wrapper.BotBase.Pulse(this)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.BotBase
        }
      end,
      Pulse = Pulse,
      __metadata__ = function (out)
        return {
          methods = {
            { "Pulse", 0x6, Pulse }
          },
          class = { 0x6 }
        }
      end
    }
  end)
end)
