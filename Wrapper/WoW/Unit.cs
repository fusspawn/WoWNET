using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;

namespace Wrapper.WoW
{
    public class WoWUnit 
        : WoWGameObject
    {

        public int Health;
        public int HealthMax;
        public int Level;
        public int Reaction;
        public bool Dead;
        public string TargetGUID;
        public bool LineOfSight;

        public bool PlayerHasFought = false;

        public bool Friend { get { return Reaction > 4; } }
        public bool Hostile { get { return Reaction < 4; } }
        public bool Neutral { get { return Reaction == 4; } }
        public bool IsCasting
        {
            get
            {
                string CastID;
                string TargetGUID;
                double TimeLeft;
                bool NotInterruptable;

                LuaBox.Instance.UnitCastingInfo(GUID, out CastID, out TargetGUID, out TimeLeft, out NotInterruptable);
                return !String.IsNullOrEmpty(CastID);
            }
        }
        public bool IsChanneling
        {
            get
            {
                string CastID;
                string TargetGUID;
                double TimeLeft;
                bool NotInterruptable;

                LuaBox.Instance.UnitChannelInfo(GUID, out CastID, out TargetGUID, out TimeLeft, out NotInterruptable);
                return !String.IsNullOrEmpty(CastID);
            }
        }

      


        public WoWUnit(string _GUID) 
            : base(_GUID)
        {
        }

        public void Interact()
        {
            LuaBox.Instance.ObjectInteract(this.GUID);
        }

        public override void Update()
        {
            
            Health = WoWAPI.UnitHealth(GUID);
            HealthMax = WoWAPI.UnitHealthMax(GUID);
            Reaction = WoWAPI.UnitReaction(GUID);
            Dead = WoWAPI.UnitIsDeadOrGhost(GUID);
            TargetGUID = LuaBox.Instance.UnitTarget(GUID);

            if(Name == "Unknown")
            {
                Name = LuaBox.Instance.ObjectName(GUID);
            }



            if(ObjectManager.Instance.Player != null 
                && Vector3.Distance(ObjectManager.Instance.Player.Position, Position) < 50)
            {
                LineOfSight = !LuaBox.Instance.Raycast(Position.X, Position.Y, Position.Z + 1.5,
                    ObjectManager.Instance.Player.Position.X, ObjectManager.Instance.Player.Position.Y, ObjectManager.Instance.Player.Position.Z + 1.5,
                    0x100010)
                && !LuaBox.Instance.Raycast(Position.X, Position.Y, Position.Z + 2,
                    ObjectManager.Instance.Player.Position.X, ObjectManager.Instance.Player.Position.Y, ObjectManager.Instance.Player.Position.Z + 2,
                    0x100010);
            } 
            else
            {
                LineOfSight = false;
            }

            base.Update();
        }

        public void Target()
        {
            WoWAPI.TargetUnit(GUID);
        }
    }
}
