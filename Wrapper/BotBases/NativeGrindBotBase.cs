using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.Helpers;
using Wrapper.NativeBehaviors;
using Wrapper.NativeBehaviors.BehaviorStateMachine;
using Wrapper.WoW;
using static Wrapper.StdUI;

namespace Wrapper.BotBases
{
    public class NativeGrindBotBase 
        : BotBase
    {
        public string name = "NativeGrind";
        public string author = "Fusspawn";



        public static NativeGrindConfigOptions ConfigOptions;
        public static StateMachine StateMachine;
        private static NativeGrindUIContainer UIContainer;
        
        public class NativeGrindUIContainer
        {
            public StdUI.StdUiFrame Container;
            public StdUI.StdUiLabel GrindLabel;

            public StdUI.StdUiCheckBox AllowGather;
            public StdUI.StdUiCheckBox AllowSkin;
            public StdUI.StdUiCheckBox AllowLoot;
            public StdUI.StdUiCheckBox AllowPullingMobs;
            public StdUI.StdUiCheckBox AllowSelfDefense;
            public StdUI.StdUiCheckBox AllowPullingYellows;
            public StdUI.StdUiCheckBox IgnoreElitesAndBosses;


            public StdUI.StdUiNumericInputFrame CombatRange;
        }

        public class NativeGrindConfigOptions
        {
            public bool AllowGather;
            public bool AllowSkin;
            public bool AllowLoot;
            public bool AllowPullingMobs;
            public bool AllowSelfDefense;

            public float CombatRange;
            internal bool AllowPullingYellows;
            internal bool IgnoreElitesAndBosses;
        }

        public NativeGrindBotBase()
        {
            name = "NativeGrind";

            LoadConfig();

            StateMachine = new StateMachine();
            StateMachine.States.Push(new NativeGrindBaseState());
        }

        private void LoadConfig()
        {
            var DirectoryPath = $"{LuaBox.Instance.GetBaseDirectory()}\\BroBot\\Config\\NativeGrind\\";

            if (!LuaBox.Instance.DirectoryExists(DirectoryPath))
            {
                LuaBox.Instance.CreateDirectory(DirectoryPath);
            }


            if(!LuaBox.Instance.FileExists(DirectoryPath + $"{ObjectManager.Instance.Player.Name}-{WoWAPI.GetRealmName()}.NativeGrind.json"))
            {
                ConfigOptions = new NativeGrindConfigOptions()
                {
                    AllowGather = ObjectManager.Instance.Player.HasProfession("Herbalism") || ObjectManager.Instance.Player.HasProfession("Mining"),
                    AllowSkin = ObjectManager.Instance.Player.HasProfession("Skinning"),
                    AllowLoot = true,
                    AllowPullingMobs = true,
                    AllowSelfDefense = true,
                    AllowPullingYellows = true,
                    CombatRange = 5,
                    IgnoreElitesAndBosses = true
                };

                SaveConfig();
            } 
            else
            {
                ConfigOptions = LibJson.Deserialize<NativeGrindConfigOptions>(LuaBox.Instance.ReadFile(DirectoryPath + $"{ObjectManager.Instance.Player.Name}-{WoWAPI.GetRealmName()}.NativeGrind.json"));
            }
        }

        private void SaveConfig()
        {
            var DirectoryPath = $"{LuaBox.Instance.GetBaseDirectory()}\\BroBot\\Config\\NativeGrind\\";
            var ConfigString = LibJson.Serialize(ConfigOptions);
            DebugLog.Log("BroBot", "Saving ConfigString: " + ConfigString);

            LuaBox.Instance.WriteFile(DirectoryPath + $"{ObjectManager.Instance.Player.Name}-{WoWAPI.GetRealmName()}.NativeGrind.json", ConfigString, false);
        }

        public double LastRun = Program.CurrentTime;
        public override void Pulse() { 
                StateMachine.Run();
        }

        public override void BuildConfig(StdUI.StdUiFrame Container)
        {

            if (UIContainer != null)
            {
                Program.MainUI.SetConfigPanel(UIContainer.Container);
                return; //Already created. Just set and continue;
            }

            UIContainer = new NativeGrindUIContainer();
            UIContainer.Container = Program.MainUI.StdUI.Frame(Container, Container.GetWidth(), Container.GetHeight() - 150, null);            
            Program.MainUI.StdUI.GlueTop(UIContainer.Container, Container, 0, -100, "TOP");

            UIContainer.GrindLabel = Program.MainUI.StdUI.Label(UIContainer.Container, "~== Native Grind Config ==~", 18, null, Container.GetWidth() - 10, 25);
            Program.MainUI.StdUI.GlueTop(UIContainer.GrindLabel, UIContainer.Container, 50, 0, "TOP");


            UIContainer.AllowGather = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Allow Gathering", 200, 25);
            UIContainer.AllowGather.SetChecked(true);
            UIContainer.AllowGather.OnValueChanged += (self, state, value) =>
            {
                DebugLog.Log("BroBot", $"OnValueChanged: {self} {state} {value}");
                ConfigOptions.AllowGather = state;
                SaveConfig();
            };

            Program.MainUI.StdUI.GlueTop(UIContainer.AllowGather, UIContainer.Container, -75, -50, "TOP");

            UIContainer.AllowSkin = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Allow Skinning", 200, 25);
            UIContainer.AllowSkin.SetChecked(ConfigOptions.AllowSkin);
            UIContainer.AllowSkin.OnValueChanged += (self, state, value) =>
            {
                DebugLog.Log("BroBot", $"OnValueChanged: {self} {state} {value}");
                ConfigOptions.AllowSkin = state;
                 SaveConfig();
             };

            Program.MainUI.StdUI.GlueTop(UIContainer.AllowSkin, UIContainer.Container, -75, -80, "TOP");

            UIContainer.AllowLoot = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Allow Looting", 200, 25);
            UIContainer.AllowLoot.SetChecked(ConfigOptions.AllowLoot);
            UIContainer.AllowLoot.OnValueChanged += (self, state, value) =>
            {
                DebugLog.Log("BroBot", $"OnValueChanged: {self} {state} {value}");
                ConfigOptions.AllowLoot = state;
                 SaveConfig();
             };

            Program.MainUI.StdUI.GlueTop(UIContainer.AllowLoot, UIContainer.Container, -75, -110, "TOP");

            UIContainer.AllowPullingMobs = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Allow Pulling Mobs", 200, 25);
            
            UIContainer.AllowPullingMobs.SetChecked(ConfigOptions.AllowPullingMobs);
            UIContainer.AllowPullingMobs.OnValueChanged += (self, state, value) =>
            {
                DebugLog.Log("BroBot", $"OnValueChanged: {self} {state} {value}");
                ConfigOptions.AllowPullingMobs = state;
                SaveConfig();
            };

            Program.MainUI.StdUI.GlueTop(UIContainer.AllowPullingMobs, UIContainer.Container, -75, -140, "TOP");

            UIContainer.AllowSelfDefense = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Allow Self Defense", 200, 25);
            UIContainer.AllowSelfDefense.SetChecked(ConfigOptions.AllowSelfDefense);
            UIContainer.AllowSelfDefense.OnValueChanged += (self, state, value) =>
            {
                DebugLog.Log("BroBot", $"OnValueChanged: {self} {state} {value}");
                ConfigOptions.AllowSelfDefense = state;
                SaveConfig();
            };

            Program.MainUI.StdUI.GlueTop(UIContainer.AllowSelfDefense, UIContainer.Container, -75, -170, "TOP");


            UIContainer.AllowPullingYellows = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Allow Pulling Yellows", 200, 25);
            UIContainer.AllowPullingYellows.SetChecked(ConfigOptions.AllowPullingYellows);
            UIContainer.AllowPullingYellows.OnValueChanged += (self, state, value) =>
            {
                DebugLog.Log("BroBot", $"OnValueChanged: {self} {state} {value}");
                ConfigOptions.AllowPullingYellows = state;
                SaveConfig();
            };

            Program.MainUI.StdUI.GlueTop(UIContainer.AllowPullingYellows, UIContainer.Container, -75, -200, "TOP");

            UIContainer.IgnoreElitesAndBosses = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Ignore Elites And Bosses", 200, 25);
            UIContainer.IgnoreElitesAndBosses.SetChecked(ConfigOptions.IgnoreElitesAndBosses);
            UIContainer.IgnoreElitesAndBosses.OnValueChanged += (self, state, value) =>
            {
                DebugLog.Log("BroBot", $"OnValueChanged: {self} {state} {value}");
                ConfigOptions.IgnoreElitesAndBosses = state;
                SaveConfig();
            };

            Program.MainUI.StdUI.GlueTop(UIContainer.IgnoreElitesAndBosses, UIContainer.Container, -75, -230, "TOP");



            UIContainer.CombatRange = Program.MainUI.StdUI.NumericBox(UIContainer.Container, 150, 25, $"{ConfigOptions.CombatRange}", null);
            UIContainer.CombatRange.SetValue(ConfigOptions.CombatRange);
            UIContainer.CombatRange.OnValueChanged += (self, value) =>
            {
                DebugLog.Log("BroBot", $"OnValueChanged: {self} {value}");
                ConfigOptions.CombatRange = value;
                SaveConfig();
            };

            Program.MainUI.StdUI.AddLabel(UIContainer.Container, UIContainer.CombatRange, "Pull Range", "TOP", null);
            Program.MainUI.StdUI.GlueTop(UIContainer.CombatRange, UIContainer.Container, -85, -280, "TOP");
            Program.MainUI.SetConfigPanel(UIContainer.Container);
        }

        public override void DrawDebug()
        {

            var Green = new LibDraw.LibDrawColor()
            {
                R = 0,
                G = 1,
                B = 0,
                A = 1,
            };

            var Red = new LibDraw.LibDrawColor()
            {
                R = 1,
                G = 0,
                B = 0,
                A = 1,
            };

            var Purple = new LibDraw.LibDrawColor()
            {
                R = 1,
                G = 0,
                B = 1,
                A = 1,
            };



            foreach (var Task 
                in NativeGrindBaseState.SmartObjective.Tasks) {



                LibDraw.Circle(Task.TargetUnitOrObject.Position, 1, 1, Task.Score > 0 ? Green : Red);
                LibDraw.Text($"{Task.TaskType}: {Task.Score}", Task.TargetUnitOrObject.Position, 12, Task.Score > 0 ? Green : Red, null);
            }

            var CurrentTask = NativeGrindBaseState.SmartObjective.GetNextTask(false);
            if (CurrentTask != null)
            {
                var OffSetPosition = CurrentTask.TargetUnitOrObject.Position - new WoW.Vector3(0, 0, .45);
                LibDraw.Text($"{CurrentTask.TaskType}: CURRENT TASK", OffSetPosition, 16,  Purple, null);
            }


            foreach (var Entry in Blacklist.BlackListEntrys)
            {
                if(LuaBox.Instance.ObjectExists(Entry.Key) 
                    && ObjectManager.Instance.AllObjects.ContainsKey(Entry.Key))
                {
                    LibDraw.Text($"Blacklisted - Remaining: {(int)Math.Abs(Program.CurrentTime - Entry.Value)}", ObjectManager.Instance.AllObjects[Entry.Key].Position, 12, Red, null);
                }
            }

            base.DrawDebug();
        }
    }
}
