using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.WoW
{
    public class FilteredList
    {
        protected Dictionary<string, WoWGameObject> FilteredObjects;
        protected Dictionary<string, WoWUnit> FilteredUnits;

        public FilteredList()
        {
            FilteredObjects
               = new Dictionary<string, WoWGameObject>();
            FilteredUnits
                = new Dictionary<string, WoWUnit>();
        }


        public virtual Dictionary<string, WoWGameObject> GetObjects() => FilteredObjects;
        public virtual Dictionary<string, WoWUnit> GetUnits() => FilteredUnits;



        public void Remove(string item)
        {
            //  Console.WriteLine($"removing {LuaBox.Instance.ObjectName(item)} in List {this.GetType().Name}");

            if (FilteredObjects.ContainsKey(item))
            {
                FilteredObjects.Remove(item);
            }

            if (FilteredUnits.ContainsKey(item))
            {
                FilteredUnits.Remove(item);
            }
        }

    }
}
