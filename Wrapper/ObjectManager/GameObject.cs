using System;
using System.Collections.Generic;
using System.Numerics;
using System.Text;
using Wrapper.API;

namespace Wrapper.ObjectManager
{
    public class WoWGameObject
    {
        public string GUID;
        public string Name;
        public LuaBox.EObjectType ObjectType;
        public Vector3 Position;


        public WoWGameObject(string _GUID)
        {
            GUID = _GUID;
            Name = LuaBox.Instance.ObjectName(this.GUID);
            ObjectType = LuaBox.Instance.ObjectType(this.GUID);
        }

        public virtual void Update()
        {
            this.Position = LuaBox.Instance.ObjectPositionVector3(this.GUID);
        }
    }
}
