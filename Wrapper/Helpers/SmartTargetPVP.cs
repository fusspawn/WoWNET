using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Wrapper.API;
using Wrapper.WoW;

namespace Wrapper.Helpers
{
    public class SmartTargetPVP
    {
        public List<ScoredWowPlayer> Units
            = new List<ScoredWowPlayer>();


        double LastUpdateTime;

        public void Pulse()
        {
            if (WoWAPI.GetTime() - LastUpdateTime < 5)
                return;

            LastUpdateTime =Program.CurrentTime;

            Units.Clear();

            var AllValid = (from p in ObjectManager.GetAllPlayers(60)
                            where !p.Dead && p.GUID != ObjectManager.Instance.Player.GUID
                            && p.Reaction < 4 select p);

            foreach(var player in AllValid)
            {
                float score = 1000 - (float)Vector3.Distance(player.Position,
                    ObjectManager.Instance.Player.Position);
                score = score + ((player.HealthMax - player.Health) / 5);

                if (WoWAPI.UnitPvpClassification(player.GUID) 
                    != WoWAPI.PVPClassification.None)
                {
                    score = score + 100;
                }

                var target = LuaBox.Instance.UnitTarget(player.GUID);
                if (target != null)
                {
                   if (target == ObjectManager.Instance.Player.GUID
                        && WoWAPI.UnitAffectingCombat(target))
                   {
                        score = score + 152;
                   }     
                }

                Units.Add(new ScoredWowPlayer()
                {
                    Player = player,
                    Score = score
                });
            }
        }


        public WoWPlayer GetBestUnit()
        {
            return Units.Count() > 0 ? Units.OrderByDescending(x => x.Score).FirstOrDefault().Player : null;
        }
    }
}
