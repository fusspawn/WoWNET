-- Generated by CSharp.lua Compiler
local System = System
System.namespace("Wrapper.Database", function (namespace)
  namespace.enum("NPCNodeType", function ()
    return {
      Repair = 1,
      Vendor = 2,
      FlightMaster = 3,
      InnKeeper = 4,
      MailBox = 5,
      __metadata__ = function (out)
        return {
          fields = {
            { "FlightMaster", 0xE, System.Int32 },
            { "InnKeeper", 0xE, System.Int32 },
            { "MailBox", 0xE, System.Int32 },
            { "Repair", 0xE, System.Int32 },
            { "Vendor", 0xE, System.Int32 }
          },
          class = { 0x6 }
        }
      end
    }
  end)
end)
