using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Wrapper.API;

namespace Wrapper.ObjectManager
{
    public class ObjectManager
    {
        private static ObjectManager _instance;
        public static ObjectManager Instance
        { 
            get {
                if (_instance == null) {
                    _instance = new ObjectManager();
                } 

                return _instance;
            } 
        }

        public Dictionary<string, WoWGameObject> AllObjects = new Dictionary<string, WoWGameObject>();

        public void Pulse()
        {
            foreach (var GUID in LuaBox.Instance.GetObjects(500))
            {
                if (!this.AllObjects.ContainsKey(GUID)) {

                    //Console.WriteLine($"Created WoW Object In OM: {GUID}");
                    this.AllObjects[GUID] = CreateWowObject(GUID);
                }
            }

            var RemovalList = new List<string>();

            foreach(var kvp in this.AllObjects)
            {
                if(!LuaBox.Instance.ObjectExists(kvp.Key)){
                    RemovalList.Add(kvp.Key);
                } 
                else
                {
                    kvp.Value.Update();
                }
            }

            RemovalList.ForEach((item) => {
                //Console.WriteLine($"Removed Object From OM: {item}");
                AllObjects.Remove(item); 
            });
        }

        private WoWGameObject CreateWowObject(string GUID)
        {
            switch(LuaBox.Instance.ObjectType(GUID))
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
                x.ObjectType == LuaBox.EObjectType.Player).Select(x => x as WoWPlayer);
        }
    }
}
