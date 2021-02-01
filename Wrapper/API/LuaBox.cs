using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.ObjectManager;

namespace Wrapper.API
{
    public class LuaBox
    {
        private static LuaBox _instance;
        public static LuaBox Instance { get { if (_instance == null) { _instance = new LuaBox(); } return _instance; } }

        public Navigator Navigator = new Navigator();

        public enum EClientTypes
        {
            Classic = 1,
            Retail = 0
        }
        public enum EGameObjectTypes
        {
            AreaDamage = 12,
            AuraGenerator = 30,
            BarberChair = 32,
            Binder = 4,
            Button = 1,
            Camera = 13,
            CapturePoint = 42,
            Chair = 7,
            ChallengeModeReward = 51,
            Chest = 3,
            ClientCreature = 40,
            ClientItem = 41,
            ControlZone = 29,
            DestructibleBuilding = 33,
            Door = 0,
            DuelArbiter = 16,
            DungeonDifficulty = 31,
            FishingHole = 25,
            FishingNode = 17,
            FlagDrop = 26,
            FlagStand = 24,
            GarrisonBuilding = 38,
            GarrisonMonument = 44,
            GarrisonMonumentPlaque = 46,
            GarrisonPlot = 39,
            GarrisonShipment = 45,
            GatheringNode = 50,
            Generic = 5,
            Goober = 10,
            GuardPost = 21,
            GuildBank = 34,
            Invalid = 1,
            ItemForge = 47,
            KeystoneReceptacle = 49,
            Mailbox = 19,
            MapObject = 14,
            MapObjTransport = 15,
            MeetingStone = 23,
            MiniGame = 27,
            Multi = 52,
            NewFlag = 36,
            NewFlagDrop = 37,
            PhaseableMo = 43,
            PvpReward = 55,
            QuestGiver = 2,
            Ritual = 18,
            SiegeableMo = 54,
            SiegeableMulti = 53,
            SpellCaster = 22,
            SpellFocus = 8,
            Text = 9,
            Transport = 11,
            Trap = 6,
            TrapDoor = 35,
            UiLink = 48
        }
        public enum ELockTypes
        {
            AncientMana = 30,
            Archaelogy = 22,
            ArmTrap = 9,
            Blasting = 16,
            CalcifiedElvenGems = 7,
            CataclysmHerbalism = 35,
            CataclysmMining = 43,
            ClassicHerbalism = 32,
            ClassicMining = 40,
            Close = 8,
            DisarmTrap = 4,
            DraenorHerbalism = 37,
            DraenorMining = 45,
            Fishing = 19,
            Gahzridian = 15,
            Herbalism = 2,
            Inscription = 20,
            KulTiranHerbalien = 39,
            KulTiranMining = 47,
            LegionHerbalism = 38,
            LegionMining = 46,
            LockPicking = 1,
            LumberMill = 28,
            Mining = 3,
            NorthrendHerbalism = 34,
            NorthrendMining = 42,
            Open = 5,
            OpenAttacking = 14,
            OpenFromVehicle = 21,
            OpenKneeling = 13,
            OpenTinkering = 12,
            OutlandHerbalism = 33,
            OutlandMining = 41,
            PandariaHerbalism = 36,
            PandariaMining = 44,
            PvpClose = 18,
            PvpOpen = 17,
            PvpOpenFast = 23,
            QuickClose = 11,
            QuickOpen = 10,
            Skinning = 29,
            Skinning2 = 48,
            Treasure = 6,
            WarBoard = 31
        }
        public enum EMovementFlags
        {
            Ascending = 2097152,
            Backward = 2,
            CanFly = 8388608,
            Descending = 4194304,
            Falling = 2048,
            FallingFar = 4096,
            Flying = 16777216,
            Forward = 1,
            Immobilized = 1024,
            PitchDown = 128,
            PitchUp = 64,
            StrafeLeft = 4,
            StrafeRight = 8,
            Swimming = 1048576,
            TurnLeft = 16,
            TurnRight = 32,
            Walking = 256,
        }
        public enum ENpcFlags : uint
        {
            ArtifactPowerRespec = 134217728,
            Auctioneer = 2097152,
            Banker = 131072,
            BattleMaster = 1048576,
            BlackMarket = 2147483648,
            Gossip = 1,
            GuildBanker = 8388608,
            Innkeeper = 65536,
            Mailbox = 67108864,
            PlayerVehicle = 33554432,
            QuestGiver = 2,
            Repair = 4096,
            SpellClick = 16777216,
            SpiritGuide = 32768,
            StableMaster = 4194304,
            Trainer = 16,
            TrainerClass = 32,
            TrainerProfession = 64,
            Transmogrifier = 268435456,
            VaultKeeper = 536870912,
            Vendor = 128,
            VendorAmmo = 256,
            VendorFood = 512,
            VendorPoison = 1024,
            VendorReagent = 2048,
            WildBattlePet = 1073741824,
        }
        public enum ERaycastFlags
        {
            Collision = 1048849,
            Cull = 524288,
            DoodadCollision = 1,
            DoodadRender = 2,
            EntityCollision = 1048576,
            EntityRender = 2097152,
            LineOfSight = 1048592,
            LiquidAll = 131072,
            LiquidWaterWalkable = 65536,
            Terrain = 256,
            WmoCollision = 16,
            WmoIgnoreDoodad = 8192,
            WmoNoCamCollision = 64,
            WmoRender = 32
        }
        public enum EUnitDynamicFlags
        {
            Invisible = 1,
            Phased = 2,
            Lootable = 4,
            Tracked = 8,
            Tapped = 16,
            SpecialInfo = 32,
            Dead = 64,
            ReferAFriendLinked = 128
        }
        public enum EUnitFlags
        {
            CannotSwim = 16384,
            Confused = 4194304,
            Disarmed = 2097152,
            Fleeing = 8388608,
            ImmuneToNpc = 512,
            ImmuneToPc = 256,
            InCombat = 524288,
            Looting = 1024,
            Mount = 134217728,
            NonAttackable = 2,
            NotAttackable1 = 128,
            NotSelectable = 33554432,
            Pacified = 131072,
            PetInCombat = 2048,
            PlayerControlled = 16777216,
            Preparation = 32,
            PvpAttackable = 8,
            RemoveClientControl = 4,
            Rename = 16,
            ServerController = 1,
            Sheath = 1073741824,
            Silenced = 8192,
            Skinnable = 67108864,
            Stunned = 262144,
            TaxiFlight = 1048576
        }
        public enum EUnitFlags2
        {
            AllowChangingTalents = 512,
            AllowCheatSpells = 262144,
            AllowEnemyInteract = 16384,
            ComprehendLang = 8,
            DisablePredStats = 256,
            DisableTurn = 32768,
            DisarmOffhand = 128,
            DisarmRanged = 1024,
            FeignDeath = 1,
            ForceMovement = 64,
            IgnoreReputation = 4,
            InstantAppearModel = 3,
            MirrorImage = 16,
            NoActions = 8388608,
            PlayDeathAnim = 131072,
            PreventSpellClick = 8192,
            RegeneratePower = 2048,
            RestrictPartyInteraction = 4096
        }


        public enum EObjectType
        {
            Object = 0,
            Item = 1,
            Container = 2,
            AzeriteEmpoweredItem = 3,
            AzeriteItem = 4,
            Unit = 5,
            Player = 6,
            ActivePlayer = 7,
            GameObject = 8,
            DynamicObject = 9,
            Corpse = 10,
            AreaTrigger = 11,
            SceneObject = 12,
            ConversationData = 13
        }
        /// <summary>
        /// @CSharpLua.Template = "__LB__.CancelPendingSpell()"        /// 
        /// Cancel pending spells
        /// </summary>
        public extern void CancelPendingSpell();

        /// <summary>
        /// @CSharpLua.Template = "__LB__.ClickPosition({0}, {1}, {2}, {3})"        /// 
        /// Perform on click on the terrain at the given location
        /// If rightClick parameter is true, a right click is performed
        /// </summary>
        public extern void ClickPosition(float x, float y, float z, bool rightClick = false);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.CloseGame()"
        /// </summary>
        public extern void CloseGame();

        /// <summary>
        /// @CSharpLua.Template = " __LB__.CreateDirectory({0})"
        /// </summary>
        public extern bool CreateDirectory(string Directory);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.DirectoryExists({0})"
        /// </summary>
        public extern bool DirectoryExists(string Directory);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.DisableRelogger()"
        /// </summary>
        public extern void DisableRelogger();

        /// <summary>
        /// @CSharpLua.Template = " __LB__.FileExists({0})"
        /// </summary>
        public extern bool FileExists(string Directory);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.GameObjectHasLockType({0}, {1})"
        /// </summary>
        public extern bool GameObjectHasLockType(string GUID, LuaBox.ELockTypes LockType);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.GameObjectLockTypes({0})"
        /// </summary>
        public extern LuaBox.ELockTypes[] GameObjectLockTypes(string GUID);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.GameObjectType({0})"
        /// </summary>
        public extern LuaBox.EGameObjectTypes GameObjectType(string GUID);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetBaseDirectory()"
        /// </summary>
        public extern string GetBaseDirectory();


        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetCameraAngles()"
        /// </summary>
        public extern void GetCameraAngles(out float facing, out float pitch);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetClientType()"
        /// </summary>
        public extern LuaBox.EClientTypes GetClientType();

        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetDevMode()"
        /// </summary>
        public extern bool GetDevMode();

        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetDirectories({0})"
        /// </summary>
        public extern string[] GetDirectories(string Path);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetFiles({0})"
        /// </summary>
        public extern string[] GetFiles(string Path);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetGameAccountName()"
        /// </summary>
        public extern string GetGameAccountName();

        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetGameDirectory()"
        /// </summary>
        public extern string GetGameDirectory();


        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetDistance3D({0}, {1}, {2}, {3}, {4}, {5})"
        /// </summary>
        public extern float GetDistance3D(float x, float y, float z, float a, float b, float c);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetDistance3D({0}, {1})"
        /// </summary>
        public extern float GetDistance3D(string UnitIdFrom, string UnitIdTo);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetLastWorldClickPosition()"
        /// </summary>
        public extern void GetLastWorldClickPosition(out float x, out float y, out float z);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetMapId()"
        /// </summary>
        public extern int GetMapId();


        /// <summary>
        /// @CSharpLua.Template = "__LB__.GetObjects({0})"
        /// </summary>
        public extern string[] GetObjects(float Distance);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetObjects({0}, {1})"
        /// </summary>
        public extern string[] GetObjects(float Distance, LuaBox.EGameObjectTypes Type);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.GetObjects({0}, {1}, {2})"
        /// </summary>
        public extern string[] GetObjects(float Distance, LuaBox.EGameObjectTypes Type, LuaBox.EGameObjectTypes Type2);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.GetObjects({0}, {1}, {2}, {3})"
        /// </summary>
        public extern string[] GetObjects(float Distance, LuaBox.EGameObjectTypes Type, LuaBox.EGameObjectTypes Type2, LuaBox.EGameObjectTypes Type3);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetPlayerCorpsePosition()"
        /// </summary>
        public extern void GetPlayerCorpsePosition(out float x, out float y, out float z);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.GetWindowSize()"
        /// </summary>
        public extern void GetWindowSize(out float width, out float height);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.HttpAsyncGet({0}, {1}, {2}, {3}, {4}, {5})"
        /// </summary>
        public extern bool HttpAsyncGet(string host, int port, bool isHttps, string path, Func<string> OnSuccess, Func<string> OnError);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.HttpAsyncPost({0}, {1}, {2}, {3}, {4}, {5}, {6})"
        /// </summary>
        public extern bool HttpAsyncPost(string host, int port, bool isHttps, string path, string postData, Func<string> OnSuccess, Func<string> OnError);


        /// <summary>
        /// @CSharpLua.Template = "__LB__.LoadScript({0})"
        /// </summary>
        public extern void LoadScript(string Hash);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.IsAoEPending({0})"
        /// </summary>
        public extern bool IsAoEPending(string GuidOrUnitId);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.ObjectCreator({0})"
        /// </summary>
        public extern string ObjectCreator(string GuidOrUnitId);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.ObjectDynamicFlags({0})"
        /// </summary>
        public extern int ObjectDynamicFlags(string GuidOrUnitId);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.ObjectExists({0})"
        /// </summary>
        public extern bool ObjectExists(string GuidOrUnitId);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.ObjectFacing({0})"
        /// </summary>
        public extern float ObjectFacing(string GuidOrUnitId);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.ObjectHasDynamicFlag({0}, {1})"
        /// </summary>
        public extern bool ObjectHasDynamicFlag(string GuidOrUnitId, LuaBox.EUnitDynamicFlags Flag);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.ObjectId({0}, {1})"
        /// </summary>
        public extern int ObjectId(string GuidOrUnitId);

        /// <summary>
        /// @CSharpLua.Template = "local func = function (...) return __LB__.Unlock(__LB__.ObjectInteract, ...) end func({0})"
        /// </summary>
        public extern void ObjectInteract(string GuidOrUnitId);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.ObjectLocked({0})"
        /// </summary>
        public extern bool ObjectLocked(string GuidOrUnitId);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.ObjectName({0})"
        /// </summary>
        public extern string ObjectName(string GuidOrUnitId);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.ObjectPitch({0})"
        /// </summary>
        public extern float ObjectPitch(string GuidOrUnitId);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.ObjectPointer({0})"
        /// </summary>
        public extern string ObjectPointer(string GuidOrUnitId);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.ObjectPosition({0})"
        /// </summary>
        public extern void ObjectPosition(string GuidOrUnitId, out float x, out float y, out float z);

        public Vector3 ObjectPositionVector3(string GUIDorUnitID)
        {
            float x, y, z;
            LuaBox.Instance.ObjectPosition(GUIDorUnitID, out x, out y, out z);
            return new Vector3(x,y,z);
        }


        /// <summary>
        /// @CSharpLua.Template = "__LB__.ObjectType({0})"
        /// </summary>
        public extern EObjectType ObjectType(string GuidOrUnitId);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.PlayerSpecializationId({0})"
        /// </summary>
        public extern int PlayerSpecializationId(string GuidOrUnitId);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.Raycast({0}, {1}, {2}, {3}, {4}, {5}, {6})"
        /// </summary>
        public extern bool Raycast(float x, float y, float z, float a, float b, float c, int Flags);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.RunString({0})"
        /// </summary>
        public extern void RunString(string code);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.SetCameraAngles({0}, {1})"
        /// </summary>
        public extern void SetCameraAngles(float facing, float pitch);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitAuras({0})"
        /// </summary>
        public extern Dictionary<int, string> UnitAuras(string UnitGuidOrUnitID);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitAurasInfo({0}, {1})"
        /// </summary>
        public extern UnitAura[] UnitAurasInfo(string UnitGuidOrUnitID, int[] SpellIds);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitBoundingHeight({0})"
        /// </summary>
        public extern float UnitBoundingHeight(string UnitGuidOrUnitID);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitBoundingRadius({0})"
        /// </summary>
        public extern float UnitBoundingRadius(string UnitGuidOrUnitID);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitCastingInfo({0})"
        /// </summary>
        public extern float UnitCastingInfo(string UnitGuidOrUnitID, out string CastGUID, out string TargetGUID, out float TimeLeftInSeconds, out bool NotInterruptible);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitChannelInfo({0})"
        /// </summary>
        public extern float UnitChannelInfo(string UnitGuidOrUnitID, out string CastGUID, out string TargetGUID, out float TimeLeftInSeconds, out bool NotInterruptible);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitCollisionScale({0})"
        /// </summary>
        public extern float UnitCollisionScale(string UnitGuidOrUnitID);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitCombatReach({0})"
        /// </summary>
        public extern float UnitCombatReach(string UnitGuidOrUnitID);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitFlags({0})"
        /// </summary>
        public extern int UnitFlags(string UnitGuidOrUnitID);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitFlags2({0})"
        /// </summary>
        public extern int UnitFlags2(string UnitGuidOrUnitID);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitHasFlag({0}, {1})"
        /// </summary>
        public extern bool UnitHasFlag(string UnitGuidOrUnitID, EUnitFlags Flag);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitHasFlag2({0}, {1})"
        /// </summary>
        public extern bool UnitHasFlag2(string UnitGuidOrUnitID, EUnitFlags2 Flag);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitHasNpcFlag({0}, {1})"
        /// </summary>
        public extern bool UnitHasNpcFlag(string UnitGuidOrUnitID, ENpcFlags Flag);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitIsLootable({0})"
        /// </summary>
        public extern bool UnitIsLootable(string UnitGuidOrUnitID);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitMovementFlags({0})"
        /// </summary>
        public extern int UnitMovementFlags(string UnitGuidOrUnitID);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitNpcFlags({0})"
        /// </summary>
        public extern int UnitNpcFlags(string UnitGuidOrUnitID);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.UnitTarget({0})"
        /// </summary>
        public extern string UnitTarget(string UnitGuidOrUnitID);


        /// <summary>
        /// @CSharpLua.Template = " __LB__.UpdateAFK()"
        /// </summary>
        public extern void UpdateAFK();

        /// <summary>
        /// @CSharpLua.Template = " __LB__.UpdatePlayerMovement()"
        /// </summary>
        public extern void UpdatePlayerMovement();


        /// <summary>
        /// @CSharpLua.Template = " __LB__.WriteFile({0}, {1}, {2})"
        /// </summary>
        public extern bool WriteFile(string Path, string Contents, bool IsAppend=true);

    }

    public class UnitAura
    {
        public bool Active;
        public int AuraId;
        public bool Cancelable;
        public bool CanStealOrPurge;
        public string Caster;
        public int Count;
        public float Duration;
        public float Expiration;
        public bool Harmful;
        public string Name;
        public bool Passive;
        public int Id;
    }


    public class Navigator
    {
        /// <summary>
        /// @CSharpLua.Template = " __LB__.Navigator:GetDestination()"
        /// </summary>
        public extern void GetDestination(out float x, out float y, out float z);

        /// <summary>
        /// @CSharpLua.Template = " __LB__.Navigator:MoveTo({0}, {1}, {2})"
        /// </summary>
        public extern void MoveTo(float x, float y, float z, int index = 1, float proximityTolerance = 1);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.Navigator:Stop()"
        /// </summary>
        public extern void Stop();
    }

}
