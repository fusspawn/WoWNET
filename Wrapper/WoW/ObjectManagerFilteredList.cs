using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;

namespace Wrapper.WoW
{
    public class ObjectManagerFilteredList
         : FilteredList
    {
        bool TrackChanges = false;

        public ObjectManagerFilteredList()
        {
           
            ObjectManager.Instance.RegisterFilteredList(this);
        }

       
        public virtual bool FilterGameObject(WoWGameObject GameObject) => false;
        public virtual bool FilterUnit(WoWUnit Unit) => false;

        public void TrackObject(WoWGameObject _Object) {
           // DebugLog.Log("BroBot", $"Tracking GameObject {_Object.Name} in List {this.GetType().Name}"); 
            FilteredObjects.Add(_Object.GUID, _Object); 
        }
        public void TrackUnit(WoWUnit _Object)
        {
           // DebugLog.Log("BroBot", $"Tracking Unit {_Object.Name} in List {this.GetType().Name}");
            FilteredUnits.Add(_Object.GUID, _Object);
        } 

        public void ProcessChanges()
        {
            if (!TrackChanges) return;

            var RemovalList = new List<string>();
            
            foreach(var GameObject in FilteredObjects)
            {
                if (!FilterGameObject(GameObject.Value))
                    RemovalList.Add(GameObject.Key);
            }

            RemovalList.ForEach(x => FilteredObjects.Remove(x));
            RemovalList.Clear();
            
            foreach (var GameObject in FilteredUnits)
            {
                if (!FilterUnit(GameObject.Value))
                    RemovalList.Add(GameObject.Key);
            }

            RemovalList.ForEach(x => FilteredUnits.Remove(x));
        }
    }
}
