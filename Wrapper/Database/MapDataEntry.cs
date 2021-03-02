using System;
using System.Collections.Generic;
using Wrapper.API;
using Wrapper.WoW;

namespace Wrapper.Database
{
    public class MapDataEntry
    {
        public List<NPCLocationInfo> InnKeepers = new List<NPCLocationInfo>();
        public List<NPCLocationInfo> MailBoxes = new List<NPCLocationInfo>();
        public List<NPCLocationInfo> Auctioneers = new List<NPCLocationInfo>();
        public List<NPCLocationInfo> FlightMaster = new List<NPCLocationInfo>();
        public List<NPCLocationInfo> Vendors = new List<NPCLocationInfo>();
        public List<NPCLocationInfo> Repair = new List<NPCLocationInfo>();
        public List<NPCLocationInfo> Beasts = new List<NPCLocationInfo>();
        public List<NodeLocationInfo> Nodes = new List<NodeLocationInfo>();
        public List<Vector3> PlayerDeathSpots = new List<Vector3>();

        public void RestoreFromJson(MapDataEntry mapDataEntry)
        {
            foreach(var node in mapDataEntry.Nodes) {
                Nodes.Add(new NodeLocationInfo()
                {
                    X = node.X,
                    Y = node.Y,
                    Z = node.Z,
                    Name = node.Name,
                    NodeType = node.NodeType,
                    MapID = node.MapID,
                    ObjectId = node.ObjectId
                });
            }

            foreach (var node in mapDataEntry.Repair)
            {
                if(WoWDatabase.BannedObjectIDs.Contains(node.ObjectId))
                {
                    DebugLog.Log("BroBot", "Removing Banned Repair Vendor From DataBase");
                    continue;
                }

                Repair.Add(new NPCLocationInfo()
                {
                    X = node.X,
                    Y = node.Y,
                    Z = node.Z,
                    Name = node.Name,
                    NodeType = node.NodeType,
                    MapID = node.MapID,
                    ObjectId = node.ObjectId
                });
            }

            foreach (var node in mapDataEntry.Vendors)
            {
                if (WoWDatabase.BannedObjectIDs.Contains(node.ObjectId))
                {
                    DebugLog.Log("BroBot", "Removing Banned Vendor From DataBase");
                    continue;
                }

                Vendors.Add(new NPCLocationInfo()
                {
                    X = node.X,
                    Y = node.Y,
                    Z = node.Z,
                    Name = node.Name,
                    NodeType = node.NodeType,
                    MapID = node.MapID,
                    ObjectId = node.ObjectId
                });
            }

            foreach (var node in mapDataEntry.InnKeepers)
            {
                InnKeepers.Add(new NPCLocationInfo()
                {
                    X = node.X,
                    Y = node.Y,
                    Z = node.Z,
                    Name = node.Name,
                    NodeType = node.NodeType,
                    MapID = node.MapID,
                    ObjectId = node.ObjectId
                });
            }

            foreach (var node in mapDataEntry.FlightMaster)
            {
                FlightMaster.Add(new NPCLocationInfo()
                {
                    X = node.X,
                    Y = node.Y,
                    Z = node.Z,
                    Name = node.Name,
                    NodeType = node.NodeType,
                    MapID = node.MapID,
                    ObjectId = node.ObjectId
                });
            }
        

            foreach (var node in mapDataEntry.MailBoxes)
            {
                MailBoxes.Add(new NPCLocationInfo()
                {
                    X = node.X,
                    Y = node.Y,
                    Z = node.Z,
                    Name = node.Name,
                    NodeType = node.NodeType,
                    MapID = node.MapID,
                    ObjectId = node.ObjectId
                });
            }


            foreach (var node in mapDataEntry.Beasts)
            {
                Beasts.Add(new NPCLocationInfo()
                {
                    X = node.X,
                    Y = node.Y,
                    Z = node.Z,
                    Name = node.Name,
                    NodeType = node.NodeType,
                    MapID = node.MapID,
                    ObjectId = node.ObjectId
                });
            }


            /*
            foreach(var node in mapDataEntry.PlayerDeathSpots)
            {
                PlayerDeathSpots.Add(new Vector3()
                {
                    X = node.X,
                    Y = node.Y,
                    Z = node.Z
                });
            }
            */

        }
    }
}