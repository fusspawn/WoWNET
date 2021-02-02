using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.API
{
    public class WoWAPI
    {


        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitIsPlayer, {0})"
        /// </summary>
        public static extern bool UnitIsPlayer(string GUID);

        /// <summary>
        /// @CSharpLua.Template = "GetTime()"
        /// </summary>
        public static extern double GetTime();


        /// <summary>
        /// @CSharpLua.Template = "RepopMe()"
        /// </summary>
        public static extern bool RepopMe();


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
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitReaction, "player", {0})" 
        /// </summary>
        public static extern int UnitReaction(string GUID);

        /// <summary>
        /// @CSharpLua.Template = "IsInInstance()" 
        /// </summary>
        public static extern bool IsInInstance();

        /// <summary>
        /// @CSharpLua.Template = "GetBattlefieldStatus({0})" 
        /// </summary>
        public static extern string GetBattlefieldStatus(int unkn);

        /// <summary>
        /// @CSharpLua.Template = "JoinBattlefield({0}, {1}, {2})" 
        /// </summary>
        public static extern void JoinBattlefield(int unkn, bool unkn1, bool unkn2);


        /// <summary>
        /// @CSharpLua.Template = "AcceptBattlefieldPort({0}, {1})" 
        /// </summary>
        public static extern void AcceptBattlefieldPort(int unkn, int unkn1);

        /// <summary>
        /// @CSharpLua.Template = "StaticPopup_Hide({0})" 
        /// </summary>
        public static extern void StaticPopup_Hide(string popupname);

        /// <summary>
        /// @CSharpLua.Template = "GetSpecializationRole({0})" 
        /// </summary>
        public static extern string GetSpecializationRole(int spec);

        /// <summary>
        /// @CSharpLua.Template = "GetSpecialization({0})" 
        /// </summary>
        public static extern int GetSpecialization();

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitIsDeadOrGhost, {0})" 
        /// </summary>
        public static extern bool UnitIsDeadOrGhost(string UnitGUIDorUnitID);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitIsGhost, {0})" 
        /// </summary>
        public static extern bool UnitIsGhost(string GUID);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitAffectingCombat, {0})" 
        /// </summary>
        public static extern bool UnitAffectingCombat(string UnitGUIDorUnitID);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitAffectingCombat, {0}, {1})" 
        /// </summary>
        public static extern bool UnitAffectingCombat(string UnitGUIDorUnitID, string OtherUnit);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(TargetUnit, {0})" 
        /// </summary>
        public static extern void TargetUnit(string TargetGUID);

        /// <summary>
        /// @CSharpLua.Template = "RunMacroText({0})" 
        /// </summary>
        public static extern void RunMacroText(string Text);

        public enum PVPClassification {
            None = -1,
            FlagCarrierHorde,
    	    FlagCarrierAlliance,
    	    FlagCarrierNeutral,
    	    CartRunnerHorde,
    	    CartRunnerAlliance,	
    	    AssassinHorde,
    	    AssassinAlliance,	
    	    OrbCarrierBlue,
    	    OrbCarrierGreen,
    	    OrbCarrierOrange,	
        	OrbCarrierPurple 
        }

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitPvpClassification, {0})" 
        /// </summary>
        public static extern PVPClassification UnitPvpClassification(string UnitGUIDorUnitID);

        /// <summary>
        /// @CSharpLua.Template = "C_Timer.NewTicker({1}, {0})" 
        /// </summary>
        public static extern void NewTicker(Action Func, float Duration);
    }
}
