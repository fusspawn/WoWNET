using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.API
{
    public class WoW
    {
        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitIsPlayer, {0})"
        /// </summary>
        public static extern bool UnitIsPlayer(string GUID);


        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitHealth, {0})" 
        /// </summary>
        public static extern int UnitHealth(string GUID);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitHealthMax, {0})" 
        /// </summary>
        public static extern int UnitHealthMax(string GUID);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitLevel, {0})" 
        /// </summary>
        public static extern int UnitLevel(string GUID);


        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitReaction, {0})" 
        /// </summary>
        public static extern int UnitReaction(string GUID);


        /// <summary>
        /// @CSharpLua.Template = "C_Timer.NewTicker({1}, {0})" 
        /// </summary>
        public static extern void NewTicker(Action Func, float Duration);
    }
}
