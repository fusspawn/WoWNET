using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.BotBases;
using Wrapper.Helpers;
using static Wrapper.StdUI;

namespace Wrapper.UI
{
    public class BotMainUI
    {
        public class BotUIDataContainer
        {
            public StdUiFrame MainBotUIFrame;
            public StdUiCheckBox EnabledCheckbox;
            public StdUiDropdown SelectedBotBase;
            public StdUiButton ToggleBotUI;

            public StdUiFrame ConfigFrame;
        }


        public StdUI StdUI;
       
        public BotUIDataContainer UIContainer;

        public BotMainUI()
        {
            CreateMainFrame();
        }

        public void SetConfigPanel(StdUI.StdUiFrame Frame)
        {
            if (UIContainer.ConfigFrame != null)
                UIContainer.ConfigFrame.Hide();

            UIContainer.ConfigFrame = Frame;

            if (Frame != null)
            {
                Frame.Show();
            }
        }

        private void CreateMainFrame()
        {
            if(StdUI == null)
            {
                StdUI = new LibStub().GetNewInstance<StdUI>("StdUi");
            }

            UIContainer = new BotUIDataContainer();
            UIContainer.MainBotUIFrame = StdUI.Window(LuaHelper.GetGlobalFrom_G<WoWFrame>("UIParent"), 500, 600, "BroBot");
            UIContainer.MainBotUIFrame.SetPoint("CENTER", 0, 0);
            UIContainer.MainBotUIFrame.Show();


            UIContainer.EnabledCheckbox = StdUI.Checkbox(UIContainer.MainBotUIFrame, "Enabled", 150, 25);            
            UIContainer.EnabledCheckbox.OnValueChanged += (self, state, value) =>
            {
                Program.IsRunning = UIContainer.EnabledCheckbox.GetValue<bool>();
                Console.WriteLine("Toggled Bot: Is Running: " + Program.IsRunning);

                LuaBox.Instance.Navigator.Stop();
            };
            StdUI.GlueTop(UIContainer.EnabledCheckbox, UIContainer.MainBotUIFrame, -150, -40, "TOP");


            StdUiDropdown.StdUiDropdownItems[] Options = null;
            /*[[
                  local Options = { 
                        {text="Nothing", value=0},
                        {text="BGBot", value=1}, 
                        {text="GrindBot", value=2},
                        {text="WoWScanner", value=3}
                    }
            ]]*/

            UIContainer.SelectedBotBase = StdUI.Dropdown(UIContainer.MainBotUIFrame, 200, 25, Options, null, false, false);
            
            UIContainer.SelectedBotBase.SetOptions(Options);
            UIContainer.SelectedBotBase.SetPlaceholder("~-- Please Select a BotBase --~");
            UIContainer.SelectedBotBase.OnValueChanged += (self, values) =>
            {
                var Value = UIContainer.SelectedBotBase.GetValue<int>();
                if (Value == 1)
                {
                    Console.WriteLine("Switching to PVP Bot base");
                    Program.Base = new PVPBotBase();
                }
                else if (Value == 2)
                {
                    Console.WriteLine("Switching to Grind Bot base");
                    Program.Base = new NativeGrindBotBase();
                }
                else if (Value == 3)
                {
                    Console.WriteLine("Switching to Grind Bot base");
                    Program.Base = new DataLoggerBase();
                } else
                {
                    Console.WriteLine("Selected Empty Bot Base");
                    Program.Base = null;
                }


                if (Program.Base != null)
                    Program.Base.BuildConfig(UIContainer.MainBotUIFrame);
            };

            StdUI.GlueTop(UIContainer.SelectedBotBase, UIContainer.MainBotUIFrame, 0, -40, "TOP");


            UIContainer.ToggleBotUI = StdUI.HighlightButton(LuaHelper.GetGlobalFrom_G<WoWFrame>("UIParent"), 100, 25, "Toggle BroBot UI");
            UIContainer.ToggleBotUI.SetScript<Action>("OnClick", () =>
            {
                if (!UIContainer.MainBotUIFrame.IsShown())
                    UIContainer.MainBotUIFrame.Show();
                else
                    UIContainer.MainBotUIFrame.Hide();
            });    
            
            StdUI.GlueTop(UIContainer.ToggleBotUI, LuaHelper.GetGlobalFrom_G<WoWFrame>("UIParent"), 20, 5, "TOP");

            
        }
    }
}
