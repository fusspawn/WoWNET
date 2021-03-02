using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Wrapper.API;

namespace Wrapper.WoW.Filters
{
    public class DeadUnitsFilterList
        : FilteredList
    {
        public WoWFrame EventFrame;

        public DeadUnitsFilterList()
        {
            ScanObjectManager();
            CreateEventTrackingFrame();

            ObjectManager.Instance.OnRemoveObject += (gameObject) =>
            {
                if (FilteredUnits.ContainsKey(gameObject.GUID))
                {
                    DebugLog.Log("DeadUnitFilter", $"Removing Dead Unit: {gameObject.Name}");
                    FilteredUnits.Remove(gameObject.GUID);
                }
            };
        }

        //--timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, ... = 
        private void CreateEventTrackingFrame()
        {
            EventFrame = WoWAPI.CreateFrame<WoWFrame>("Frame");
            EventFrame.RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
            EventFrame.SetScript<Action<double, string, object, string, string, long, long, string, string, long, long>>("OnEvent",
                (timeStamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags) =>
            {

                /*[[
                    timeStamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
                 ]]*/

                //DebugLog.Log("BroBot", "CombatEvent: " + subevent);
                if (subevent != "PARTY_KILL")
                    return;

                var DestExists = ObjectManager.Instance.AllObjects.ContainsKey(destGUID);
                if(!DestExists)
                {
                    DebugLog.Log("DeadUnitFilter", "Was given a dead event guid for an unknown unit");
                    return;
                }

                DebugLog.Log("DeadUnitFilter", $"Found Dead Unit: {ObjectManager.Instance.AllObjects[destGUID].Name}");
                FilteredUnits.Add(destGUID, ObjectManager.Instance.AllObjects[destGUID] as WoWUnit);
            });
        }


        private void ScanObjectManager()
        {
            foreach (var Unit in ObjectManager.Instance.AllObjects.Where(x => x.Value.ObjectType == LuaBox.EObjectType.Unit
                 && WoWAPI.UnitIsDead(x.Value.GUID))) {
                FilteredUnits.Add(Unit.Value.GUID, (WoWUnit)Unit.Value);
            };
        }
    }
}
