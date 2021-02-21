-- Generated by CSharp.lua Compiler
local System = System
local Linq = System.Linq.Enumerable
local ListString = System.List(System.String)
local WrapperWoW
local ListWoWGameObject
local DictStringWoWGameObject
System.import(function (out)
  WrapperWoW = Wrapper.WoW
  ListWoWGameObject = System.List(WrapperWoW.WoWGameObject)
  DictStringWoWGameObject = System.Dictionary(System.String, WrapperWoW.WoWGameObject)
end)
System.namespace("Wrapper.WoW", function (namespace)
  namespace.class("ObjectManager", function (namespace)
    local _instance, getInstance, Pulse, CreateWowObject, GetAllPlayers, class, __ctor__
    __ctor__ = function (this)
      this.AllObjects = DictStringWoWGameObject()
      this.Pendings = ListWoWGameObject()
    end
    getInstance = function ()
      if _instance == nil then
        _instance = class()
        _instance.Player = WrapperWoW.WoWPlayer("player")
      end

      return _instance
    end
    Pulse = function (this)
      this.Player:Update()

      for _, GUID in System.each(__LB__.GetObjects(500)) do
        if not this.AllObjects:ContainsKey(GUID) and  __LB__.ObjectName(GUID) ~= "Unknown" then
          this.AllObjects:set(GUID, CreateWowObject(this, GUID))

          repeat
            local default = this.AllObjects:get(GUID).ObjectType
            if default == 5 --[[EObjectType.Unit]] then
              if this.OnNewUnit ~= nil then
                this.OnNewUnit(System.as(this.AllObjects:get(GUID), WrapperWoW.WoWUnit))
              end
              break
            elseif default == 8 --[[EObjectType.GameObject]] then
              if this.OnNewGameObject ~= nil then
                this.OnNewGameObject(this.AllObjects:get(GUID))
              end
              break
            end
          until 1
        end
      end

      local RemovalList = ListString()

      for _, kvp in System.each(this.AllObjects) do
        if not  __LB__.ObjectExists(kvp.Key) then
          RemovalList:Add(kvp.Key)
        else
          kvp.Value:Update()
        end
      end

      RemovalList:ForEach(function (item)
        --Console.WriteLine($"Removed Object From OM: {item}");
        this.AllObjects:RemoveKey(item)
      end)
    end
    CreateWowObject = function (this, GUID)
      repeat
        local default = __LB__.ObjectType(GUID)
        if default == 6 --[[EObjectType.Player]] then
          return WrapperWoW.WoWPlayer(GUID)
        elseif default == 5 --[[EObjectType.Unit]] then
          return WrapperWoW.WoWUnit(GUID)
        else
          return WrapperWoW.WoWGameObject(GUID)
        end
      until 1
    end
    GetAllPlayers = function (Yards)
      return Linq.Select(Linq.Where(getInstance().AllObjects:getValues(), function (x)
        return x.ObjectType == 6 --[[EObjectType.Player]] and WrapperWoW.Vector3.Distance(x.Position, getInstance().Player.Position) <= Yards
      end), function (x)
        return System.as(x, WrapperWoW.WoWPlayer)
      end, WrapperWoW.WoWPlayer)
    end
    class = {
      getInstance = getInstance,
      Pulse = Pulse,
      GetAllPlayers = GetAllPlayers,
      __ctor__ = __ctor__,
      __metadata__ = function (out)
        return {
          fields = {
            { "_instance", 0x9, class },
            { "AllObjects", 0x6, System.Dictionary(System.String, out.Wrapper.WoW.WoWGameObject) },
            { "OnNewGameObject", 0x6, System.Delegate(out.Wrapper.WoW.WoWGameObject, System.Void) },
            { "OnNewUnit", 0x6, System.Delegate(out.Wrapper.WoW.WoWUnit, System.Void) },
            { "Pendings", 0x6, System.List(out.Wrapper.WoW.WoWGameObject) },
            { "Player", 0x6, out.Wrapper.WoW.WoWPlayer }
          },
          properties = {
            { "Instance", 0x20E, class, getInstance }
          },
          methods = {
            { "CreateWowObject", 0x181, CreateWowObject, System.String, out.Wrapper.WoW.WoWGameObject },
            { "GetAllPlayers", 0x18E, GetAllPlayers, System.Single, System.IEnumerable_1(out.Wrapper.WoW.WoWPlayer) },
            { "Pulse", 0x6, Pulse }
          },
          class = { 0x6 }
        }
      end
    }
    return class
  end)
end)
