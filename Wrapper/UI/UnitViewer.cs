using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using Wrapper.Helpers;

namespace Wrapper.UI
{
    public class UnitViewer
    {

        public class UnitViewerUIContainer
        {
            public WoWFrame MainFrame;
        }

        UnitViewerUIContainer UIContainer;


        public UnitViewer()
        {
            CreateUI();
        }

        private void CreateUI()
        {
            UIContainer = new UnitViewerUIContainer();
            UIContainer.MainFrame = Program.MainUI.StdUI.Window(LuaHelper.GetGlobalFrom_G<WoWFrame>("UIParent"), 800, 500, "UnitViewer");
            UIContainer.MainFrame.SetPoint("CENTER", 0, 0);



        }
    }
}
