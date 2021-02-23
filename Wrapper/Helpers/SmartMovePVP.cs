using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Wrapper.API;
using Wrapper.WoW;

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

        public void Pulse()
        {
            if (WoWAPI.GetTime() - LastUpdateTime < 5)
                return;

            LastUpdateTime = WoWAPI.GetTime();

            Units.Clear();

            int FriendlyScore = 4;
            int HostileScore = 2;

            string Role = WoWAPI.GetSpecializationRole(WoWAPI.GetSpecialization());

            if (Role == "HEALER")
            {

                FriendlyScore = 5;
                HostileScore = 2;
            }


            var ValidUnits = ObjectManager.GetAllPlayers(500).Where(x =>
            {
                return x.GUID != ObjectManager.Instance.Player.GUID && !x.Dead;
            });

            //Console.WriteLine("Smart Move Found " + ValidUnits.Count() + " Units");

            foreach(var unit in ValidUnits)
            {
                float score = 0;

                int NumFriends = (from p in ValidUnits.Where(x =>
                                  Vector3.Distance(x.Position, unit.Position) < 60 && x.Reaction > 4)
                                  select p).Count();

                int NumHostile = (from p in ValidUnits.Where(x =>
                                  Vector3.Distance(x.Position, unit.Position) < 60 && x.Reaction < 4)
                                  select p).Count();

                score = 1000 + (NumFriends * FriendlyScore) + (NumHostile * HostileScore);

                if ((NumHostile * HostileScore)
                    > (NumFriends * FriendlyScore) * 1.5)
                {
                    score = score - 1000; // No suicde plx.
                }

                //Console.WriteLine("Scored New Unit: " + unit.Name + " score: " + score);
                Units.Add(new ScoredWowPlayer() { Player = unit, Score = score });
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
