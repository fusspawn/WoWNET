using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Wrapper.API;

namespace Wrapper.WoW
{
    public class ObjectManager
    {
        private static ObjectManager _instance;
        public static ObjectManager Instance
        {
            get
            {
                if (_instance == null)
                {
                    _instance = new ObjectManager();
                    _instance.Player = new LocalPlayer();
                }

                return _instance;
            }
        }

        internal void RegisterFilteredList(ObjectManagerFilteredList objectManagerFilteredList)
        {
            FilteredLists.Add(objectManagerFilteredList);

            foreach(var x in AllObjects)
            {
                if (x.Value.ObjectType == LuaBox.EObjectType.GameObject)
                {
                    if (objectManagerFilteredList.FilterGameObject(x.Value))
                    {
                        objectManagerFilteredList.TrackObject(x.Value);
                    }
                }

                if (x.Value.ObjectType == LuaBox.EObjectType.Unit)
                {
                    if (objectManagerFilteredList.FilterUnit(x.Value as WoWUnit))
                    {
                        objectManagerFilteredList.TrackUnit(x.Value as WoWUnit);
                    }
                }
            }
        }

        public Dictionary<string, WoWGameObject> AllObjects = new Dictionary<string, WoWGameObject>();
        public LocalPlayer Player;

        public delegate void OnNewUnitDelegate(WoWUnit Unit);
        public OnNewUnitDelegate OnNewUnit;

        public delegate void OnNewGameObjectDelegate(WoWGameObject Object);
        public OnNewGameObjectDelegate OnNewGameObject;


        public delegate void OnRemoveGameObjectDelegate(WoWGameObject Object);
        public OnRemoveGameObjectDelegate OnRemoveObject;

        public List<WoWGameObject> Pendings = new List<WoWGameObject>();

        public List<ObjectManagerFilteredList> FilteredLists
            = new List<ObjectManagerFilteredList>();


        public static int ObjectManagerScanRange = 999999999;
        private double LastFilterListUpdate;

        public void Pulse()
        {
            try
            {
                Player.Update();

                foreach (var GUID in LuaBox.Instance.GetObjects(ObjectManagerScanRange))
                {
                    if (!this.AllObjects.ContainsKey(GUID)
                        && LuaBox.Instance.ObjectName(GUID) != "Unknown")
                    {
                        this.AllObjects[GUID] = CreateWowObject(GUID);

                        switch (AllObjects[GUID].ObjectType)
                        {
                            case LuaBox.EObjectType.Unit:
                                if (OnNewUnit != null)
                                {
                                    OnNewUnit(AllObjects[GUID] as WoWUnit);
                                }

                                FilteredLists.ForEach(x => {
                                    if (x.FilterUnit(AllObjects[GUID] as WoWUnit)) { 
                                        x.TrackUnit(AllObjects[GUID] as WoWUnit); 
                                    } 
                                });

                                break;

                            case LuaBox.EObjectType.GameObject:
                                if (OnNewGameObject != null)
                                {
                                    OnNewGameObject(AllObjects[GUID]);
                                }

                                FilteredLists.ForEach(x => {
                                    if (x.FilterGameObject(AllObjects[GUID])) {
                                        x.TrackObject(AllObjects[GUID]);
                                    }
                                });
                                break;
                        }
                    }
                }

                var CurrentTime = Program.CurrentTime;
                var RemovalList = new List<string>();

                foreach (var kvp in this.AllObjects)
                {
                    if (!LuaBox.Instance.ObjectExists(kvp.Key))
                    {
                        RemovalList.Add(kvp.Key);
                    }
                    else
                    {
                        if (CurrentTime - kvp.Value.NextUpdate > 0)
                        {
                            kvp.Value.Update();
                        }
                    }
                }

                RemovalList.ForEach((item) =>
                {
                    if (OnRemoveObject != null)
                        OnRemoveObject(AllObjects[item]);

                    FilteredLists.ForEach(x => x.Remove(item));
                    AllObjects.Remove(item);
                });

                if ( Program.CurrentTime - LastFilterListUpdate > 1)
                {
                    LastFilterListUpdate = Program.CurrentTime;
                    FilteredLists.ForEach(x => x.ProcessChanges());
                }
            }
            catch (Exception E)
            {
                DebugLog.Log("BroBot", "OM Error: " + E.Message + "StackTrace: " + WoWAPI.DebugStack());
            }
        }

        public List<WoWGameObject> FindByName(string Name)
        {
            return AllObjects.Where(x => x.Value.Name == Name).Select( x=> x.Value).ToList();
        }

        private WoWGameObject CreateWowObject(string GUID)
        {
            switch (LuaBox.Instance.ObjectType(GUID))
            {

                case LuaBox.EObjectType.Player:
                    return new WoWPlayer(GUID);
                case LuaBox.EObjectType.Unit:
                    return new WoWUnit(GUID);
                default:
                    return new WoWGameObject(GUID);
            }
        }

        public static IEnumerable<WoWPlayer> GetAllPlayers(float Yards)
        {
            return ObjectManager.Instance.AllObjects.Values.Where(x =>
                x.ObjectType == LuaBox.EObjectType.Player
                && Vector3.Distance(x.Position, Instance.Player.Position) <= Yards)
                    .Select(x => x as WoWPlayer);
        }


        public static WoWUnit? FindNPCByObjectID(int ObjectID)
        {
            return ObjectManager.Instance.AllObjects.Values.Where(x => x.ObjectType == LuaBox.EObjectType.Unit
                    && x.ObjectId == ObjectID).OrderBy(x => x.DistanceToPlayer()).FirstOrDefault() as WoWUnit;
        }
    }
}
