using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.API
{
    public class LibStub
    {

        /// <summary>
        ///   @CSharpLua.Template = "LibStub({0})"
        /// </summary>
        public extern T GetLib<T>(string Name);


        /// <summary>
        ///   @CSharpLua.Template = "LibStub({0}):NewInstance()"
        /// </summary>
        public extern T GetNewInstance<T>(string Name);
    }
}
