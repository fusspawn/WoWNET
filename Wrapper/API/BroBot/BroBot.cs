using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.API
{
    public class BroBotAPI
    {
        /// <summary>
        ///   @CSharpLua.Template = registerRawFighter({1}, {0})"
        /// </summary>
        public static extern void registerFighter(string Name, object Instance);


        /// <summary>
        ///   @CSharpLua.Template = registerBehavior({1}, {0})"
        /// </summary>
        public static extern void registerBehavior(string Name, object Behavior);

        /// <summary>
        ///   @CSharpLua.Template = (BroBot.Engine.BlackList.BannedGUIDs[{0}] ~= nil)"
        /// </summary>
        public static extern bool UnitIsOnBlackList(string GUID);

        /// <summary>
        ///   @CSharpLua.Template = BroBot.Engine.BlackList:RegisterUnitInstance({0}, {1})"
        /// </summary>
        public static extern void RegisterOnBlackList(string GUID, double seconds);



        /// <summary>
        ///   @CSharpLua.Template = subtaskframe:SetText("[" .. {0} .. "]" .. {1})"
        /// </summary>
        public static extern void BroBotDebugMessage(string Task, string Message);
    }


}
