using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Wrapper.Helpers
{
    public class LuaHelper
    {
        /// <summary>
        ///   @CSharpLua.Template = "{0}"
        /// </summary>
        public static extern T GetGlobal<T>(string Name);

        /// <summary>
        ///   @CSharpLua.Template = "_G[{0}]"
        /// </summary>
        public static extern T GetGlobalFrom_G<T>(string Name);


        /// <summary>
        ///   @CSharpLua.Template = "{0}['{1}']"
        /// </summary>
        public static extern T GetProperty<T>(object Object, string Name);


        public static T GetGlobalFrom_G_Namespace<T>(string[] PropertyChain) 
        {

            var CurrentObject = LuaHelper.GetGlobalFrom_G<object>(PropertyChain[0]);
            //Console.WriteLine("Aquired Global Object: " + PropertyChain[0]);
            int Index = 1;

            while (Index < PropertyChain.Length)
            {
                //Console.WriteLine("Trying To Access Property: " + PropertyChain[Index]);
                var NameValue = PropertyChain[Index];
                /*
                 [[
                        CurrentObject = CurrentObject[NameValue]
                 ]] 
                */
                Index++;
            }

            return (T)CurrentObject;  
        }
    }
}
