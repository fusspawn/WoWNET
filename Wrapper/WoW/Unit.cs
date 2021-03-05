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

        public bool Attackable { get { return WoWAPI.UnitCanAttack("player", GUID); } }
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

        public bool IsBossOrElite;

        public bool IsTargettingMeOrPet
        {
            get
            {

                if (TargetGUID == null)
                {
                    return false;
                }

              
                if (TargetGUID == ObjectManager.Instance.Player.GUID)
                {
                    DebugLog.Log("Unit", $"{Name} Is Targetting me");
                      return true;
                }

                if (ObjectManager.Instance.Player.Pet != null)
                {
                    if (TargetGUID == ObjectManager.Instance.Player.Pet.GUID)
                    {
                        return true;
                    }
                }


                return false;
            }
        }


        public WoWUnit(string _GUID) 
            : base(_GUID)
        {
            /*
             [[
                this.IsBossOrElite = (__LB__.UnitTagHandler(UnitClassification, this.GUID) == "worldboss"
                    or __LB__.UnitTagHandler(UnitClassification, this.GUID) == "elite"
                    or __LB__.UnitTagHandler(UnitClassification, this.GUID) == "rareelite")
             ]]
            */

            Update();
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


        public bool UnitIsFlying()
        {
            this.Position = LuaBox.Instance.ObjectPositionVector3(this.GUID);


            var HitPos = LuaBox.Instance.RaycastPosition(Position.X, Position.Y, Position.Z + 1,
                    Position.X, Position.Y, Position.Z - 100,
                    0x100010);

            if (HitPos.HasValue)
            {
                return Vector3.Distance(HitPos.Value, Position) > 5;
            }

            return true;
        }

        public void Target()
        {
            WoWAPI.TargetUnit(GUID);
        }
    }
}
