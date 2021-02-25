using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;
using static Wrapper.StdUI.StdUiDropdown;

namespace Wrapper
{
    public class StdUI
    {

        private static bool IsInjected = false;

		public class StdUiFrame
			: WoWFrame
		{
			public dynamic config;

			public extern List<StdUiFrame> GetChildrenWidgets();
			public extern void SetFullWidth(bool Flag);


		}

        public class StdUiNumericInputFrame :
            StdUiInputFrame
        {
            public extern void SetMinMaxValue(float min, float max);
        }

		public class StdUiInputFrame
				: StdUiFrame
		{
			public extern T GetValue<T>();
            public extern void SetValue(object value);
		}

		public class StdUiCheckBox
				: StdUiInputFrame
		{
			public delegate void _OnValueChanged(StdUiCheckBox self, bool State, bool value);
			public _OnValueChanged OnValueChanged;
		}

        public class StdUiLabel 
            : StdUiFrame
        {
            public extern void SetText(string Text);
        }

        public class StdUiButton
            : StdUiFrame
        {
         //   StdUi:HighlightButton(parent, width, height, text)
        }

        public class StdUiDropdown 
            : StdUiFrame
        {
            public class StdUiDropdownItems
            {
                public string text;
                public object value;
            }

            public extern void SetValue(object value, string Text);
            public extern T GetValue<T>();
            public extern void SetPlaceholder(string Text);
            public extern void SetOptions(StdUiDropdownItems[] options);

            public delegate void _OnValueChanged(StdUiCheckBox self, object value);
            public _OnValueChanged OnValueChanged;
        }


        public extern StdUiDropdown Dropdown(WoWFrame parent, int width, int height, StdUiDropdownItems[] options, object value, bool multi, bool assoc);

		public extern StdUiFrame Frame(WoWFrame Parent, int Width, int Height, string Inherits);
        public extern StdUiFrame Panel(WoWFrame Parent, int Width, int Height, string Inherits);
        public extern StdUiFrame PanelWithLabel(WoWFrame Parent, int Width, int Height, string Inherits, string Text);
        public extern StdUiFrame PanelWithTitle(WoWFrame Parent, int Width, int Height, string Text);
        public extern WoWTexture Texture(WoWFrame Parent, int Width, int Height, string TexturePath);
        public extern WoWTexture ArrowTexture(WoWFrame Parent, string Direction);
        public extern StdUiFrame Window(WoWFrame UIParent, int Width, int Height, string Text);
		public extern StdUiCheckBox Checkbox(WoWFrame UIParent, string Text, int width, int height);
		public extern StdUiInputFrame SimpleEditBox(WoWFrame UIParent, int Width, int Height, string Text);
		public extern StdUiInputFrame SearchEditBox(WoWFrame UIParent, int Width, int Height, string Text);
		public extern StdUiInputFrame EditBox(WoWFrame UIParent, int Width, int Height, string Text, Func<bool> Validator);
		public extern StdUiInputFrame NumericBox(WoWFrame UIParent, int Width, int Height, string Text, Func<bool> Validator);
		public extern StdUiInputFrame MoneyBox(WoWFrame UIParent, int Width, int Height, string Text, Func<bool> Validator, bool ignoreCopper);
        public extern StdUiButton HighlightButton(WoWFrame ParentFrame, int width, int height, string Text);
#pragma warning disable CS8632 // The annotation for nullable reference types should only be used in code within a '#nullable' annotations context.
        public extern StdUiLabel AddLabel(WoWFrame UIParent, StdUiFrame AttachParent, string Text, string? LabelPosition, int? LabelWidth);
#pragma warning restore CS8632 // The annotation for nullable reference types should only be used in code within a '#nullable' annotations context.
        public extern StdUiLabel Label(WoWFrame UIParent, string Text, int size, string? inherit, int width, int height);
        public extern void GlueTop(WoWFrame Frame, WoWFrame ParentFrame, int XOffset, int YOffset, string Relation);


		public static void Init()
        {
            if (!IsInjected)
            {
                Console.WriteLine("Injecting StdUI");
                /*
				 [[
				 
					 --LibStub is a simple versioning stub meant for use in Libraries.http://www.wowace.com/wiki/LibStub for more info
					 --LibStub is hereby placed in the Public Domain Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
					 local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2-- NEVER MAKE THIS AN SVN REVISION! IT NEEDS TO BE USABLE IN ALL REPOS!
					 local LibStub = _G[LIBSTUB_MAJOR]

					 if not LibStub or LibStub.minor < LIBSTUB_MINOR then
						 LibStub = LibStub or { libs = { }, minors = { } }
								 _G[LIBSTUB_MAJOR] = LibStub
						 LibStub.minor = LIBSTUB_MINOR


						 function LibStub:NewLibrary(major, minor)
							 assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
							 minor = assert(tonumber(strmatch(minor, "%d+")), "Minor version must either be a number or contain a number.")


							 local oldminor = self.minors[major]
							 if oldminor and oldminor >= minor then return nil end
							 self.minors[major], self.libs[major] = minor, self.libs[major] or { }
								 return self.libs[major], oldminor
							 end


						 function LibStub:GetLibrary(major, silent)
							 if not self.libs[major] and not silent then
								 error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
							 end
							 return self.libs[major], self.minors[major]
						 end

						 function LibStub: IterateLibraries() return pairs(self.libs) end
						  setmetatable(LibStub, { __call = LibStub.GetLibrary })
					 end

					local function a(...)
                        local b, c = "StdUi", 5
                        local d = LibStub:NewLibrary(b, c)
                        if not d then
                            return
                        end
                        local e = tinsert
                        d.moduleVersions = {}
                        if not StdUiInstances then
                            StdUiInstances = {d}
                        else
                            e(StdUiInstances, d)
                        end
                        function d:NewInstance()
                            local f = CopyTable(self)
                            f:ResetConfig()
                            e(StdUiInstances, f)
                            return f
                        end
                        function d:RegisterModule(g, h)
                            self.moduleVersions[g] = h
                        end
                        function d:UpgradeNeeded(g, h)
                            if not self.moduleVersions[g] then
                                return true
                            end
                            return self.moduleVersions[g] < h
                        end
                        function d:RegisterWidget(i, j)
                            if not self[i] then
                                self[i] = j
                                return true
                            end
                            return false
                        end
                        function d:InitWidget(k)
                            k.isWidget = true
                            function k:GetChildrenWidgets()
                                local l = {k:GetChildren()}
                                local m = {}
                                for n = 1, #l do
                                    local o = l[n]
                                    if o.isWidget then
                                        e(m, o)
                                    end
                                end
                                return m
                            end
                        end
                        function d:SetObjSize(p, q, r)
                            if q then
                                p:SetWidth(q)
                            end
                            if r then
                                p:SetHeight(r)
                            end
                        end
                        function d:SetTextColor(s, t)
                            t = t or "normal"
                            if s.SetTextColor then
                                local u = self.config.font.color[t]
                                s:SetTextColor(u.r, u.g, u.b, u.a)
                            end
                        end
                        d.SetHighlightBorder = function(self)
                            if self.target then
                                self = self.target
                            end
                            if self.isDisabled then
                                return
                            end
                            local v = self.stdUi.config.highlight.color
                            if not self.origBackdropBorderColor then
                                self.origBackdropBorderColor = {self:GetBackdropBorderColor()}
                            end
                            self:SetBackdropBorderColor(v.r, v.g, v.b, 1)
                        end
                        d.ResetHighlightBorder = function(self)
                            if self.target then
                                self = self.target
                            end
                            if self.isDisabled then
                                return
                            end
                            local v = self.origBackdropBorderColor
                            if v then
                                self:SetBackdropBorderColor(unpack(v))
                            end
                        end
                        function d:HookHoverBorder(w)
                            if not w.SetBackdrop then
                                Mixin(w, BackdropTemplateMixin)
                            end
                            w:HookScript("OnEnter", self.SetHighlightBorder)
                            w:HookScript("OnLeave", self.ResetHighlightBorder)
                        end
                        function d:ApplyBackdrop(x, type, y, z)
                            local A = x.config or self.config
                            local B = {bgFile = A.backdrop.texture, edgeFile = A.backdrop.texture, edgeSize = 1}
                            if z then
                                B.insets = z
                            end
                            if not x.SetBackdrop then
                                Mixin(x, BackdropTemplateMixin)
                            end
                            x:SetBackdrop(B)
                            type = type or "button"
                            y = y or "border"
                            if A.backdrop[type] then
                                x:SetBackdropColor(A.backdrop[type].r, A.backdrop[type].g, A.backdrop[type].b, A.backdrop[type].a)
                            end
                            if A.backdrop[y] then
                                x:SetBackdropBorderColor(A.backdrop[y].r, A.backdrop[y].g, A.backdrop[y].b, A.backdrop[y].a)
                            end
                        end
                        function d:ClearBackdrop(x)
                            if not x.SetBackdrop then
                                Mixin(x, BackdropTemplateMixin)
                            end
                            x:SetBackdrop(nil)
                        end
                        function d:ApplyDisabledBackdrop(x, C)
                            if x.target then
                                x = x.target
                            end
                            if C then
                                self:ApplyBackdrop(x, "button", "border")
                                self:SetTextColor(x, "normal")
                                if x.label then
                                    self:SetTextColor(x.label, "normal")
                                end
                                if x.text then
                                    self:SetTextColor(x.text, "normal")
                                end
                                x.isDisabled = false
                            else
                                self:ApplyBackdrop(x, "buttonDisabled", "borderDisabled")
                                self:SetTextColor(x, "disabled")
                                if x.label then
                                    self:SetTextColor(x.label, "disabled")
                                end
                                if x.text then
                                    self:SetTextColor(x.text, "disabled")
                                end
                                x.isDisabled = true
                            end
                        end
                        function d:HookDisabledBackdrop(x)
                            local D = self
                            hooksecurefunc(
                                x,
                                "Disable",
                                function(self)
                                    D:ApplyDisabledBackdrop(self, false)
                                end
                            )
                            hooksecurefunc(
                                x,
                                "Enable",
                                function(self)
                                    D:ApplyDisabledBackdrop(self, true)
                                end
                            )
                        end
                        function d:StripTextures(x)
                            for n = 1, x:GetNumRegions() do
                                local E = select(n, x:GetRegions())
                                if E and E:GetObjectType() == "Texture" then
                                    E:SetTexture(nil)
                                end
                            end
                        end
                        function d:MakeDraggable(x, F)
                            x:SetMovable(true)
                            x:EnableMouse(true)
                            x:RegisterForDrag("LeftButton")
                            x:SetScript("OnDragStart", x.StartMoving)
                            x:SetScript("OnDragStop", x.StopMovingOrSizing)
                            if F then
                                F:EnableMouse(true)
                                F:SetMovable(true)
                                F:RegisterForDrag("LeftButton")
                                F:SetScript(
                                    "OnDragStart",
                                    function(self)
                                        x.StartMoving(x)
                                    end
                                )
                                F:SetScript(
                                    "OnDragStop",
                                    function(self)
                                        x.StopMovingOrSizing(x)
                                    end
                                )
                            end
                        end
                        function d:MakeResizable(x, G)
                            local H = {
                                ["TOP"] = 0,
                                ["TOPRIGHT"] = 1.5708,
                                ["RIGHT"] = 0,
                                ["BOTTOMRIGHT"] = 0,
                                ["BOTTOM"] = 0,
                                ["BOTTOMLEFT"] = -1.5708,
                                ["LEFT"] = 0,
                                ["TOPLEFT"] = 3.1416
                            }
                            G = string.upper(G)
                            if not H[G] then
                                return false
                            end
                            x:SetResizable(true)
                            local I = CreateFrame("Button", nil, x)
                            I:SetPoint(G, x, G)
                            if G == "TOP" or G == "BOTTOM" then
                                I:SetHeight(self.config.resizeHandle.height)
                                I:SetPoint("LEFT", x, "LEFT", self.config.resizeHandle.width, 0)
                                I:SetPoint("RIGHT", x, "RIGHT", self.config.resizeHandle.width * -1, 0)
                            elseif G == "LEFT" or G == "RIGHT" then
                                I:SetWidth(self.config.resizeHandle.width)
                                I:SetPoint("TOP", x, "TOP", 0, self.config.resizeHandle.height * -1)
                                I:SetPoint("BOTTOM", x, "BOTTOM", 0, self.config.resizeHandle.height)
                            else
                                I:SetNormalTexture(self.config.resizeHandle.texture.normal)
                                I:SetHighlightTexture(self.config.resizeHandle.texture.highlight)
                                I:SetPushedTexture(self.config.resizeHandle.texture.pushed)
                                I:SetSize(self.config.resizeHandle.width, self.config.resizeHandle.height)
                                I:GetNormalTexture():SetRotation(H[G])
                                I:GetHighlightTexture():SetRotation(H[G])
                                I:GetPushedTexture():SetRotation(H[G])
                            end
                            I:SetScript(
                                "OnMouseDown",
                                function(self, J)
                                    if J == "LeftButton" then
                                        x:StartSizing(G)
                                        x:SetUserPlaced(true)
                                    end
                                end
                            )
                            I:SetScript(
                                "OnMouseUp",
                                function(self, J)
                                    if J == "LeftButton" then
                                        x:StopMovingOrSizing()
                                    end
                                end
                            )
                        end
                    end
                    local function K(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Config", 4
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local IsAddOnLoaded = IsAddOnLoaded
                        d.config = {}
                        function d:ResetConfig()
                            local L, M = GameFontNormal:GetFont()
                            local N, O = GameFontNormalLarge:GetFont()
                            self.config = {
                                font = {
                                    family = L,
                                    size = M,
                                    titleSize = O,
                                    effect = "NONE",
                                    strata = "OVERLAY",
                                    color = {
                                        normal = {r = 1, g = 1, b = 1, a = 1},
                                        disabled = {r = 0.55, g = 0.55, b = 0.55, a = 1},
                                        header = {r = 1, g = 0.9, b = 0, a = 1}
                                    }
                                },
                                backdrop = {
                                    texture = "Interface\\Buttons\\WHITE8X8",
                                    panel = {r = 0.0588, g = 0.0588, b = 0, a = 0.8},
                                    slider = {r = 0.15, g = 0.15, b = 0.15, a = 1},
                                    highlight = {r = 0.40, g = 0.40, b = 0, a = 0.5},
                                    button = {r = 0.20, g = 0.20, b = 0.20, a = 1},
                                    buttonDisabled = {r = 0.15, g = 0.15, b = 0.15, a = 1},
                                    border = {r = 0.00, g = 0.00, b = 0.00, a = 1},
                                    borderDisabled = {r = 0.40, g = 0.40, b = 0.40, a = 1}
                                },
                                progressBar = {color = {r = 1, g = 0.9, b = 0, a = 0.5}},
                                highlight = {color = {r = 1, g = 0.9, b = 0, a = 0.4}, blank = {r = 0, g = 0, b = 0, a = 0}},
                                dialog = {width = 400, height = 100, button = {width = 100, height = 20, margin = 5}},
                                tooltip = {padding = 10},
                                resizeHandle = {
                                    width = 10,
                                    height = 10,
                                    texture = {
                                        normal = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
                                        highlight = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
                                        pushed = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down"
                                    }
                                }
                            }
                            if IsAddOnLoaded("ElvUI") then
                                local P = ElvUI[1].media.backdropfadecolor
                                self.config.backdrop.panel = {r = P[1], g = P[2], b = P[3], a = P[4]}
                            end
                        end
                        d:ResetConfig()
                        function d:SetDefaultFont(L, Q, R, S)
                            self.config.font.family = L
                            self.config.font.size = Q
                            self.config.font.effect = R
                            self.config.font.strata = S
                        end
                        d:RegisterModule(g, h)
                    end
                    local function T(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Position", 2
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local U = "CENTER"
                        local V = "TOP"
                        local W = "BOTTOM"
                        local X = "LEFT"
                        local Y = "RIGHT"
                        local Z = "TOPLEFT"
                        local _ = "TOPRIGHT"
                        local a0 = "BOTTOMLEFT"
                        local a1 = "BOTTOMRIGHT"
                        d.Anchors = {
                            Center = U,
                            Top = V,
                            Bottom = W,
                            Left = X,
                            Right = Y,
                            TopLeft = Z,
                            TopRight = _,
                            BottomLeft = a0,
                            BottomRight = a1
                        }
                        function d:GlueBelow(w, a2, a3, a4, a5)
                            if a5 == X then
                                w:SetPoint(Z, a2, a0, a3, a4)
                            elseif a5 == Y then
                                w:SetPoint(_, a2, a1, a3, a4)
                            else
                                w:SetPoint(V, a2, W, a3, a4)
                            end
                        end
                        function d:GlueAbove(w, a2, a3, a4, a5)
                            if a5 == X then
                                w:SetPoint(a0, a2, Z, a3, a4)
                            elseif a5 == Y then
                                w:SetPoint(a1, a2, _, a3, a4)
                            else
                                w:SetPoint(W, a2, V, a3, a4)
                            end
                        end
                        function d:GlueTop(w, a2, a3, a4, a5)
                            if a5 == X then
                                w:SetPoint(Z, a2, Z, a3, a4)
                            elseif a5 == Y then
                                w:SetPoint(_, a2, _, a3, a4)
                            else
                                w:SetPoint(V, a2, V, a3, a4)
                            end
                        end
                        function d:GlueBottom(w, a2, a3, a4, a5)
                            if a5 == X then
                                w:SetPoint(a0, a2, a0, a3, a4)
                            elseif a5 == Y then
                                w:SetPoint(a1, a2, a1, a3, a4)
                            else
                                w:SetPoint(W, a2, W, a3, a4)
                            end
                        end
                        function d:GlueRight(w, a2, a3, a4, a6)
                            if a6 then
                                w:SetPoint(Y, a2, Y, a3, a4)
                            else
                                w:SetPoint(X, a2, Y, a3, a4)
                            end
                        end
                        function d:GlueLeft(w, a2, a3, a4, a6)
                            if a6 then
                                w:SetPoint(X, a2, X, a3, a4)
                            else
                                w:SetPoint(Y, a2, X, a3, a4)
                            end
                        end
                        function d:GlueAfter(w, a2, a7, a8, a9, aa)
                            if a7 and a8 then
                                w:SetPoint(Z, a2, _, a7, a8)
                            end
                            if a9 and aa then
                                w:SetPoint(a0, a2, a1, a9, aa)
                            end
                        end
                        function d:GlueBefore(w, a2, a7, a8, a9, aa)
                            if a7 and a8 then
                                w:SetPoint(_, a2, Z, a7, a8)
                            end
                            if a9 and aa then
                                w:SetPoint(a1, a2, a0, a9, aa)
                            end
                        end
                        function d:GlueAcross(w, a2, ab, ac, ad, ae)
                            w:SetPoint(Z, a2, Z, ab, ac)
                            w:SetPoint(a1, a2, a1, ad, ae)
                        end
                        function d:GlueOpposite(w, a2, a3, a4, I)
                            if I == "TOP" then
                                w:SetPoint("BOTTOM", a2, I, a3, a4)
                            elseif I == "BOTTOM" then
                                w:SetPoint("TOP", a2, I, a3, a4)
                            elseif I == "LEFT" then
                                w:SetPoint("RIGHT", a2, I, a3, a4)
                            elseif I == "RIGHT" then
                                w:SetPoint("LEFT", a2, I, a3, a4)
                            elseif I == "TOPLEFT" then
                                w:SetPoint("BOTTOMRIGHT", a2, I, a3, a4)
                            elseif I == "TOPRIGHT" then
                                w:SetPoint("BOTTOMLEFT", a2, I, a3, a4)
                            elseif I == "BOTTOMLEFT" then
                                w:SetPoint("TOPRIGHT", a2, I, a3, a4)
                            elseif I == "BOTTOMRIGHT" then
                                w:SetPoint("TOPLEFT", a2, I, a3, a4)
                            else
                                w:SetPoint("CENTER", a2, I, a3, a4)
                            end
                        end
                        d:RegisterModule(g, h)
                    end
                    local function af(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Util", 10
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local ag = table.getn
                        local e = tinsert
                        local ah = table.sort
                        function d:MarkAsValid(x, ai)
                            if not x.SetBackdrop then
                                Mixin(x, BackdropTemplateMixin)
                            end
                            if not ai then
                                x:SetBackdropBorderColor(1, 0, 0, 1)
                                x.origBackdropBorderColor = {x:GetBackdropBorderColor()}
                            else
                                x:SetBackdropBorderColor(
                                    self.config.backdrop.border.r,
                                    self.config.backdrop.border.g,
                                    self.config.backdrop.border.b,
                                    self.config.backdrop.border.a
                                )
                                x.origBackdropBorderColor = {x:GetBackdropBorderColor()}
                            end
                        end
                        d.Util = {
                            editBoxValidator = function(self)
                                self.value = self:GetText()
                                self.stdUi:MarkAsValid(self, true)
                                return true
                            end,
                            moneyBoxValidator = function(self)
                                local aj = self:GetText()
                                aj = aj:trim()
                                local ak, al, am, an, ao = d.Util.parseMoney(aj)
                                if not ao or ak == 0 then
                                    self.stdUi:MarkAsValid(self, false)
                                    return false
                                end
                                self:SetText(d.Util.formatMoney(ak))
                                self.value = ak
                                self.stdUi:MarkAsValid(self, true)
                                return true
                            end,
                            moneyBoxValidatorExC = function(self)
                                local aj = self:GetText()
                                aj = aj:trim()
                                local ak, al, am, an, ao = d.Util.parseMoney(aj)
                                if not ao or ak == 0 or an and tonumber(an) > 0 then
                                    self.stdUi:MarkAsValid(self, false)
                                    return false
                                end
                                self:SetText(d.Util.formatMoney(ak, true))
                                self.value = ak
                                self.stdUi:MarkAsValid(self, true)
                                return true
                            end,
                            numericBoxValidator = function(self)
                                local aj = self:GetText()
                                aj = aj:trim()
                                local ap = tonumber(aj)
                                if ap == nil then
                                    self.stdUi:MarkAsValid(self, false)
                                    return false
                                end
                                if self.maxValue and self.maxValue < ap then
                                    self.stdUi:MarkAsValid(self, false)
                                    return false
                                end
                                if self.minValue and self.minValue > ap then
                                    self.stdUi:MarkAsValid(self, false)
                                    return false
                                end
                                self.value = ap
                                self.stdUi:MarkAsValid(self, true)
                                return true
                            end,
                            spellValidator = function(self)
                                local aj = self:GetText()
                                aj = aj:trim()
                                local i, N, aq, N, N, N, ar = GetSpellInfo(aj)
                                if not i then
                                    self.stdUi:MarkAsValid(self, false)
                                    return false
                                end
                                self:SetText(i)
                                self.value = ar
                                self.icon:SetTexture(aq)
                                self.stdUi:MarkAsValid(self, true)
                                return true
                            end,
                            parseMoney = function(aj)
                                aj = d.Util.stripColors(aj)
                                local ak = 0
                                local as, N, an = string.find(aj, "(%d+)c$")
                                if as then
                                    aj = string.gsub(aj, "(%d+)c$", "")
                                    aj = aj:trim()
                                    ak = tonumber(an)
                                end
                                local at, N, am = string.find(aj, "(%d+)s$")
                                if at then
                                    aj = string.gsub(aj, "(%d+)s$", "")
                                    aj = aj:trim()
                                    ak = ak + tonumber(am) * 100
                                end
                                local au, N, al = string.find(aj, "(%d+)g$")
                                if au then
                                    aj = string.gsub(aj, "(%d+)g$", "")
                                    aj = aj:trim()
                                    ak = ak + tonumber(al) * 100 * 100
                                end
                                local av = tonumber(aj:len())
                                local ao = aj:len() == 0 and ak > 0
                                return ak, al, am, an, ao
                            end,
                            formatMoney = function(aw, ax)
                                if type(aw) ~= "number" then
                                    return aw
                                end
                                aw = tonumber(aw)
                                local ay = "|cfffff209"
                                local az = "|cff7b7b7a"
                                local aA = "|cffac7248"
                                local al = floor(aw / COPPER_PER_GOLD)
                                local am = floor((aw - al * COPPER_PER_GOLD) / COPPER_PER_SILVER)
                                local an = floor(aw % COPPER_PER_SILVER)
                                local aB = ""
                                if al > 0 then
                                    aB = format("%s%i%s ", ay, al, "|rg")
                                end
                                if al > 0 or am > 0 then
                                    aB = format("%s%s%02i%s ", aB, az, am, "|rs")
                                end
                                if not ax then
                                    aB = format("%s%s%02i%s ", aB, aA, an, "|rc")
                                end
                                return aB:trim()
                            end,
                            stripColors = function(aj)
                                aj = string.gsub(aj, "|c%x%x%x%x%x%x%x%x", "")
                                aj = string.gsub(aj, "|r", "")
                                return aj
                            end,
                            WrapTextInColor = function(aj, aC, aD, aE, aF)
                                local aG =
                                    string.format(
                                    "%02x%02x%02x%02x",
                                    Clamp(aF * 255, 0, 255),
                                    Clamp(aC * 255, 0, 255),
                                    Clamp(aD * 255, 0, 255),
                                    Clamp(aE * 255, 0, 255)
                                )
                                return WrapTextInColorCode(aj, aG)
                            end,
                            tableCount = function(aH)
                                local aI = #aH
                                if aI == 0 then
                                    for N in pairs(aH) do
                                        aI = aI + 1
                                    end
                                end
                                return aI
                            end,
                            tableMerge = function(aJ, aK)
                                local m = {}
                                for aL, aM in pairs(aJ) do
                                    if type(aM) == "table" then
                                        if aK[aL] then
                                            m[aL] = d.Util.tableMerge(aM, aK[aL])
                                        else
                                            m[aL] = aM
                                        end
                                    else
                                        m[aL] = aK[aL] or aJ[aL]
                                    end
                                end
                                for aL, aM in pairs(aK) do
                                    if not m[aL] then
                                        m[aL] = aM
                                    end
                                end
                                return m
                            end,
                            stringSplit = function(aN, aO, aP)
                                return {strsplit(aN, aO, aP)}
                            end,
                            __genOrderedIndex = function(aQ)
                                local aR = {}
                                for aS in pairs(aQ) do
                                    e(aR, aS)
                                end
                                ah(
                                    aR,
                                    function(aF, aE)
                                        if not aQ[aF].order or not aQ[aE].order then
                                            return aF < aE
                                        end
                                        return aQ[aF].order < aQ[aE].order
                                    end
                                )
                                return aR
                            end,
                            orderedNext = function(aQ, aT)
                                local aS
                                if aT == nil then
                                    aQ.__orderedIndex = d.Util.__genOrderedIndex(aQ)
                                    aS = aQ.__orderedIndex[1]
                                else
                                    for n = 1, ag(aQ.__orderedIndex) do
                                        if aQ.__orderedIndex[n] == aT then
                                            aS = aQ.__orderedIndex[n + 1]
                                        end
                                    end
                                end
                                if aS then
                                    return aS, aQ[aS]
                                end
                                aQ.__orderedIndex = nil
                                return
                            end,
                            orderedPairs = function(aQ)
                                return d.Util.orderedNext, aQ, nil
                            end,
                            roundPrecision = function(ap, aU)
                                local aV = 10 ^ (aU or 0)
                                return math.floor(ap * aV + 0.5) / aV
                            end
                        }
                        d:RegisterModule(g, h)
                    end
                    local function aW(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Layout", 3
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local e = tinsert
                        local aX = tremove
                        local pairs = pairs
                        local aY = math.max
                        local aZ = math.floor
                        local a_ = {gutter = 10, columns = 12, padding = {top = 0, right = 10, left = 10, bottom = 10}}
                        local b0 = {margin = {top = 0, right = 0, bottom = 15, left = 0}}
                        local b1 = {margin = {top = 0, right = 0, bottom = 0, left = 0}}
                        local b2 = {AddElement = function(self, x, A)
                                if not x.layoutConfig then
                                    x.layoutConfig = d.Util.tableMerge(b1, A or {})
                                elseif A then
                                    x.layoutConfig = d.Util.tableMerge(x.layoutConfig, A or {})
                                end
                                e(self.elements, x)
                            end, AddElements = function(self, ...)
                                local aC = {...}
                                local b3 = aX(aC, #aC)
                                if b3.column == "even" then
                                    b3.column = aZ(self.parent.layout.columns / #aC)
                                end
                                for n = 1, #aC do
                                    self:AddElement(aC[n], d.Util.tableMerge(b1, b3))
                                end
                            end, GetColumnsTaken = function(self)
                                local b4 = 0
                                local b5 = self.parent.layout
                                for n = 1, #self.elements do
                                    local b6 = self.elements[n].layoutConfig
                                    local b7 = b6.column or b5.columns
                                    b4 = b4 + b7
                                end
                                return b4
                            end, DrawRow = function(self, b8, b9)
                                b9 = b9 or 0
                                local b5 = self.parent.layout
                                local aD = b5.gutter
                                local ba = self.config.margin
                                local bb = 0
                                local b4 = 0
                                local a3 = aD + b5.padding.left + ba.left
                                b8 = b8 - ba.left - ba.right
                                for n = 1, #self.elements do
                                    local x = self.elements[n]
                                    x:ClearAllPoints()
                                    local b6 = x.layoutConfig
                                    local bc = b6.margin
                                    if b6.fullSize then
                                        d:GlueAcross(x, self.parent, b5.padding.left, -b5.padding.top, -b5.padding.right, b5.padding.bottom)
                                        if x.DoLayout then
                                            x:DoLayout()
                                        end
                                        bb = aY(bb, x:GetHeight() + bc.bottom + bc.top + ba.top + ba.bottom)
                                        return bb
                                    end
                                    local b7 = b6.column or b5.columns
                                    local bd = b8 / (b5.columns / b7) - 2 * aD
                                    x:SetWidth(bd)
                                    if b4 + b7 > self.parent.layout.columns then
                                        print("Element will not fit row capacity: " .. b5.columns)
                                        return bb
                                    end
                                    x:SetPoint("TOPLEFT", self.parent, "TOPLEFT", a3, b9 - bc.top - ba.top)
                                    if b6.fullHeight then
                                        x:SetPoint("BOTTOMLEFT", self.parent, "BOTTOMLEFT", a3, bc.bottom + ba.bottom)
                                    end
                                    a3 = a3 + bd + 2 * aD
                                    if x.DoLayout then
                                        x:DoLayout()
                                    end
                                    bb = aY(bb, x:GetHeight() + bc.bottom + bc.top + ba.top + ba.bottom)
                                    b4 = b4 + b7
                                end
                                return bb
                            end}
                        function d:EasyLayoutRow(be, A)
                            local bf = {parent = be, config = self.Util.tableMerge(b0, A or {}), elements = {}}
                            for aL, aM in pairs(b2) do
                                bf[aL] = aM
                            end
                            return bf
                        end
                        local bg = {AddRow = function(self, A)
                                if not self.rows then
                                    self.rows = {}
                                end
                                local bf = self.stdUi:EasyLayoutRow(self, A)
                                e(self.rows, bf)
                                return bf
                            end, DoLayout = function(self)
                                local b5 = self.layout
                                local q = self:GetWidth() - b5.padding.left - b5.padding.right
                                local a4 = -b5.padding.top
                                for n = 1, #self.rows do
                                    local bf = self.rows[n]
                                    a4 = a4 - bf:DrawRow(q, a4)
                                end
                            end}
                        function d:EasyLayout(be, A)
                            be.stdUi = self
                            be.layout = self.Util.tableMerge(a_, A or {})
                            for aL, aM in pairs(bg) do
                                be[aL] = aM
                            end
                        end
                        d:RegisterModule(g, h)
                    end
                    local function bh(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Grid", 4
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        function d:ObjectList(be, bi, bj, bk, bl, bm, bn, bo, bp)
                            local D = self
                            bn = bn or 1
                            bo = bo or -1
                            bm = bm or 0
                            if not bi then
                                bi = {}
                            end
                            for n = 1, #bi do
                                bi[n]:Hide()
                            end
                            local bb = -bo
                            local n = 1
                            for aS, ap in pairs(bl) do
                                local bq = bi[n]
                                if not bq then
                                    if type(bj) == "string" then
                                        bi[n] = D[bj](D, be)
                                    else
                                        bi[n] = bj(be, ap, n, aS)
                                    end
                                    bq = bi[n]
                                end
                                bk(be, bq, ap, n, aS)
                                bq:Show()
                                bb = bb + bq:GetHeight()
                                if n == 1 then
                                    D:GlueTop(bq, be, bn, bo, "LEFT")
                                else
                                    D:GlueBelow(bq, bi[n - 1], 0, -bm)
                                    bb = bb + bm
                                end
                                if bp and bp(n, bb, bq:GetHeight()) then
                                    break
                                end
                                n = n + 1
                            end
                            return bi, bb
                        end
                        function d:ObjectGrid(be, br, bj, bk, bl, bs, bt, bn, bo)
                            bn = bn or 1
                            bo = bo or -1
                            bs = bs or 0
                            bt = bt or 0
                            if not br then
                                br = {}
                            end
                            for a4 = 1, #br do
                                for a3 = 1, #br[a4] do
                                    br[a4][a3]:Hide()
                                end
                            end
                            for bu = 1, #bl do
                                local bf = bl[bu]
                                for bv = 1, #bf do
                                    if not br[bu] then
                                        br[bu] = {}
                                    end
                                    local bq = br[bu][bv]
                                    if not bq then
                                        if type(bj) == "string" then
                                            bq = self[bj](self, be)
                                        else
                                            bq = bj(be, bl[bu][bv], bu, bv)
                                        end
                                        br[bu][bv] = bq
                                    end
                                    bk(be, bq, bl[bu][bv], bu, bv)
                                    bq:Show()
                                    if bu == 1 and bv == 1 then
                                        self:GlueTop(bq, be, bn, bo, "LEFT")
                                    else
                                        if bv == 1 then
                                            self:GlueBelow(bq, br[bu - 1][bv], 0, -bt, "LEFT")
                                        else
                                            self:GlueRight(bq, br[bu][bv - 1], bs, 0)
                                        end
                                    end
                                end
                            end
                        end
                        d:RegisterModule(g, h)
                    end
                    local function bw(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Builder", 6
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local bx = d.Util
                        local function by(bz, aS, ap)
                            if aS:find(".") then
                                local bA = d.Util.stringSplit(".", aS)
                                local bB = bz
                                for n, bC in pairs(bA) do
                                    if n == #bA then
                                        bB[bC] = ap
                                        return
                                    end
                                    bB = bB[bC]
                                end
                            else
                                bz[aS] = ap
                            end
                        end
                        local function bD(bz, aS)
                            if aS:find(".") then
                                local bA = d.Util.stringSplit(".", aS)
                                local bB = bz
                                for n, bC in pairs(bA) do
                                    if n == #bA then
                                        return bB[bC]
                                    end
                                    bB = bB[bC]
                                end
                            else
                                return bz[aS]
                            end
                        end
                        function d:BuildElement(x, bf, bE, bF, bz)
                            local bG
                            local bH = function(bI, ap)
                                by(bI.dbReference, bI.dataKey, ap)
                                if bI.onChange then
                                    bI:onChange(ap)
                                end
                            end
                            local bJ = false
                            if bE.type == "checkbox" then
                                bG = self:Checkbox(x, bE.label)
                            elseif bE.type == "editBox" then
                                bG = self:EditBox(x, nil, 20)
                            elseif bE.type == "multiLineBox" then
                                bG = self:MultiLineBox(x, 300, 20)
                            elseif bE.type == "dropdown" then
                                bG = self:Dropdown(x, 300, 20, bE.options or {}, nil, bE.multi or nil, bE.assoc or false)
                            elseif bE.type == "autocomplete" then
                                bG = self:Autocomplete(x, 300, 20, "")
                                if bE.validator then
                                    bG.validator = bE.validator
                                end
                                if bE.transformer then
                                    bG.transformer = bE.transformer
                                end
                                if bE.buttonCreate then
                                    bG.buttonCreate = bE.buttonCreate
                                end
                                if bE.buttonUpdate then
                                    bG.buttonUpdate = bE.buttonUpdate
                                end
                                if bE.items then
                                    bG:SetItems(bE.items)
                                end
                            elseif bE.type == "slider" or bE.type == "sliderWithBox" then
                                bG = self:SliderWithBox(x, nil, 32, 0, bE.min or 0, bE.max or 2)
                                if bE.precision then
                                    bG:SetPrecision(bE.precision)
                                end
                            elseif bE.type == "color" then
                                bG = self:ColorInput(x, bE.label, 100, 20, bE.color)
                            elseif bE.type == "button" then
                                bG = self:Button(x, nil, 20, bE.text or "")
                                if bE.onClick then
                                    bG:SetScript("OnClick", bE.onClick)
                                end
                            elseif bE.type == "header" then
                                bG = self:Header(x, bE.label)
                            elseif bE.type == "label" then
                                bG = self:Label(x, bE.label)
                            elseif bE.type == "texture" then
                                bG = self:Texture(x, bE.width or 24, bE.height or 24, bE.texture)
                            elseif bE.type == "panel" then
                                bG = self:Panel(x, 300, 20)
                            elseif bE.type == "scroll" then
                                bG = self:ScrollFrame(x, 300, 20, type(bE.scrollChild) == "table" and bE.scrollChild or nil)
                                if type(bE.scrollChild) == "function" then
                                    bE.scrollChild(bG)
                                end
                            elseif bE.type == "fauxScroll" then
                                bG =
                                    self:FauxScrollFrame(
                                    x,
                                    300,
                                    20,
                                    bE.displayCount or 5,
                                    bE.lineHeight or 22,
                                    type(bE.scrollChild) == "table" and bE.scrollChild or nil
                                )
                                if type(bE.scrollChild) == "function" then
                                    bE.scrollChild(bG)
                                end
                            elseif bE.type == "tab" then
                                bG = self:TabPanel(x, 300, 20, bE.tabs or {}, bE.vertical or false, bE.buttonWidth, bE.buttonHeight)
                            elseif bE.type == "custom" then
                                bG = bE.createFunction(x, bf, bE, bF, bz)
                            end
                            if not bG then
                                print("Could not build element with type: ", bE.type)
                            end
                            if bE.init then
                                bE.init(bG)
                            end
                            bG.dbReference = bz
                            bG.dataKey = bF
                            if bE.onChange then
                                bG.onChange = bE.onChange
                            end
                            if bG.hasLabel then
                                bJ = true
                            end
                            local bK = bE.type ~= "checkbox" and bE.type ~= "header" and bE.type ~= "label" and bE.type ~= "color"
                            if bE.label and bK then
                                self:AddLabel(x, bG, bE.label)
                                bJ = true
                            end
                            if bE.initialValue then
                                if bG.SetChecked then
                                    bG:SetChecked(bE.initialValue)
                                elseif bG.SetColor then
                                    bG:SetColor(bE.initialValue)
                                elseif bG.SetValue then
                                    bG:SetValue(bE.initialValue)
                                end
                            end
                            if bE.onValueChanged then
                                bG.OnValueChanged = bE.onValueChanged
                            elseif bz then
                                local bL = bD(bz, bF)
                                if bE.type == "checkbox" then
                                    bG:SetChecked(bL)
                                elseif bG.SetColor then
                                    bG:SetColor(bL)
                                elseif bG.SetValue then
                                    bG:SetValue(bL)
                                end
                                bG.OnValueChanged = bH
                            end
                            if bE.children then
                                self:BuildWindow(bG, bE.children)
                                self:EasyLayout(bG, {padding = {top = 10}})
                                bG:SetScript(
                                    "OnShow",
                                    function(bM)
                                        bM:DoLayout()
                                    end
                                )
                            end
                            bf:AddElement(
                                bG,
                                {
                                    column = bE.column or 12,
                                    fullSize = bE.fullSize or false,
                                    fullHeight = bE.fullHeight or false,
                                    margin = bE.layoutMargins or {top = bJ and 20 or 0}
                                }
                            )
                            return bG
                        end
                        function d:BuildRow(x, bE, bz)
                            local bf = x:AddRow()
                            for aS, bG in bx.orderedPairs(bE) do
                                local bF = bG.key or aS or nil
                                local bI = self:BuildElement(x, bf, bG, bF, bz)
                                if bG then
                                    if not x.elements then
                                        x.elements = {}
                                    end
                                    x.elements[aS] = bI
                                end
                            end
                        end
                        function d:BuildWindow(x, bE)
                            local bz = bE.database or nil
                            assert(bE.rows, "Rows are required in order to build table")
                            local bN = bE.rows
                            self:EasyLayout(x, bE.layoutConfig)
                            for N, bf in bx.orderedPairs(bN) do
                                self:BuildRow(x, bf, bz)
                            end
                            x:DoLayout()
                        end
                        d:RegisterModule(g, h)
                    end
                    local function bO(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Basic", 3
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        function d:Frame(be, q, r, bP)
                            local x = CreateFrame("Frame", nil, be, bP)
                            self:InitWidget(x)
                            self:SetObjSize(x, q, r)
                            return x
                        end
                        function d:Panel(be, q, r, bP)
                            local x = self:Frame(be, q, r, bP)
                            self:ApplyBackdrop(x, "panel")
                            return x
                        end
                        function d:PanelWithLabel(be, q, r, bP, aj)
                            local x = self:Panel(be, q, r, bP)
                            x.label = self:Header(x, aj)
                            x.label:SetAllPoints()
                            x.label:SetJustifyH("MIDDLE")
                            return x
                        end
                        function d:PanelWithTitle(be, q, r, aj)
                            local x = self:Panel(be, q, r)
                            x.titlePanel = self:PanelWithLabel(x, 100, 20, nil, aj)
                            x.titlePanel:SetPoint("TOP", 0, -10)
                            x.titlePanel:SetPoint("LEFT", 30, 0)
                            x.titlePanel:SetPoint("RIGHT", -30, 0)
                            x.titlePanel:SetBackdrop(nil)
                            return x
                        end
                        function d:Texture(be, q, r, bQ)
                            local bR = be:CreateTexture(nil, "ARTWORK")
                            self:SetObjSize(bR, q, r)
                            if bQ then
                                bR:SetTexture(bQ)
                            end
                            return bR
                        end
                        function d:ArrowTexture(be, G)
                            local bQ = self:Texture(be, 16, 8, "Interface\\Buttons\\Arrow-Up-Down")
                            if G == "UP" then
                                bQ:SetTexCoord(0, 1, 0.5, 1)
                            else
                                bQ:SetTexCoord(0, 1, 1, 0.5)
                            end
                            return bQ
                        end
                        d:RegisterModule(g, h)
                    end
                    local function bS(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Window", 5
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        function d:Window(be, q, r, bT)
                            be = be or UIParent
                            local x = self:PanelWithTitle(be, q, r, bT)
                            x:SetClampedToScreen(true)
                            x.titlePanel.isWidget = false
                            self:MakeDraggable(x)
                            local bU = self:Button(x, 16, 16, "X")
                            bU.text:SetFontSize(12)
                            bU.isWidget = false
                            self:GlueTop(bU, x, -10, -10, "RIGHT")
                            bU:SetScript(
                                "OnClick",
                                function(self)
                                    self:GetParent():Hide()
                                end
                            )
                            x.closeBtn = bU
                            function x:SetWindowTitle(aQ)
                                self.titlePanel.label:SetText(aQ)
                            end
                            function x:MakeResizable(G)
                                d:MakeResizable(x, G)
                                return x
                            end
                            return x
                        end
                        d.dialogs = {}
                        function d:Dialog(bT, bV, bW)
                            local bX
                            if bW and self.dialogs[bW] then
                                bX = self.dialogs[bW]
                            else
                                bX = self:Window(nil, self.config.dialog.width, self.config.dialog.height, bT)
                                bX:SetPoint("CENTER")
                                bX:SetFrameStrata("DIALOG")
                            end
                            if bX.messageLabel then
                                bX.messageLabel:SetText(bV)
                            else
                                bX.messageLabel = self:Label(bX, bV)
                                bX.messageLabel:SetJustifyH("MIDDLE")
                                self:GlueAcross(bX.messageLabel, bX, 5, -10, -5, 5)
                            end
                            bX:Show()
                            if bW then
                                self.dialogs[bW] = bX
                            end
                            return bX
                        end
                        function d:Confirm(bT, bV, bY, bW)
                            local bX = self:Dialog(bT, bV, bW)
                            if bY and not bX.buttons then
                                bX.buttons = {}
                                local bZ = self.Util.tableCount(bY)
                                local b_ = self.config.dialog.button.margin
                                local c0 = self.config.dialog.button.width
                                local c1 = self.config.dialog.button.height
                                local c2 = bZ * c0 + (bZ - 1) * b_
                                local c3 = math.floor((self.config.dialog.width - c2) / 2)
                                local n = 0
                                for aL, c4 in pairs(bY) do
                                    local c5 = self:Button(bX, c0, c1, c4.text)
                                    c5.window = bX
                                    self:GlueBottom(c5, bX, c3 + n * (c0 + b_), 10, "LEFT")
                                    if c4.onClick then
                                        c5:SetScript("OnClick", c4.onClick)
                                    end
                                    bX.buttons[aL] = c5
                                    n = n + 1
                                end
                                bX.messageLabel:ClearAllPoints()
                                self:GlueAcross(bX.messageLabel, bX, 5, -10, -5, 5 + c1 + 5)
                            end
                            return bX
                        end
                        d:RegisterModule(g, h)
                    end
                    local function c6(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Button", 6
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local c7 = {
                            UP = {0.45312500, 0.64062500, 0.01562500, 0.20312500},
                            DOWN = {0.45312500, 0.64062500, 0.20312500, 0.01562500},
                            LEFT = {0.23437500, 0.42187500, 0.01562500, 0.20312500},
                            RIGHT = {0.42187500, 0.23437500, 0.01562500, 0.20312500},
                            DELETE = {0.01562500, 0.20312500, 0.01562500, 0.20312500}
                        }
                        local c8 = {SetIconDisabled = function(self, bQ, c9, ca)
                                self.iconDisabled = self.stdUi:Texture(self, c9, ca, bQ)
                                self.iconDisabled:SetDesaturated(true)
                                self.iconDisabled:SetPoint("CENTER", 0, 0)
                                self:SetDisabledTexture(self.iconDisabled)
                            end, SetIcon = function(self, bQ, c9, ca, cb)
                                self.icon = self.stdUi:Texture(self, c9, ca, bQ)
                                self.icon:SetPoint("CENTER", 0, 0)
                                self:SetNormalTexture(self.icon)
                                if cb then
                                    self:SetIconDisabled(bQ, c9, ca)
                                end
                            end}
                        function d:SquareButton(be, q, r, aq)
                            local J = CreateFrame("Button", nil, be)
                            J.stdUi = self
                            self:InitWidget(J)
                            self:SetObjSize(J, q, r)
                            self:ApplyBackdrop(J)
                            self:HookDisabledBackdrop(J)
                            self:HookHoverBorder(J)
                            for aL, aM in pairs(c8) do
                                J[aL] = aM
                            end
                            local cc = c7[aq]
                            if cc then
                                J:SetIcon("Interface\\Buttons\\SquareButtonTextures", 16, 16, true)
                                J.icon:SetTexCoord(cc[1], cc[2], cc[3], cc[4])
                                J.iconDisabled:SetTexCoord(cc[1], cc[2], cc[3], cc[4])
                            end
                            return J
                        end
                        function d:ButtonLabel(be, aj)
                            local cd = self:Label(be, aj)
                            cd:SetJustifyH("CENTER")
                            self:GlueAcross(cd, be, 2, -2, -2, 2)
                            be:SetFontString(cd)
                            return cd
                        end
                        function d:HighlightButtonTexture(J)
                            local ce = self:Texture(J, nil, nil, nil)
                            ce:SetColorTexture(
                                self.config.highlight.color.r,
                                self.config.highlight.color.g,
                                self.config.highlight.color.b,
                                self.config.highlight.color.a
                            )
                            ce:SetAllPoints()
                            return ce
                        end
                        function d:HighlightButton(be, q, r, aj, cf)
                            local J = CreateFrame("Button", nil, be, cf)
                            self:InitWidget(J)
                            self:SetObjSize(J, q, r)
                            J.text = self:ButtonLabel(J, aj)
                            function J:SetFontSize(cg)
                                self.text:SetFontSize(cg)
                            end
                            local ce = self:HighlightButtonTexture(J)
                            ce:SetBlendMode("ADD")
                            J:SetHighlightTexture(ce)
                            J.highlightTexture = ce
                            return J
                        end
                        function d:Button(be, q, r, aj, cf)
                            local J = self:HighlightButton(be, q, r, aj, cf)
                            J.stdUi = self
                            J:SetHighlightTexture(nil)
                            self:ApplyBackdrop(J)
                            self:HookDisabledBackdrop(J)
                            self:HookHoverBorder(J)
                            return J
                        end
                        function d:ButtonAutoWidth(J, bm)
                            bm = bm or 5
                            J:SetWidth(J.text:GetStringWidth() + bm * 2)
                        end
                        d:RegisterModule(g, h)
                    end
                    local function ch(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "EditBox", 9
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local pairs = pairs
                        local strlen = strlen
                        local ci = {SetFontSize = function(self, cg)
                                self:SetFont(self:GetFont(), cg, self.stdUi.config.font.effect)
                            end}
                        local cj = {OnEscapePressed = function(self)
                                self:ClearFocus()
                            end}
                        function d:SimpleEditBox(be, q, r, aj)
                            local ck = CreateFrame("EditBox", nil, be)
                            ck.stdUi = self
                            self:InitWidget(ck)
                            ck:SetTextInsets(3, 3, 3, 3)
                            ck:SetFontObject(ChatFontNormal)
                            ck:SetAutoFocus(false)
                            for aL, aM in pairs(ci) do
                                ck[aL] = aM
                            end
                            for aL, aM in pairs(cj) do
                                ck:SetScript(aL, aM)
                            end
                            if aj then
                                ck:SetText(aj)
                            end
                            self:HookDisabledBackdrop(ck)
                            self:HookHoverBorder(ck)
                            self:ApplyBackdrop(ck)
                            self:SetObjSize(ck, q, r)
                            return ck
                        end
                        local cl = function(self)
                            if strlen(self:GetText()) > 0 then
                                self.placeholder.icon:Hide()
                                self.placeholder.label:Hide()
                            else
                                self.placeholder.icon:Show()
                                self.placeholder.label:Show()
                            end
                        end
                        function d:ApplyPlaceholder(k, cm, aq, cn)
                            k.placeholder = {}
                            local cd = self:Label(k, cm)
                            self:SetTextColor(cd, "disabled")
                            k.placeholder.label = cd
                            if aq then
                                local bQ = self:Texture(k, 14, 14, aq)
                                local u = cn or self.config.font.color.disabled
                                bQ:SetVertexColor(u.r, u.g, u.b, u.a)
                                self:GlueLeft(bQ, k, 5, 0, true)
                                self:GlueRight(cd, bQ, 2, 0)
                                k.placeholder.icon = bQ
                            else
                                self:GlueLeft(cd, k, 2, 0, true)
                            end
                            k:HookScript("OnTextChanged", cl)
                        end
                        local co = function(self)
                            if self.OnValueChanged then
                                self:OnValueChanged(self:GetText())
                            end
                        end
                        function d:SearchEditBox(be, q, r, cm)
                            local ck = self:SimpleEditBox(be, q, r, "")
                            ck:SetScript("OnTextChanged", co)
                            self:ApplyPlaceholder(ck, cm, "Interface\\Common\\UI-Searchbox-Icon")
                            return ck
                        end
                        local cp = {GetValue = function(self)
                                return self.value
                            end, SetValue = function(self, ap)
                                self.value = ap
                                self:SetText(ap)
                                self:Validate()
                                self.button:Hide()
                            end, IsValid = function(self)
                                return self.isValid
                            end, Validate = function(self)
                                self.isValidated = true
                                self.isValid = self.validator(self)
                                if self.isValid then
                                    if self.button then
                                        self.button:Hide()
                                    end
                                    if self.OnValueChanged and tostring(self.lastValue) ~= tostring(self.value) then
                                        self:OnValueChanged(self.value)
                                        self.lastValue = self.value
                                    end
                                end
                                self.isValidated = false
                            end}
                        local cq = function(self)
                            self.editBox:Validate(self.editBox)
                        end
                        local cr = {OnEnterPressed = function(self)
                                self:Validate()
                            end, OnTextChanged = function(self, cs)
                                local ap = d.Util.stripColors(self:GetText())
                                if tostring(ap) ~= tostring(self.value) then
                                    if not self.isValidated and self.button and cs then
                                        self.button:Show()
                                    end
                                else
                                    self.button:Hide()
                                end
                            end}
                        function d:EditBox(be, q, r, aj, ct)
                            ct = ct or d.Util.editBoxValidator
                            local ck = self:SimpleEditBox(be, q, r, aj)
                            ck.validator = ct
                            local J = self:Button(ck, 40, r - 4, OKAY)
                            J:SetPoint("RIGHT", -2, 0)
                            J:Hide()
                            J.editBox = ck
                            ck.button = J
                            for aL, aM in pairs(cp) do
                                ck[aL] = aM
                            end
                            J:SetScript("OnClick", cq)
                            for aL, aM in pairs(cr) do
                                ck:SetScript(aL, aM)
                            end
                            return ck
                        end
                        local cu = {SetMaxValue = function(self, ap)
                                self.maxValue = ap
                                self:Validate()
                            end, SetMinValue = function(self, ap)
                                self.minValue = ap
                                self:Validate()
                            end, SetMinMaxValue = function(self, cv, cw)
                                self.minValue = cv
                                self.maxValue = cw
                                self:Validate()
                            end}
                        function d:NumericBox(be, q, r, aj, ct)
                            ct = ct or self.Util.numericBoxValidator
                            local ck = self:EditBox(be, q, r, aj, ct)
                            ck:SetNumeric(true)
                            for aL, aM in pairs(cu) do
                                ck[aL] = aM
                            end
                            return ck
                        end
                        local cx = {SetValue = function(self, ap)
                                self.value = ap
                                local cy = self.stdUi.Util.formatMoney(ap)
                                self:SetText(cy)
                                self:Validate()
                                self.button:Hide()
                            end}
                        function d:MoneyBox(be, q, r, aj, ct, ax)
                            if ax then
                                ct = ct or self.Util.moneyBoxValidatorExC
                            else
                                ct = ct or self.Util.moneyBoxValidator
                            end
                            local ck = self:EditBox(be, q, r, aj, ct)
                            ck.stdUi = self
                            ck:SetMaxLetters(20)
                            for aL, aM in pairs(cx) do
                                ck[aL] = aM
                            end
                            return ck
                        end
                        local cz = {SetValue = function(self, ap)
                                self.editBox:SetText(ap)
                                if self.OnValueChanged then
                                    self:OnValueChanged(ap)
                                end
                            end, GetValue = function(self)
                                return self.editBox:GetText()
                            end, SetFont = function(self, L, Q, cA)
                                self.editBox:SetFont(L, Q, cA)
                            end, Enable = function(self)
                                self.editBox:Enable()
                            end, Disable = function(self)
                                self.editBox:Disable()
                            end, SetFocus = function(self)
                                self.editBox:SetFocus()
                            end, ClearFocus = function(self)
                                self.editBox:ClearFocus()
                            end, HasFocus = function(self)
                                return self.editBox:HasFocus()
                            end}
                        local cB = function(self, N, a4, N, cC)
                            local cD, cE = self.scrollFrame, -a4
                            local cF = cD:GetVerticalScroll()
                            if cE < cF then
                                cD:SetVerticalScroll(cE)
                            else
                                cE = cE + cC - cD:GetHeight() + 6
                                if cE > cF then
                                    cD:SetVerticalScroll(math.ceil(cE))
                                end
                            end
                        end
                        local cG = function(self)
                            if self.panel.OnValueChanged then
                                self.panel.OnValueChanged(self.panel, self:GetText())
                            end
                        end
                        local cH = function(self, J)
                            self.scrollChild:SetFocus()
                        end
                        local cI = function(self, cF)
                            self.scrollChild:SetHitRectInsets(0, 0, cF, self.scrollChild:GetHeight() - cF - self:GetHeight())
                        end
                        function d:MultiLineBox(be, q, r, aj)
                            local ck = CreateFrame("EditBox")
                            local k = self:ScrollFrame(be, q, r, ck)
                            ck.stdUi = self
                            local cJ = k.scrollFrame
                            cJ.editBox = ck
                            k.editBox = ck
                            ck.panel = k
                            self:ApplyBackdrop(k, "button")
                            self:HookHoverBorder(cJ)
                            self:HookHoverBorder(ck)
                            ck:SetWidth(cJ:GetWidth())
                            self:GlueAcross(cJ, k, 2, -2, -k.scrollBarWidth - 2, 3)
                            ck:SetTextInsets(3, 3, 3, 3)
                            ck:SetFontObject(ChatFontNormal)
                            ck:SetAutoFocus(false)
                            ck:SetScript("OnEscapePressed", ck.ClearFocus)
                            ck:SetMultiLine(true)
                            ck:EnableMouse(true)
                            ck:SetAutoFocus(false)
                            ck:SetCountInvisibleLetters(false)
                            ck:SetAllPoints()
                            ck.scrollFrame = cJ
                            ck.panel = k
                            for aL, aM in pairs(cz) do
                                k[aL] = aM
                            end
                            if aj then
                                ck:SetText(aj)
                            end
                            ck:SetScript("OnCursorChanged", cB)
                            ck:SetScript("OnTextChanged", cG)
                            cJ:HookScript("OnMouseDown", cH)
                            cJ:HookScript("OnVerticalScroll", cI)
                            k.SetText = k.SetValue
                            k.GetText = k.GetValue
                            return k
                        end
                        d:RegisterModule(g, h)
                    end
                    local function cK(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Checkbox", 5
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local cL = {SetChecked = function(self, cM, cN)
                                self.isChecked = cM
                                if not cN and self.OnValueChanged then
                                    self:OnValueChanged(cM, self.value)
                                end
                                if not cM then
                                    self.checkedTexture:Hide()
                                    self.disabledCheckedTexture:Hide()
                                    return
                                end
                                if self.isDisabled then
                                    self.checkedTexture:Hide()
                                    self.disabledCheckedTexture:Show()
                                else
                                    self.checkedTexture:Show()
                                    self.disabledCheckedTexture:Hide()
                                end
                            end, GetChecked = function(self)
                                return self.isChecked
                            end, SetText = function(self, aQ)
                                self.text:SetText(aQ)
                            end, SetValue = function(self, ap)
                                self.value = ap
                            end, GetValue = function(self)
                                if self:GetChecked() then
                                    return self.value
                                else
                                    return nil
                                end
                            end, Disable = function(self)
                                self.isDisabled = true
                                self:SetChecked(self.isChecked)
                            end, Enable = function(self)
                                self.isDisabled = false
                                self:SetChecked(self.isChecked)
                            end, AutoWidth = function(self)
                                self:SetWidth(self.target:GetWidth() + 15 + self.text:GetWidth())
                            end}
                        local cO = {OnClick = function(self)
                                if not self.isDisabled then
                                    self:SetChecked(not self:GetChecked())
                                end
                            end}
                        function d:Checkbox(be, aj, q, r)
                            local cP = CreateFrame("Button", nil, be)
                            cP.stdUi = self
                            cP:EnableMouse(true)
                            self:SetObjSize(cP, q, r or 20)
                            self:InitWidget(cP)
                            cP.target = self:Panel(cP, 16, 16)
                            cP.target.stdUi = self
                            cP.target:SetPoint("LEFT", 0, 0)
                            cP.value = true
                            cP.isChecked = false
                            cP.text = self:Label(cP, aj)
                            cP.text:SetPoint("LEFT", cP.target, "RIGHT", 5, 0)
                            cP.text:SetPoint("RIGHT", cP, "RIGHT", -5, 0)
                            cP.target.text = cP.text
                            cP.checkedTexture = self:Texture(cP.target, nil, nil, "Interface\\Buttons\\UI-CheckBox-Check")
                            cP.checkedTexture:SetAllPoints()
                            cP.checkedTexture:Hide()
                            cP.disabledCheckedTexture = self:Texture(cP.target, nil, nil, "Interface\\Buttons\\UI-CheckBox-Check-Disabled")
                            cP.disabledCheckedTexture:SetAllPoints()
                            cP.disabledCheckedTexture:Hide()
                            for aL, aM in pairs(cL) do
                                cP[aL] = aM
                            end
                            self:ApplyBackdrop(cP.target)
                            self:HookDisabledBackdrop(cP)
                            self:HookHoverBorder(cP)
                            if q == nil then
                                cP:AutoWidth()
                            end
                            for aL, aM in pairs(cO) do
                                cP:SetScript(aL, aM)
                            end
                            return cP
                        end
                        function d:IconCheckbox(be, aq, aj, q, r, cQ)
                            cQ = cQ or 16
                            local cP = self:Checkbox(be, aj, q, r)
                            cP.icon = self:Texture(cP, cQ, cQ, aq)
                            cP.icon:SetPoint("LEFT", cP.target, "RIGHT", 5, 0)
                            cP.text:ClearAllPoints()
                            cP.text:SetPoint("LEFT", cP.target, "RIGHT", cQ + 5, 0)
                            cP.text:SetPoint("RIGHT", cP, "RIGHT", -5, 0)
                            return cP
                        end
                        local cR = {OnClick = function(self)
                                if not self.isDisabled then
                                    self:SetChecked(true)
                                end
                            end}
                        function d:Radio(be, aj, cS, q, r)
                            local cT = self:Checkbox(be, aj, q, r)
                            cT.checkedTexture = self:Texture(cT.target, nil, nil, "Interface\\Buttons\\UI-RadioButton")
                            cT.checkedTexture:SetAllPoints(cT.target)
                            cT.checkedTexture:Hide()
                            cT.checkedTexture:SetTexCoord(0.25, 0.5, 0, 1)
                            cT.disabledCheckedTexture = self:Texture(cT.target, nil, nil, "Interface\\Buttons\\UI-RadioButton")
                            cT.disabledCheckedTexture:SetAllPoints(cT.target)
                            cT.disabledCheckedTexture:Hide()
                            cT.disabledCheckedTexture:SetTexCoord(0.75, 1, 0, 1)
                            for aL, aM in pairs(cR) do
                                cT:SetScript(aL, aM)
                            end
                            if cS then
                                self:AddToRadioGroup(cT, cS)
                            end
                            return cT
                        end
                        d.radioGroups = {}
                        d.radioGroupValues = {}
                        function d:RadioGroup(cS)
                            if not self.radioGroups[cS] then
                                self.radioGroups[cS] = {}
                            end
                            if not self.radioGroupValues[cS] then
                                self.radioGroupValues[cS] = {}
                            end
                            return self.radioGroups[cS]
                        end
                        function d:GetRadioGroupValue(cS)
                            local cU = self:RadioGroup(cS)
                            for n = 1, #cU do
                                local cT = cU[n]
                                if cT:GetChecked() then
                                    return cT:GetValue()
                                end
                            end
                            return nil
                        end
                        function d:SetRadioGroupValue(cS, ap)
                            local cU = self:RadioGroup(cS)
                            for n = 1, #cU do
                                local cT = cU[n]
                                cT:SetChecked(cT.value == ap)
                            end
                            return nil
                        end
                        local cV = function(cT)
                            cT.notified = true
                            local cU = cT.radioGroup
                            local cS = cT.radioGroupName
                            for n = 1, #cU do
                                if not cU[n].notified then
                                    return
                                end
                            end
                            local cW = cT.stdUi:GetRadioGroupValue(cS)
                            if cT.stdUi.radioGroupValues[cS] ~= cW then
                                cT.OnValueChangedCallback(cW, cS)
                            end
                            cT.stdUi.radioGroupValues[cS] = cW
                            for n = 1, #cU do
                                cU[n].notified = false
                            end
                        end
                        function d:OnRadioGroupValueChanged(cS, cX)
                            local cU = self:RadioGroup(cS)
                            for n = 1, #cU do
                                local cT = cU[n]
                                cT.OnValueChangedCallback = cX
                                cT.OnValueChanged = cV
                            end
                            return nil
                        end
                        local cY = {OnClick = function(cT)
                                for n = 1, #cT.radioGroup do
                                    local cZ = cT.radioGroup[n]
                                    if cZ ~= cT then
                                        cZ:SetChecked(false)
                                    end
                                end
                            end}
                        function d:AddToRadioGroup(cT, cS)
                            local cU = self:RadioGroup(cS)
                            tinsert(cU, cT)
                            cT.radioGroup = cU
                            cT.radioGroupName = cS
                            for aL, aM in pairs(cY) do
                                cT:HookScript(aL, aM)
                            end
                        end
                        d:RegisterModule(g, h)
                    end
                    local function c_(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Dropdown", 4
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local e = tinsert
                        local d0 = StdUiDropdowns or {}
                        StdUiDropdowns = d0
                        local d1 = function(self)
                            self.dropdown:SetValue(self.value, self:GetText())
                            self.dropdown.optsFrame:Hide()
                        end
                        local d2 = function(cP, d3)
                            cP.dropdown:ToggleValue(cP.value, d3)
                        end
                        local d4 = {buttonCreate = function(be)
                                local d5 = be.dropdown
                                local d6
                                if d5.multi then
                                    d6 = d5.stdUi:Checkbox(be, "", be:GetWidth(), 20)
                                else
                                    d6 = d5.stdUi:HighlightButton(be, be:GetWidth(), 20, "")
                                    d6.text:SetJustifyH("LEFT")
                                end
                                d6.dropdown = d5
                                d6:SetFrameLevel(be:GetFrameLevel() + 2)
                                if not d5.multi then
                                    d6:SetScript("OnClick", d1)
                                else
                                    d6.OnValueChanged = d2
                                end
                                return d6
                            end, buttonUpdate = function(be, bq, bl)
                                bq:SetWidth(be:GetWidth())
                                bq:SetText(bl.text)
                                if bq.dropdown.multi then
                                    bq:SetValue(bl.value)
                                else
                                    bq.value = bl.value
                                end
                            end, ShowOptions = function(self)
                                for n = 1, #d0 do
                                    d0[n]:HideOptions()
                                end
                                self.optsFrame:UpdateSize(self:GetWidth(), self.optsFrame:GetHeight())
                                self.optsFrame:Show()
                                self.optsFrame:Update()
                                self:RepaintOptions()
                            end, HideOptions = function(self)
                                self.optsFrame:Hide()
                            end, ToggleOptions = function(self)
                                if self.optsFrame:IsShown() then
                                    self:HideOptions()
                                else
                                    self:ShowOptions()
                                end
                            end, SetPlaceholder = function(self, cm)
                                if self:GetText() == "" or self:GetText() == self.placeholder then
                                    self:SetText(cm)
                                end
                                self.placeholder = cm
                            end, RepaintOptions = function(self)
                                local d7 = self.optsFrame.scrollChild
                                self.stdUi:ObjectList(d7, d7.items, self.buttonCreate, self.buttonUpdate, self.options)
                                self.optsFrame:UpdateItemsCount(#self.options)
                            end, SetOptions = function(self, d8)
                                self.options = d8
                                local d9 = #d8 * 20
                                local d7 = self.optsFrame.scrollChild
                                if not d7.items then
                                    d7.items = {}
                                end
                                self.optsFrame:SetHeight(math.min(d9 + 4, 200))
                                d7:SetHeight(d9)
                                self:RepaintOptions()
                            end, ToggleValue = function(self, ap, aT)
                                assert(self.multi, "Single dropdown cannot have more than one value!")
                                if self.assoc then
                                    self.value[ap] = aT
                                else
                                    if aT then
                                        if not tContains(self.value, ap) then
                                            e(self.value, ap)
                                        end
                                    else
                                        if tContains(self.value, ap) then
                                            tDeleteItem(self.value, ap)
                                        end
                                    end
                                end
                                self:SetValue(self.value)
                            end, SetValue = function(self, ap, aj)
                                self.value = ap
                                if aj then
                                    self:SetText(aj)
                                else
                                    self:SetText(self:FindValueText(ap))
                                end
                                if self.multi then
                                    for N, cP in pairs(self.optsFrame.scrollChild.items) do
                                        local d3 = false
                                        if self.assoc then
                                            d3 = self.value[cP.value]
                                        else
                                            d3 = tContains(self.value, cP.value)
                                        end
                                        cP:SetChecked(d3, true)
                                    end
                                end
                                if self.OnValueChanged then
                                    self.OnValueChanged(self, ap, self:GetText())
                                end
                            end, GetValue = function(self)
                                return self.value
                            end, FindValueText = function(self, ap)
                                if type(ap) ~= "table" then
                                    for n = 1, #self.options do
                                        local da = self.options[n]
                                        if da.value == ap then
                                            return da.text
                                        end
                                    end
                                    return self.placeholder or ""
                                else
                                    local m = ""
                                    for n = 1, #self.options do
                                        local da = self.options[n]
                                        if self.assoc then
                                            for aS, db in pairs(ap) do
                                                if db and aS == da.value then
                                                    if m == "" then
                                                        m = da.text
                                                    else
                                                        m = m .. ", " .. da.text
                                                    end
                                                end
                                            end
                                        else
                                            for a3 = 1, #ap do
                                                if ap[a3] == da.value then
                                                    if m == "" then
                                                        m = da.text
                                                    else
                                                        m = m .. ", " .. da.text
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    if m ~= "" then
                                        return m
                                    else
                                        return self.placeholder or ""
                                    end
                                end
                            end}
                        local dc = {OnClick = function(self)
                                self:ToggleOptions()
                            end}
                        function d:Dropdown(be, q, r, dd, ap, de, df)
                            local d5 = self:Button(be, q, r, "")
                            d5.stdUi = self
                            d5.text:SetJustifyH("LEFT")
                            d5.text:ClearAllPoints()
                            self:GlueAcross(d5.text, d5, 2, -2, -16, 2)
                            local dg = self:Texture(d5, 15, 15, "Interface\\Buttons\\SquareButtonTextures")
                            dg:SetTexCoord(0.45312500, 0.64062500, 0.20312500, 0.01562500)
                            self:GlueRight(dg, d5, -2, 0, true)
                            local dh = self:FauxScrollFrame(d5, d5:GetWidth(), 200, 10, 20)
                            dh:Hide()
                            self:GlueBelow(dh, d5, 0, 1, "LEFT")
                            d5:SetFrameLevel(dh:GetFrameLevel() + 1)
                            d5.multi = de
                            d5.assoc = df
                            d5.optsFrame = dh
                            d5.dropTex = dg
                            d5.options = dd
                            dh.scrollChild.dropdown = d5
                            for aL, aM in pairs(d4) do
                                d5[aL] = aM
                            end
                            if dd then
                                d5:SetOptions(dd)
                            end
                            if ap then
                                d5:SetValue(ap)
                            elseif de then
                                d5.value = {}
                            end
                            for aL, aM in pairs(dc) do
                                d5:SetScript(aL, aM)
                            end
                            e(d0, d5)
                            return d5
                        end
                        d:RegisterModule(g, h)
                    end
                    local function di(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Autocomplete", 3
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local e = tinsert
                        d.Util.autocompleteTransformer = function(N, ap)
                            return ap
                        end
                        d.Util.autocompleteValidator = function(self)
                            self.stdUi:MarkAsValid(self, true)
                            return true
                        end
                        d.Util.autocompleteItemTransformer = function(N, ap)
                            if not ap or ap == "" then
                                return ap
                            end
                            local dj = GetItemInfo(ap)
                            return dj
                        end
                        d.Util.autocompleteItemValidator = function(dk)
                            local dj, dl
                            local aQ = dk:GetText()
                            local aM = dk:GetValue()
                            if tonumber(aQ) ~= nil then
                                dj = GetItemInfo(tonumber(aQ))
                                if dj then
                                    dl = tonumber(aQ)
                                end
                            elseif aM then
                                dj = GetItemInfo(aM)
                                if dj == aQ then
                                    dl = aM
                                end
                            end
                            if dl then
                                dk.value = dl
                                dk:SetText(dj)
                                self.stdUi:MarkAsValid(dk, true)
                                return true
                            else
                                self.stdUi:MarkAsValid(dk, false)
                                return false
                            end
                        end
                        local dm = {
                            buttonCreate = function(dn)
                                local d6
                                d6 = d:HighlightButton(dn, dn:GetWidth(), 20, "")
                                d6.text:SetJustifyH("LEFT")
                                d6.autocomplete = dn.autocomplete
                                d6:SetFrameLevel(dn:GetFrameLevel() + 2)
                                d6:SetScript(
                                    "OnClick",
                                    function(aE)
                                        local dk = aE.autocomplete
                                        if aE.boundItem then
                                            aE.autocomplete.selectedItem = aE.boundItem
                                        end
                                        dk:SetValue(aE.value, aE:GetText())
                                        aE.autocomplete.dropdown:Hide()
                                    end
                                )
                                return d6
                            end,
                            buttonUpdate = function(dn, d6, bl)
                                d6.boundItem = bl
                                d6.value = bl.value
                                d6:SetWidth(dn:GetWidth())
                                d6:SetText(bl.text)
                            end,
                            filterItems = function(dk, dp, dq)
                                local m = {}
                                for N, dr in pairs(dq) do
                                    local ds = tostring(dr.value)
                                    if dr.text:lower():find(dp:lower(), nil, true) or ds:lower():find(dp:lower(), nil, true) then
                                        e(m, dr)
                                    end
                                    if #m >= dk.itemLimit then
                                        break
                                    end
                                end
                                return m
                            end,
                            SetItems = function(self, dt)
                                self.items = dt
                                self:RenderItems()
                                self.dropdown:Hide()
                            end,
                            RenderItems = function(self)
                                local du = 20 * #self.filteredItems
                                self.dropdown:SetHeight(du)
                                self.stdUi:ObjectList(
                                    self.dropdown,
                                    self.itemTable,
                                    self.buttonCreate,
                                    self.buttonUpdate,
                                    self.filteredItems
                                )
                            end,
                            ValueToText = function(self, ap)
                                return self.transformer(ap)
                            end,
                            SetValue = function(self, ap, aQ)
                                self.value = ap
                                self:SetText(aQ or self:ValueToText(ap) or "")
                                self:Validate()
                                self.button:Hide()
                            end,
                            Validate = function(self)
                                self.isValidated = true
                                self.isValid = self:validator()
                                if self.isValid then
                                    if self.OnValueChanged then
                                        self:OnValueChanged(self.value, self:GetText())
                                    end
                                end
                                self.isValidated = false
                            end
                        }
                        local dv = {OnEditFocusLost = function(dw)
                                dw.dropdown:Hide()
                            end, OnEnterPressed = function(dw)
                                dw.dropdown:Hide()
                                dw:Validate()
                            end, OnTextChanged = function(dk, cs)
                                local dx = d.Util.stripColors(dk:GetText())
                                dk.selectedItem = nil
                                if cs then
                                    dk.value = nil
                                    if type(dk.items) == "function" then
                                        dk.filteredItems = dk:items(dx)
                                    elseif type(dk.items) == "table" then
                                        dk.filteredItems = dk:filterItems(dx, dk.items)
                                    end
                                    if not dk.filteredItems or #dk.filteredItems == 0 then
                                        dk.dropdown:Hide()
                                    else
                                        dk:RenderItems()
                                        dk.dropdown:Show()
                                    end
                                end
                            end}
                        function d:Autocomplete(be, q, r, aj, ct, dy, dz)
                            dy = dy or d.Util.autocompleteTransformer
                            ct = ct or d.Util.autocompleteValidator
                            local dA = self:EditBox(be, q, r, aj, ct)
                            dA.stdUi = self
                            dA.transformer = dy
                            dA.items = dz
                            dA.filteredItems = {}
                            dA.selectedItem = nil
                            dA.itemLimit = 8
                            dA.itemTable = {}
                            dA.dropdown = self:Panel(be, q, 20)
                            dA.dropdown:SetPoint("TOPLEFT", dA, "BOTTOMLEFT", 0, 0)
                            dA.dropdown:SetPoint("TOPRIGHT", dA, "BOTTOMRIGHT", 0, 0)
                            dA.dropdown:Hide()
                            dA.dropdown:SetFrameLevel(dA:GetFrameLevel() + 10)
                            dA.dropdown.autocomplete = dA
                            for aL, aM in pairs(dm) do
                                dA[aL] = aM
                            end
                            for aL, aM in pairs(dv) do
                                dA:SetScript(aL, aM)
                            end
                            return dA
                        end
                        d:RegisterModule(g, h)
                    end
                    local function dB(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Label", 3
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local dC = {SetFontSize = function(self, cg)
                                self:SetFont(self:GetFont(), cg)
                            end}
                        function d:FontString(be, aj, cf)
                            local dD = be:CreateFontString(nil, self.config.font.strata, cf or "GameFontNormal")
                            dD:SetText(aj)
                            dD:SetJustifyH("LEFT")
                            dD:SetJustifyV("MIDDLE")
                            for aL, aM in pairs(dC) do
                                dD[aL] = aM
                            end
                            return dD
                        end
                        function d:Label(be, aj, Q, cf, q, r)
                            local dD = self:FontString(be, aj, cf)
                            if Q then
                                dD:SetFontSize(Q)
                            end
                            self:SetTextColor(dD, "normal")
                            self:SetObjSize(dD, q, r)
                            return dD
                        end
                        function d:Header(be, aj, Q, cf, q, r)
                            local dD = self:Label(be, aj, Q, cf or "GameFontNormalLarge", q, r)
                            self:SetTextColor(dD, "header")
                            return dD
                        end
                        function d:AddLabel(be, w, aj, dE, dF)
                            local dG = self.config.font.size + 4
                            local cd = self:Label(be, aj, self.config.font.size, nil, dF, dG)
                            if dE == "TOP" or dE == nil then
                                self:GlueAbove(cd, w, 0, 4, "LEFT")
                            elseif dE == "RIGHT" then
                                self:GlueRight(cd, w, 4, 0)
                            else
                                cd:SetWidth(dF or cd:GetStringWidth())
                                self:GlueLeft(cd, w, -4, 0)
                            end
                            w.label = cd
                            return cd
                        end
                        d:RegisterModule(g, h)
                    end
                    local function dH(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Scroll", 6
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local dI = function(dJ)
                            return math.floor(dJ + .5)
                        end
                        d.ScrollBarEvents = {UpDownButtonOnClick = function(self)
                                local dK = self.scrollBar
                                local cJ = dK.scrollFrame
                                local dL = dK.scrollStep or cJ:GetHeight() / 2
                                if self.direction == 1 then
                                    dK:SetValue(dK:GetValue() - dL)
                                else
                                    dK:SetValue(dK:GetValue() + dL)
                                end
                            end, OnValueChanged = function(self, ap)
                                self.scrollFrame:SetVerticalScroll(ap)
                            end}
                        d.ScrollFrameEvents = {OnMouseWheel = function(self, ap, dK)
                                dK = dK or self.scrollBar
                                local dL = dK.scrollStep or dK:GetHeight() / 2
                                if ap > 0 then
                                    dK:SetValue(dK:GetValue() - dL)
                                else
                                    dK:SetValue(dK:GetValue() + dL)
                                end
                            end, OnScrollRangeChanged = function(self, N, dM)
                                local dN = self.scrollBar
                                if not dM then
                                    dM = self:GetVerticalScrollRange()
                                end
                                dM = math.floor(dM)
                                local ap = math.min(dN:GetValue(), dM)
                                dN:SetMinMaxValues(0, dM)
                                dN:SetValue(ap)
                                local dO = dN.ScrollDownButton
                                local dP = dN.ScrollUpButton
                                local dQ = dN.ThumbTexture
                                if dM == 0 then
                                    if self.scrollBarHideable then
                                        dN:Hide()
                                        dO:Hide()
                                        dP:Hide()
                                        dQ:Hide()
                                    else
                                        dO:Disable()
                                        dP:Disable()
                                        dO:Show()
                                        dP:Show()
                                        if not self.noScrollThumb then
                                            dQ:Show()
                                        end
                                    end
                                else
                                    dO:Show()
                                    dP:Show()
                                    dN:Show()
                                    if not self.noScrollThumb then
                                        dQ:Show()
                                    end
                                    if dM - ap > 0.005 then
                                        dO:Enable()
                                    else
                                        dO:Disable()
                                    end
                                end
                            end, OnVerticalScroll = function(self, cF)
                                local dK = self.scrollBar
                                dK:SetValue(cF)
                                local N, cw = dK:GetMinMaxValues()
                                dK.ScrollUpButton:SetEnabled(cF ~= 0)
                                dK.ScrollDownButton:SetEnabled(dK:GetValue() - cw ~= 0)
                            end}
                        d.ScrollFrameMethods = {SetScrollStep = function(self, dL)
                                dL = dI(dL)
                                self.scrollBar.scrollStep = dL
                                self.scrollBar:SetValueStep(dL)
                            end, GetChildFrames = function(self)
                                return self.scrollBar, self.scrollChild, self.scrollBar.ScrollUpButton, self.scrollBar.ScrollDownButton
                            end, UpdateSize = function(self, dR, dS)
                                self:SetSize(dR, dS)
                                self.scrollFrame:ClearAllPoints()
                                self.scrollFrame:SetSize(dR - self.scrollBarWidth - 5, dS - 4)
                                self.stdUi:GlueAcross(self.scrollFrame, self, 2, -2, -self.scrollBarWidth - 2, 2)
                                self.scrollBar.panel:SetPoint("TOPRIGHT", self, "TOPRIGHT", -2, -2)
                                self.scrollBar.panel:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, 2)
                                if self.scrollChild then
                                    self.scrollChild:SetWidth(self.scrollFrame:GetWidth())
                                    self.scrollChild:SetHeight(self.scrollFrame:GetHeight())
                                end
                            end}
                        function d:ScrollFrame(be, q, r, d7)
                            local dn = self:Panel(be, q, r)
                            dn.stdUi = self
                            dn.offset = 0
                            dn.scrollBarWidth = 16
                            local cJ = CreateFrame("ScrollFrame", nil, dn)
                            local dK = self:ScrollBar(dn, dn.scrollBarWidth)
                            dK:SetMinMaxValues(0, 0)
                            dK:SetValue(0)
                            dK:SetScript("OnValueChanged", self.ScrollBarEvents.OnValueChanged)
                            dK.ScrollUpButton.direction = 1
                            dK.ScrollDownButton.direction = -1
                            dK.ScrollDownButton:SetScript("OnClick", self.ScrollBarEvents.UpDownButtonOnClick)
                            dK.ScrollUpButton:SetScript("OnClick", self.ScrollBarEvents.UpDownButtonOnClick)
                            dK.ScrollDownButton:Disable()
                            dK.ScrollUpButton:Disable()
                            if self.noScrollThumb then
                                dK.ThumbTexture:Hide()
                            end
                            dK.scrollFrame = cJ
                            cJ.scrollBar = dK
                            cJ.panel = dn
                            dn.scrollBar = dK
                            dn.scrollFrame = cJ
                            for aL, aM in pairs(self.ScrollFrameMethods) do
                                dn[aL] = aM
                            end
                            for aL, aM in pairs(self.ScrollFrameEvents) do
                                cJ:SetScript(aL, aM)
                            end
                            if not d7 then
                                d7 = CreateFrame("Frame", nil, cJ)
                                d7:SetWidth(cJ:GetWidth())
                                d7:SetHeight(cJ:GetHeight())
                            else
                                d7:SetParent(cJ)
                            end
                            dn.scrollChild = d7
                            dn:UpdateSize(q, r)
                            cJ:SetScrollChild(d7)
                            cJ:EnableMouse(true)
                            cJ:SetClampedToScreen(true)
                            cJ:SetClipsChildren(true)
                            d7:SetPoint("RIGHT", cJ, "RIGHT", 0, 0)
                            cJ.scrollChild = d7
                            return dn
                        end
                        d.FauxScrollFrameMethods = {GetOffset = function(self)
                                return self.offset or 0
                            end, DoVerticalScroll = function(self, ap, dT, dU)
                                local dK = self.scrollBar
                                dT = dT or self.lineHeight
                                dK:SetValue(ap)
                                self.offset = floor(ap / dT + 0.5)
                                if dU then
                                    dU(self)
                                end
                            end, Redraw = function(self)
                                self:Update(self.itemCount or #self.scrollChild.items, self.displayCount, self.lineHeight)
                            end, UpdateItemsCount = function(self, dV)
                                self.itemCount = dV
                                self:Update(dV, self.displayCount, self.lineHeight)
                            end, Update = function(self, dW, dX, dY)
                                local dK, dZ, dP, dO = self:GetChildFrames()
                                local d_
                                if dW == nil or dX == nil then
                                    return
                                end
                                if dW > dX then
                                    d_ = 1
                                else
                                    dK:SetValue(0)
                                end
                                if self:IsShown() then
                                    local e0 = 0
                                    local e1 = 0
                                    if dW > 0 then
                                        e0 = (dW - dX) * dY
                                        e1 = dW * dY
                                        if e0 < 0 then
                                            e0 = 0
                                        end
                                        dZ:Show()
                                    else
                                        dZ:Hide()
                                    end
                                    local e2 = (dW - dX) * dY
                                    if e2 < 0 then
                                        e2 = 0
                                    end
                                    dK:SetMinMaxValues(0, e2)
                                    self:SetScrollStep(dY)
                                    dK:SetStepsPerPage(dX - 1)
                                    dZ:SetHeight(e1)
                                    if dK:GetValue() == 0 then
                                        dP:Disable()
                                    else
                                        dP:Enable()
                                    end
                                    if dK:GetValue() - e0 == 0 then
                                        dO:Disable()
                                    else
                                        dO:Enable()
                                    end
                                end
                                return d_
                            end}
                        local e3 = function(self)
                            self:Redraw()
                        end
                        d.FauxScrollFrameEvents = {OnVerticalScroll = function(self, ap)
                                ap = dI(ap)
                                local dn = self.panel
                                dn:DoVerticalScroll(ap, dn.lineHeight, e3)
                            end}
                        function d:FauxScrollFrame(be, q, r, e4, e5, d7)
                            local dn = self:ScrollFrame(be, q, r, d7)
                            dn.lineHeight = e5
                            dn.displayCount = e4
                            for aL, aM in pairs(self.FauxScrollFrameMethods) do
                                dn[aL] = aM
                            end
                            for aL, aM in pairs(self.FauxScrollFrameEvents) do
                                dn.scrollFrame:SetScript(aL, aM)
                            end
                            return dn
                        end
                        d.HybridScrollFrameMethods = {
                            Update = function(self, bb)
                                local e6 = floor(bb - self.scrollChild:GetHeight() + 0.5)
                                if e6 > 0 and self.scrollBar then
                                    local N, e7 = self.scrollBar:GetMinMaxValues()
                                    if math.floor(self.scrollBar:GetValue()) >= math.floor(e7) then
                                        self.scrollBar:SetMinMaxValues(0, e6)
                                        if e6 < e7 then
                                            if math.floor(self.scrollBar:GetValue()) ~= math.floor(e6) then
                                                self.scrollBar:SetValue(e6)
                                            else
                                                self:SetOffset(self, e6)
                                            end
                                        end
                                    else
                                        self.scrollBar:SetMinMaxValues(0, e6)
                                    end
                                    self.scrollBar:Enable()
                                    self:UpdateScrollBarState()
                                    self.scrollBar:Show()
                                elseif self.scrollBar then
                                    self.scrollBar:SetValue(0)
                                    if self.scrollBar.doNotHide then
                                        self.scrollBar:Disable()
                                        self.scrollBar.ScrollUpButton:Disable()
                                        self.scrollBar.ScrollDownButton:Disable()
                                        self.scrollBar.ThumbTexture:Hide()
                                    else
                                        self.scrollBar:Hide()
                                    end
                                end
                                self.range = e6
                                self.totalHeight = bb
                                self.scrollFrame:UpdateScrollChildRect()
                            end,
                            SetData = function(self, bl)
                                self.data = bl
                            end,
                            SetUpdateFunction = function(self, e8)
                                self.updateFn = e8
                            end,
                            UpdateScrollBarState = function(self, e9)
                                if not e9 then
                                    e9 = self.scrollBar:GetValue()
                                end
                                self.scrollBar.ScrollUpButton:Enable()
                                self.scrollBar.ScrollDownButton:Enable()
                                local ea, e7 = self.scrollBar:GetMinMaxValues()
                                if e9 >= e7 then
                                    self.scrollBar.ThumbTexture:Show()
                                    if self.scrollBar.ScrollDownButton then
                                        self.scrollBar.ScrollDownButton:Disable()
                                    end
                                end
                                if e9 <= ea then
                                    self.scrollBar.ThumbTexture:Show()
                                    if self.scrollBar.ScrollUpButton then
                                        self.scrollBar.ScrollUpButton:Disable()
                                    end
                                end
                            end,
                            GetOffset = function(self)
                                return math.floor(self.offset or 0), self.offset or 0
                            end,
                            SetOffset = function(self, cF)
                                local dz = self.items
                                local dT = self.itemHeight
                                local bG, eb
                                local ec = 0
                                if self.dynamic then
                                    if cF < dT then
                                        bG, ec = 0, cF
                                    else
                                        bG, ec = self.dynamic(cF)
                                    end
                                else
                                    bG = cF / dT
                                    eb = bG - math.floor(bG)
                                    ec = eb * dT
                                end
                                if math.floor(self.offset or 0) ~= math.floor(bG) and self.updateFn then
                                    self.offset = bG
                                    self:UpdateItems()
                                else
                                    self.offset = bG
                                end
                                self.scrollFrame:SetVerticalScroll(ec)
                            end,
                            CreateItems = function(self, bl, bj, bk, bm, bn, bo)
                                local d7 = self.scrollChild
                                local dT = 0
                                local dW = #bl
                                if not self.items then
                                    self.items = {}
                                end
                                self.data = bl
                                self.createFn = bj
                                self.updateFn = bk
                                self.itemPadding = bm
                                self.stdUi:ObjectList(
                                    d7,
                                    self.items,
                                    bj,
                                    bk,
                                    bl,
                                    bm,
                                    bn,
                                    bo,
                                    function(n, bb, ed)
                                        return bb > self:GetHeight() + ed
                                    end
                                )
                                if self.items[1] then
                                    dT = dI(self.items[1]:GetHeight() + bm)
                                end
                                self.itemHeight = dT
                                local bb = dW * dT
                                self.scrollFrame:SetVerticalScroll(0)
                                local dK = self.scrollBar
                                dK:SetMinMaxValues(0, bb)
                                dK.itemHeight = dT
                                self:SetScrollStep(dT / 2)
                                dK:SetStepsPerPage(dW - 2)
                                dK:SetValue(0)
                                self:Update(bb)
                            end,
                            UpdateItems = function(self)
                                local ee = #self.data
                                local cF = self:GetOffset()
                                local dz = self:GetItems()
                                for n = 1, #dz do
                                    local dr = dz[n]
                                    local ef = cF + n
                                    if ef <= ee then
                                        self.updateFn(self.scrollChild, dr, self.data[ef], ef, n)
                                    end
                                end
                                local eg = dz[1]
                                local bb = 0
                                if eg then
                                    bb = ee * (eg:GetHeight() + self.itemPadding)
                                end
                                self:Update(bb, self:GetHeight())
                            end,
                            GetItems = function(self)
                                return self.items
                            end,
                            SetDoNotHideScrollBar = function(self, eh)
                                if not self.scrollBar or self.scrollBar.doNotHide == eh then
                                    return
                                end
                                self.scrollBar.doNotHide = eh
                                self:Update(self.totalHeight or 0, self.scrollChild:GetHeight())
                            end,
                            ScrollToIndex = function(self, ef, ei)
                                local bb = 0
                                local e0 = self:GetHeight()
                                for n = 1, ef do
                                    local ej = ei(n)
                                    if n == ef then
                                        local cF = 0
                                        if bb + ej > e0 then
                                            if ej > e0 then
                                                cF = bb
                                            else
                                                local ek = e0 - ej
                                                cF = bb - ek / 2
                                            end
                                            local el = self.scrollBar:GetValueStep()
                                            cF = cF + el - mod(cF, el)
                                            if cF > bb then
                                                cF = cF - el
                                            end
                                        end
                                        self.scrollBar:SetValue(cF)
                                        break
                                    end
                                    bb = bb + ej
                                end
                            end
                        }
                        local em = function(self, ap)
                            local k = self.scrollFrame.panel
                            ap = dI(ap)
                            k:SetOffset(ap)
                            k:UpdateScrollBarState(ap)
                        end
                        function d:HybridScrollFrame(be, q, r, d7)
                            local dn = self:ScrollFrame(be, q, r, d7)
                            dn.scrollBar:SetScript("OnValueChanged", em)
                            dn.scrollFrame:SetScript("OnScrollRangeChanged", nil)
                            dn.scrollFrame:SetScript("OnVerticalScroll", nil)
                            for aL, aM in pairs(self.HybridScrollFrameMethods) do
                                dn[aL] = aM
                            end
                            return dn
                        end
                        d:RegisterModule(g, h)
                    end
                    local function en(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "ScrollTable", 6
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local e = tinsert
                        local ah = table.sort
                        local bm = 2.5
                        local eo = {
                            SetAutoHeight = function(self)
                                self:SetHeight(self.numberOfRows * self.rowHeight + 10)
                                self:Refresh()
                            end,
                            SetAutoWidth = function(self)
                                local q = 13
                                for N, b7 in pairs(self.columns) do
                                    q = q + b7.width
                                end
                                self:SetWidth(q + 20)
                                self:Refresh()
                            end,
                            ScrollToLine = function(self, ep)
                                ep = Clamp(ep, 1, #self.filtered - self.numberOfRows + 1)
                                self:DoVerticalScroll(
                                    self.rowHeight * (ep - 1),
                                    self.rowHeight,
                                    function(dw)
                                        dw:Refresh()
                                    end
                                )
                            end,
                            SetColumns = function(self, eq)
                                local table = self
                                self.columns = eq
                                local er = self.head
                                if not er then
                                    er = CreateFrame("Frame", nil, self)
                                    er:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 4, 0)
                                    er:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -4, 0)
                                    er:SetHeight(self.rowHeight)
                                    er.columns = {}
                                    self.head = er
                                end
                                for n = 1, #eq do
                                    local es = self.columns[n]
                                    local et = er.columns[n]
                                    if not er.columns[n] then
                                        et = self.stdUi:HighlightButton(er)
                                        et:SetPushedTextOffset(0, 0)
                                        et.arrow = self.stdUi:Texture(et, 8, 8, "Interface\\Buttons\\UI-SortArrow")
                                        et.arrow:Hide()
                                        if self.headerEvents then
                                            for eu, ev in pairs(self.headerEvents) do
                                                et:SetScript(
                                                    eu,
                                                    function(ew, ...)
                                                        table:FireHeaderEvent(eu, ev, et, er, n, ...)
                                                    end
                                                )
                                            end
                                        end
                                        er.columns[n] = et
                                        es.head = et
                                        es.cells = {}
                                    end
                                    local a5 = eq[n].align or "LEFT"
                                    et.text:SetJustifyH(a5)
                                    et.text:SetText(eq[n].name)
                                    if a5 == "LEFT" then
                                        et.arrow:ClearAllPoints()
                                        self.stdUi:GlueRight(et.arrow, et, 0, 0, true)
                                    else
                                        et.arrow:ClearAllPoints()
                                        self.stdUi:GlueLeft(et.arrow, et, 5, 0, true)
                                    end
                                    if eq[n].sortable == false and eq[n].sortable ~= nil then
                                    else
                                    end
                                    if n > 1 then
                                        et:SetPoint("LEFT", er.columns[n - 1], "RIGHT", 0, 0)
                                    else
                                        et:SetPoint("LEFT", er, "LEFT", 2, 0)
                                    end
                                    et:SetHeight(self.rowHeight)
                                    et:SetWidth(eq[n].width)
                                    function es:SetWidth(q)
                                        es.width = q
                                        es.head:SetWidth(q)
                                        for ex = 1, #es.cells do
                                            es.cells[ex]:SetWidth(q)
                                        end
                                    end
                                end
                                self:SetDisplayRows(self.numberOfRows, self.rowHeight)
                                self:SetAutoWidth()
                            end,
                            SetDisplayRows = function(self, ey, ez)
                                local table = self
                                self.numberOfRows = ey
                                self.rowHeight = ez
                                if not self.rows then
                                    self.rows = {}
                                end
                                for n = 1, ey do
                                    local eA = self.rows[n]
                                    if not eA then
                                        eA = CreateFrame("Button", nil, self)
                                        self.rows[n] = eA
                                        if n > 1 then
                                            eA:SetPoint("TOPLEFT", self.rows[n - 1], "BOTTOMLEFT", 0, 0)
                                            eA:SetPoint("TOPRIGHT", self.rows[n - 1], "BOTTOMRIGHT", 0, 0)
                                        else
                                            eA:SetPoint("TOPLEFT", self.scrollFrame, "TOPLEFT", 1, -1)
                                            eA:SetPoint("TOPRIGHT", self.scrollFrame, "TOPRIGHT", -1, -1)
                                        end
                                        eA:SetHeight(ez)
                                    end
                                    if not eA.columns then
                                        eA.columns = {}
                                    end
                                    for ex = 1, #self.columns do
                                        local eB = self.columns[ex]
                                        local eC = eA.columns[ex]
                                        if not eC then
                                            eC = CreateFrame("Button", nil, eA)
                                            eC.text = self.stdUi:FontString(eC, "")
                                            eA.columns[ex] = eC
                                            self.columns[ex].cells[n] = eC
                                            local a5 = eB.align or "LEFT"
                                            eC.text:SetJustifyH(a5)
                                            eC:EnableMouse(true)
                                            eC:RegisterForClicks("AnyUp")
                                            if self.cellEvents then
                                                for eu, ev in pairs(self.cellEvents) do
                                                    eC:SetScript(
                                                        eu,
                                                        function(ew, ...)
                                                            if table.offset then
                                                                local eD = table.filtered[n + table.offset]
                                                                local eE = table:GetRow(eD)
                                                                table:FireCellEvent(eu, ev, ew, eA, eE, eB, eD, ...)
                                                            end
                                                        end
                                                    )
                                                end
                                            end
                                            if eB.events then
                                                for eu, ev in pairs(eB.events) do
                                                    eC:SetScript(
                                                        eu,
                                                        function(ew, ...)
                                                            if table.offset then
                                                                local eD = table.filtered[n + table.offset]
                                                                local eE = table:GetRow(eD)
                                                                table:FireCellEvent(eu, ev, ew, eA, eE, eB, eD, ...)
                                                            end
                                                        end
                                                    )
                                                end
                                            end
                                        end
                                        if ex > 1 then
                                            eC:SetPoint("LEFT", eA.columns[ex - 1], "RIGHT", 0, 0)
                                        else
                                            eC:SetPoint("LEFT", eA, "LEFT", 2, 0)
                                        end
                                        eC:SetHeight(ez)
                                        eC:SetWidth(self.columns[ex].width)
                                        eC.text:SetPoint("TOP", eC, "TOP", 0, 0)
                                        eC.text:SetPoint("BOTTOM", eC, "BOTTOM", 0, 0)
                                        eC.text:SetWidth(self.columns[ex].width - 2 * bm)
                                    end
                                    local ex = #self.columns + 1
                                    local b7 = eA.columns[ex]
                                    while b7 do
                                        b7:Hide()
                                        ex = ex + 1
                                        b7 = eA.columns[ex]
                                    end
                                end
                                for n = ey + 1, #self.rows do
                                    self.rows[n]:Hide()
                                end
                                self:SetAutoHeight()
                            end,
                            SetColumnWidth = function(self, eF, q)
                                self.columns[eF]:SetWidth(q)
                            end,
                            SortData = function(self, eG)
                                if not self.sortTable or #self.sortTable ~= #self.data then
                                    self.sortTable = {}
                                end
                                if #self.sortTable ~= #self.data then
                                    for n = 1, #self.data do
                                        self.sortTable[n] = n
                                    end
                                end
                                if not eG then
                                    local n = 1
                                    while n <= #self.columns and not eG do
                                        if self.columns[n].sort then
                                            eG = n
                                        end
                                        n = n + 1
                                    end
                                end
                                if eG then
                                    ah(
                                        self.sortTable,
                                        function(eH, eI)
                                            local es = self.columns[eG]
                                            if es.compareSort then
                                                return es.compareSort(self, eH, eI, eG)
                                            else
                                                return self:CompareSort(eH, eI, eG)
                                            end
                                        end
                                    )
                                end
                                self.filtered = self:DoFilter()
                                self:Refresh()
                                self:UpdateSortArrows(eG)
                            end,
                            CompareSort = function(self, eH, eI, eG)
                                local aF = self:GetRow(eH)
                                local aE = self:GetRow(eI)
                                local es = self.columns[eG]
                                local eJ = es.index
                                local G = es.sort or es.defaultSort or "asc"
                                if G:lower() == "asc" then
                                    return aF[eJ] > aE[eJ]
                                else
                                    return aF[eJ] < aE[eJ]
                                end
                            end,
                            Filter = function(self, eE)
                                return true
                            end,
                            SetFilter = function(self, eK, eL)
                                self.Filter = eK
                                if not eL then
                                    self:SortData()
                                end
                            end,
                            DoFilter = function(self)
                                local m = {}
                                for bf = 1, #self.data do
                                    local eM = self.sortTable[bf]
                                    local eE = self:GetRow(eM)
                                    if self:Filter(eE) then
                                        e(m, eM)
                                    end
                                end
                                return m
                            end,
                            SetHighLightColor = function(self, x, eN)
                                if not x.highlight then
                                    x.highlight = x:CreateTexture(nil, "OVERLAY")
                                    x.highlight:SetAllPoints(x)
                                end
                                if not eN then
                                    x.highlight:SetColorTexture(0, 0, 0, 0)
                                else
                                    x.highlight:SetColorTexture(eN.r, eN.g, eN.b, eN.a)
                                end
                            end,
                            ClearHighlightedRows = function(self)
                                self.highlightedRows = {}
                                self:Refresh()
                            end,
                            HighlightRows = function(self, eO)
                                self.highlightedRows = eO
                                self:Refresh()
                            end,
                            EnableSelection = function(self, cM)
                                self.selectionEnabled = cM
                            end,
                            ClearSelection = function(self)
                                self:SetSelection(nil)
                            end,
                            SetSelection = function(self, eD)
                                self.selected = eD
                                self:Refresh()
                            end,
                            GetSelection = function(self)
                                return self.selected
                            end,
                            GetSelectedItem = function(self)
                                return self:GetRow(self.selected)
                            end,
                            SetData = function(self, bl)
                                self.data = bl
                                self:SortData()
                            end,
                            GetRow = function(self, eD)
                                return self.data[eD]
                            end,
                            GetCell = function(self, bf, b7)
                                local eE = bf
                                if type(bf) == "number" then
                                    eE = self:GetRow(bf)
                                end
                                return eE[b7]
                            end,
                            IsRowVisible = function(self, eD)
                                return eD > self.offset and eD <= self.numberOfRows + self.offset
                            end,
                            DoCellUpdate = function(table, eP, eA, ew, ap, eB, eE, eD)
                                if eP then
                                    local format = eB.format
                                    if type(format) == "function" then
                                        ew.text:SetText(format(ap, eE, eB))
                                    elseif format == "money" then
                                        ap = table.stdUi.Util.formatMoney(ap)
                                        ew.text:SetText(ap)
                                    elseif format == "moneyShort" then
                                        ap = table.stdUi.Util.formatMoney(ap, true)
                                        ew.text:SetText(ap)
                                    elseif format == "number" then
                                        ap = tostring(ap)
                                        ew.text:SetText(ap)
                                    elseif format == "icon" then
                                        if ew.texture then
                                            ew.texture:SetTexture(ap)
                                        else
                                            local cQ = eB.iconSize or table.rowHeight
                                            ew.texture = table.stdUi:Texture(ew, cQ, cQ, ap)
                                            ew.texture:SetPoint("CENTER", 0, 0)
                                        end
                                    elseif format == "custom" then
                                        eB.renderer(ew, ap, eE, eB)
                                    else
                                        ew.text:SetText(ap)
                                    end
                                    local eN
                                    if eE.color then
                                        eN = eE.color
                                    elseif eB.color then
                                        eN = eB.color
                                    end
                                    if type(eN) == "function" then
                                        eN = eN(table, ap, eE, eB)
                                    end
                                    if eN then
                                        ew.text:SetTextColor(eN.r, eN.g, eN.b, eN.a)
                                    else
                                        table.stdUi:SetTextColor(ew.text, "normal")
                                    end
                                    if table.selectionEnabled then
                                        if table.selected == eD then
                                            table:SetHighLightColor(eA, table.stdUi.config.highlight.color)
                                        else
                                            table:SetHighLightColor(eA, nil)
                                        end
                                    else
                                        if tContains(table.highlightedRows, eD) then
                                            table:SetHighLightColor(eA, table.stdUi.config.highlight.color)
                                        else
                                            table:SetHighLightColor(eA, nil)
                                        end
                                    end
                                else
                                    ew.text:SetText("")
                                end
                            end,
                            Refresh = function(self)
                                self:Update(#self.filtered, self.numberOfRows, self.rowHeight)
                                local eQ = self:GetOffset()
                                self.offset = eQ
                                for n = 1, self.numberOfRows do
                                    local bf = n + eQ
                                    if self.rows then
                                        local eA = self.rows[n]
                                        local eD = self.filtered[bf]
                                        local eE = self:GetRow(eD)
                                        local eP = true
                                        for b7 = 1, #self.columns do
                                            local ew = eA.columns[b7]
                                            local eB = self.columns[b7]
                                            local eR = self.DoCellUpdate
                                            local ap
                                            if eE then
                                                ap = eE[eB.index]
                                                self.rows[n]:Show()
                                                if eE.doCellUpdate then
                                                    eR = eE.doCellUpdate
                                                elseif eB.doCellUpdate then
                                                    eR = eB.doCellUpdate
                                                end
                                            else
                                                self.rows[n]:Hide()
                                                eP = false
                                            end
                                            eR(self, eP, eA, ew, ap, eB, eE, eD)
                                        end
                                    end
                                end
                            end,
                            UpdateSortArrows = function(self, eG)
                                if not self.head then
                                    return
                                end
                                for n = 1, #self.columns do
                                    local b7 = self.head.columns[n]
                                    if b7 then
                                        if n == eG then
                                            local es = self.columns[eG]
                                            local G = es.sort or es.defaultSort or "asc"
                                            if G == "asc" then
                                                b7.arrow:SetTexCoord(0, 0.5625, 0, 1)
                                            else
                                                b7.arrow:SetTexCoord(0, 0.5625, 1, 0)
                                            end
                                            b7.arrow:Show()
                                        else
                                            b7.arrow:Hide()
                                        end
                                    end
                                end
                            end,
                            FireCellEvent = function(self, eu, ev, ...)
                                if not ev(self, ...) then
                                    if self.cellEvents[eu] then
                                        self.cellEvents[eu](self, ...)
                                    end
                                end
                            end,
                            FireHeaderEvent = function(self, eu, ev, ...)
                                if not ev(self, ...) then
                                    if self.headerEvents[eu] then
                                        self.headerEvents[eu](self, ...)
                                    end
                                end
                            end,
                            RegisterEvents = function(self, eS, eT, eU)
                                local table = self
                                if eS then
                                    for n, eA in ipairs(self.rows) do
                                        for ex, eC in ipairs(eA.columns) do
                                            local eB = self.columns[ex]
                                            if eU and self.cellEvents then
                                                for eu, ev in pairs(self.cellEvents) do
                                                    eC:SetScript(eu, nil)
                                                end
                                            end
                                            for eu, ev in pairs(eS) do
                                                eC:SetScript(
                                                    eu,
                                                    function(ew, ...)
                                                        local eD = table.filtered[n + table.offset]
                                                        local eE = table:GetRow(eD)
                                                        table:FireCellEvent(eu, ev, ew, eA, eE, eB, eD, ...)
                                                    end
                                                )
                                            end
                                            if eB.events then
                                                for eu, ev in pairs(self.columns[ex].events) do
                                                    eC:SetScript(
                                                        eu,
                                                        function(ew, ...)
                                                            if table.offset then
                                                                local eD = table.filtered[n + table.offset]
                                                                local eE = table:GetRow(eD)
                                                                table:FireCellEvent(eu, ev, ew, eA, eE, eB, eD, ...)
                                                            end
                                                        end
                                                    )
                                                end
                                            end
                                        end
                                    end
                                end
                                if eT then
                                    for eV, et in ipairs(self.head.columns) do
                                        if eU and self.headerEvents then
                                            for eu, N in pairs(self.headerEvents) do
                                                et:SetScript(eu, nil)
                                            end
                                        end
                                        for eu, ev in pairs(eT) do
                                            et:SetScript(
                                                eu,
                                                function(ew, ...)
                                                    table:FireHeaderEvent(eu, ev, et, self.head, eV, ...)
                                                end
                                            )
                                        end
                                    end
                                end
                            end
                        }
                        local eS = {OnEnter = function(table, ew, eA, eE, eB, eD)
                                table:SetHighLightColor(eA, table.stdUi.config.highlight.color)
                                return true
                            end, OnLeave = function(table, ew, eA, eE, eB, eD)
                                if eD ~= table.selected or not table.selectionEnabled then
                                    table:SetHighLightColor(eA, nil)
                                end
                                return true
                            end, OnClick = function(table, ew, eA, eE, eB, eD, J)
                                if J == "LeftButton" then
                                    if table:GetSelection() == eD then
                                        table:ClearSelection()
                                    else
                                        table:SetSelection(eD)
                                    end
                                    return true
                                end
                            end}
                        local eT = {OnClick = function(table, et, er, eV, J, ...)
                                if J == "LeftButton" then
                                    local eq = table.columns
                                    local es = eq[eV]
                                    for n, N in ipairs(er.columns) do
                                        if n ~= eV then
                                            eq[n].sort = nil
                                        end
                                    end
                                    local eW = "asc"
                                    if not es.sort and es.defaultSort then
                                        eW = es.defaultSort
                                    elseif es.sort and es.sort:lower() == "asc" then
                                        eW = "dsc"
                                    end
                                    es.sort = eW
                                    table:SortData()
                                    return true
                                end
                            end}
                        local eX = function(self)
                            self:Refresh()
                        end
                        local eY = function(self, cF)
                            local eZ = self.panel
                            eZ:DoVerticalScroll(cF, eZ.rowHeight, eX)
                        end
                        function d:ScrollTable(be, eq, e_, ez)
                            local eZ = self:FauxScrollFrame(be, 100, 100, ez or 15)
                            local cJ = eZ.scrollFrame
                            eZ.stdUi = self
                            eZ.numberOfRows = e_ or 12
                            eZ.rowHeight = ez or 15
                            eZ.columns = eq
                            eZ.data = {}
                            eZ.cellEvents = eS
                            eZ.headerEvents = eT
                            eZ.highlightedRows = {}
                            for f0, f1 in pairs(eo) do
                                eZ[f0] = f1
                            end
                            cJ:SetScript("OnVerticalScroll", eY)
                            eZ:SortData()
                            eZ:SetColumns(eZ.columns)
                            eZ:UpdateSortArrows()
                            eZ:RegisterEvents(eZ.cellEvents, eZ.headerEvents)
                            return eZ
                        end
                        d:RegisterModule(g, h)
                    end
                    local function f2(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Slider", 7
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        function d:SliderButton(be, q, r, G)
                            local J = self:Button(be, q, r)
                            local bQ = self:ArrowTexture(J, G)
                            bQ:SetPoint("CENTER")
                            local f3 = self:ArrowTexture(J, G)
                            f3:SetPoint("CENTER")
                            f3:SetDesaturated(0)
                            J:SetNormalTexture(bQ)
                            J:SetDisabledTexture(f3)
                            return J
                        end
                        function d:StyleScrollBar(dK)
                            local f4, f5 = dK:GetChildren()
                            dK.background = d:Panel(dK)
                            dK.background:SetFrameLevel(dK:GetFrameLevel() - 1)
                            dK.background:SetWidth(dK:GetWidth())
                            self:GlueAcross(dK.background, dK, 0, 1, 0, -1)
                            self:StripTextures(f4)
                            self:StripTextures(f5)
                            self:ApplyBackdrop(f4, "button")
                            self:ApplyBackdrop(f5, "button")
                            f4:SetWidth(dK:GetWidth())
                            f5:SetWidth(dK:GetWidth())
                            local f6 = self:ArrowTexture(f4, "UP")
                            f6:SetPoint("CENTER")
                            local f7 = self:ArrowTexture(f4, "UP")
                            f7:SetPoint("CENTER")
                            f7:SetDesaturated(0)
                            f4:SetNormalTexture(f6)
                            f4:SetDisabledTexture(f7)
                            local f8 = self:ArrowTexture(f5, "DOWN")
                            f8:SetPoint("CENTER")
                            local f9 = self:ArrowTexture(f5, "DOWN")
                            f9:SetPoint("CENTER")
                            f9:SetDesaturated(0)
                            f5:SetNormalTexture(f8)
                            f5:SetDisabledTexture(f9)
                            local fa = dK:GetWidth()
                            dK:GetThumbTexture():SetWidth(fa)
                            self:StripTextures(dK)
                            dK.thumb = self:Panel(dK)
                            dK.thumb:SetAllPoints(dK:GetThumbTexture())
                            self:ApplyBackdrop(dK.thumb, "button")
                        end
                        local fb = {SetPrecision = function(self, fc)
                                self.precision = fc
                            end, GetPrecision = function(self)
                                return self.precision
                            end, GetValue = function(self)
                                local fd, fe = self:GetMinMaxValues()
                                return Clamp(d.Util.roundPrecision(self:OriginalGetValue(), self.precision), fd, fe)
                            end}
                        local ff = {OnValueChanged = function(self, ap, ...)
                                if self.lock then
                                    return
                                end
                                self.lock = true
                                ap = self:GetValue()
                                if self.OnValueChanged then
                                    self:OnValueChanged(ap, ...)
                                end
                                self.lock = false
                            end}
                        function d:Slider(be, q, r, ap, fg, cv, cw)
                            local fh = CreateFrame("Slider", nil, be)
                            self:InitWidget(fh)
                            self:ApplyBackdrop(fh, "panel")
                            self:SetObjSize(fh, q, r)
                            fh.vertical = fg
                            fh.precision = 1
                            local fi = fg and q or 20
                            local fj = fg and 20 or r
                            fh.ThumbTexture = self:Texture(fh, fi, fj, self.config.backdrop.texture)
                            fh.ThumbTexture:SetVertexColor(
                                self.config.backdrop.slider.r,
                                self.config.backdrop.slider.g,
                                self.config.backdrop.slider.b,
                                self.config.backdrop.slider.a
                            )
                            fh:SetThumbTexture(fh.ThumbTexture)
                            fh.thumb = self:Frame(fh)
                            fh.thumb:SetAllPoints(fh:GetThumbTexture())
                            self:ApplyBackdrop(fh.thumb, "button")
                            if fg then
                                fh:SetOrientation("VERTICAL")
                                fh.ThumbTexture:SetPoint("LEFT")
                                fh.ThumbTexture:SetPoint("RIGHT")
                            else
                                fh:SetOrientation("HORIZONTAL")
                                fh.ThumbTexture:SetPoint("TOP")
                                fh.ThumbTexture:SetPoint("BOTTOM")
                            end
                            fh.OriginalGetValue = fh.GetValue
                            for aL, aM in pairs(fb) do
                                fh[aL] = aM
                            end
                            fh:SetMinMaxValues(cv or 0, cw or 100)
                            fh:SetValue(ap or cv or 0)
                            for aL, aM in pairs(ff) do
                                fh:HookScript(aL, aM)
                            end
                            return fh
                        end
                        local fk = {SetValue = function(self, aM)
                                self.lock = true
                                self.slider:SetValue(aM)
                                aM = self.slider:GetValue()
                                self.editBox:SetValue(aM)
                                self.value = aM
                                self.lock = false
                                if self.OnValueChanged then
                                    self.OnValueChanged(self, aM)
                                end
                            end, GetValue = function(self)
                                return self.value
                            end, SetValueStep = function(self, fl)
                                self.slider:SetValueStep(fl)
                            end, SetPrecision = function(self, fc)
                                self.slider.precision = fc
                            end, GetPrecision = function(self)
                                return self.slider.precision
                            end, SetMinMaxValues = function(self, cv, cw)
                                self.min = cv
                                self.max = cw
                                self.editBox:SetMinMaxValue(cv, cw)
                                self.slider:SetMinMaxValues(cv, cw)
                                self.leftLabel:SetText(cv)
                                self.rightLabel:SetText(cw)
                            end}
                        local fm = function(self, fn)
                            if self.widget.lock then
                                return
                            end
                            self.widget:SetValue(fn)
                        end
                        function d:SliderWithBox(be, q, r, ap, cv, cw)
                            local k = CreateFrame("Frame", nil, be)
                            self:SetObjSize(k, q, r)
                            k.slider = self:Slider(k, 100, 12, ap, false)
                            k.editBox = self:NumericBox(k, 80, 16, ap)
                            k.value = ap
                            k.editBox:SetNumeric(false)
                            k.leftLabel = self:Label(k, "")
                            k.rightLabel = self:Label(k, "")
                            k.slider.widget = k
                            k.editBox.widget = k
                            for aL, aM in pairs(fk) do
                                k[aL] = aM
                            end
                            if cv and cw then
                                k:SetMinMaxValues(cv, cw)
                            end
                            k.slider.OnValueChanged = fm
                            k.editBox.OnValueChanged = fm
                            k.slider:SetPoint("TOPLEFT", k, "TOPLEFT", 0, 0)
                            k.slider:SetPoint("TOPRIGHT", k, "TOPRIGHT", 0, 0)
                            self:GlueBelow(k.editBox, k.slider, 0, -5, "CENTER")
                            k.leftLabel:SetPoint("TOPLEFT", k.slider, "BOTTOMLEFT", 0, 0)
                            k.rightLabel:SetPoint("TOPRIGHT", k.slider, "BOTTOMRIGHT", 0, 0)
                            return k
                        end
                        function d:ScrollBar(be, q, r, fo)
                            local dn = self:Panel(be, q, r)
                            local dK = self:Slider(be, q, r, 0, not fo)
                            dK.ScrollDownButton = self:SliderButton(be, q, 16, "DOWN")
                            dK.ScrollUpButton = self:SliderButton(be, q, 16, "UP")
                            dK.panel = dn
                            dK.ScrollUpButton.scrollBar = dK
                            dK.ScrollDownButton.scrollBar = dK
                            if fo then
                            else
                                dK.ScrollUpButton:SetPoint("TOPLEFT", dn, "TOPLEFT", 0, 0)
                                dK.ScrollUpButton:SetPoint("TOPRIGHT", dn, "TOPRIGHT", 0, 0)
                                dK.ScrollDownButton:SetPoint("BOTTOMLEFT", dn, "BOTTOMLEFT", 0, 0)
                                dK.ScrollDownButton:SetPoint("BOTTOMRIGHT", dn, "BOTTOMRIGHT", 0, 0)
                                dK:SetPoint("TOPLEFT", dK.ScrollUpButton, "BOTTOMLEFT", 0, 1)
                                dK:SetPoint("TOPRIGHT", dK.ScrollUpButton, "BOTTOMRIGHT", 0, 1)
                                dK:SetPoint("BOTTOMLEFT", dK.ScrollDownButton, "TOPLEFT", 0, -1)
                                dK:SetPoint("BOTTOMRIGHT", dK.ScrollDownButton, "TOPRIGHT", 0, -1)
                            end
                            return dK, dn
                        end
                        d:RegisterModule(g, h)
                    end
                    local function fp(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Tooltip", 3
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        d.tooltips = {}
                        d.frameTooltips = {}
                        local fq = {
                            OnEnter = function(self)
                                local fr = self.stdUiTooltip
                                fr:SetOwner(fr.owner or UIParent, fr.anchor or "ANCHOR_NONE")
                                if type(fr.text) == "string" then
                                    fr:SetText(
                                        fr.text,
                                        fr.stdUi.config.font.color.r,
                                        fr.stdUi.config.font.color.g,
                                        fr.stdUi.config.font.color.b,
                                        fr.stdUi.config.font.color.a
                                    )
                                elseif type(fr.text) == "function" then
                                    fr.text(fr)
                                end
                                fr:Show()
                                fr:ClearAllPoints()
                                fr.stdUi:GlueOpposite(fr, fr.owner, 0, 0, fr.anchor)
                            end,
                            OnLeave = function(self)
                                local fr = self.stdUiTooltip
                                fr:Hide()
                            end
                        }
                        function d:Tooltip(fs, aj, ft, I, fu)
                            local fr
                            if ft and self.tooltips[ft] then
                                fr = self.tooltips[ft]
                            else
                                fr = CreateFrame("GameTooltip", ft, UIParent, "GameTooltipTemplate")
                                self:ApplyBackdrop(fr, "panel")
                            end
                            fr.owner = fs
                            fr.anchor = I
                            fr.text = aj
                            fr.stdUi = self
                            fs.stdUiTooltip = fr
                            if fu then
                                for aL, aM in pairs(fq) do
                                    fs:HookScript(aL, aM)
                                end
                            end
                            return fr
                        end
                        local fv = {SetText = function(self, aj, aC, aD, aE)
                                if aC and aD and aE then
                                    aj = self.stdUi.Util.WrapTextInColor(aj, aC, aD, aE, 1)
                                end
                                self.text:SetText(aj)
                                self:RecalculateSize()
                            end, GetText = function(self)
                                return self.text:GetText()
                            end, AddLine = function(self, aj, aC, aD, aE)
                                local fw = self:GetText()
                                if not fw then
                                    fw = ""
                                else
                                    fw = fw .. "\n"
                                end
                                if aC and aD and aE then
                                    aj = self.stdUi.Util.WrapTextInColor(aj, aC, aD, aE, 1)
                                end
                                self:SetText(fw .. aj)
                            end, RecalculateSize = function(self)
                                self:SetSize(self.text:GetWidth() + self.padding * 2, self.text:GetHeight() + self.padding * 2)
                            end}
                        local fx = function(self)
                            self:RecalculateSize()
                            self:ClearAllPoints()
                            self.stdUi:GlueOpposite(self, self.owner, 0, 0, self.anchor)
                        end
                        local fy = {OnEnter = function(self)
                                self.stdUiTooltip:Show()
                            end, OnLeave = function(self)
                                self.stdUiTooltip:Hide()
                            end}
                        function d:FrameTooltip(fs, aj, ft, I, fu, fz)
                            local fr
                            if ft and self.frameTooltips[ft] then
                                fr = self.frameTooltips[ft]
                            else
                                fr = self:Panel(fs, 10, 10)
                                fr.stdUi = self
                                fr:SetFrameStrata("TOOLTIP")
                                self:ApplyBackdrop(fr, "panel")
                                fr.padding = self.config.tooltip.padding
                                fr.text = self:FontString(fr, "")
                                self:GlueTop(fr.text, fr, fr.padding, -fr.padding, "LEFT")
                                for aL, aM in pairs(fv) do
                                    fr[aL] = aM
                                end
                                if not fz then
                                    hooksecurefunc(fr, "Show", fx)
                                end
                            end
                            fr.owner = fs
                            fr.anchor = I
                            fs.stdUiTooltip = fr
                            if type(aj) == "string" then
                                fr:SetText(aj)
                            elseif type(aj) == "function" then
                                aj(fr)
                            end
                            if fu then
                                for aL, aM in pairs(fy) do
                                    fs:HookScript(aL, aM)
                                end
                            end
                            return fr
                        end
                        d:RegisterModule(g, h)
                    end
                    local function fA(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Table", 2
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local e = tinsert
                        local fB = strlen
                        local fC = {SetColumns = function(self, eq)
                                self.columns = eq
                            end, SetData = function(self, bl)
                                self.tableData = bl
                            end, AddRow = function(self, bf)
                                if not self.tableData then
                                    self.tableData = {}
                                end
                                e(self.tableData, bf)
                            end, DrawHeaders = function(self)
                                if not self.headers then
                                    self.headers = {}
                                end
                                local fD = 0
                                for n = 1, #self.columns do
                                    local b7 = self.columns[n]
                                    if b7.header and fB(b7.header) > 0 then
                                        if not self.headers[n] then
                                            self.headers[n] = {text = self.stdUi:FontString(self, "")}
                                        end
                                        local es = self.headers[n]
                                        es.text:SetText(b7.header)
                                        es.text:SetWidth(b7.width)
                                        es.text:SetHeight(self.rowHeight)
                                        es.text:ClearAllPoints()
                                        if b7.align then
                                            es.text:SetJustifyH(b7.align)
                                        end
                                        self.stdUi:GlueTop(es.text, self, fD, 0, "LEFT")
                                        fD = fD + b7.width
                                        es.index = b7.index
                                        es.width = b7.width
                                    end
                                end
                            end, DrawData = function(self)
                                if not self.rows then
                                    self.rows = {}
                                end
                                local fE = -self.rowHeight
                                for a4 = 1, #self.tableData do
                                    local bf = self.tableData[a4]
                                    local fD = 0
                                    for a3 = 1, #self.columns do
                                        local b7 = self.columns[a3]
                                        if not self.rows[a4] then
                                            self.rows[a4] = {}
                                        end
                                        if not self.rows[a4][a3] then
                                            self.rows[a4][a3] = {text = self.stdUi:FontString(self, "")}
                                        end
                                        local eC = self.rows[a4][a3]
                                        eC.text:SetText(bf[b7.index])
                                        eC.text:SetWidth(b7.width)
                                        eC.text:SetHeight(self.rowHeight)
                                        eC.text:ClearAllPoints()
                                        if b7.align then
                                            eC.text:SetJustifyH(b7.align)
                                        end
                                        self.stdUi:GlueTop(eC.text, self, fD, fE, "LEFT")
                                        fD = fD + b7.width
                                    end
                                    fE = fE - self.rowHeight
                                end
                            end, DrawTable = function(self)
                                self:DrawHeaders()
                                self:DrawData()
                            end}
                        function d:Table(be, q, r, ez, eq, bl)
                            local dn = self:Panel(be, q, r)
                            dn.stdUi = self
                            dn.rowHeight = ez
                            for aL, aM in pairs(fC) do
                                dn[aL] = aM
                            end
                            dn:SetColumns(eq)
                            dn:SetData(bl)
                            dn:DrawTable()
                            return dn
                        end
                        d:RegisterModule(g, h)
                    end
                    local function fF(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "ProgressBar", 3
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local fG = {GetPercentageValue = function(self)
                                local N, cw = self:GetMinMaxValues()
                                local ap = self:GetValue()
                                return ap / cw * 100
                            end, TextUpdate = function(self)
                                return Round(self:GetPercentageValue()) .. "%"
                            end}
                        local fH = {OnValueChanged = function(self, ap)
                                local cv, cw = self:GetMinMaxValues()
                                self.text:SetText(self:TextUpdate(cv, cw, ap))
                            end, OnMinMaxChanged = function(self)
                                local cv, cw = self:GetMinMaxValues()
                                local ap = self:GetValue()
                                self.text:SetText(self:TextUpdate(cv, cw, ap))
                            end}
                        function d:ProgressBar(be, q, r, fg)
                            fg = fg or false
                            local fI = CreateFrame("StatusBar", nil, be)
                            fI:SetStatusBarTexture(self.config.backdrop.texture)
                            fI:SetStatusBarColor(
                                self.config.progressBar.color.r,
                                self.config.progressBar.color.g,
                                self.config.progressBar.color.b,
                                self.config.progressBar.color.a
                            )
                            self:SetObjSize(fI, q, r)
                            fI.texture = fI:GetRegions()
                            fI.texture:SetDrawLayer("BORDER", -1)
                            if fg then
                                fI:SetOrientation("VERTICAL")
                            end
                            fI.text = self:Label(fI, "")
                            fI.text:SetJustifyH("MIDDLE")
                            fI.text:SetAllPoints()
                            self:ApplyBackdrop(fI)
                            for aL, aM in pairs(fG) do
                                fI[aL] = aM
                            end
                            for aL, aM in pairs(fH) do
                                fI:SetScript(aL, aM)
                            end
                            return fI
                        end
                        d:RegisterModule(g, h)
                    end
                    local function fJ(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "ColorPicker", 6
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local fK = {SetColorRGBA = function(self, aC, aD, aE, aF)
                                self:SetColorAlpha(aF)
                                self:SetColorRGB(aC, aD, aE)
                                self.newTexture:SetVertexColor(aC, aD, aE, aF)
                            end, GetColorRGBA = function(self)
                                local aC, aD, aE = self:GetColorRGB()
                                return aC, aD, aE, self:GetColorAlpha()
                            end, SetColor = function(self, u)
                                self:SetColorAlpha(u.a or 1)
                                self:SetColorRGB(u.r, u.g, u.b)
                                self.newTexture:SetVertexColor(u.r, u.g, u.b, u.a or 1)
                            end, GetColor = function(self)
                                local aC, aD, aE = self:GetColorRGB()
                                return {r = aC, g = aD, b = aE, a = self:GetColorAlpha()}
                            end, SetColorAlpha = function(self, aF, fL)
                                aF = Clamp(aF, 0, 1)
                                if not fL then
                                    self.alphaSlider:SetValue(100 - aF * 100)
                                end
                                self.aEdit:SetValue(Round(aF * 100))
                                self.aEdit:Validate()
                                self:SetColorRGB(self:GetColorRGB())
                            end, GetColorAlpha = function(self)
                                local aF = Clamp(tonumber(self.aEdit:GetValue()) or 100, 0, 100)
                                return aF / 100
                            end}
                        local fM = {OnColorSelect = function(self)
                                local aC, aD, aE, aF = self:GetColorRGBA()
                                if not self.skipTextUpdate then
                                    self.rEdit:SetValue(aC * 255)
                                    self.gEdit:SetValue(aD * 255)
                                    self.bEdit:SetValue(aE * 255)
                                    self.aEdit:SetValue(100 * aF)
                                    self.rEdit:Validate()
                                    self.gEdit:Validate()
                                    self.bEdit:Validate()
                                    self.aEdit:Validate()
                                end
                                self.newTexture:SetVertexColor(aC, aD, aE, aF)
                                self.alphaTexture:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, aC, aD, aE, 1)
                            end}
                        local function fN(self)
                            local fO = self:GetParent()
                            local aC = tonumber(fO.rEdit:GetValue() or 255) / 255
                            local aD = tonumber(fO.gEdit:GetValue() or 255) / 255
                            local aE = tonumber(fO.bEdit:GetValue() or 255) / 255
                            local aF = tonumber(fO.aEdit:GetValue() or 100) / 100
                            fO.skipTextUpdate = true
                            fO:SetColorRGB(aC, aD, aE)
                            fO.alphaSlider:SetValue(100 - aF * 100)
                            fO.skipTextUpdate = false
                        end
                        function d:ColorPicker(be, fP)
                            local fQ = 128
                            local fi = 10
                            local fR = 16
                            local fO = CreateFrame("ColorSelect", nil, be)
                            fO:SetPoint("CENTER")
                            self:ApplyBackdrop(fO, "panel")
                            self:SetObjSize(fO, 340, 200)
                            fO.wheelTexture = self:Texture(fO, fQ, fQ)
                            self:GlueTop(fO.wheelTexture, fO, 10, -10, "LEFT")
                            fO.wheelThumbTexture = self:Texture(fO, fi, fi, "Interface\\Buttons\\UI-ColorPicker-Buttons")
                            fO.wheelThumbTexture:SetTexCoord(0, 0.15625, 0, 0.625)
                            fO.valueTexture = self:Texture(fO, fR, fQ)
                            self:GlueRight(fO.valueTexture, fO.wheelTexture, 10, 0)
                            fO.valueThumbTexture = self:Texture(fO, fR, fi, "Interface\\Buttons\\UI-ColorPicker-Buttons")
                            fO.valueThumbTexture:SetTexCoord(0.25, 1, 0.875, 0)
                            fO:SetColorWheelTexture(fO.wheelTexture)
                            fO:SetColorWheelThumbTexture(fO.wheelThumbTexture)
                            fO:SetColorValueTexture(fO.valueTexture)
                            fO:SetColorValueThumbTexture(fO.valueThumbTexture)
                            fO.alphaSlider = CreateFrame("Slider", nil, fO)
                            fO.alphaSlider:SetOrientation("VERTICAL")
                            fO.alphaSlider:SetMinMaxValues(0, 100)
                            fO.alphaSlider:SetValue(0)
                            self:SetObjSize(fO.alphaSlider, fR, fQ + fi)
                            self:GlueRight(fO.alphaSlider, fO.valueTexture, 10, 0)
                            fO.alphaTexture = self:Texture(fO.alphaSlider, nil, nil, fP)
                            self:GlueAcross(fO.alphaTexture, fO.alphaSlider, 0, -fi / 2, 0, fi / 2)
                            fO.alphaThumbTexture = self:Texture(fO.alphaSlider, fR, fi, "Interface\\Buttons\\UI-ColorPicker-Buttons")
                            fO.alphaThumbTexture:SetTexCoord(0.275, 1, 0.875, 0)
                            fO.alphaThumbTexture:SetDrawLayer("ARTWORK", 2)
                            fO.alphaSlider:SetThumbTexture(fO.alphaThumbTexture)
                            fO.newTexture = self:Texture(fO, 32, 32, "Interface\\Buttons\\WHITE8X8")
                            fO.oldTexture = self:Texture(fO, 32, 32, "Interface\\Buttons\\WHITE8X8")
                            fO.newTexture:SetDrawLayer("ARTWORK", 5)
                            fO.oldTexture:SetDrawLayer("ARTWORK", 4)
                            self:GlueTop(fO.newTexture, fO, -30, -30, "RIGHT")
                            self:GlueBelow(fO.oldTexture, fO.newTexture, 20, 45)
                            fO.rEdit = self:NumericBox(fO, 60, 20)
                            fO.gEdit = self:NumericBox(fO, 60, 20)
                            fO.bEdit = self:NumericBox(fO, 60, 20)
                            fO.aEdit = self:NumericBox(fO, 60, 20)
                            fO.rEdit:SetMinMaxValue(0, 255)
                            fO.gEdit:SetMinMaxValue(0, 255)
                            fO.bEdit:SetMinMaxValue(0, 255)
                            fO.aEdit:SetMinMaxValue(0, 100)
                            self:AddLabel(fO, fO.rEdit, "R", "LEFT")
                            self:AddLabel(fO, fO.gEdit, "G", "LEFT")
                            self:AddLabel(fO, fO.bEdit, "B", "LEFT")
                            self:AddLabel(fO, fO.aEdit, "A", "LEFT")
                            self:GlueAfter(fO.rEdit, fO.alphaSlider, 20, -fi / 2)
                            self:GlueBelow(fO.gEdit, fO.rEdit, 0, -10)
                            self:GlueBelow(fO.bEdit, fO.gEdit, 0, -10)
                            self:GlueBelow(fO.aEdit, fO.bEdit, 0, -10)
                            fO.okButton = d:Button(fO, 100, 20, OKAY)
                            fO.cancelButton = d:Button(fO, 100, 20, CANCEL)
                            self:GlueBottom(fO.okButton, fO, 40, 20, "LEFT")
                            self:GlueBottom(fO.cancelButton, fO, -40, 20, "RIGHT")
                            for aL, aM in pairs(fK) do
                                fO[aL] = aM
                            end
                            fO.alphaSlider:SetScript(
                                "OnValueChanged",
                                function(fh)
                                    fO:SetColorAlpha((100 - fh:GetValue()) / 100, true)
                                end
                            )
                            for aL, aM in pairs(fM) do
                                fO:SetScript(aL, aM)
                            end
                            fO.rEdit.OnValueChanged = fN
                            fO.gEdit.OnValueChanged = fN
                            fO.bEdit.OnValueChanged = fN
                            fO.aEdit.OnValueChanged = fN
                            return fO
                        end
                        local fS = function(self)
                            local fO = self:GetParent()
                            if fO.okCallback then
                                fO.okCallback(fO)
                            end
                            fO:Hide()
                        end
                        local fT = function(self)
                            local fO = self:GetParent()
                            if fO.cancelCallback then
                                fO.cancelCallback(fO)
                            end
                            fO:Hide()
                        end
                        function d:ColorPickerFrame(aC, aD, aE, aF, fU, fV, fP)
                            local fW = self.colorPickerFrame
                            if not fW then
                                fW = self:ColorPicker(UIParent, fP)
                                fW:SetFrameStrata("FULLSCREEN_DIALOG")
                                self.colorPickerFrame = fW
                            end
                            fW.okCallback = fU
                            fW.cancelCallback = fV
                            fW.okButton:SetScript("OnClick", fS)
                            fW.cancelButton:SetScript("OnClick", fT)
                            fW:SetColorRGBA(aC or 1, aD or 1, aE or 1, aF or 1)
                            fW.oldTexture:SetVertexColor(aC or 1, aD or 1, aE or 1, aF or 1)
                            fW:ClearAllPoints()
                            fW:SetPoint("CENTER")
                            fW:Show()
                        end
                        local fX = {SetColor = function(self, u)
                                if type(u) == "table" then
                                    self.color.r = u.r
                                    self.color.g = u.g
                                    self.color.b = u.b
                                    self.color.a = u.a or 1
                                end
                                self.target:SetBackdropColor(u.r, u.g, u.b, u.a or 1)
                                if self.OnValueChanged then
                                    self:OnValueChanged(u)
                                end
                            end, GetColor = function(self, type)
                                if type == "hex" then
                                elseif type == "rgba" then
                                    return self.color.r, self.color.g, self.color.b, self.color.a
                                else
                                    return self.color
                                end
                            end}
                        local fY = {
                            OnClick = function(self)
                                self.stdUi:ColorPickerFrame(
                                    self.color.r,
                                    self.color.g,
                                    self.color.b,
                                    self.color.a,
                                    function(fO)
                                        self:SetColor(fO:GetColor())
                                    end
                                )
                            end
                        }
                        function d:ColorInput(be, cd, q, r, eN)
                            local J = CreateFrame("Button", nil, be)
                            J.stdUi = self
                            J:EnableMouse(true)
                            self:SetObjSize(J, q, r or 20)
                            self:InitWidget(J)
                            J.target = self:Panel(J, 16, 16)
                            J.target.stdUi = self
                            J.target:SetPoint("LEFT", 0, 0)
                            J.text = self:Label(J, cd)
                            J.text:SetPoint("LEFT", J.target, "RIGHT", 5, 0)
                            J.text:SetPoint("RIGHT", J, "RIGHT", -5, 0)
                            J.color = {r = 1, g = 1, b = 1, a = 1}
                            if not J.SetBackdrop then
                                Mixin(J, BackdropTemplateMixin)
                            end
                            self:HookDisabledBackdrop(J)
                            self:HookHoverBorder(J)
                            for aL, aM in pairs(fX) do
                                J[aL] = aM
                            end
                            for aL, aM in pairs(fY) do
                                J:SetScript(aL, aM)
                            end
                            if eN then
                                J:SetColor(eN)
                            end
                            return J
                        end
                        d:RegisterModule(g, h)
                    end
                    local function fZ(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Tab", 4
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local f_ = {
                            EnumerateTabs = function(self, cX, ...)
                                local m
                                for n = 1, #self.tabs do
                                    local aH = self.tabs[n]
                                    m = cX(aH, self, n, ...)
                                    if m then
                                        break
                                    end
                                end
                                return m
                            end,
                            HideAllFrames = function(self)
                                for N, aH in pairs(self.tabs) do
                                    if aH.frame then
                                        aH.frame:Hide()
                                    end
                                end
                            end,
                            DrawButtons = function(self)
                                local g0
                                for N, aH in pairs(self.tabs) do
                                    if aH.button then
                                        aH.button:Hide()
                                    end
                                    local c5 = aH.button
                                    local g1 = self.buttonContainer
                                    if not c5 then
                                        c5 = self.stdUi:Button(g1, nil, self.buttonHeight)
                                        aH.button = c5
                                        c5.tabFrame = self
                                        c5:SetScript(
                                            "OnClick",
                                            function(g2)
                                                g2.tabFrame:SelectTab(g2.tab.name)
                                            end
                                        )
                                    end
                                    c5.tab = aH
                                    c5:SetText(aH.title)
                                    c5:ClearAllPoints()
                                    if self.vertical then
                                        c5:SetWidth(self.buttonWidth)
                                    else
                                        self.stdUi:ButtonAutoWidth(c5)
                                    end
                                    if self.vertical then
                                        if not g0 then
                                            self.stdUi:GlueTop(c5, g1, 0, 0, "CENTER")
                                        else
                                            self.stdUi:GlueBelow(c5, g0, 0, -1)
                                        end
                                    else
                                        if not g0 then
                                            self.stdUi:GlueTop(c5, g1, 0, 0, "LEFT")
                                        else
                                            self.stdUi:GlueRight(c5, g0, 5, 0)
                                        end
                                    end
                                    c5:Show()
                                    g0 = c5
                                end
                            end,
                            DrawFrames = function(self)
                                for N, aH in pairs(self.tabs) do
                                    if not aH.frame then
                                        aH.frame = self.stdUi:Frame(self.container)
                                    end
                                    aH.frame:ClearAllPoints()
                                    aH.frame:SetAllPoints()
                                    if aH.layout then
                                        self.stdUi:BuildWindow(aH.frame, aH.layout)
                                        self.stdUi:EasyLayout(aH.frame, {padding = {top = 10}})
                                        aH.frame:SetScript(
                                            "OnShow",
                                            function(bM)
                                                bM:DoLayout()
                                            end
                                        )
                                    end
                                    if aH.onHide then
                                        aH.frame:SetScript("OnHide", aH.onHide)
                                    end
                                end
                            end,
                            Update = function(self, g3)
                                if g3 then
                                    self.tabs = g3
                                end
                                self:DrawButtons()
                                self:DrawFrames()
                            end,
                            GetTabByName = function(self, i)
                                for N, aH in pairs(self.tabs) do
                                    if aH.name == i then
                                        return aH
                                    end
                                end
                            end,
                            SelectTab = function(self, i)
                                self.selected = i
                                if self.selectedTab then
                                    self.selectedTab.button:Enable()
                                end
                                self:HideAllFrames()
                                local g4 = self:GetTabByName(i)
                                if g4.name == i and g4.frame then
                                    g4.button:Disable()
                                    g4.frame:Show()
                                    self.selectedTab = g4
                                    return true
                                end
                            end,
                            GetSelectedTab = function(self)
                                return self.selectedTab
                            end,
                            DoLayout = function(self)
                                local aH = self:GetSelectedTab()
                                if aH then
                                    if aH.frame and aH.frame.DoLayout then
                                        aH.frame:DoLayout()
                                    end
                                end
                            end
                        }
                        function d:TabPanel(be, q, r, g5, fg, g6, dY)
                            fg = fg or false
                            g6 = g6 or 160
                            dY = dY or 20
                            local g7 = self:Frame(be, q, r)
                            g7.stdUi = self
                            g7.tabs = g5
                            g7.vertical = fg
                            g7.buttonWidth = g6
                            g7.buttonHeight = dY
                            g7.buttonContainer = self:Frame(g7)
                            g7.container = self:Panel(g7)
                            if fg then
                                g7.buttonContainer:SetPoint("TOPLEFT", g7, "TOPLEFT", 0, 0)
                                g7.buttonContainer:SetPoint("BOTTOMLEFT", g7, "BOTTOMLEFT", 0, 0)
                                g7.buttonContainer:SetWidth(g6)
                                g7.container:SetPoint("TOPLEFT", g7.buttonContainer, "TOPRIGHT", 5, 0)
                                g7.container:SetPoint("BOTTOMLEFT", g7.buttonContainer, "BOTTOMRIGHT", 5, 0)
                                g7.container:SetPoint("TOPRIGHT", g7, "TOPRIGHT", 0, 0)
                                g7.container:SetPoint("BOTTOMRIGHT", g7, "BOTTOMRIGHT", 0, 0)
                            else
                                g7.buttonContainer:SetPoint("TOPLEFT", g7, "TOPLEFT", 0, 0)
                                g7.buttonContainer:SetPoint("TOPRIGHT", g7, "TOPRIGHT", 0, 0)
                                g7.buttonContainer:SetHeight(dY)
                                g7.container:SetPoint("TOPLEFT", g7.buttonContainer, "BOTTOMLEFT", 0, -5)
                                g7.container:SetPoint("TOPRIGHT", g7.buttonContainer, "BOTTOMRIGHT", 0, -5)
                                g7.container:SetPoint("BOTTOMLEFT", g7, "BOTTOMLEFT", 0, 0)
                                g7.container:SetPoint("BOTTOMRIGHT", g7, "BOTTOMRIGHT", 0, 0)
                            end
                            for aL, aM in pairs(f_) do
                                g7[aL] = aM
                            end
                            g7:Update()
                            if #g7.tabs > 0 then
                                g7:SelectTab(g7.tabs[1].name)
                            end
                            return g7
                        end
                        d:RegisterModule(g, h)
                    end
                    local function g8(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "Spell", 2
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local g9 = {OnEnter = function(self)
                                if self.editBox.value then
                                    GameTooltip:SetOwner(self.editBox)
                                    GameTooltip:SetSpellByID(self.editBox.value)
                                    GameTooltip:Show()
                                end
                            end, OnLeave = function(self)
                                if self.editBox.value then
                                    GameTooltip:Hide()
                                end
                            end}
                        function d:SpellBox(be, q, r, cQ, ga)
                            cQ = cQ or 16
                            local ck = self:EditBox(be, q, r, "", ga or self.Util.spellValidator)
                            ck:SetTextInsets(cQ + 7, 3, 3, 3)
                            local gb = self:Panel(ck, cQ, cQ)
                            self:GlueLeft(gb, ck, 2, 0, true)
                            local aq = self:Texture(gb, cQ, cQ, 134400)
                            aq:SetAllPoints()
                            ck.icon = aq
                            gb.editBox = ck
                            for aL, aM in pairs(g9) do
                                gb:SetScript(aL, aM)
                            end
                            return ck
                        end
                        local gc = {SetSpell = function(self, gd)
                                local i, N, n, N, N, N, ar = GetSpellInfo(gd)
                                self.spellId = ar
                                self.spellName = i
                                self.icon:SetTexture(n)
                                self.text:SetText(i)
                            end}
                        local ge = {OnEnter = function(self)
                                GameTooltip:SetOwner(self.widget)
                                GameTooltip:SetSpellByID(self.widget.spellId)
                                GameTooltip:Show()
                            end, OnLeave = function()
                                GameTooltip:Hide()
                            end}
                        function d:SpellInfo(be, q, r, cQ)
                            cQ = cQ or 16
                            local x = self:Panel(be, q, r)
                            local gb = self:Panel(x, cQ, cQ)
                            self:GlueLeft(gb, x, 2, 0, true)
                            local aq = self:Texture(gb, cQ, cQ)
                            aq:SetAllPoints()
                            local c5 = self:SquareButton(x, cQ, cQ, "DELETE")
                            d:GlueRight(c5, x, -3, 0, true)
                            local aj = self:Label(x)
                            aj:SetPoint("LEFT", aq, "RIGHT", 3, 0)
                            aj:SetPoint("RIGHT", c5, "RIGHT", -3, 0)
                            x.removeBtn = c5
                            x.icon = aq
                            x.text = aj
                            c5.parent = x
                            gb.widget = x
                            for aL, aM in pairs(gc) do
                                x[aL] = aM
                            end
                            for aL, aM in pairs(ge) do
                                gb:SetScript(aL, aM)
                            end
                            return x
                        end
                        local gf = {SetSpell = function(self, gd)
                                local i, N, n, N, N, N, ar = GetSpellInfo(gd)
                                self.spellId = ar
                                self.spellName = i
                                self.icon:SetTexture(n)
                                self.text:SetText(i)
                            end}
                        local gg = {OnEnter = function(self)
                                if self.spellId then
                                    GameTooltip:SetOwner(self)
                                    GameTooltip:SetSpellByID(self.spellId)
                                    GameTooltip:Show()
                                end
                            end, OnLeave = function(self)
                                if self.spellId then
                                    GameTooltip:Hide()
                                end
                            end}
                        function d:SpellCheckbox(be, q, r, cQ)
                            cQ = cQ or 16
                            local cP = self:Checkbox(be, "", q, r)
                            cP.spellId = nil
                            cP.spellName = ""
                            local gb = self:Panel(cP, cQ, cQ)
                            gb:SetPoint("LEFT", cP.target, "RIGHT", 5, 0)
                            local aq = self:Texture(gb, cQ, cQ)
                            aq:SetAllPoints()
                            cP.icon = aq
                            cP.text:SetPoint("LEFT", gb, "RIGHT", 5, 0)
                            for aL, aM in pairs(gf) do
                                cP[aL] = aM
                            end
                            for aL, aM in pairs(gg) do
                                cP:SetScript(aL, aM)
                            end
                            return cP
                        end
                        d:RegisterModule(g, h)
                    end
                    local function gh(...)
                        local d = LibStub and LibStub("StdUi", true)
                        if not d then
                            return
                        end
                        local g, h = "ContextMenu", 3
                        if not d:UpgradeNeeded(g, h) then
                            return
                        end
                        local gi = function(bq, J)
                            bq.parentContext:CloseSubMenus()
                            bq.childContext:ClearAllPoints()
                            bq.childContext:SetPoint("TOPLEFT", bq, "TOPRIGHT", 0, 0)
                            bq.childContext:Show()
                        end
                        local gj = function(bq, J)
                            if J == "LeftButton" and bq.contextMenuData.callback then
                                bq.contextMenuData.callback(bq, bq.parentContext)
                            end
                        end
                        local gk = function(self, J)
                            if J == "RightButton" then
                                local gl = UIParent:GetScale()
                                local gm, gn = GetCursorPosition()
                                gm = gm / gl
                                gn = gn / gl
                                self:ClearAllPoints()
                                if self:IsShown() then
                                    self:Hide()
                                else
                                    self:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", gm, gn)
                                    self:Show()
                                end
                            end
                        end
                        d.ContextMenuMethods = {
                            CloseMenu = function(self)
                                self:CloseSubMenus()
                                self:Hide()
                            end,
                            CloseSubMenus = function(self)
                                for n = 1, #self.optionFrames do
                                    local go = self.optionFrames[n]
                                    if go.childContext then
                                        go.childContext:CloseMenu()
                                    end
                                end
                            end,
                            HookRightClick = function(self)
                                local be = self:GetParent()
                                if be then
                                    be:HookScript("OnMouseUp", gk)
                                end
                            end,
                            HookChildrenClick = function(self)
                            end,
                            CreateItem = function(be, bl, n)
                                local bq
                                if bl.title then
                                    bq = be.stdUi:Frame(be, nil, 20)
                                    bq.text = be.stdUi:Label(bq)
                                    be.stdUi:GlueLeft(bq.text, bq, 0, 0, true)
                                elseif bl.isSeparator then
                                    bq = be.stdUi:Frame(be, nil, 20)
                                    bq.texture = be.stdUi:Texture(bq, nil, 8, "Interface\\COMMON\\UI-TooltipDivider-Transparent")
                                    bq.texture:SetPoint("CENTER")
                                    bq.texture:SetPoint("LEFT")
                                    bq.texture:SetPoint("RIGHT")
                                elseif bl.checkbox then
                                    bq = be.stdUi:Checkbox(be, "")
                                elseif bl.radio then
                                    bq = be.stdUi:Radio(be, "", bl.radioGroup)
                                elseif bl.text then
                                    bq = be.stdUi:HighlightButton(be, nil, 20)
                                end
                                bq.contextMenuData = bl
                                if not bl.isSeparator then
                                    bq.text:SetJustifyH("LEFT")
                                end
                                if not bl.isSeparator and bl.children then
                                    bq.icon = be.stdUi:Texture(bq, 10, 10, "Interface\\Buttons\\SquareButtonTextures")
                                    bq.icon:SetTexCoord(0.42187500, 0.23437500, 0.01562500, 0.20312500)
                                    be.stdUi:GlueRight(bq.icon, bq, -4, 0, true)
                                    bq.childContext = be.stdUi:ContextMenu(be, bl.children, true, be.level + 1)
                                    bq.parentContext = be
                                    bq.mainContext = be.mainContext
                                    bq:HookScript("OnEnter", gi)
                                end
                                if bl.events then
                                    for gp, gq in pairs(bl.events) do
                                        bq:SetScript(gp, gq)
                                    end
                                end
                                if bl.callback then
                                    bq:SetScript("OnMouseUp", gj)
                                end
                                if bl.custom then
                                    for aS, ap in pairs(bl.custom) do
                                        bq[aS] = ap
                                    end
                                end
                                return bq
                            end,
                            UpdateItem = function(be, bq, bl, n)
                                local bm = be.padding
                                if bl.title then
                                    bq.text:SetText(bl.title)
                                    be.stdUi:ButtonAutoWidth(bq)
                                elseif bl.checkbox or bl.radio then
                                    bq.text:SetText(bl.checkbox or bl.radio)
                                    bq:AutoWidth()
                                    if bl.value then
                                        bq:SetValue(bl.value)
                                    end
                                elseif bl.text then
                                    bq:SetText(bl.text)
                                    be.stdUi:ButtonAutoWidth(bq)
                                end
                                if bl.children then
                                    bq:SetWidth(bq:GetWidth() + 16)
                                end
                                if be:GetWidth() - bm * 2 < bq:GetWidth() then
                                    be:SetWidth(bq:GetWidth() + bm * 2)
                                end
                                bq:SetPoint("LEFT", bm, 0)
                                bq:SetPoint("RIGHT", -bm, 0)
                                if bl.color and not bl.isSeparator then
                                    bq.text:SetTextColor(unpack(bl.color))
                                end
                            end,
                            DrawOptions = function(self, dd)
                                if not self.optionFrames then
                                    self.optionFrames = {}
                                end
                                local N, bb =
                                    self.stdUi:ObjectList(
                                    self,
                                    self.optionFrames,
                                    self.CreateItem,
                                    self.UpdateItem,
                                    dd,
                                    0,
                                    self.padding,
                                    -self.padding
                                )
                                self:SetHeight(bb + self.padding)
                            end,
                            StartHideCounter = function(self)
                                if self.timer then
                                    self.timer:Cancel()
                                end
                                self.timer = C_Timer:NewTimer(3, self.TimerCallback)
                            end,
                            StopHideCounter = function()
                            end
                        }
                        d.ContextMenuEvents = {OnEnter = function(self)
                            end, OnLeave = function(self)
                            end}
                        function d:ContextMenu(be, dd, gr, gs)
                            local dn = self:Panel(be)
                            dn.stdUi = self
                            dn.level = gs or 1
                            dn.padding = 16
                            dn:SetFrameStrata("FULLSCREEN_DIALOG")
                            for aL, aM in pairs(self.ContextMenuMethods) do
                                dn[aL] = aM
                            end
                            for aL, aM in pairs(self.ContextMenuEvents) do
                                dn:SetScript(aL, aM)
                            end
                            dn:DrawOptions(dd)
                            if dn.level == 1 then
                                dn.mainContext = dn
                                if not gr then
                                    dn:HookRightClick()
                                end
                            end
                            dn:Hide()
                            return dn
                        end
                        d:RegisterModule(g, h)
                    end
                a()
                K()
                T()
                af()
                aW()
                bh()
                bw()
                bO()
                bS()
                c6()
                ch()
                cK()
                c_()
                di()
                dB()
                dH()
                en()
                f2()
                fp()
                fA()
                fF()
                fJ()
                fZ()
                g8()
                gh()
	]]
				*/
                Console.WriteLine("StdUI was Injected");
                IsInjected = true;
            }
        }
    }
}
