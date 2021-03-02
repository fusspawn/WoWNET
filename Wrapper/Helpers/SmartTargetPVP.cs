using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Wrapper.API;
using Wrapper.WoW;
using Wrapper.WoW.Filters;

namespace Wrapper.Helpers
{
    public class SmartTargetPVP
    {
        public List<ScoredWowPlayer> Units
            = new List<ScoredWowPlayer>();


        double LastUpdateTime;

        public SmartTargetPVP(PlayerFilterList players)
        {
            Players = players;
        }

        public PlayerFilterList Players;

        public void Pulse()
        {
            if (WoWAPI.GetTime() - LastUpdateTime < 5)
                return;

            LastUpdateTime =Program.CurrentTime;

            Units.Clear();

            var AllValid = (from p in Players.GetUnits().Where(x=> Vector3.Distance(x.Value.Position, ObjectManager.Instance.Player.Position) < 60)
                            where !p.Value.Dead && p.Value.GUID != ObjectManager.Instance.Player.GUID
                            && p.Value.Reaction < 4 select p);

            foreach(var player in AllValid)
            {
                float score = 1000 - (float)Vector3.Distance(player.Value.Position,
                    ObjectManager.Instance.Player.Position);
                score = score + ((player.Value.HealthMax - player.Value.Health) / 5);

                if (WoWAPI.UnitPvpClassification(player.Value.GUID) 
                    != WoWAPI.PVPClassification.None)
                {
                    score = score + 100;
                }

                var target = LuaBox.Instance.UnitTarget(player.Value.GUID);
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
                    Player = player.Value as WoWPlayer,
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
