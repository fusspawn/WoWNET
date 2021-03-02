using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Wrapper.API;
using Wrapper.WoW;
using Wrapper.WoW.Filters;

namespace Wrapper.Helpers
{
    public class ScoredWowPlayer
    {
        public WoWPlayer Player;
        public float Score;
    }

    public class SmartMovePVP
    {

        public List<ScoredWowPlayer> Units 
            = new List<ScoredWowPlayer>();

        double LastUpdateTime;
        private PlayerFilterList players;

        public SmartMovePVP(PlayerFilterList players)
        {
            this.players = players;
        }

        public void Pulse()
        {
            if (WoWAPI.GetTime() - LastUpdateTime < 5)
                return;

            LastUpdateTime =Program.CurrentTime;

            Units.Clear();

            int FriendlyScore = 4;
            int HostileScore = 2;

            string Role = WoWAPI.GetSpecializationRole(WoWAPI.GetSpecialization());

            if (Role == "HEALER")
            {

                FriendlyScore = 5;
                HostileScore = 2;
            }


            var ValidUnits = players.GetUnits().Where(x =>
            {
                return x.Value.GUID != ObjectManager.Instance.Player.GUID && !x.Value.Dead;
            });

            //Console.WriteLine("Smart Move Found " + ValidUnits.Count() + " Units");

            foreach(var unit in ValidUnits)
            {
                float score = 0;

                int NumFriends = (from p in ValidUnits.Where(x =>
                                  Vector3.Distance(x.Value.Position, unit.Value.Position) < 60 && x.Value.Reaction > 4)
                                  select p).Count();

                int NumHostile = (from p in ValidUnits.Where(x =>
                                  Vector3.Distance(x.Value.Position, unit.Value.Position) < 60 && x.Value.Reaction < 4)
                                  select p).Count();

                score = 1000 + (NumFriends * FriendlyScore) + (NumHostile * HostileScore);

                if ((NumHostile * HostileScore)
                    > (NumFriends * FriendlyScore) * 1.5)
                {
                    score = score - 1000; // No suicde plx.
                }

                //Console.WriteLine("Scored New Unit: " + unit.Name + " score: " + score);
                Units.Add(new ScoredWowPlayer() { Player = unit.Value as WoWPlayer, Score = score });
            }

            
        }


        public ScoredWowPlayer GetBestUnit()
        {
            return Units.Count() > 0
                ? Units.OrderByDescending(x=>x.Score).FirstOrDefault() 
                : null;
        }
    }
}
