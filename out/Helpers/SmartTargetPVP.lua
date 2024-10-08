-- Generated by CSharp.lua Compiler
local System = System
local Linq = System.Linq.Enumerable
local WrapperHelpers
local WrapperWoW
local ListScoredWowPlayer
System.import(function (out)
  WrapperHelpers = Wrapper.Helpers
  WrapperWoW = Wrapper.WoW
  ListScoredWowPlayer = System.List(WrapperHelpers.ScoredWowPlayer)
end)
System.namespace("Wrapper.Helpers", function (namespace)
  namespace.class("SmartTargetPVP", function (namespace)
    local Pulse, GetBestUnit, __ctor__
    __ctor__ = function (this)
      this.Units = ListScoredWowPlayer()
    end
    Pulse = function (this)
      if GetTime() - this.LastUpdateTime < 5 then
        return
      end

      this.LastUpdateTime = GetTime()

      this.Units:Clear()

      local AllValid = (Linq.Where(WrapperWoW.ObjectManager.GetAllPlayers(60), function (p)
        return not p.Dead and p.GUID ~= WrapperWoW.ObjectManager.getInstance().Player.GUID and p.Reaction < 4
      end))

      for _, player in System.each(AllValid) do
        local score = 1000 - System.ToSingle(WrapperWoW.Vector3.Distance(player.Position, WrapperWoW.ObjectManager.getInstance().Player.Position))
        score = score + (System.div((player.HealthMax - player.Health), 5))

        if __LB__.UnitTagHandler(UnitPvpClassification, player.GUID) ~= -1 --[[PVPClassification.None]] then
          score = score + 100
        end

        local target =  __LB__.UnitTarget(player.GUID)
        if target ~= nil then
          if target == WrapperWoW.ObjectManager.getInstance().Player.GUID and __LB__.UnitTagHandler(UnitAffectingCombat, target) then
            score = score + 152
          end
        end

        local default = WrapperHelpers.ScoredWowPlayer()
        default.Player = player
        default.Score = score
        this.Units:Add(default)
      end
    end
    GetBestUnit = function (this)
      local default
      if Linq.Count(this.Units) > 0 then
        default = Linq.FirstOrDefault(Linq.OrderByDescending(this.Units, function (x)
          return x.Score
        end, nil, System.Single)).Player
      else
        default = nil
      end
      return default
    end
    return {
      LastUpdateTime = 0,
      Pulse = Pulse,
      GetBestUnit = GetBestUnit,
      __ctor__ = __ctor__,
      __metadata__ = function (out)
        return {
          fields = {
            { "LastUpdateTime", 0x1, System.Double },
            { "Units", 0x6, System.List(out.Wrapper.Helpers.ScoredWowPlayer) }
          },
          methods = {
            { "GetBestUnit", 0x86, GetBestUnit, out.Wrapper.WoW.WoWPlayer },
            { "Pulse", 0x6, Pulse }
          },
          class = { 0x6 }
        }
      end
    }
  end)
end)
