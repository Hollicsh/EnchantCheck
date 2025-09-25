----------------------------------------------
-- Module
----------------------------------------------
EnchantCheck = LibStub("AceAddon-3.0"):NewAddon("Enchant Check", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0");

----------------------------------------------
-- Localization
----------------------------------------------
local L = LibStub("AceLocale-3.0"):GetLocale("EnchantCheck")
local LI = LibStub("LibBabble-Inventory-3.0"):GetLookupTable()

----------------------------------------------
-- Other libs
----------------------------------------------
local libItemUpgrade = LibStub("LibItemUpgradeInfo-1.0")

----------------------------------------------
-- Version and Constants (initialized in OnInitialize)
----------------------------------------------
-- Version and constants will be set in OnInitialize to ensure proper loading order
-- Constants-dependent variables (initialized in OnInitialize)
local MAX_LEVEL = 80 -- Fallback value
local ClassColor
local CheckSlotEnchant = {}
local CheckSlotMissing = {}
local CheckOffHand

----------------------------------------------
-- Config options and debug levels (initialized in OnInitialize)
----------------------------------------------
-- These will be set in OnInitialize to ensure proper loading order
local d_warn, d_info, d_notice, debugLevel

----------------------------------------------
-- Print debug message
----------------------------------------------
function EnchantCheck:Debug(level, msg, ...)
	if debugLevel and level and (level <= debugLevel) then
		self:Printf(msg, ...)
	end
end

----------------------------------------------
-- Configuration Management
----------------------------------------------
function EnchantCheck:GetSetting(key)
	if not self.db then
		self:Debug(d_warn, "GetSetting called before db initialized")
		return nil
	end
	if not self.db.profile then
		self:Debug(d_warn, "GetSetting called but db.profile is nil")
		return nil
	end
	return self.db.profile[key]
end

function EnchantCheck:SetSetting(key, value)
	self.db.profile[key] = value
	self:OnConfigUpdate()
end

function EnchantCheck:ToggleSetting(key)
	local currentValue = self:GetSetting(key)
	if type(currentValue) == "boolean" then
		self:SetSetting(key, not currentValue)
		return not currentValue
	else
		self:Printf("Setting '%s' is not a boolean value", key)
		return nil
	end
end

----------------------------------------------
-- Console Commands
----------------------------------------------
function EnchantCheck:ChatCommand(msg)
	local args = {}
	for word in msg:gmatch("%S+") do
		table.insert(args, word)
	end
	
	if #args == 0 or args[1] == "help" then
		self:ShowHelp()
	elseif args[1] == "config" or args[1] == "settings" then
		self:ShowConfig()
	elseif args[1] == "set" and args[2] and args[3] then
		self:SetConfigValue(args[2], args[3])
	elseif args[1] == "toggle" and args[2] then
		self:ToggleConfigValue(args[2])
	elseif args[1] == "reset" then
		self:ResetConfig()
	elseif args[1] == "check" then
		self:CheckCharacter()
	elseif args[1] == "cache" then
		self:ShowCacheStats()
	elseif args[1] == "fixhead" then
		self:ForceHeadSlotCheck()
	else
		self:Printf("Unknown command. Type '/enchantcheck help' for available commands.")
	end
end

function EnchantCheck:ShowHelp()
	self:Printf("|cff00FF00EnchantCheck Commands:|cffFFFFFF")
	self:Printf("  |cffFFFF00/enchantcheck help|cffFFFFFF - Show this help")
	self:Printf("  |cffFFFF00/enchantcheck check|cffFFFFFF - Check your gear")
	self:Printf("  |cffFFFF00/enchantcheck config|cffFFFFFF - Show current settings")
	self:Printf("  |cffFFFF00/enchantcheck set <setting> <value>|cffFFFFFF - Change a setting (use camelCase)")
	self:Printf("  |cffFFFF00/enchantcheck toggle <setting>|cffFFFFFF - Toggle a boolean setting (use camelCase)")
	self:Printf("  |cffFFFF00/enchantcheck reset|cffFFFFFF - Reset all settings to defaults")
	self:Printf("  |cffFFFF00/enchantcheck cache|cffFFFFFF - Show cache statistics")
	self:Printf("  |cffFFFF00/enchantcheck fixhead|cffFFFFFF - Force re-check head enchant requirements")
	self:Printf("  |cff888888Examples: smartNotifications, showTooltips, minItemLevelForWarnings|cffFFFFFF")
end

----------------------------------------------
-- Force Head Slot Check Function
----------------------------------------------
function EnchantCheck:ForceHeadSlotCheck()
	self:Print("=== Force Head Slot Re-evaluation ===")
	
	-- Direct function definition (bypass caching issues)
	local headEnchantFunction = function()
		self:Print("Running head enchant check function...")
		
		-- Head enchants are only required during The War Within Season 2 (Season 14)
		-- Add safety checks to prevent errors
		if not C_MythicPlus then
			self:Print("  C_MythicPlus not available")
			return false
		end
		
		if not C_MythicPlus.GetCurrentSeason then
			self:Print("  C_MythicPlus.GetCurrentSeason not available")
			return false
		end
		
		local success, season = pcall(C_MythicPlus.GetCurrentSeason)
		if not success then
			self:Print("  Failed to get current season: " .. tostring(season))
			return false
		end
		
		self:Print("  Current Mythic+ Season: " .. tostring(season))
		local result = season == 14
		self:Print("  Head enchants required: " .. tostring(result))
		return result
	end
	
	-- Execute the function and update CheckSlotEnchant
	local result = headEnchantFunction()
	CheckSlotEnchant[1] = result
	
	self:Print("CheckSlotEnchant[1] set to: " .. tostring(result))
	
	-- Update minimap button
	self:UpdateMinimapButtonStatus()
	
	self:Print("Head slot check complete. Run '/enchantcheck debug' to verify.")
end

----------------------------------------------
-- Debug Function
----------------------------------------------

function EnchantCheck:ShowConfig()
	self:Printf("|cff00FF00Current EnchantCheck Settings:|cffFFFFFF")
	
	-- Check if db is available
	if not self.db or not self.db.profile then
		self:Printf("|cffFF0000ERROR: Settings database not initialized!|cffFFFFFF")
		return
	end
	
	-- Show all settings with nil handling
	self:Printf("  Smart Notifications: |cffFFFF00%s|cffFFFFFF", tostring(self:GetSetting("smartNotifications") or "nil"))
	self:Printf("  Enhanced Tooltips: |cffFFFF00%s|cffFFFFFF", tostring(self:GetSetting("showTooltips") or "nil"))
	self:Printf("  Show Minimap Button: |cffFFFF00%s|cffFFFFFF", tostring(self:GetSetting("showMinimapButton") or "nil"))
	self:Printf("  Min Item Level for Warnings: |cffFFFF00%s|cffFFFFFF", tostring(self:GetSetting("minItemLevelForWarnings") or "nil"))
	self:Printf("  Ignore Heirlooms: |cffFFFF00%s|cffFFFFFF", tostring(self:GetSetting("ignoreHeirlooms") or "nil"))
	self:Printf("  Enable Sounds: |cffFFFF00%s|cffFFFFFF", tostring(self:GetSetting("enableSounds") or "nil"))
	self:Printf("  Suppress Leveling Warnings: |cffFFFF00%s|cffFFFFFF", tostring(self:GetSetting("suppressLevelingWarnings") or "nil"))
	self:Printf("  Enable Caching: |cffFFFF00%s|cffFFFFFF", tostring(self:GetSetting("enableCaching") or "nil"))
	self:Printf("  Cache Size: |cffFFFF00%s|cffFFFFFF", tostring(self:GetSetting("cacheSize") or "nil"))
	self:Printf("  Cache TTL: |cffFFFF00%s|cffFFFFFF seconds", tostring(self:GetSetting("cacheTTL") or "nil"))
	
	-- Debug: Show raw profile table
	self:Printf("|cff00FFFFDebug - Profile keys:|cffFFFFFF")
	local count = 0
	for k, v in pairs(self.db.profile) do
		count = count + 1
		if count <= 5 then -- Show first 5 keys
			self:Printf("  %s = %s", tostring(k), tostring(v))
		end
	end
	if count > 5 then
		self:Printf("  ... and %d more keys", count - 5)
	end
end

function EnchantCheck:SetConfigValue(setting, value)
	local currentValue = self:GetSetting(setting)
	if currentValue == nil then
		self:Printf("Unknown setting: %s", setting)
		return
	end
	
	local newValue
	if type(currentValue) == "boolean" then
		newValue = (value:lower() == "true" or value == "1")
	elseif type(currentValue) == "number" then
		newValue = tonumber(value)
		if not newValue then
			self:Printf("Invalid number value: %s", value)
			return
		end
	else
		newValue = value
	end
	
	self:SetSetting(setting, newValue)
	self:Printf("Set %s to %s", setting, tostring(newValue))
end

function EnchantCheck:ToggleConfigValue(setting)
	local newValue = self:ToggleSetting(setting)
	if newValue ~= nil then
		self:Printf("Toggled %s to %s", setting, tostring(newValue))
	end
end

function EnchantCheck:ResetConfig()
	local defaults = EnchantCheckConstants.DEFAULTS or EnchantCheck.defaults
	if not defaults or not defaults.profile then
		self:Printf("|cffFF0000ERROR: Cannot reset - defaults not available!|cffFFFFFF")
		return
	end
	
	for key, value in pairs(defaults.profile) do
		self.db.profile[key] = value
	end
	self:Printf("Configuration reset to defaults")
	self:OnConfigUpdate()
end

function EnchantCheck:ShowCacheStats()
	local stats = EnchantCheckCache and EnchantCheckCache:GetCacheStats() or {size = 0, maxSize = 0, hits = 0, misses = 0, hitRate = 0}
	self:Printf("|cff00FF00EnchantCheck Cache Statistics:|cffFFFFFF")
	self:Printf("  Cache Size: |cffFFFF00%d|cffFFFFFF / |cffFFFF00%d|cffFFFFFF", stats.size, stats.maxSize)
	self:Printf("  Cache Hits: |cffFFFF00%d|cffFFFFFF", stats.hits)
	self:Printf("  Cache Misses: |cffFFFF00%d|cffFFFFFF", stats.misses)
	self:Printf("  Hit Rate: |cffFFFF00%.1f%%|cffFFFFFF", stats.hitRate)
	self:Printf("  TTL: |cffFFFF00%d|cffFFFFFF seconds", stats.ttl)
end

----------------------------------------------
-- Slot Configuration Initialization
----------------------------------------------
function EnchantCheck:InitializeSlotConfigurations()
	-- Initialize enchant slot requirements
	for slot = 1, 19 do
		local value = EnchantCheckConstants.ENCHANT_SLOTS[slot]
		if value ~= nil then
			if type(value) == "function" then
				CheckSlotEnchant[slot] = value()
			else
				CheckSlotEnchant[slot] = value
			end
		end
	end
	
	-- Get required slots from constants
	CheckSlotMissing = EnchantCheckConstants.REQUIRED_SLOTS
	
	-- Handle head enchant dynamic requirement (Season 14 only)
	if CheckSlotEnchant[1] == false then
		local headEnchantRequired = false
		if C_MythicPlus and C_MythicPlus.GetCurrentSeason then
			local success, season = pcall(C_MythicPlus.GetCurrentSeason)
			if success and season == 14 then
				headEnchantRequired = true
			end
		end
		CheckSlotEnchant[1] = headEnchantRequired
	end
end

----------------------------------------------
-- Module Dependency Validation
----------------------------------------------
function EnchantCheck:ValidateModuleDependencies()
	local requiredModules = {
		{name = "EnchantCheckConstants", module = EnchantCheckConstants},
		{name = "EnchantCheckCache", module = EnchantCheckCache},  
		{name = "EnchantCheckUtils", module = EnchantCheckUtils}
	}
	
	local missingModules = {}
	for _, moduleInfo in ipairs(requiredModules) do
		if not moduleInfo.module then
			table.insert(missingModules, moduleInfo.name)
		end
	end
	
	if #missingModules > 0 then
		self:Printf("|cffFF0000CRITICAL ERROR:|cffFFFFFF Required modules missing: %s", table.concat(missingModules, ", "))
		self:Printf("Check addon file loading order in TOC file.")
		return false
	end
	
	-- Validate constants structure
	local requiredConstants = {"VERSION", "DEFAULTS", "DEBUG_LEVELS", "ENCHANT_SLOTS", "REQUIRED_SLOTS"}
	local missingConstants = {}
	for _, constant in ipairs(requiredConstants) do
		if not EnchantCheckConstants[constant] then
			table.insert(missingConstants, constant)
		end
	end
	
	if #missingConstants > 0 then
		self:Printf("|cffFF0000CRITICAL ERROR:|cffFFFFFF Constants missing: %s", table.concat(missingConstants, ", "))
		return false
	end
	
	-- Validate version consistency (optional warning, not critical)
	local tocVersion = nil
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		tocVersion = C_AddOns.GetAddOnMetadata("EnchantCheck", "Version")
	elseif GetAddOnMetadata then
		tocVersion = GetAddOnMetadata("EnchantCheck", "Version")
	end
	
	if tocVersion and EnchantCheckConstants.VERSION then
		local constantsVersion = EnchantCheckConstants.VERSION:gsub("^v", "") -- Remove 'v' prefix
		if tocVersion ~= constantsVersion then
			self:Printf("|cffFFFF00WARNING:|cffFFFFFF Version mismatch - TOC: %s, Constants: %s", 
				tocVersion, EnchantCheckConstants.VERSION)
		end
	end
	
	return true
end

----------------------------------------------
--- Init
----------------------------------------------
function EnchantCheck:OnInitialize()
	-- Validate required modules are loaded
	if not self:ValidateModuleDependencies() then
		return
	end
	
	-- Initialize constants-dependent variables
	MAX_LEVEL = EnchantCheckConstants.MAX_LEVEL
	ClassColor = EnchantCheckConstants.CLASS_COLORS
	
	-- Set version info
	EnchantCheck.version = EnchantCheckConstants.VERSION
	EnchantCheck.authors = EnchantCheckConstants.AUTHORS
	
	-- Set defaults
	EnchantCheck.defaults = EnchantCheckConstants.DEFAULTS
	
	-- Initialize debug levels
	d_warn = EnchantCheckConstants.DEBUG_LEVELS.WARNING
	d_info = EnchantCheckConstants.DEBUG_LEVELS.INFO
	d_notice = EnchantCheckConstants.DEBUG_LEVELS.NOTICE
	debugLevel = d_warn
	
	-- Initialize slot configurations
	self:InitializeSlotConfigurations()
	
	-- Initialize weapon configuration
	CheckOffHand = EnchantCheckConstants.OFFHAND_REQUIRED(LI)
	
	-- Initialize database
	self.db = LibStub("AceDB-3.0"):New("EnchantCheckDB", EnchantCheck.defaults, "profile")
	
	-- Initialize cache system
	if EnchantCheckCache then
		EnchantCheckCache:ConfigureFromSettings(self.db.profile)
	end

	-- Register console commands
	self:RegisterChatCommand("enchantcheck", "ChatCommand")
	self:RegisterChatCommand("ec", "ChatCommand")

	EnchantCheckFrameTitle:SetText("Enchant Check "..self.version);

	CharacterFrameEnchantCheckButton:SetText(L["BTN_CHECK_ENCHANTS"]);
	InspectFrameEnchantCheckButton:SetText(L["BTN_CHECK_ENCHANTS"]);

	EnchantCheckItemsFrame.titleFont:SetText(L["UI_ITEMS_TITLE"]);
	EnchantCheckGemsFrame.titleFont:SetText(L["UI_GEMS_TITLE"]);
	EnchantCheckEnchantsFrame.titleFont:SetText(L["UI_ENCHANTS_TITLE"]);

	-- Initialize minimap button
	if self.db.profile.showMinimapButton then
		self:InitializeMinimapButton()
	end

	if self.db.profile.enable then
		self:Enable();
	end

	self:Debug(d_notice, L["LOADED"]);
end

----------------------------------------------
-- OnEnable()
----------------------------------------------
----------------------------------------------
-- Tooltip Hooking
----------------------------------------------
function EnchantCheck:SetupTooltipHooks()
	if not self:GetSetting("showTooltips") then
		return
	end
	
	local tooltipsHooked = 0
	
	-- Try hooking GameTooltip with different approaches
	if GameTooltip then
		-- Method 1: Try HookScript with OnTooltipSetItem
		local success = false
		if GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetItem") then
			success, err = pcall(function()
				self:HookScript(GameTooltip, "OnTooltipSetItem", "OnTooltipSetItem")
			end)
			if success then
				tooltipsHooked = tooltipsHooked + 1
				self:Debug(d_info, "Successfully hooked GameTooltip via OnTooltipSetItem")
			else
				self:Debug(d_warn, "Failed to hook GameTooltip OnTooltipSetItem: %s", err)
			end
		end
		
		-- Method 2: Try HookScript with OnShow if OnTooltipSetItem failed
		if not success and GameTooltip.HasScript and GameTooltip:HasScript("OnShow") then
			success, err = pcall(function()
				self:HookScript(GameTooltip, "OnShow", function(tooltip)
					if tooltip:GetItem() then
						self:OnTooltipSetItem(tooltip)
					end
				end)
			end)
			if success then
				tooltipsHooked = tooltipsHooked + 1
				self:Debug(d_info, "Successfully hooked GameTooltip via OnShow")
			else
				self:Debug(d_warn, "Failed to hook GameTooltip OnShow: %s", err)
			end
		end
		
		-- Method 3: Try Ace3 Hook as last resort
		if not success then
			success, err = pcall(function()
				self:Hook(GameTooltip, "SetHyperlink", function(tooltip, link)
					if link and link:match("item:") then
						self:OnTooltipSetItem(tooltip)
					end
				end, true) -- true for post-hook
			end)
			if success then
				tooltipsHooked = tooltipsHooked + 1
				self:Debug(d_info, "Successfully hooked GameTooltip via SetHyperlink")
			else
				self:Debug(d_warn, "Failed to hook GameTooltip SetHyperlink: %s", err)
			end
		end
		
		if not success then
			self:Debug(d_warn, "All GameTooltip hooking methods failed")
		end
	else
		self:Debug(d_warn, "GameTooltip not available")
	end
	
	-- Try similar approaches for other tooltips
	local otherTooltips = {"ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2"}
	for _, tooltipName in ipairs(otherTooltips) do
		local tooltip = _G[tooltipName]
		if tooltip then
			local success, err = pcall(function()
				if tooltip.HasScript and tooltip:HasScript("OnTooltipSetItem") then
					self:HookScript(tooltip, "OnTooltipSetItem", "OnTooltipSetItem")
				elseif tooltip.SetHyperlink then
					self:Hook(tooltip, "SetHyperlink", function(tt, link)
						if link and link:match("item:") then
							self:OnTooltipSetItem(tt)
						end
					end, true)
				end
			end)
			if success then
				tooltipsHooked = tooltipsHooked + 1
				self:Debug(d_info, "Successfully hooked %s tooltip", tooltipName)
			else
				self:Debug(d_warn, "Failed to hook %s tooltip: %s", tooltipName, err)
			end
		end
	end
	
	if tooltipsHooked > 0 then
		self:Debug(d_info, "Successfully hooked %d tooltip(s)", tooltipsHooked)
		self.tooltipsHooked = true
	else
		self:Debug(d_warn, "Failed to hook any tooltips - enhanced tooltips may not work")
		self.tooltipsHooked = false
	end
	
	self.needsTooltipHooking = false
end

----------------------------------------------
-- Event Handlers
----------------------------------------------
function EnchantCheck:OnEnable()
	self:RegisterEvent("INSPECT_READY");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("PLAYER_LOGIN");

	-- Defer tooltip hooking until ADDON_LOADED or PLAYER_LOGIN when frames are available
	self.needsTooltipHooking = self:GetSetting("showTooltips")
	
	-- Start cache maintenance timer if caching is enabled
	if self:GetSetting("enableCaching") then
		if EnchantCheckCache then
			EnchantCheckCache:StartMaintenanceTimer(60) -- Every minute
		end
	end

	self:Debug(d_notice, L["ENABLED"]);
end

----------------------------------------------
-- OnDisable()
----------------------------------------------
function EnchantCheck:OnDisable()
	self:UnregisterEvent("INSPECT_READY");
	self:UnregisterEvent("UNIT_INVENTORY_CHANGED");
	self:UnregisterEvent("PLAYER_ENTERING_WORLD");
	self:UnregisterEvent("PLAYER_LOGIN");
	
	-- Stop cache maintenance and clear cache
	if EnchantCheckCache then
		EnchantCheckCache:StopMaintenanceTimer()
		EnchantCheckCache:ClearItemCache()
	end

	self:Debug(d_notice, L["DISABLED"]);
end

----------------------------------------------
-- OnConfigUpdate()
----------------------------------------------
function EnchantCheck:OnConfigUpdate()
	-- Update cache configuration
	if EnchantCheckCache then
		EnchantCheckCache:ConfigureFromSettings(self.db.profile)
	end
	
	-- Handle tooltip hooks when showTooltips setting changes
	if self:GetSetting("showTooltips") and not self.tooltipsHooked then
		self:SetupTooltipHooks()
	end
	
	-- Enable
	if (self.db.profile.enable) then
		if not EnchantCheck:IsEnabled() then
			EnchantCheck:Enable()
		end
	else
		if EnchantCheck:IsEnabled() then
			EnchantCheck:Disable()
		end
	end
end

----------------------------------------------
-- Item link functions
----------------------------------------------
function EnchantCheck:GetActualItemLevel(link)
	if not link or link == "" then
		return 0
	end
	
	local success, itemLevel = pcall(function()
		return libItemUpgrade:GetUpgradedItemLevel(link)
	end)
	
	if success and itemLevel and itemLevel > 0 then
		return itemLevel
	else
		-- Fallback to basic item level using modern API
		local basicLevel
		if C_Item and C_Item.GetItemInfo then
			_, _, _, basicLevel = C_Item.GetItemInfo(link)
		else
			_, _, _, basicLevel = GetItemInfo(link)
		end
		return basicLevel or 0
	end
end

function EnchantCheck:GetItemLinkInfo(link)
	if not link or type(link) ~= "string" or link == "" then
		return nil, nil, nil
	end
	
	-- Validate item link format
	if not link:match("|Hitem:") then
		self:Debug(d_warn, "Invalid item link format: %s", tostring(link))
		return nil, nil, nil
	end
	
	-- Try multiple patterns for different item link formats
	local itemColor, itemString, itemName
	
	-- Pattern 1: Full item link with color
	itemColor, itemString, itemName = link:match("(|c%x+)|Hitem:([-%d:]*)|h%[(.-)%]|h|r")
	
	if not itemString then
		-- Pattern 2: Item link without color but with name
		itemString, itemName = link:match("|Hitem:([-%d:]*)|h%[(.-)%]|h")
		if itemString then
			itemColor = "|cffffffff"
		end
	end
	
	if not itemString then
		-- Pattern 3: Item link without name (truncated)
		itemString = link:match("|Hitem:([-%d:]*)")
		if itemString then
			itemName = "Unknown Item"
			itemColor = "|cffffffff"
		end
	end
	
	if not itemString then
		-- Pattern 4: Just extract the item ID and build a basic string
		local itemId = link:match("|Hitem:(%d+)")
		if itemId then
			itemString = itemId .. ":::::::::::::::::"  -- Basic item string format
			itemName = "Item " .. itemId
			itemColor = "|cffffffff"
		else
			-- Complete failure - log more details
			self:Debug(d_warn, "Failed to parse any item data from link (length=%d): %s", 
				string.len(link or ""), string.sub(tostring(link), 1, 150))
			return nil, nil, nil
		end
	end
	
	return itemColor, itemString, itemName
end


----------------------------------------------
-- Item string functions
----------------------------------------------
function EnchantCheck:StringSplit(separator, value)
	local fields = {};
	gsub(value..separator, "([^"..separator.."]*)"..separator, function(v) table.insert(fields, v) end);
	return fields;
end

function EnchantCheck:SplitValue(value)
	if ( value == "" ) then
		value = "0"
	end
	return tonumber(value)
end


----------------------------------------------
-- Cache System Reference
----------------------------------------------
-- Cache functionality moved to modules/cache.lua
-- Using EnchantCheckCache for all caching operations

----------------------------------------------
-- Minimap Button System
----------------------------------------------

function EnchantCheck:InitializeMinimapButton()
	-- Create minimap button data object
	self.minimapButton = {
		type = "data source",
		text = "EnchantCheck",
		icon = "Interface\\Icons\\INV_Enchant_EssenceCosmicGreater",
		OnClick = function(self, button)
			EnchantCheck:OnMinimapButtonClick(button)
		end,
		OnTooltipShow = function(tooltip)
			EnchantCheck:ShowMinimapTooltip(tooltip)
		end,
	}
	
	-- Simple minimap button fallback if LibDBIcon isn't available
	if not LibStub then
		self:CreateSimpleMinimapButton()
	else
		local LibDBIcon = LibStub("LibDBIcon-1.0", true)
		if LibDBIcon then
			LibDBIcon:Register("EnchantCheck", self.minimapButton, self.db.profile.minimap)
		else
			self:CreateSimpleMinimapButton()
		end
	end
end

function EnchantCheck:CreateSimpleMinimapButton()
	-- Create a simple minimap button without LibDBIcon
	local button = CreateFrame("Button", "EnchantCheckMinimapButton", Minimap)
	button:SetSize(32, 32)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -15, -15)
	
	-- Button texture
	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")
	icon:SetTexture("Interface\\Icons\\INV_Enchant_EssenceCosmicGreater")
	
	-- Border
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(32, 32)
	border:SetPoint("CENTER")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	
	-- Click handlers
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function(self, button)
		EnchantCheck:OnMinimapButtonClick(button)
	end)
	
	-- Tooltip
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		EnchantCheck:ShowMinimapTooltip(GameTooltip)
		GameTooltip:Show()
	end)
	
	button:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	
	self.minimapButtonFrame = button
	self:UpdateMinimapButtonStatus()
end

function EnchantCheck:OnMinimapButtonClick(button)
	if button == "LeftButton" then
		-- Left click: Toggle gear check
		self:CheckCharacter()
	elseif button == "RightButton" then
		-- Right click: Show options menu
		self:ShowMinimapMenu()
	end
end

function EnchantCheck:ShowMinimapTooltip(tooltip)
	tooltip:AddLine("|cff00FF00EnchantCheck|r")
	tooltip:AddLine(" ")
	
	-- Show current status
	local status = self:GetCurrentGearStatus()
	if status.hasIssues then
		tooltip:AddLine("|cffFF0000Issues detected:|r")
		if status.missingEnchants > 0 then
			tooltip:AddLine("  |cffFFFF00" .. status.missingEnchants .. " missing enchants|r")
		end
		if status.missingGems > 0 then
			tooltip:AddLine("  |cffFFFF00" .. status.missingGems .. " missing gems|r")
		end
		if status.lowItems > 0 then
			tooltip:AddLine("  |cffFFFF00" .. status.lowItems .. " low level items|r")
		end
	else
		tooltip:AddLine("|cff00FF00All gear looks good!|r")
	end
	
	tooltip:AddLine(" ")
	tooltip:AddLine("|cffFFFFFFLeft-click:|r Check gear")
	tooltip:AddLine("|cffFFFFFFRight-click:|r Options menu")
end

function EnchantCheck:ShowMinimapMenu()
	-- Create dropdown menu
	local menuFrame = CreateFrame("Frame", "EnchantCheckMinimapMenu", UIParent, "UIDropDownMenuTemplate")
	
	local function InitializeMenu(self, level)
		local info = UIDropDownMenu_CreateInfo()
		
		if level == 1 then
			-- Title
			info.text = "EnchantCheck"
			info.isTitle = true
			info.notCheckable = true
			UIDropDownMenu_AddButton(info)
			
			-- Check Gear
			info = UIDropDownMenu_CreateInfo()
			info.text = "Check Gear"
			info.func = function() EnchantCheck:CheckCharacter() end
			info.notCheckable = true
			UIDropDownMenu_AddButton(info)
			
			-- Settings (with submenu)
			info = UIDropDownMenu_CreateInfo()
			info.text = "Settings"
			info.hasArrow = true
			info.value = "settings"
			info.notCheckable = true
			UIDropDownMenu_AddButton(info)
			
			-- Help
			info = UIDropDownMenu_CreateInfo()
			info.text = "Help"
			info.func = function() EnchantCheck:ShowHelp() end
			info.notCheckable = true
			UIDropDownMenu_AddButton(info)
			
		elseif level == 2 and UIDROPDOWNMENU_MENU_VALUE == "settings" then
			-- Settings submenu - Smart Notification Settings
			info.text = "Smart Notifications"
			info.checked = EnchantCheck:GetSetting("smartNotifications")
			info.func = function() EnchantCheck:ToggleSetting("smartNotifications") end
			UIDropDownMenu_AddButton(info, level)
			
			info = UIDropDownMenu_CreateInfo()
			info.text = "Ignore Heirlooms"
			info.checked = EnchantCheck:GetSetting("ignoreHeirlooms")
			info.func = function() EnchantCheck:ToggleSetting("ignoreHeirlooms") end
			UIDropDownMenu_AddButton(info, level)
			
			-- Warning Settings
			info = UIDropDownMenu_CreateInfo()
			info.text = "Warn Missing Items"
			info.checked = EnchantCheck:GetSetting("warnMissingItems")
			info.func = function() EnchantCheck:ToggleSetting("warnMissingItems") end
			UIDropDownMenu_AddButton(info, level)
			
			info = UIDropDownMenu_CreateInfo()
			info.text = "Warn Missing Enchants"
			info.checked = EnchantCheck:GetSetting("warnMissingEnchants")
			info.func = function() EnchantCheck:ToggleSetting("warnMissingEnchants") end
			UIDropDownMenu_AddButton(info, level)
			
			info = UIDropDownMenu_CreateInfo()
			info.text = "Warn Missing Gems"
			info.checked = EnchantCheck:GetSetting("warnMissingGems")
			info.func = function() EnchantCheck:ToggleSetting("warnMissingGems") end
			UIDropDownMenu_AddButton(info, level)
			
			info = UIDropDownMenu_CreateInfo()
			info.text = "Warn Low Item Level"
			info.checked = EnchantCheck:GetSetting("warnLowItemLevel")
			info.func = function() EnchantCheck:ToggleSetting("warnLowItemLevel") end
			UIDropDownMenu_AddButton(info, level)
			
			-- Sound Settings
			info = UIDropDownMenu_CreateInfo()
			info.text = "Enable Sounds"
			info.checked = EnchantCheck:GetSetting("enableSounds")
			info.func = function() EnchantCheck:ToggleSetting("enableSounds") end
			UIDropDownMenu_AddButton(info, level)
			
			-- Visual Settings
			info = UIDropDownMenu_CreateInfo()
			info.text = "Enhanced Tooltips"
			info.checked = EnchantCheck:GetSetting("showTooltips")
			info.func = function() EnchantCheck:ToggleSetting("showTooltips") end
			UIDropDownMenu_AddButton(info, level)
			
			info = UIDropDownMenu_CreateInfo()
			info.text = "Show Progress Bar"
			info.checked = EnchantCheck:GetSetting("showProgressBar")
			info.func = function() EnchantCheck:ToggleSetting("showProgressBar") end
			UIDropDownMenu_AddButton(info, level)
			
			info = UIDropDownMenu_CreateInfo()
			info.text = "Color Code Severity"
			info.checked = EnchantCheck:GetSetting("colorCodeSeverity")
			info.func = function() EnchantCheck:ToggleSetting("colorCodeSeverity") end
			UIDropDownMenu_AddButton(info, level)
			
			info = UIDropDownMenu_CreateInfo()
			info.text = "Show Slot Icons"
			info.checked = EnchantCheck:GetSetting("showSlotIcons")
			info.func = function() EnchantCheck:ToggleSetting("showSlotIcons") end
			UIDropDownMenu_AddButton(info, level)
			
			-- Content-Specific Settings
			info = UIDropDownMenu_CreateInfo()
			info.text = "Suppress Leveling Warnings"
			info.checked = EnchantCheck:GetSetting("suppressLevelingWarnings")
			info.func = function() EnchantCheck:ToggleSetting("suppressLevelingWarnings") end
			UIDropDownMenu_AddButton(info, level)
			
			info = UIDropDownMenu_CreateInfo()
			info.text = "Enhanced Dungeon Checks"
			info.checked = EnchantCheck:GetSetting("enhancedDungeonChecks")
			info.func = function() EnchantCheck:ToggleSetting("enhancedDungeonChecks") end
			UIDropDownMenu_AddButton(info, level)
			
			info = UIDropDownMenu_CreateInfo()
			info.text = "Raid Ready Mode"
			info.checked = EnchantCheck:GetSetting("raidReadyMode")
			info.func = function() EnchantCheck:ToggleSetting("raidReadyMode") end
			UIDropDownMenu_AddButton(info, level)
			
			-- Performance Settings
			info = UIDropDownMenu_CreateInfo()
			info.text = "Enable Caching"
			info.checked = EnchantCheck:GetSetting("enableCaching")
			info.func = function() EnchantCheck:ToggleSetting("enableCaching") end
			UIDropDownMenu_AddButton(info, level)
			
			info = UIDropDownMenu_CreateInfo()
			info.text = "Batch Processing"
			info.checked = EnchantCheck:GetSetting("batchProcessing")
			info.func = function() EnchantCheck:ToggleSetting("batchProcessing") end
			UIDropDownMenu_AddButton(info, level)
			
			info = UIDropDownMenu_CreateInfo()
			info.text = "Show Minimap Button"
			info.checked = EnchantCheck:GetSetting("showMinimapButton")
			info.func = function() EnchantCheck:ToggleSetting("showMinimapButton") end
			UIDropDownMenu_AddButton(info, level)
		end
	end
	
	UIDropDownMenu_Initialize(menuFrame, InitializeMenu, "MENU")
	ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
end

function EnchantCheck:GetCurrentGearStatus()
	-- Quick gear status check for minimap button
	local status = {
		hasIssues = false,
		missingEnchants = 0,
		missingGems = 0,
		lowItems = 0,
	}
	
	-- Check currently equipped items using same logic as character frame
	local totalItemLevel = 0
	local itemCount = 0
	
	for slot = 1, EnchantCheckConstants.EQUIPMENT_SLOTS.TOTAL do
		local itemLink = GetInventoryItemLink("player", slot)
		if itemLink then
			itemCount = itemCount + 1
			local itemLevel = self:GetActualItemLevel(itemLink)
			totalItemLevel = totalItemLevel + itemLevel
		end
	end
	
	-- Calculate average item level and content type for smart notifications
	local avgItemLevel = itemCount > 0 and (totalItemLevel / itemCount) or 0
	local contentType = self:DetectContentType(avgItemLevel)
	
	-- Second pass: check enchants and gems using smart logic
	for slot = 1, EnchantCheckConstants.EQUIPMENT_SLOTS.TOTAL do
		local itemLink = GetInventoryItemLink("player", slot)
		if itemLink then
			-- Check enchants using the same logic as character frame
			local _, enchantId = self:GetEnchantInfoFromLink(itemLink)
			if enchantId == 0 and self:ShouldWarnAboutSlot(slot, contentType, avgItemLevel) then
				-- Use the same shield/weapon logic as the main check function
				local itemType
				if C_Item and C_Item.GetItemInfo then
					itemType = select(6, C_Item.GetItemInfo(itemLink))
				else
					itemType = select(6, GetItemInfo(itemLink))
				end
				
				-- Don't warn about shields (slot 17 offhand items that aren't weapons)
				if not (libItemUpgrade:IsArtifact(itemLink) or (slot == 17 and itemType ~= WEAPON)) then
					status.missingEnchants = status.missingEnchants + 1
					status.hasIssues = true
				end
			end
			
			-- Check gems
			local gems = self:GetGemInfoFromLink(itemLink)
			local sockets = self:GetSocketCountFromLink(itemLink)
			if #gems < sockets then
				status.missingGems = status.missingGems + 1
				status.hasIssues = true
			end
		end
	end
	
	-- Check for low item levels
	if itemCount > 0 then
		local avgLevel = totalItemLevel / itemCount
		for slot = 1, EnchantCheckConstants.EQUIPMENT_SLOTS.TOTAL do
			local itemLink = GetInventoryItemLink("player", slot)
			if itemLink then
				local itemLevel = self:GetActualItemLevel(itemLink)
				if itemLevel < avgLevel * EnchantCheckConstants.ITEM_LEVEL.LOW_THRESHOLD_MULTIPLIER then
					status.lowItems = status.lowItems + 1
					status.hasIssues = true
				end
			end
		end
	end
	
	return status
end

function EnchantCheck:UpdateMinimapButtonStatus()
	if not self.minimapButtonFrame then return end
	
	local status = self:GetCurrentGearStatus()
	
	-- Get the existing icon texture
	for i = 1, self.minimapButtonFrame:GetNumRegions() do
		local region = select(i, self.minimapButtonFrame:GetRegions())
		if region:GetObjectType() == "Texture" and region:GetTexture() then
			if region:GetTexture():find("INV_Enchant") then
				-- Update button appearance based on status
				if status.hasIssues then
					-- Red tint for issues
					region:SetVertexColor(1.0, 0.3, 0.3)
				else
					-- Normal color
					region:SetVertexColor(1.0, 1.0, 1.0)
				end
				break
			end
		end
	end
end

----------------------------------------------
-- Smart Notification System
----------------------------------------------


function EnchantCheck:DetectContentType(avgItemLevel)
	local inInstance, instanceType = IsInInstance()
	
	-- Check if in specific content
	if inInstance then
		if instanceType == "party" then
			local name, instanceType, difficultyID = GetInstanceInfo()
			if difficultyID and difficultyID >= 23 then -- Mythic+ difficulties
				return EnchantCheckConstants.CONTENT_TYPES.MYTHIC_PLUS
			else
				return EnchantCheckConstants.CONTENT_TYPES.DUNGEON
			end
		elseif instanceType == "raid" then
			return EnchantCheckConstants.CONTENT_TYPES.RAID
		elseif instanceType == "pvp" or instanceType == "arena" then
			return EnchantCheckConstants.CONTENT_TYPES.PVP
		end
	end
	
	-- Check level and item level to determine content type
	local playerLevel = UnitLevel("player")
	if playerLevel < MAX_LEVEL then
		return EnchantCheckConstants.CONTENT_TYPES.LEVELING
	else
		-- For max level players, be conservative about endgame classification
		-- Only classify as endgame if significantly above the threshold
		local endgameThreshold = EnchantCheckConstants.CONTENT_ILVL_REQUIREMENTS[EnchantCheckConstants.CONTENT_TYPES.ENDGAME]
		if avgItemLevel >= endgameThreshold + 20 then -- 20 ilvl buffer
			return EnchantCheckConstants.CONTENT_TYPES.ENDGAME
		else
			return EnchantCheckConstants.CONTENT_TYPES.LEVELING
		end
	end
end

function EnchantCheck:ShouldWarnAboutSlot(slot, contentType, avgItemLevel)
	-- Check if smart notifications are enabled
	if not self:GetSetting("smartNotifications") then
		-- When smart notifications are disabled, fall back to basic slot checking
		return CheckSlotEnchant[slot] or false
	end
	
	-- Check if slot normally requires enchants first
	if not CheckSlotEnchant[slot] then
		return false
	end
	
	-- Don't warn about enchants for low-level content if setting enabled
	if self:GetSetting("suppressLevelingWarnings") then
		if contentType == EnchantCheckConstants.CONTENT_TYPES.LEVELING then
			if avgItemLevel < self:GetSetting("minItemLevelForWarnings") then
				return false
			end
		end
		-- Also suppress for ENDGAME content if item level is below warning threshold
		if contentType == EnchantCheckConstants.CONTENT_TYPES.ENDGAME then
			if avgItemLevel < self:GetSetting("minItemLevelForWarnings") then
				return false
			end
		end
	end
	
	-- Check content-specific settings
	if contentType == EnchantCheckConstants.CONTENT_TYPES.DUNGEON and not self:GetSetting("enhancedDungeonChecks") then
		return false
	end
	
	-- For ENDGAME content, be more restrictive
	if contentType == EnchantCheckConstants.CONTENT_TYPES.ENDGAME then
		-- Only warn if we're clearly in endgame content (high item level)
		local endgameThreshold = self:GetSetting("minItemLevelForWarnings") or 400
		if avgItemLevel < endgameThreshold then
			return false
		end
	end
	
	return true
end


----------------------------------------------
-- Tooltip Enhancement System
----------------------------------------------

function EnchantCheck:GetItemSlotFromLink(itemLink)
	if not itemLink then return nil end
	
	-- Check if this item is currently equipped
	for slot = 1, EnchantCheckConstants.EQUIPMENT_SLOTS.TOTAL do
		local equippedLink = GetInventoryItemLink("player", slot)
		if equippedLink and equippedLink == itemLink then
			return slot
		end
	end
	return nil
end

function EnchantCheck:GetEnchantInfoFromLink(itemLink)
	if not itemLink then return nil, 0 end
	
	local _, itemString = self:GetItemLinkInfo(itemLink)
	if not itemString then return nil, 0 end
	
	local ids = self:StringSplit(":", itemString)
	if not ids or #ids < 2 then return nil, 0 end
	
	local enchantId = self:SplitValue(ids[2] or "0")
	local enchantName = nil
	
	-- Try to get enchant name if enchanted
	if enchantId > 0 then
		-- This would need enchant ID -> name mapping, simplified for now
		enchantName = "Enchanted (ID: " .. enchantId .. ")"
	end
	
	return enchantName, enchantId
end

function EnchantCheck:GetGemInfoFromLink(itemLink)
	if not itemLink then return {} end
	
	local gems = {}
	for i = 1, 4 do
		local _, gemLink = GetItemGem(itemLink, i)
		if gemLink then
			local gemName = GetItemInfo(gemLink)
			if gemName then
				table.insert(gems, gemName)
			end
		end
	end
	return gems
end

function EnchantCheck:GetSocketCountFromLink(itemLink)
	if not itemLink then return 0 end
	
	local success, stats = pcall(C_Item.GetItemStats, itemLink)
	if not success or not stats then return 0 end
	
	local socketCount = 0
	for label in pairs(stats) do
		if label and label:find("EMPTY_SOCKET_", 1, true) then
			socketCount = socketCount + 1
		end
	end
	
	return socketCount
end

function EnchantCheck:OnTooltipSetItem(tooltip)
	if not self:GetSetting("showTooltips") then return end
	
	local name, link = tooltip:GetItem()
	if not link then return end
	
	local slot = self:GetItemSlotFromLink(link)
	
	-- Add enchant information
	local enchantName, enchantId = self:GetEnchantInfoFromLink(link)
	if slot and CheckSlotEnchant[slot] then
		if enchantId > 0 then
			tooltip:AddLine(EnchantCheckConstants.UI.COLORS.GOOD .. "✓ Enchanted" .. EnchantCheckConstants.UI.COLORS.RESET, 1, 1, 1)
			if enchantName then
				tooltip:AddLine("  " .. enchantName, 0.8, 0.8, 0.8)
			end
		else
			tooltip:AddLine(EnchantCheckConstants.UI.COLORS.ERROR .. "✗ Missing Enchant" .. EnchantCheckConstants.UI.COLORS.RESET, 1, 1, 1)
		end
	end
	
	-- Add gem information
	local gems = self:GetGemInfoFromLink(link)
	local socketCount = self:GetSocketCountFromLink(link)
	
	if socketCount > 0 then
		local gemmedCount = #gems
		if gemmedCount == socketCount then
			tooltip:AddLine(EnchantCheckConstants.UI.COLORS.GOOD .. "✓ All sockets filled (" .. gemmedCount .. "/" .. socketCount .. ")" .. EnchantCheckConstants.UI.COLORS.RESET, 1, 1, 1)
		else
			tooltip:AddLine(EnchantCheckConstants.UI.COLORS.WARNING .. "◐ Sockets: " .. gemmedCount .. "/" .. socketCount .. EnchantCheckConstants.UI.COLORS.RESET, 1, 1, 1)
		end
		
		-- List gems
		for i, gemName in ipairs(gems) do
			tooltip:AddLine("  " .. EnchantCheckConstants.UI.COLORS.INFO .. gemName .. EnchantCheckConstants.UI.COLORS.RESET, 1, 1, 1)
		end
	end
	
	-- Add item level context if this is equipped gear
	if slot then
		local currentIlvl = self:GetActualItemLevel(link)
		local playerLevel = UnitLevel("player")
		local contentType = self:DetectContentType(currentIlvl)
		
		-- Show context for endgame players
		if playerLevel >= EnchantCheckConstants.MAX_LEVEL then
			local reqIlvl = EnchantCheckConstants.CONTENT_ILVL_REQUIREMENTS[contentType] or 0
			if currentIlvl < reqIlvl then
				tooltip:AddLine(EnchantCheckConstants.UI.COLORS.WARNING .. "Below " .. contentType .. " recommended (" .. reqIlvl .. ")" .. EnchantCheckConstants.UI.COLORS.RESET, 1, 1, 1)
			end
		end
	end
end

----------------------------------------------
-- Visual Enhancement Functions
----------------------------------------------

function EnchantCheck:GetColorForSeverity(severity)
	-- Return default color if constants not loaded
	if not EnchantCheckConstants or not EnchantCheckConstants.UI or not EnchantCheckConstants.UI.COLORS or not EnchantCheckConstants.UI.SEVERITY then
		return ""
	end
	
	if not self:GetSetting("colorCodeSeverity") then
		return EnchantCheckConstants.UI.COLORS.RESET
	end
	
	if severity == EnchantCheckConstants.UI.SEVERITY.GOOD then
		return EnchantCheckConstants.UI.COLORS.GOOD
	elseif severity == EnchantCheckConstants.UI.SEVERITY.INFO then
		return EnchantCheckConstants.UI.COLORS.INFO
	elseif severity == EnchantCheckConstants.UI.SEVERITY.WARNING then
		return EnchantCheckConstants.UI.COLORS.WARNING
	elseif severity == EnchantCheckConstants.UI.SEVERITY.ERROR then
		return EnchantCheckConstants.UI.COLORS.ERROR
	else
		return EnchantCheckConstants.UI.COLORS.RESET
	end
end

function EnchantCheck:FormatMessage(message, severity)
	local color = self:GetColorForSeverity(severity)
	local reset = EnchantCheckConstants and EnchantCheckConstants.UI and EnchantCheckConstants.UI.COLORS and EnchantCheckConstants.UI.COLORS.RESET or "|r"
	return color .. message .. reset
end

function EnchantCheck:ShowProgressUpdate(current, total, message)
	if not self:GetSetting("showProgressBar") then
		return
	end
	
	local percentage = math.floor((current / total) * 100)
	local progressBar = "["
	local barLength = 20
	local filledLength = math.floor((current / total) * barLength)
	
	for i = 1, barLength do
		if i <= filledLength then
			progressBar = progressBar .. "="
		else
			progressBar = progressBar .. "-"
		end
	end
	progressBar = progressBar .. "]"
	
	local progressMessage = string.format("%s %s %d%% (%d/%d)", 
		message or "Scanning", progressBar, percentage, current, total)
	
	self:Printf("%s", self:FormatMessage(progressMessage, EnchantCheckConstants.UI.SEVERITY.INFO))
end

function EnchantCheck:PlayNotificationSound()
	if not self:GetSetting("enableSounds") then
		return
	end
	
	PlaySound(SOUNDKIT.ALARM_CLOCK_WARNING_3, self:GetSetting("soundChannel"))
end

----------------------------------------------
-- Helper Functions for CheckGear
----------------------------------------------

function EnchantCheck:ProcessItemData(item, slot, itemLink, itemName, itemRarity, itemSubType)
	if not item or not item.link then
		self:Debug(d_warn, "ProcessItemData called with invalid item")
		return false
	end
	
	-- Check cache first
	local cachedData = EnchantCheckCache and EnchantCheckCache:GetItemData(item.link) or nil
	if cachedData then
		-- Apply cached data to item
		for key, value in pairs(cachedData) do
			item[key] = value
		end
		
		-- Still need to check two-handed status for this slot
		local twoHanded = false
		if slot == 16 and itemSubType and CheckOffHand then -- MAINHAND
			twoHanded = not CheckOffHand[itemSubType]
		end
		return twoHanded
	end
	
	local _, itemString = self:GetItemLinkInfo(item.link)
	if not itemString then
		self:Debug(d_warn, "Failed to get item string for slot %d", slot)
		return false
	end
	
	local ids = self:StringSplit(":", itemString)
	if not ids or #ids < 6 then
		self:Debug(d_warn, "Invalid item string format for slot %d", slot)
		return false
	end
	
	-- Parse item string components with error handling
	local enchant = self:SplitValue(ids[2] or "0")
	local gems = {
		self:SplitValue(ids[3] or "0"),
		self:SplitValue(ids[4] or "0"),
		self:SplitValue(ids[5] or "0"),
		self:SplitValue(ids[6] or "0")
	}
	
	-- Count gems efficiently
	item.gems = 0
	for _, gemId in ipairs(gems) do
		if gemId > 0 then
			item.gems = item.gems + 1
		end
	end
	
	-- Set item properties with safe defaults
	item.rarity = itemRarity or 0
	item.enchant = enchant or 0
	item.level = self:GetActualItemLevel(item.link) or 0
	
	-- Debug: warn if item level is 0
	if item.level == 0 then
		self:Debug(d_warn, "Warning: Item level is 0 for slot %d (%s)", slot, item.link or "no link")
	end
	
	-- Safely get item stats
	local success, stats = pcall(C_Item.GetItemStats, item.link)
	item.stats = (success and stats) and stats or {}
	
	-- Count sockets efficiently
	item.sockets = 0
	for label in pairs(item.stats) do
		if label and label:find("EMPTY_SOCKET_", 1, true) then -- faster than regex
			item.sockets = item.sockets + 1
		end
	end
	
	-- Cache the processed data
	local dataToCache = {
		gems = item.gems,
		rarity = item.rarity,
		enchant = item.enchant,
		level = item.level,
		stats = item.stats,
		sockets = item.sockets
	}
	if EnchantCheckCache then
		EnchantCheckCache:SetItemData(item.link, dataToCache)
	end
	
	-- Check if two-handed weapon
	local twoHanded = false
	if slot == INVSLOT_MAINHAND and itemSubType and CheckOffHand then
		twoHanded = not CheckOffHand[itemSubType]
	end
	
	return twoHanded
end

function EnchantCheck:CheckMissingItems(items, twoHanded)
	local missingItems = {}
	local hasMissingItems = false
	
	for slot = 1, EnchantCheckConstants.EQUIPMENT_SLOTS.TOTAL do
		if not items[slot].link and not items[slot].id then
			if CheckSlotMissing[slot] and ((slot ~= 17) or not twoHanded) then -- 17 = OFFHAND
				table.insert(missingItems, slot)
				hasMissingItems = true
			end
		end
	end
	
	return missingItems, hasMissingItems
end

function EnchantCheck:CheckMissingEnchants(items, avgItemLevel, contentType)
	local missingEnchants = {}
	local hasMissingEnchants = false
	
	for slot = 1, EnchantCheckConstants.EQUIPMENT_SLOTS.TOTAL do
		local item = items[slot]
		if item.link and (item.enchant == 0) then
			-- Use smart notification system to determine if we should warn
			if self:ShouldWarnAboutSlot(slot, contentType, avgItemLevel) then
				-- Use modern API with fallback
				local itemType
				if C_Item and C_Item.GetItemInfo then
					itemType = select(6, C_Item.GetItemInfo(item.link))
				else
					itemType = select(6, GetItemInfo(item.link))
				end
				
				if not (libItemUpgrade:IsArtifact(item.link) or (slot == 17 and itemType ~= WEAPON)) then -- 17 = OFFHAND
					table.insert(missingEnchants, slot)
					hasMissingEnchants = true
				end
			end
		end
	end
	
	return missingEnchants, hasMissingEnchants
end

function EnchantCheck:CheckMissingGems(items)
	local missingGems = {}
	local hasMissingGems = false
	
	for slot = 1, EnchantCheckConstants.EQUIPMENT_SLOTS.TOTAL do
		local item = items[slot]
		if item.link and item.gems < item.sockets then
			table.insert(missingGems, slot)
			hasMissingGems = true
		end
	end
	
	return missingGems, hasMissingGems
end

function EnchantCheck:CalculateItemLevels(items, twoHanded)
	local itemLevelMin = 0
	local itemLevelMax = 0
	local itemLevelSum = 0
	local lowLevelItems = {}
	
	for slot = 1, EnchantCheckConstants.EQUIPMENT_SLOTS.TOTAL do
		local item = items[slot]
		if item.link and (slot ~= 4) and (slot ~= 19) and item.level and item.level > 0 then -- 4 = BODY, 19 = TABARD
			if item.level < itemLevelMin or itemLevelMin == 0 then
				itemLevelMin = item.level
			end
			if item.level > itemLevelMax then
				itemLevelMax = item.level
			end
			itemLevelSum = itemLevelSum + item.level
		end
	end
	
	-- Calculate average item level
	local avgItemLevel = 0
	if itemLevelSum and itemLevelSum > 0 then
		if twoHanded then
			local divisor = EnchantCheckConstants.EQUIPMENT_SLOTS.TWO_HANDED_COUNT
			if divisor and divisor > 0 then
				avgItemLevel = itemLevelSum / divisor
			end
		else
			local divisor = EnchantCheckConstants.EQUIPMENT_SLOTS.ONE_HANDED_COUNT
			if divisor and divisor > 0 then
				avgItemLevel = itemLevelSum / divisor
			end
		end
	end
	
	-- Check for extremely low item levels
	for slot = 1, EnchantCheckConstants.EQUIPMENT_SLOTS.TOTAL do
		local item = items[slot]
		if item.link and item.level and item.level > 0 then
			local shouldWarn = (item.level < avgItemLevel * EnchantCheckConstants.ITEM_LEVEL.LOW_THRESHOLD_MULTIPLIER) and
				(slot ~= 4) and (slot ~= 19) -- 4 = BODY, 19 = TABARD
			
			-- Check heirloom setting
			if self:GetSetting("ignoreHeirlooms") and item.rarity == EnchantCheckConstants.ITEM_LEVEL.HEIRLOOM_RARITY then
				shouldWarn = false
			end
			
			if shouldWarn then
				table.insert(lowLevelItems, {slot = slot, link = item.link})
			end
		end
	end
	
	return avgItemLevel, itemLevelMin, itemLevelMax, lowLevelItems
end

function EnchantCheck:GenerateReport(unit, avgItemLevel, itemLevelMin, itemLevelMax, lowLevelItems, missingItems, hasMissingItems, missingGems, hasMissingGems, missingEnchants, hasMissingEnchants, contentType)
	local report = {}
	local warnings = {}
	local items_state = true
	local gems_state = true
	local enchants_state = true
	local hasAnyIssues = false
	
	-- Header with role and content context
	table.insert(report, "------------")
	local displayClass, class = UnitClass(unit)
	local name = UnitName(unit)
	local classColor = ClassColor[class] or "FFFFFF" -- fallback to white
	table.insert(report, string.format(L["ENCHANT_REPORT_HEADER"],
		"|cff"..classColor..name.."|cffFFFFFF",
		UnitLevel(unit), "|cff"..classColor..displayClass.."|cffFFFFFF"))
	
	-- Add context information with enhanced formatting
	local contextMsg = string.format("%s Content", contentType)
	if EnchantCheckConstants and EnchantCheckConstants.UI and EnchantCheckConstants.UI.SEVERITY then
		table.insert(report, self:FormatMessage(contextMsg, EnchantCheckConstants.UI.SEVERITY.INFO))
	else
		table.insert(report, contextMsg)
	end
	
	-- Average item level with color coding
	local ilvlMsg = string.format(L["AVG_ITEM_LEVEL"], floor(avgItemLevel or 0), itemLevelMin or 0, itemLevelMax or 0)
	local ilvlSeverity = EnchantCheckConstants and EnchantCheckConstants.UI and EnchantCheckConstants.UI.SEVERITY and EnchantCheckConstants.UI.SEVERITY.GOOD or nil
	local minItemLevel = self:GetSetting("minItemLevelForWarnings")
	if avgItemLevel and minItemLevel and avgItemLevel < minItemLevel then
		ilvlSeverity = EnchantCheckConstants and EnchantCheckConstants.UI and EnchantCheckConstants.UI.SEVERITY and EnchantCheckConstants.UI.SEVERITY.WARNING or nil
	end
	if ilvlSeverity then
		table.insert(report, self:FormatMessage(ilvlMsg, ilvlSeverity))
	else
		table.insert(report, ilvlMsg)
	end
	if EnchantCheckItemsFrame and EnchantCheckItemsFrame.titleInfoFont then
		EnchantCheckItemsFrame.titleInfoFont:SetText(string.format("%d (%d -> %d)", floor(avgItemLevel or 0), itemLevelMin or 0, itemLevelMax or 0))
	end
	
	-- Check for extremely low item levels
	if #lowLevelItems > 0 and self:GetSetting("warnLowItemLevel") then
		for _, itemData in ipairs(lowLevelItems) do
			local lowItemMsg = L["LOW_ITEM_LEVEL"] .. " " .. itemData.link
			local formattedMsg = self:FormatMessage(lowItemMsg, EnchantCheckConstants.UI.SEVERITY.ERROR)
			table.insert(report, formattedMsg)
			table.insert(warnings, formattedMsg)
			EnchantCheckItemsFrame.messages:AddMessage(formattedMsg)
			items_state = false
			hasAnyIssues = true
		end
	end
	
	-- Check for missing items
	if hasMissingItems and self:GetSetting("warnMissingItems") then
		local s = ""
		for k, slot in ipairs(missingItems) do
			s = s .. L["INVSLOT_"..slot]
			if k < #missingItems then
				s = s .. ", "
			end
		end
		local missingItemsMsg = L["MISSING_ITEMS"] .. " " .. s
		local formattedMsg = self:FormatMessage(missingItemsMsg, EnchantCheckConstants.UI.SEVERITY.ERROR)
		table.insert(report, formattedMsg)
		table.insert(warnings, formattedMsg)
		EnchantCheckItemsFrame.messages:AddMessage(formattedMsg)
		items_state = false
		hasAnyIssues = true
	end
	
	-- Check for missing gems
	if hasMissingGems and self:GetSetting("warnMissingGems") then
		local s = ""
		for k, slot in ipairs(missingGems) do
			s = s .. L["INVSLOT_"..slot]
			if k < #missingGems then
				s = s .. ", "
			end
		end
		local missingGemsMsg = L["MISSING_GEMS"] .. " " .. s
		local formattedMsg = self:FormatMessage(missingGemsMsg, EnchantCheckConstants.UI.SEVERITY.WARNING)
		table.insert(report, formattedMsg)
		table.insert(warnings, formattedMsg)
		EnchantCheckGemsFrame.messages:AddMessage(formattedMsg)
		gems_state = false
		hasAnyIssues = true
	else
		local properGemsMsg = self:FormatMessage(L["PROPER_GEMS"], EnchantCheckConstants.UI.SEVERITY.GOOD)
		table.insert(report, properGemsMsg)
		EnchantCheckGemsFrame.messages:AddMessage(properGemsMsg)
	end
	
	-- Check for missing enchants
	if hasMissingEnchants and self:GetSetting("warnMissingEnchants") then
		local s = ""
		for k, slot in ipairs(missingEnchants) do
			s = s .. L["INVSLOT_"..slot]
			if k < #missingEnchants then
				s = s .. ", "
			end
		end
		local missingEnchantsMsg = L["MISSING_ENCHANTS"] .. " " .. s
		local formattedMsg = self:FormatMessage(missingEnchantsMsg, EnchantCheckConstants.UI.SEVERITY.WARNING)
		table.insert(report, formattedMsg)
		table.insert(warnings, formattedMsg)
		EnchantCheckEnchantsFrame.messages:AddMessage(formattedMsg)
		enchants_state = false
		hasAnyIssues = true
	else
		local properEnchantsMsg = self:FormatMessage(L["PROPER_ENCHANTS"], EnchantCheckConstants.UI.SEVERITY.GOOD)
		table.insert(report, properEnchantsMsg)
		EnchantCheckEnchantsFrame.messages:AddMessage(properEnchantsMsg)
	end
	
	-- Footer
	table.insert(report, "------------")
	
	-- Play notification sound if there are issues
	if hasAnyIssues then
		self:PlayNotificationSound()
	end
	
	return report, warnings, items_state, gems_state, enchants_state
end

----------------------------------------------
-- Gear Checking System
----------------------------------------------
function EnchantCheck:CheckGear(unit, items, iter, printWarnings)
	-- Check if constants are loaded
	if not EnchantCheckConstants then
		self:Debug(d_warn, "EnchantCheckConstants not loaded, cannot check gear")
		if EnchantCheckFrame and EnchantCheckFrame:IsShown() then
			EnchantCheckFrame:Hide()
		end
		self:Print("|cffFF0000Error: Addon not fully loaded. Please restart World of Warcraft.|r")
		return
	end
	
	local isInspect = not UnitIsUnit("player", unit)
	local doRescan = false
	local twoHanded = false
	
	-- Initialize parameters
	if not items then items = {} end
	if not iter then iter = 0 end
	
	-- Clear previous scan data to free memory
	if iter == 0 then
		collectgarbage("collect")
	end
	
	-- Set up head enchant check for Dragonflight
	if not isInspect and EnchantCheckConstants and EnchantCheckConstants.QUEST_IDS and EnchantCheckConstants.EXPANSIONS then
		if C_QuestLog.IsQuestFlaggedCompleted(EnchantCheckConstants.QUEST_IDS.HEAD_ENCHANT_UNLOCK) and GetExpansionLevel() == EnchantCheckConstants.EXPANSIONS.DRAGONFLIGHT then
			CheckSlotEnchant[1] = true -- HEAD
		end
	end
	
	self.scanInProgress = true
	libItemUpgrade:CleanCache()
	
	-- Batch process items for better performance
	local itemsToProcess = {}
	local itemsReady = 0
	local totalItems = 0
	
	-- First pass: collect item data and check readiness
	for slot = 1, EnchantCheckConstants.EQUIPMENT_SLOTS.TOTAL do
		local item = {
			gems = 0,
			rarity = 0,
			enchant = 0,
			level = 0,
			stats = {},
			sockets = 0
		}
		item.id = GetInventoryItemID(unit, slot)
		item.link = GetInventoryItemLink(unit, slot)
		
		if item.link then
			totalItems = totalItems + 1
			-- Use modern C_Item API with fallback
			local success, itemName, itemLink, itemRarity, itemLevel, itemMinLevel,
				itemType, itemSubType, itemStackCount, itemEquipLoc,
				itemTexture, itemSellPrice
			
			if C_Item and C_Item.GetItemInfo then
				success, itemName, itemLink, itemRarity, itemLevel, itemMinLevel,
					itemType, itemSubType, itemStackCount, itemEquipLoc,
					itemTexture, itemSellPrice = pcall(C_Item.GetItemInfo, item.link)
			else
				-- Fallback to legacy API
				success, itemName, itemLink, itemRarity, itemLevel, itemMinLevel,
					itemType, itemSubType, itemStackCount, itemEquipLoc,
					itemTexture, itemSellPrice = pcall(GetItemInfo, item.link)
			end
			
			if success and itemLink then
				itemsReady = itemsReady + 1
				itemsToProcess[slot] = {
					item = item,
					itemName = itemName,
					itemLink = itemLink, 
					itemRarity = itemRarity,
					itemSubType = itemSubType
				}
			else
				-- Item data not ready
				doRescan = true
			end
		elseif item.id then
			-- Item ID exists but link not ready
			doRescan = true
		end
		
		items[slot] = item
	end
	
	-- Handle rescan if needed
	if doRescan then
		if iter < self.db.profile.rescanCount then
			local rescanMsg = string.format(L["RESCAN"] .. " (%d/%d items ready)", itemsReady, totalItems)
			self:Debug(d_info, "%s", self:FormatMessage(rescanMsg, EnchantCheckConstants.UI.SEVERITY.WARNING))
			-- Instead of using timer, collect all item data first
			for i = 1, 5 do -- Force-load item data with multiple attempts
				local allReady = true
				for slot = 1, EnchantCheckConstants.EQUIPMENT_SLOTS.TOTAL do
					local link = GetInventoryItemLink(unit, slot)
					if link then
						local itemName = GetItemInfo(link)
						if not itemName then
							allReady = false
							-- Force request item data
							local itemID = GetItemInfoFromHyperlink(link)
							if itemID and C_Item and C_Item.RequestLoadItemDataByID then
								C_Item.RequestLoadItemDataByID(itemID)
							end
						end
					end
				end
				if allReady then break end
			end
			-- Continue immediately without timer
			self:CheckGear(unit, items, iter+1)
			return
		else
			local incompleteMsg = string.format(L["SCAN_INCOMPLETE"] .. " (%d/%d items ready)", itemsReady, totalItems)
			self:Debug(d_warn, "%s", self:FormatMessage(incompleteMsg, EnchantCheckConstants.UI.SEVERITY.ERROR))
			self.scanInProgress = nil
			return
		end
	end
	
	-- Show progress update
	if totalItems > 0 then
		self:ShowProgressUpdate(itemsReady, totalItems, "Processing items")
	end
	
	-- Second pass: process ready items in batches
	for slot, itemData in pairs(itemsToProcess) do
		local itemTwoHanded = self:ProcessItemData(
			itemData.item, slot, itemData.itemLink, 
			itemData.itemName, itemData.itemRarity, itemData.itemSubType
		)
		if itemTwoHanded then
			twoHanded = true
		end
	end
	
	-- Clear temporary processing data to free memory
	itemsToProcess = nil
	
	-- Get player context for smart notifications
	local avgItemLevel, itemLevelMin, itemLevelMax, lowLevelItems = self:CalculateItemLevels(items, twoHanded)
	local contentType = self:DetectContentType(avgItemLevel)
	
	-- Use helper functions to check for issues with smart filtering
	local missingItems, hasMissingItems = self:CheckMissingItems(items, twoHanded)
	local missingEnchants, hasMissingEnchants = self:CheckMissingEnchants(items, avgItemLevel, contentType)
	local missingGems, hasMissingGems = self:CheckMissingGems(items)
	
	-- Generate enhanced report with context
	local report, warnings, items_state, gems_state, enchants_state = self:GenerateReport(
		unit, avgItemLevel, itemLevelMin, itemLevelMax, lowLevelItems,
		missingItems, hasMissingItems, missingGems, hasMissingGems, 
		missingEnchants, hasMissingEnchants, contentType
	)
	
	-- Set UI frame states
	self:SetCheckFrame(EnchantCheckItemsFrame, items_state)
	self:SetCheckFrame(EnchantCheckGemsFrame, gems_state)
	self:SetCheckFrame(EnchantCheckEnchantsFrame, enchants_state)
	
	-- Print warnings if requested
	if printWarnings then
		for _, warning in ipairs(warnings) do
			self:Print(warning)
		end
	end
	
	-- Final memory cleanup
	report = nil
	warnings = nil
	lowLevelItems = nil
	collectgarbage("step", 100) -- Incremental garbage collection
	
	self.scanInProgress = nil
end

----------------------------------------------
-- CheckCharacter()
----------------------------------------------
function EnchantCheck:CheckCharacter()
	if not self.scanInProgress then
		if EnchantCheckFrame:GetParent() ~= CharacterModelScene then
			EnchantCheckFrame:Hide()
			EnchantCheckFrame:SetParent(CharacterModelScene)
			EnchantCheckFrame:ClearAllPoints()
			EnchantCheckFrame:SetAllPoints()
		elseif EnchantCheckFrame:IsShown() then
			EnchantCheckFrame:Hide()
			return
		end
		EnchantCheck:ClearCheckFrame(EnchantCheckItemsFrame)
		EnchantCheck:ClearCheckFrame(EnchantCheckGemsFrame)
		EnchantCheck:ClearCheckFrame(EnchantCheckEnchantsFrame)
		EnchantCheckFrame:Show()

		self:CheckGear("player")
	end
end

----------------------------------------------
-- CheckInspected()
----------------------------------------------
function EnchantCheck:CheckInspected()
	if InspectFrame.unit and CanInspect(InspectFrame.unit) then
		if not self.scanInProgress then
			if EnchantCheckFrame:GetParent() ~= InspectModelFrame then
				EnchantCheckFrame:Hide()
				EnchantCheckFrame:SetParent(InspectModelFrame)
				EnchantCheckFrame:ClearAllPoints()
				EnchantCheckFrame:SetAllPoints()
			elseif EnchantCheckFrame:IsShown() then
				EnchantCheckFrame:Hide()
				return
			end
			EnchantCheck:ClearCheckFrame(EnchantCheckItemsFrame)
			EnchantCheck:ClearCheckFrame(EnchantCheckGemsFrame)
			EnchantCheck:ClearCheckFrame(EnchantCheckEnchantsFrame)
			EnchantCheckFrame:Show()

			self:Debug(d_info, "|cff00FF00" .. L["SCAN"] .. "|cffFFFFFF")
			NotifyInspect(InspectFrame.unit)
			self.pendingInspection = true
		end
	else
		self:Debug(d_warn, "No inspected unit found!")
	end
end

----------------------------------------------
-- ClearCheckFrame(frame)
----------------------------------------------
function EnchantCheck:ClearCheckFrame(frame)
	-- clean up
	frame.titleFont:SetTextColor(1, 1, 0)
	frame.titleInfoFont:SetText("")
	frame.readyTex:Hide()
	frame.notReadyTex:Hide()
	frame.waitingTex:Show()
	frame.messages:Clear()
end

----------------------------------------------
-- SetCheckFrame(frame, value)
-- value: nil/false - red, 1/true - green, anything else - yellow
----------------------------------------------
function EnchantCheck:SetCheckFrame(frame, value)
	if value == 1 or value == true then
		frame.titleFont:SetTextColor(0, 1, 0)
		frame.readyTex:Show()
		frame.notReadyTex:Hide()
		frame.waitingTex:Hide()
	elseif not value then
		frame.titleFont:SetTextColor(1, 0, 0)
		frame.readyTex:Hide()
		frame.notReadyTex:Show()
		frame.waitingTex:Hide()
	else
		frame.titleFont:SetTextColor(1, 1, 0)
		frame.readyTex:Hide()
		frame.notReadyTex:Hide()
		frame.waitingTex:Show()
	end
end

----------------------------------------------
-- INSPECT_READY()
----------------------------------------------
function EnchantCheck:INSPECT_READY(event, guid)
	-- inspect frame is load-on-demand, add buttons once it is loaded
	if not InspectFrameEnchantCheckButton:GetParent() and InspectPaperDollFrame then
		local isElvUILoaded = C_AddOns.IsAddOnLoaded("ElvUI");
		local offset = isElvUILoaded and EnchantCheckConstants.UI.ELVUI_BUTTON_OFFSET.INSPECT_FRAME or EnchantCheckConstants.UI.DEFAULT_BUTTON_OFFSET.INSPECT_FRAME
		InspectFrameEnchantCheckButton:SetParent(InspectPaperDollFrame);
		InspectFrameEnchantCheckButton:ClearAllPoints();
		InspectFrameEnchantCheckButton:SetPoint("LEFT", InspectPaperDollFrame, "BOTTOMLEFT", offset.x, offset.y);
		InspectFrameEnchantCheckButton:Show();
		self:HookScript(InspectFrame, "OnHide", "InspectFrame_OnHide");

		--self:Debug(d_notice, "Added inspect buttons")
	end

	--self:Debug(d_notice, "INSPECT_READY")

	if self.pendingInspection and (UnitGUID(InspectFrame.unit) == guid) then
		if EnchantCheckFrame:IsShown() then
			self:CheckGear(InspectFrame.unit)
		end
		self.pendingInspection = nil
	end
end

----------------------------------------------
-- UNIT_INVENTORY_CHANGED()
----------------------------------------------
function EnchantCheck:UNIT_INVENTORY_CHANGED(event, unit)
	-- Clear item cache when inventory changes
	if UnitIsUnit("player", unit) then
		if EnchantCheckCache then
			EnchantCheckCache:ClearItemCache()
		end
		-- Update minimap button status
		self:UpdateMinimapButtonStatus()
	end
	
	if EnchantCheckFrame:IsShown() then
		EnchantCheckFrame:Hide()
		EnchantCheck:ClearCheckFrame(EnchantCheckItemsFrame)
		EnchantCheck:ClearCheckFrame(EnchantCheckGemsFrame)
		EnchantCheck:ClearCheckFrame(EnchantCheckEnchantsFrame)
	end
end

----------------------------------------------
-- InspectFrame_OnHide()
----------------------------------------------
function EnchantCheck:InspectFrame_OnHide()
	if EnchantCheckFrame:IsShown() then
		EnchantCheckFrame:Hide()
		EnchantCheck:ClearCheckFrame(EnchantCheckItemsFrame)
		EnchantCheck:ClearCheckFrame(EnchantCheckGemsFrame)
		EnchantCheck:ClearCheckFrame(EnchantCheckEnchantsFrame)
	end
end

----------------------------------------------
-- PLAYER_ENTERING_WORLD()
----------------------------------------------
function EnchantCheck:PLAYER_ENTERING_WORLD(event)
	local inInstance, instanceType = IsInInstance()
	if inInstance and (instanceType ~= "none") and (UnitLevel("player") == MAX_LEVEL) then
		self:CheckGear("player", nil, nil, true)
	end
end

----------------------------------------------
-- PLAYER_LOGIN()
----------------------------------------------
function EnchantCheck:PLAYER_LOGIN(event)
	local isElvUILoaded = C_AddOns.IsAddOnLoaded("ElvUI");
	local checkButton = CharacterFrameEnchantCheckButton;

	if isElvUILoaded and checkButton then
		local offset = EnchantCheckConstants.UI.ELVUI_BUTTON_OFFSET.CHARACTER_FRAME
		checkButton:ClearAllPoints();
		checkButton:SetPoint("RIGHT", checkButton:GetParent(), "BOTTOMRIGHT", offset.x, offset.y);
	end

	-- Setup tooltip hooks now that all frames should be available
	if self.needsTooltipHooking then
		self:SetupTooltipHooks()
	end
end
