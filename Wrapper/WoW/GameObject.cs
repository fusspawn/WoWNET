using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using System.Text;
using Wrapper.API;
using Wrapper.Database;

namespace Wrapper.WoW
{
    public class WoWGameObject
    {
        public string GUID;
        public string Name;
        public LuaBox.EObjectType ObjectType;
        public Vector3 Position;
        public int ObjectId;


        private bool? WasHerb = null;
        public bool IsHerb
        {
            get
            {
                if (WasHerb == null)
                {
                    WasHerb = GatherableTypes.HerbNames.Any(x => x == this.Name);
                }

                return WasHerb.Value;
            }

        }

        private bool? WasOre = null;
        public bool IsOre
        {
            get
            {
                if (WasOre == null)
                {
                    WasOre = GatherableTypes.OreNames.Any(x=>x == this.Name);
                }

                return WasOre.Value;
            }
        }

        public WoWGameObject(string _GUID)
        {
            GUID = _GUID;
            Name = LuaBox.Instance.ObjectName(this.GUID);
            ObjectType = LuaBox.Instance.ObjectType(this.GUID);
            ObjectId = LuaBox.Instance.ObjectId(this.GUID);

            Update();
        }

        public virtual void Update()
        {
            this.Position = LuaBox.Instance.ObjectPositionVector3(this.GUID);
        }
    }
}
