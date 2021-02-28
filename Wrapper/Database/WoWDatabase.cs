using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Wrapper.API;
using Wrapper.WoW;

namespace Wrapper.Database
{
    public class WoWDatabase
    {
        public static Dictionary<int, MapDataEntry> Maps
            = new Dictionary<int, MapDataEntry>();

        public static int GRID_SIZE = 20;
        public static HashSet<int> BannedObjectIDs = new HashSet<int>()
        {
            62822, //cousin-slowhands
            64515, //mystic-birdhat
            32642, //mojodishu
            32641, //drix-blackwrench
            142668, //merchant-maku
            142666, //collector-unta,
            32639, //gnimo
        };

        private static List<int> DirtyMapIds = new List<int>();
        private static bool IsSaveTaskRunning = false;

        public static bool HasDirtyMaps
        {
            get { return DirtyMapIds.Count() > 0; }
        }

        public static int GetGridHash(Vector3 Location)
        {
            return Vector3.Floor(Vector3.Divide(new Vector3(Location.X, Location.Y, Location.Z), GRID_SIZE)).GetHashCode();
        }

        public static void InsertDeathSpotIfRequired(Vector3 Position)
        {
            var MapId = LuaBox.Instance.GetMapId();
            var IsDirty = false;
            var MapDatabase = GetMapDatabase(MapId);


            if (!MapDatabase.PlayerDeathSpots.Any(x => 
                Vector3.Distance(Position, new Vector3(x.X, x.Y, x.Z)) < GRID_SIZE))
            {
                MapDatabase.PlayerDeathSpots.Add(Position);
                IsDirty = true;
            }

            if (IsDirty && !DirtyMapIds.Contains(MapId))
            {
                DirtyMapIds.Add(MapId);
                EnsureSaveProcessIsRunning();
            }
        }

        public static void InsertNpcIfRequired(WoWUnit Unit)
        {
            var MapId = LuaBox.Instance.GetMapId();
            var IsRepair = LuaBox.Instance.UnitHasNpcFlag(Unit.GUID, LuaBox.ENpcFlags.Repair);
            var IsVendor = LuaBox.Instance.UnitHasNpcFlag(Unit.GUID, LuaBox.ENpcFlags.Vendor);
            var IsInnKeeper = false;
            var IsFlightmaster = false;
            var IsMailBox = false; //LuaBox.Instance.UnitHasNpcFlag(Unit.GUID, LuaBox.ENpcFlags.Mailbox);

            if ((!IsRepair && !IsVendor && !IsInnKeeper && !IsFlightmaster && !IsMailBox)
                || WoWAPI.GetUnitSpeed(Unit.GUID) > 1
                || BannedObjectIDs.Contains(Unit.ObjectId))
            // Dont record moving NPCS. Itll ruin shit.
            {
                return;
            }

            var IsDirty = false;
            var MapDatabase = GetMapDatabase(MapId);



            if (IsRepair)
            {
                if (!MapDatabase.Repair.Any(x => x.ObjectId == Unit.ObjectId
                   && Vector3.Distance(Unit.Position, new Vector3(x.X, x.Y, x.Z)) < GRID_SIZE))
                // If we cant find a matching ObjectID within GRID_SIZE yards. Lets add this entry
                {

                    FactionID UnitFaction;
                    var FactionGroupString = WoWAPI.UnitFactionGroup(Unit.GUID);

                    switch (FactionGroupString)
                    {
                        case "Alliance":
                            UnitFaction = FactionID.Alliance;
                            break;
                        case "Horde":
                            UnitFaction = FactionID.Horde;
                            break;
                        default:
                            UnitFaction = FactionID.Neutral;
                            break;
                    }

                    MapDatabase.Repair.Add(new NPCLocationInfo()
                    {
                        X = Unit.Position.X,
                        Y = Unit.Position.Y,
                        Z = Unit.Position.Z,
                        ObjectId = Unit.ObjectId,
                        MapID = MapId,
                        NodeType = NPCNodeType.Repair,
                        Faction = UnitFaction,
                        Name = Unit.Name
                    });

                    Console.WriteLine("[WoWDatabase] Found New Repair NPC: " + Unit.Name);
                    IsDirty = true;
                }

            }
            if (IsVendor)
            {
                if (!MapDatabase.Vendors.Any(x => x.ObjectId == Unit.ObjectId
                         && Vector3.Distance(Unit.Position, new Vector3(x.X, x.Y, x.Z)) < GRID_SIZE))
                // If we cant find a matching ObjectID within GRID_SIZE yards. Lets add this entry
                {

                    FactionID UnitFaction;
                    var FactionGroupString = WoWAPI.UnitFactionGroup(Unit.GUID);

                    switch (FactionGroupString)
                    {
                        case "Alliance":
                            UnitFaction = FactionID.Alliance;
                            break;
                        case "Horde":
                            UnitFaction = FactionID.Horde;
                            break;
                        default:
                            UnitFaction = FactionID.Neutral;
                            break;
                    }

                    MapDatabase.Vendors.Add(new NPCLocationInfo()
                    {
                        X = Unit.Position.X,
                        Y = Unit.Position.Y,
                        Z = Unit.Position.Z,
                        ObjectId = Unit.ObjectId,
                        MapID = MapId,
                        NodeType = NPCNodeType.Vendor,
                        Faction = UnitFaction,
                        Name = Unit.Name
                    });

                    Console.WriteLine("[WoWDatabase] Found New Vendor NPC: " + Unit.Name);
                    IsDirty = true;
                }
            }
            if (IsInnKeeper)
            {
                if (!MapDatabase.InnKeepers.Any(x => x.ObjectId == Unit.ObjectId
                      && Vector3.Distance(Unit.Position, new Vector3(x.X, x.Y, x.Z)) < GRID_SIZE))
                // If we cant find a matching ObjectID within GRID_SIZE yards. Lets add this entry
                {

                    FactionID UnitFaction;
                    var FactionGroupString = WoWAPI.UnitFactionGroup(Unit.GUID);

                    switch (FactionGroupString)
                    {
                        case "Alliance":
                            UnitFaction = FactionID.Alliance;
                            break;
                        case "Horde":
                            UnitFaction = FactionID.Horde;
                            break;
                        default:
                            UnitFaction = FactionID.Neutral;
                            break;
                    }

                    MapDatabase.InnKeepers.Add(new NPCLocationInfo()
                    {
                        X = Unit.Position.X,
                        Y = Unit.Position.Y,
                        Z = Unit.Position.Z,
                        ObjectId = Unit.ObjectId,
                        MapID = MapId,
                        NodeType = NPCNodeType.InnKeeper,
                        Faction = UnitFaction,
                        Name = Unit.Name
                    });

                    Console.WriteLine("[WoWDatabase] Found New InnKeeper NPC: " + Unit.Name);
                    IsDirty = true;
                }
            }
            if (IsFlightmaster)
            {
                if (!MapDatabase.FlightMaster.Any(x => x.ObjectId == Unit.ObjectId
                  && Vector3.Distance(Unit.Position, new Vector3(x.X, x.Y, x.Z)) < GRID_SIZE))
                // If we cant find a matching ObjectID within GRID_SIZE yards. Lets add this entry
                {

                    FactionID UnitFaction;
                    var FactionGroupString = WoWAPI.UnitFactionGroup(Unit.GUID);

                    switch (FactionGroupString)
                    {
                        case "Alliance":
                            UnitFaction = FactionID.Alliance;
                            break;
                        case "Horde":
                            UnitFaction = FactionID.Horde;
                            break;
                        default:
                            UnitFaction = FactionID.Neutral;
                            break;
                    }

                    MapDatabase.FlightMaster.Add(new NPCLocationInfo()
                    {
                        X = Unit.Position.X,
                        Y = Unit.Position.Y,
                        Z = Unit.Position.Z,
                        ObjectId = Unit.ObjectId,
                        MapID = MapId,
                        NodeType = NPCNodeType.FlightMaster,
                        Faction = UnitFaction,
                        Name = Unit.Name
                    });

                    Console.WriteLine("[WoWDatabase] Found New Flightmaster NPC: " + Unit.Name);
                    IsDirty = true;
                }
            }
            if (IsMailBox)
            {
                if (!MapDatabase.MailBoxes.Any(x => x.ObjectId == Unit.ObjectId
                  && Vector3.Distance(Unit.Position, new Vector3(x.X, x.Y, x.Z)) < GRID_SIZE))
                // If we cant find a matching ObjectID within GRID_SIZE yards. Lets add this entry
                {

                    FactionID UnitFaction;
                    var FactionGroupString = WoWAPI.UnitFactionGroup(Unit.GUID);

                    switch (FactionGroupString)
                    {
                        case "Alliance":
                            UnitFaction = FactionID.Alliance;
                            break;
                        case "Horde":
                            UnitFaction = FactionID.Horde;
                            break;
                        default:
                            UnitFaction = FactionID.Neutral;
                            break;
                    }

                    MapDatabase.MailBoxes.Add(new NPCLocationInfo()
                    {
                        X = Unit.Position.X,
                        Y = Unit.Position.Y,
                        Z = Unit.Position.Z,
                        ObjectId = Unit.ObjectId,
                        MapID = MapId,
                        NodeType = NPCNodeType.MailBox,
                        Faction = UnitFaction,
                        Name = Unit.Name
                    });

                    Console.WriteLine("[WoWDatabase] Found New MailBox NPC: " + Unit.Name);
                    IsDirty = true;
                }
            }

            if (IsDirty && !DirtyMapIds.Contains(MapId))
            {
                DirtyMapIds.Add(MapId);
                EnsureSaveProcessIsRunning();
            }
        }

        public static bool IsConsideredDeathSpot(double x, double y, double z)
        {
            var CheckPos = new WoW.Vector3(x, y, z);
            var MapId = LuaBox.Instance.GetMapId();
            var Data = GetMapDatabase(MapId);

            return Data.PlayerDeathSpots.Any(x
                => Vector3.Distance(x, CheckPos) < GRID_SIZE);
        }

        public static void HandlePersistance()
        {
            if (!LuaBox.Instance.DirectoryExists($"{LuaBox.Instance.GetBaseDirectory()}\\BroBot\\Database\\MapData\\"))
            {
                LuaBox.Instance.CreateDirectory($"{LuaBox.Instance.GetBaseDirectory()}\\BroBot\\Database\\MapData\\");
            }

            foreach (var MapId in DirtyMapIds)
            {
                var Path = $"{LuaBox.Instance.GetBaseDirectory()}\\BroBot\\Database\\MapData\\{MapId}.db";
                var Data = GetMapDatabase(MapId);
                LuaBox.Instance.WriteFile(Path, LibJson.Serialize(Data), false);
                Console.WriteLine("[WoWDatabase] Persisted Changes to MapId: " + MapId);
            }

            DirtyMapIds.Clear();
        }

        public static void InsertNodeIfRequired(WoWGameObject Unit)
        {
            var MapId = LuaBox.Instance.GetMapId();
            var IsHerbOrOre = (Unit.IsHerb || Unit.IsOre);
            var IsMailBox = LuaBox.Instance.GameObjectType(Unit.GUID) == LuaBox.EGameObjectTypes.Mailbox;

            

            if ((!IsHerbOrOre && !IsMailBox)
                || BannedObjectIDs.Contains(Unit.ObjectId))
            // Dont record moving NPCS. Itll ruin shit.
            {
                return;
            }

            var IsDirty = false;
            var MapDatabase = GetMapDatabase(MapId);


            if (IsMailBox)
            {
                Console.WriteLine("Handling MailBox");

                if (!MapDatabase.MailBoxes.Any(x => x.ObjectId == Unit.ObjectId
                  && Vector3.Distance(Unit.Position, new Vector3(x.X, x.Y, x.Z)) < GRID_SIZE))
                // If we cant find a matching ObjectID within GRID_SIZE yards. Lets add this entry
                {

                    MapDatabase.MailBoxes.Add(new NPCLocationInfo()
                    {
                        X = Unit.Position.X,
                        Y = Unit.Position.Y,
                        Z = Unit.Position.Z,
                        ObjectId = Unit.ObjectId,
                        MapID = MapId,
                        NodeType = NPCNodeType.MailBox,
                        Faction = FactionID.Neutral,
                        Name = Unit.Name
                    });

                    Console.WriteLine("[WoWDatabase] Found New MailBox GameObject: " + Unit.Name);
                    IsDirty = true;
                }

                return;
            }








            if (!MapDatabase.Nodes.Any(x => x.ObjectId == Unit.ObjectId
               && Vector3.Distance(Unit.Position, new Vector3(x.X, x.Y, x.Z)) < GRID_SIZE))
            // If we cant find a matching ObjectID within GRID_SIZE yards. Lets add this entry
            {
                MapDatabase.Nodes.Add(new NodeLocationInfo()
                {
                    X = Unit.Position.X,
                    Y = Unit.Position.Y,
                    Z = Unit.Position.Z,
                    ObjectId = Unit.ObjectId,
                    MapID = MapId,
                    NodeType = Unit.IsHerb ? NodeType.Herb : NodeType.Ore,
                    Name = Unit.Name
                });

                Console.WriteLine("[WoWDatabase] Found New Harvest Node: " + Unit.Name);
                IsDirty = true;
            }

            if (IsDirty 
                && !DirtyMapIds.Contains(MapId))
            {
                DirtyMapIds.Add(MapId);
                EnsureSaveProcessIsRunning();
            }

        }

        private static void EnsureSaveProcessIsRunning()
        {
            if (!IsSaveTaskRunning)
            {
                IsSaveTaskRunning = true;

                WoWAPI.NewTicker(() =>
                {
                    WoWDatabase.HandlePersistance();
                }, 15);
            }
        }

        public static MapDataEntry GetMapDatabase(int MapId)
        {
            if (!Maps.ContainsKey(MapId))
            {
                if (!LuaBox.Instance.FileExists($"{LuaBox.Instance.GetBaseDirectory()}\\BroBot\\Database\\MapData\\{MapId}.db"))
                {
                    Maps.Add(MapId, new MapDataEntry()
                    {
                        Nodes = new List<NodeLocationInfo>(),
                        Vendors = new List<NPCLocationInfo>(),
                        Repair = new List<NPCLocationInfo>()
                    });
                }
                else
                {
                    var Text = LuaBox.Instance.ReadFile($"{LuaBox.Instance.GetBaseDirectory()}\\BroBot\\Database\\MapData\\{MapId}.db");
                    var MapDataEntry = LibJson.Deserialize<MapDataEntry>(Text);
                    var MapDataClass = new MapDataEntry();
                    MapDataClass.RestoreFromJson(MapDataEntry);
                    Maps.Add(MapId, MapDataClass);
                }
            }

            return Maps[MapId];
        }


        public static NPCLocationInfo GetClosestRepairNPC()
        {
            var MapDb = GetMapDatabase(LuaBox.Instance.GetMapId());
            
            if(MapDb.Repair.Count() > 0)
            {
                return MapDb.Repair.OrderBy(x => Vector3.Distance(ObjectManager.Instance.Player.Position, 
                    new Vector3(x.X, x.Y, x.Z))).FirstOrDefault();
            }

            return null;
        }


        public static NPCLocationInfo GetClosestVendorNPC()
        {
            var MapDb = GetMapDatabase(LuaBox.Instance.GetMapId());

            if (MapDb.Vendors.Count() > 0)
            {
                return MapDb.Vendors.OrderBy(x => Vector3.Distance(ObjectManager.Instance.Player.Position,
                    new Vector3(x.X, x.Y, x.Z))).FirstOrDefault();
            }

            return null;
        }

        public static List<NodeLocationInfo> GetAllHerbLocations()
        {
            var MapDb = GetMapDatabase(LuaBox.Instance.GetMapId());
            var Herbs = MapDb.Nodes.Where(x => x.NodeType == NodeType.Herb).ToList();
            return Herbs;
        }

        public static List<NodeLocationInfo> GetAllOreLocations()
        {
            var MapDb = GetMapDatabase(LuaBox.Instance.GetMapId());
            var Herbs = MapDb.Nodes.Where(x => x.NodeType == NodeType.Ore).ToList();
            return Herbs;
        }


    }
}
