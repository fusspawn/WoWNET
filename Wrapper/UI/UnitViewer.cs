using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Wrapper.API;
using Wrapper.Helpers;
using Wrapper.WoW;
using static Wrapper.StdUI;

namespace Wrapper.UI
{
    public class UnitViewer
    {

        public class UnitViewerUIContainer
        {
            public WoWFrame MainFrame;
            public StdUiScrollTable ScrollTable;
        }

        public UnitViewerUIContainer UIContainer;


        public UnitViewer()
        {
            CreateUI();
        }

        private void CreateUI()
        {
            UIContainer = new UnitViewerUIContainer();
            UIContainer.MainFrame = Program.MainUI.StdUI.Window(LuaHelper.GetGlobalFrom_G<WoWFrame>("UIParent"), 800, 500, "UnitViewer");
            UIContainer.MainFrame.SetPoint("CENTER", 0, 0);


            UIContainer.ScrollTable = Program.MainUI.StdUI.ScrollTable(UIContainer.MainFrame, new List<StdUiScrollTable.StdUiScrollTableColumnDefinition>()
            {
                new StdUiScrollTable.StdUiScrollTableColumnDefinition()
                {
                    name = "Name",
                    index = "Name",
                    align = "LEFT",
                    width = 100
                },
                
                new StdUiScrollTable.StdUiScrollTableColumnDefinition()
                {
                    name = "GUID",
                    index = "GUID",
                    align = "LEFT",
                    width = 250
                },

                new StdUiScrollTable.StdUiScrollTableColumnDefinition()
                {
                    name = "Targetting Us",
                    index = "IsTargettingMeOrPet",
                    align = "LEFT",
                    width = 125
                },
                new StdUiScrollTable.StdUiScrollTableColumnDefinition()
                {
                    name = "HP",
                    index = "HP",
                    align = "LEFT",
                    width = 75
                },
                 new StdUiScrollTable.StdUiScrollTableColumnDefinition()
                {
                    name = "Distance",
                    index = "Distance",
                    align = "LEFT",
                    width = 125
                },

            }, 10 , 25);


            Program.MainUI.StdUI.GlueTop(UIContainer.ScrollTable, UIContainer.MainFrame, 0, -50, "TOP");

            UIContainer.ScrollTable.SetData(ObjectManager.Instance.AllObjects.Values.Where(x => x.ObjectType == LuaBox.EObjectType.Unit).Select(x => new { Name=x.Name,
                GUID=x.GUID, IsTargettingMeOrPet= (x as WoWUnit).IsTargettingMeOrPet.ToString(), HP=(x as WoWUnit).Health, Distance=(int)Vector3.Distance(ObjectManager.Instance.Player.Position, x.Position)}).OrderBy(x => x.Distance).ToList<Object>());
        }

        public void UpdateUI()
        {
            if (UIContainer.MainFrame.IsShown())
            {
                UIContainer.ScrollTable.SetData(ObjectManager.Instance.AllObjects.Values.Where(x => x.ObjectType == LuaBox.EObjectType.Unit).Select(x => new
                {
                    Name = x.Name,
                    GUID = x.GUID,
                    IsTargettingMeOrPet = (x as WoWUnit).IsTargettingMeOrPet ? "True" : "False",
                    HP = (x as WoWUnit).Health,
                    Distance = (int)Vector3.Distance(ObjectManager.Instance.Player.Position, x.Position)
                }).OrderBy(x => x.Distance).ToList<Object>());
            }
        }
    }
}
