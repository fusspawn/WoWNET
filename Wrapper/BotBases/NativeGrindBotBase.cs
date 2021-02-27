using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.NativeBehaviors;
using Wrapper.NativeBehaviors.BehaviorStateMachine;
using Wrapper.WoW;

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
        }

        public class NativeGrindConfigOptions
        {
            public bool AllowGather;
            public bool AllowSkin;
            public bool AllowLoot;
            public bool AllowPullingMobs;
            public bool AllowSelfDefense;

            public bool UseMaxRange;
            public double MaxRange;
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
                    AllowSelfDefense = true
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
            UIContainer.AllowGather.SetValue(true);
            UIContainer.AllowGather.OnValueChanged += (self, state, value) =>
            {
                ConfigOptions.AllowGather = value;
                SaveConfig();
            };

            Program.MainUI.StdUI.GlueTop(UIContainer.AllowGather, UIContainer.Container, -75, -50, "TOP");

            UIContainer.AllowSkin = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Allow Skinning", 200, 25);
            UIContainer.AllowSkin.SetValue(ConfigOptions.AllowSkin);
            UIContainer.AllowSkin.OnValueChanged += (self, state, value) =>
             {
                 ConfigOptions.AllowSkin = value;
                 SaveConfig();
             };

            Program.MainUI.StdUI.GlueTop(UIContainer.AllowSkin, UIContainer.Container, -75, -80, "TOP");

            UIContainer.AllowLoot = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Allow Looting", 200, 25);
            UIContainer.AllowLoot.SetValue(ConfigOptions.AllowLoot);
            UIContainer.AllowLoot.OnValueChanged += (self, state, value) =>
             {
                 ConfigOptions.AllowLoot = value;
                 SaveConfig();
             };

            Program.MainUI.StdUI.GlueTop(UIContainer.AllowLoot, UIContainer.Container, -75, -110, "TOP");

            UIContainer.AllowPullingMobs = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Allow Pulling Mobs", 200, 25);
            UIContainer.AllowPullingMobs.SetValue(ConfigOptions.AllowPullingMobs);
            UIContainer.AllowPullingMobs.OnValueChanged += (self, state, value) =>
            {
                ConfigOptions.AllowPullingMobs = value;
                SaveConfig();
            };

            Program.MainUI.StdUI.GlueTop(UIContainer.AllowPullingMobs, UIContainer.Container, -75, -140, "TOP");

            UIContainer.AllowSelfDefense = Program.MainUI.StdUI.Checkbox(UIContainer.Container, "Allow Self Defense", 200, 25);
            UIContainer.AllowSelfDefense.SetValue(ConfigOptions.AllowSelfDefense);
            UIContainer.AllowSelfDefense.OnValueChanged += (self, state, value) =>
            {
                ConfigOptions.AllowSelfDefense = value;
                SaveConfig();
            };
            Program.MainUI.StdUI.GlueTop(UIContainer.AllowSelfDefense, UIContainer.Container, -75, -170, "TOP");




            Program.MainUI.SetConfigPanel(UIContainer.Container);
        }
    }
}
