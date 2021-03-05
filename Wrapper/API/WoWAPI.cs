using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.API
{
    public class WoWAPI
    {
        /// <summary>
        /// @CSharpLua.Template = "StartAttack()"
        /// </summary>
        public static extern bool StartAttack();

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
        /// @CSharpLua.Template = "GetRealmName()" 
        /// </summary>
        public static extern string GetRealmName();


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
              /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitIsTrivial, {0})" 
              /// </summary>
        public static extern bool UnitIsTrivial(string UnitGUIDorUnitID);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitIsGhost, {0})" 
        /// </summary>
        public static extern bool UnitIsGhost(string GUID);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitIsDead, {0})" 
        /// </summary>
        public static extern bool UnitIsDead(string GUID);


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


        /// <summary>
        /// @CSharpLua.Template = "MoveViewDownStart()" 
        /// </summary>
        public static extern void MoveViewDownStart();


        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitCreatureType, {0})" 
        /// </summary>
        public static extern string UnitCreatureType(string gUID);

        /// <summary>
        /// @CSharpLua.Template = "MoveViewDownStart()" 
        /// </summary>
        public static extern void MoveViewDownStop();
        /// <summary>
        /// @CSharpLua.Template = "MoveViewDownStart()" 
        /// </summary>
        public static extern void MoveViewUpStart();
        /// <summary>
        /// @CSharpLua.Template = "MoveViewDownStart()" 
        /// </summary>
        public static extern void MoveViewUpStop();


        /// <summary>
        /// @CSharpLua.Template = "MoveForwardStart()" 
        /// </summary>
        public static extern void MoveForwardStart();

        /// <summary>
        /// @CSharpLua.Template = "MoveForwardStop()" 
        /// </summary>
        public static extern void MoveForwardStop();


        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(GetUnitSpeed, {0})" 
        /// </summary>
        public static extern float GetUnitSpeed(string UnitGuidOrID);


        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitFactionGroup, {0})" 
        /// </summary>
        public static extern string UnitFactionGroup(string UnitGuidOrID);


        /// <summary>
        /// @CSharpLua.Template = "IsUsableSpell({0})" 
        /// </summary>
        public static extern bool IsUsableSpell(string SpellName);

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(CastSpellByName, {0}, {1})" 
        /// </summary>
        public static extern void CastSpellByName(string SpellName, string? TargetGUID);

        public static void SetCVar(string cvar, object value)
        {
            /*[[
                    __LB__.Unlock(SetCVar, cvar, value);
            ]]*/
        }

        // <summary>
        /// @CSharpLua.Template = "CreateFrame({0}, {1}, {2}, {3})
        /// </summary>
        public static extern T CreateFrame<T>(string Type, string Name=null, WoWFrame ParentFrame=null, string InheritsFrame = null);


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

        /// <summary>
        /// @CSharpLua.Template = "C_Timer.After({1}, {0})" 
        /// </summary>
        public static extern void After(Action Func, float Duration);

        /// <summary>
        /// @CSharpLua.Template = "GetItemCount({0})" 
        /// </summary>
        public static extern int GetItemCount(string ItemName);


        /// <summary>
        /// @CSharpLua.Template = "UseItemByName({0})" 
        /// </summary>
        public static extern void UseItemByName(string ItemName);


        /// <summary>
        /// @CSharpLua.Template = "select(2,__LB__.UnitTagHandler(UnitClass, {0}))" 
        /// </summary>
        public static extern string UnitClass(string GUID);

         /// <summary>
         /// @CSharpLua.Template = "select(2,__LB__.UnitTagHandler(InteractUnit, {0}))" 
         /// </summary>
        public static extern string InteractUnit(string GUID);

        /// <summary>
        /// @CSharpLua.Template = "debugstack()" 
        /// </summary>
        public static extern string DebugStack();




        /// <summary>
        /// @CSharpLua.Template = "CreateFromMixin({0})" 
        /// </summary>
        public static extern T CreateFromMixin<T>(object Mixin);


        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitCanAttack, {0}, {1})" 
        /// </summary>
        public static extern bool UnitCanAttack(string from, string to);

        /// <summary>
        /// @CSharpLua.Template = "IsOutdoors()" 
        /// </summary>
        public static extern bool IsOutdoors();

        /// <summary>
        /// @CSharpLua.Template = "IsMounted()" 
        /// </summary>
        public static extern bool IsMounted();

        /// <summary>
        /// @CSharpLua.Template = "__LB__.UnitTagHandler(UnitIsUnit, {0}, {1})" 
        /// </summary>
        public static extern bool UnitIsUnit(string GUID, string Type);
    }

    public class WoWFrame
    {


        public WoWTexture texture;

        public extern void SetScript<T>(string Name, T func);
        public extern void SetParent(WoWFrame Parent);
        public extern void Show();
        public extern void Hide();
        public extern void SetFrameStrata(string Strata);
        public extern void SetWidth(int Width);
        public extern void SetHeight(int Height);
        public extern int GetWidth();
        public extern int GetHeight();

        public extern void SetAllPoints(WoWFrame Parent);
        public extern void SetPoint(string Relation, int x, int y);

        public extern bool IsVisible();
        public extern bool IsShown();

        public extern WoWTexture CreateTexture(string name = null, string layer = null, string inheritsFrom = null);

        public extern void RegisterEvent(string Event);
    }

    public class WoWTexture 
        : WoWFrame
    {

        private static WoWTexture _holder = new WoWTexture();
        //public extern void SetTexture(double r, double g, double b, double a = 1);
        public extern void SetTexture(string Path);

     
        
    }

    public class WoWButton
        : WoWFrame
    {
        private static WoWButton _holder = new WoWButton();
        public extern void SetText(string Name);
        public extern void SetNormalTexture(WoWTexture Texture);
    }


    public interface DataProviderBase 
    {
        public void RemoveAllData();
        public void RefreshAllData(bool fromOnShow);
        public void OnShow();
        public void OnHide();
        public void OnEvent(string Event, params object[] args);


        /// <summary>
        /// @CSharpLua.Template = "this:GetMap()" 
        /// </summary>
        public extern dynamic GetMap();
    }

   

}
