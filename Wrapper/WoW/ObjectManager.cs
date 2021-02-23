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

        public Dictionary<string, WoWGameObject> AllObjects = new Dictionary<string, WoWGameObject>();
        public LocalPlayer Player;

        public delegate void OnNewUnitDelegate(WoWUnit Unit);
        public OnNewUnitDelegate OnNewUnit;

        public delegate void OnNewGameObjectDelegate(WoWGameObject Object);
        public OnNewGameObjectDelegate OnNewGameObject;

        public List<WoWGameObject> Pendings = new List<WoWGameObject>();
        public static int ObjectManagerScanRange = 500;

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
                                break;

                            case LuaBox.EObjectType.GameObject:
                                if (OnNewGameObject != null)
                                {
                                    OnNewGameObject(AllObjects[GUID]);
                                }
                                break;
                        }
                    }
                }

                var RemovalList = new List<string>();
                foreach (var kvp in this.AllObjects)
                {
                    if (!LuaBox.Instance.ObjectExists(kvp.Key))
                    {
                        RemovalList.Add(kvp.Key);
                    }
                    else
                    {
                        kvp.Value.Update();
                    }
                }

                RemovalList.ForEach((item) =>
                {
                        AllObjects.Remove(item);
                });
            } 
            catch(Exception E)
            {
                Console.WriteLine("OM Error: " + E.Message + "StackTrace: " + WoWAPI.DebugStack());
            }
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
    }
}
