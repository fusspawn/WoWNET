using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.Helpers
{
    public class LuaHelper
    {


        /// <summary>
        ///   @CSharpLua.Template = "{0}"
        /// </summary>
        public static extern T GetGlobal<T>(string Name);
    }
}
