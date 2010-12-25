local version = "2.21";
local GUILD_BANK_CONTAINER = -2;

-- dump output to DEFAULT_CHAT_FRAME
function Highlight_OutputMessage(msg)
	if (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage(msg);
	end
end

-- Entry point for highlight
function HighlightLoad()
	SlashCmdList["HIGHLIGHT"] = Highlight_Slash;
	SLASH_HIGHLIGHT1 = "/highlight";
	SLASH_HIGHLIGHT2 = "/hl";

    -- Indicate version at load time
	Highlight_OutputMessage(string.format("|cffffffffHighlight|cffff9900 %s|cffffffff loaded", version))
end

-- Main function for highlight
function Highlight_Slash(search)
	
	Highlight_EnumerateProfessions()

	local OldText = Highlight_EditBox:GetText()
	-- ensure the bags are opened
	OpenAllBags(false)
	OpenAllBags(true)

	-- get the number of entries
	local found = Highlight_Search(search, true, true)

	-- update the edit box
	if (search == "") then
		Highlight_EditBox:SetFocus()
		Highlight_EditBox:SetText(OldText)
		Highlight_EditBox:HighlightText()
	else
		Highlight_EditBox:SetText(search)
	end

	local messagetext
	-- return the output message
	if (search == "") then
        	-- default text
        	outmessagetext = "Highlight prompt: /highlight <criterion> or /hl <criterion>, examples include '/hl rare' for all rare items and '/hl stack' to display all complete stacks"
	else
        if (found > 0) then
        	-- correct the suffix if more that one entries found
            local suffix = "entry"
            if (found > 1) then
            	suffix = "entries"
            end
        	outmessagetext = string.format("Highlight looking for: %s found %s %s", search, found, suffix)
    	else
        	-- no items found
        	outmessagetext = string.format("No items found that match required criterion: %s", search)
        end
   	end
	
	Highlight_OutputMessage(outmessagetext)
end

-- the core bag search mechanism
local BagCount = 0
local GuildBankCount = 0
local SearchActive = false
function Highlight_Search(search, SearchBags, SearchGuildBank)

	local ItemsFound = 0
    	-- no point searching for a blank string
	if (search == "") then
		if (SearchActive) then
			Highlight_ClearFilter()
		end
		Highlight_Count:SetText("---")
		SearchActive = false
    	else
		if (SearchBags) then
			BagCount = Highlight_FilterBags(search)
		end
		if (SearchGuildBank) then
			GuildBankCount = Highlight_FilterGuildBank(search)
		end
		ItemsFound = BagCount + GuildBankCount
        	Highlight_Count:SetText(string.format("%3d", ItemsFound))
		SearchActive = true
    	end

    	-- return the total number of items that fit the search criterion
	return ItemsFound
end



local RedrawGuildBank = false
local RedrawBags = false
function Highlight_OnEvent(self, event, ...)
--	local arg1, arg2 = ...;
	if (event == "VARIABLES_LOADED") then 
		HighlightLoad();
	elseif (event == "GUILDBANKBAGSLOTS_CHANGED") then
		Highlight_RequestRedraw(false);
	elseif (event == "GUILDBANK_ITEM_LOCK_CHANGED") then
		Highlight_RequestRedraw(false);
	elseif (event == "BAG_UPDATE") then
		Highlight_RequestRedraw(true);
	elseif (event == "BANKFRAME_OPENED") then 
		Highlight_RequestRedraw(true);

-- force the tradeskill reagent list to refresh
	elseif (event == "SKILL_LINES_CHANGED") then 
		Highlight_ResetTradeskills();
-- register redraw events
	elseif (event == "PLAYER_ENTERING_WORLD") then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD");
		self:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED");
		self:RegisterEvent("GUILDBANK_ITEM_LOCK_CHANGED");
		self:RegisterEvent("BAG_UPDATE");
		self:RegisterEvent("BANKFRAME_OPENED");
		hooksecurefunc("ContainerFrame_OnShow",
			function(...)
				Highlight_RequestRedraw(true);
			end);
	end
end

-- if we do a redraw immediately, it will get overwritten,
-- so instead wait for the next update event to trigger our refresh
local RedrawBags = false
local RedrawGuildBank = false
function Highlight_RequestRedraw(ForBags)

	local search = Highlight_EditBox:GetText()
	if (search ~= "") then
		if (ForBags) then
			RedrawBags = true
		else
			RedrawGuildBank = true
		end

		Highlight_EditBox:SetScript("OnUpdate", Highlight_DoRedraw);
	end
end
-- triggered off the OnUpdate event
function Highlight_DoRedraw(self, elapsed)
	-- immediately clear the OnUpdate event so it's only called once
	Highlight_EditBox:SetScript("OnUpdate", nil)
	local search = Highlight_EditBox:GetText()
	Highlight_Search(search, RedrawBags, RedrawGuildBank)
	RedrawBags = false
	RedrawGuildBank = false
end


-- lookup for rarity type
function Highlight_ConvertItemRarityToString(itemType)

    local itemTypeString = "unknown";

    if (itemType ~= nil) then
        if (itemType == 1) then
            itemTypeString = "white common"
        elseif (itemType == 2) then
            itemTypeString = "green uncommon"
        elseif (itemType == 3) then
            itemTypeString = "blue rare"
        elseif (itemType == 4) then
            itemTypeString = "purple epic"
        elseif (itemType == 5) then
            itemTypeString = "orange legendary"
        elseif (itemType == 6) then
            itemTypeString = "gold artifact heirloom"
        else
            itemTypeString = "gray grey poor junk trash"
        end
    end
    return itemTypeString;
end

-- toggle the graphics colour of the item
function Highlight_EnableBagItem(bag, slot, enable)

	local button

    -- allow Bankframe and ContainerFrame to be handled differently
    if (bag == BANK_CONTAINER) then
        button = getglobal("BankFrameItem"..slot.."IconTexture")
    elseif (bag == GUILD_BANK_CONTAINER) then
        index = mod(slot, NUM_SLOTS_PER_GUILDBANK_GROUP);
		if ( index == 0 ) then
			index = NUM_SLOTS_PER_GUILDBANK_GROUP;
		end
		column = ceil((slot-0.5)/NUM_SLOTS_PER_GUILDBANK_GROUP);
		button = getglobal("GuildBankColumn"..column.."Button"..index.."IconTexture")
    else
        button = getglobal("ContainerFrame"..bag.."Item"..slot.."IconTexture")
	end

    -- define the vertex colours
	if (enable == true) then
		button:SetVertexColor(1.0, 1.0, 1.0)
	else
		button:SetVertexColor(0.2, 0.2, 0.2)
	end
end

function Highlight_GetItemLink(bag, slot)
	if (bag == GUILD_BANK_CONTAINER) then
		if (GetGuildBankItemLink(GetCurrentGuildBankTab(), slot) ~= nil) then
			return GetGuildBankItemLink(GetCurrentGuildBankTab(), slot)
		end
	else
		return GetContainerItemLink(bag, slot)
	end
	return nil
end

-- 'Full' Stack check
function Highlight_StackCheck(bag, slot, search)

    local FullStack = false
    local stackstring = "stack"

    if (search == stackstring) then
		local stackSize
        local maxStackSize
		stackSize = Highlight_GetStackSize(bag, slot)
		maxStackSize = Highlight_GetMaxStackSize(bag, slot)
		if (stackSize ~= nil and maxStackSize ~= nil and maxStackSize > 1) then
			FullStack = (stackSize == maxStackSize)
		end
    end
    return FullStack
end

function Highlight_ParseComparison(search)
	local compareBegin
	local compareEnd
	compareBegin, compareEnd = string.find(search, "[=<>]+")
	if (compareBegin and compareEnd) then
		local typestr = string.sub(search, 1, compareBegin - 1)
		local comparestr = string.sub(search, compareBegin, compareEnd)
		local valuestr = string.sub(search, compareEnd + 1)

		if (typestr == "") then
			typestr = "$"
		end

--		Highlight_OutputMessage(string.format("type %s compare %s value %s", typestr, comparestr, valuestr))
		return typestr, comparestr, valuestr
	end
end

function Highlight_ValueCheck(bag, slot, search)

	local compareResult = false
	local valueType
	local compareType
	local compareTo
	local itemValue

	valueType, compareType, compareTo = Highlight_ParseComparison(search)
	if (compareTo) then
		compareTo = tonumber(compareTo)
	end
	if (valueType) then
		valueType = string.lower(valueType)
	end

	if (valueType and compareType and compareTo) then

		if (valueType == "$" or valueType == "cost" or valueType == "gold") then
			compareTo = math.floor(compareTo * 10000 + 0.5)
			itemValue = Highlight_GetVendorValue(bag, slot)

		elseif (valueType == "ilvl" or valueType == "itemlevel") then
			itemValue = Highlight_GetItemLevel(bag, slot)

		elseif (valueType == "lvl" or valueType == "level" or valueType == "rlvl" or valueType == "minlevel" or valueType == "minlvl") then
			itemValue = Highlight_GetMinLevel(bag, slot)

		elseif (valueType == "stack" or valueType == "count" or valueType == "size") then
			itemValue = Highlight_GetStackSize(bag, slot)

		end

		if (itemValue ~= nil) then
			if (string.find(compareType, "<") and itemValue < compareTo) then
				compareResult = true
			elseif (string.find(compareType, ">") and itemValue > compareTo) then
				compareResult = true
			elseif (string.find(compareType, "=") and itemValue == compareTo) then
				compareResult = true
			end
		end
	end
	return compareResult
end

function Highlight_GetStackSize(bag, slot)
	local itemCount
	if (bag == GUILD_BANK_CONTAINER) then
		_, itemCount = GetGuildBankItemInfo(GetCurrentGuildBankTab(), slot)
	else
		_, itemCount = GetContainerItemInfo(bag, slot)
	end
	return itemCount
end

function Highlight_GetMaxStackSize(bag, slot)
	local itemLink
	itemLink = Highlight_GetItemLink(bag, slot)
	if (itemLink ~= nil) then
		local maxSize
		_ , _, _,_ ,_ ,_, _, maxSize = GetItemInfo(itemLink)
		return maxSize
	end
	return nil
end

function Highlight_GetVendorValue(bag, slot)
	local itemLink
	itemLink = Highlight_GetItemLink(bag, slot)
	if (itemLink ~= nil) then

		local itemCount = Highlight_GetStackSize(bag, slot)
		local itemSellPrice
		_, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)

		if (itemSellPrice ~= nil) then
			return itemCount * tonumber(itemSellPrice)
		end
	end
	return nil
end

function Highlight_GetItemLevel(bag, slot)
	local itemLink
	itemLink = Highlight_GetItemLink(bag, slot)
	if (itemLink ~= nil) then

		local itemLevel
		_, _, _, itemLevel, _, _, _, _, _, _, _ = GetItemInfo(itemLink)
		return itemLevel

	end
	return nil
end

function Highlight_GetMinLevel(bag, slot)
	local itemLink
	itemLink = Highlight_GetItemLink(bag, slot)
	if (itemLink ~= nil) then

		local itemMinLevel
		_, _, _, _, itemMinLevel, _, _, _, _, _, _ = GetItemInfo(itemLink)
		return itemMinLevel

	end
	return nil
end


local ReagentList = {};
function Highlight_ReagentCheck(itemname, search)
--	Highlight_OutputMessage(string.format("item %s search %s", itemname, search))
	local description = ReagentList[itemname]
	if (description ~= nil) then
--		Highlight_OutputMessage(string.format("item %s found %s", itemname, description))
		return (string.find(description, search) ~= nil);
	end
	return false
end

local TradeSkillsLoaded = false
function Highlight_ResetTradeskills()
	TradeSkillsLoaded = false
end

function Highlight_EnumerateProfessions()
	if (not TradeSkillsLoaded) then
		ReagentList = {}
		local Professions =
		{
			"Alchemy",
			"Blacksmithing",
			"Cooking",
			"Enchanting",
			"Engineering",
			"First Aid",
			"Inscription",
			"Jewelcrafting",
			"Leatherworking",
			"Smelting",
			"Tailoring"
		}
		CloseTradeSkill()
		local index
		local profession
		for index,profession in pairs(Professions) do
			if IsUsableSpell(profession) then
				-- show profession screen
				CastSpellByName(profession)
				-- clear item filters
				SetTradeSkillInvSlotFilter(0, 0, nil)
				SetTradeSkillSubClassFilter(0, 0, nil)
				-- load all reagents for all recipes
				Highlight_EnumerateReagents(string.lower(profession))
				CloseTradeSkill()
--			else
--				Highlight_OutputMessage(string.format("profession not usable %s", profession))
			end
		end
		TradeSkillsLoaded = true;
	end
end

function Highlight_EnumerateReagents(professionName)
	local i, j
	local reagentName
	local skillname
	local skilltype
	local altVerb
	local tradeskillcount = GetNumTradeSkills()
	for i=1, tradeskillcount, 1 do
		skillname, skilltype, _, _, altVerb = GetTradeSkillInfo(i);
		if (skillname ~= nil and skilltype ~= "header") then
			local numReagents = GetTradeSkillNumReagents(i);

			if (not ReagentList[skillname]) then
				ReagentList[skillname] = professionName
			end

			if (not altVerb) then
				altVerb = "Create"
			end;
			for j=1, numReagents, 1 do
				local reagentName, _, _, _ = GetTradeSkillReagentInfo(i, j)
				if (reagentName ~= nil) then
					local description = ReagentList[reagentName]
					if (not description) then
						description = string.lower(altVerb) .. " craftable reagent "
					end;
					if (string.find(description, professionName) == nil) then
						description = description .. " " .. professionName
					end
					ReagentList[reagentName] = description
				end
			end;
		end;
	end;
	return 0;
end


-- See if the item in the bag slot has the required criteria
function Highlight_ItemIdentified(bag, slot, search)
	local identified = true;
	local itemname
    	local itemrarity
	local itemLevel
	local itemMinLevel
   	local itemsummary
	local itemtype
	local itemsubtype
	local itemSellPrice
	local customItemModifiers = ""
	local itemlink = nil

	itemlink = Highlight_GetItemLink(bag, slot)
	if (itemlink ~= nil) then
		itemname, itemlink, itemrarity, itemLevel , itemMinLevel , itemtype, itemsubtype, _, itemequiploc, _, itemSellPrice = GetItemInfo(itemlink)
	end

	if (itemequiploc ~= "") then
		customItemModifiers = "wearable "
	end

	-- can it be found ?
	--  check the following details for an item
	--  * its name
	--  * its rarity
	--  * its type
	--  * its sub type
	--  * its location
	--  * whether it's in a full stack (only works on keywork stack)
	--  * price
	if (itemname ~= nil and itemname ~= "") then
		-- split the search into parts seperated by white space
		for subsearch in string.lower(search):gmatch("%S+") do
			-- if it starts with a ! or ~
			local IsNegated = string.match(subsearch, "^[!~]")
			local subfound = true
			if IsNegated then
				-- if it's negated, we'll only look at what comes after the ~ or !
				subsearch = string.sub(subsearch, 2)
				-- but if there's nothing after it, don't negate it
				if subsearch == "" then
					IsNegated = false
				end
			end
			if ((string.find(string.lower(itemname), subsearch) == nil) and
				(string.find(Highlight_ConvertItemRarityToString(itemrarity), subsearch) == nil) and
				(string.find(string.lower(itemtype), subsearch) == nil) and
				(string.find(string.lower(itemsubtype), subsearch) == nil) and
				(string.find(string.lower(itemequiploc), subsearch) == nil) and
				(string.find(customItemModifiers, subsearch) == nil) and
				(not Highlight_ReagentCheck(itemname, subsearch)) and
				(not Highlight_StackCheck(bag, slot, subsearch)) and
				(not Highlight_ValueCheck(bag, slot, subsearch))) then
					subfound = false
			end
			-- if the subsearch is negated, we need to reverse the result
			if (IsNegated) then
				subfound = not subfound
			end
			if (not subfound) then
				identified = false
			end
		end
	end
	return identified;
end

function Highlight_GuildBankFrameVisible()
	return getglobal("GuildBankFrame") ~= nil and GuildBankFrame:IsVisible()
end

function Highlight_ClearFilter()
	local bag
	GuildBankCount = 0
	BagCount = 0
	-- reset the bag items
	for bag = BANK_CONTAINER, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS  do

		-- As each bag can have different slots, get the number of slots for the current bag
		local maxSlots = GetContainerNumSlots(bag)

		-- allow number of slots in a bag to be handled differently
		if (bag == BANK_CONTAINER) then
			maxSlots = NUM_BANKGENERIC_SLOTS
		end

		-- work through all bag slots
		for slot = 1, maxSlots do

			-- create tempbag variable to handle the required bag
			local tempbag = BANK_CONTAINER
			-- create tempalot variable to handle the required slot
			local tempslot = slot
			if (bag ~= BANK_CONTAINER) then
				tempbag = bag + 1
				tempslot  = (maxSlots + 1) - slot
			end

			-- hightlight the required item in the appropriate slot
			Highlight_EnableBagItem(tempbag, tempslot, true)
		end
	end
    	if (Highlight_GuildBankFrameVisible()) then
		local slot;
		for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB do
			-- highlight the required item in the appropriate slot
			Highlight_EnableBagItem(GUILD_BANK_CONTAINER, slot, true)
		end
	end
end

function Highlight_FilterBags(search)

	local count = 0

	-- work through every bag
	local bag
	for bag = BANK_CONTAINER, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do

		-- As each bag can have different slots, the get the number of slots for the current bag
		local maxSlots = GetContainerNumSlots(bag)

		if (bag == BANK_CONTAINER) then
			maxSlots = NUM_BANKGENERIC_SLOTS
		end

		-- work through all bag slots
		local slot;
		for slot = 1, maxSlots do
			if (GetContainerItemLink(bag, slot)) then

				-- Highlight the item or not
				local result = Highlight_CheckItem(bag, slot, maxSlots, search)

				if (result == 0 or result == 1) then
					count = count + result
				else
					-- Add appropriate error text
					Highlight_OutputMessage(result .. " in bag " .. bag)
				end
			end
		end
	end
	return count
end

function Highlight_FilterGuildBank(search)
	local count = 0
    -- guild bank filter
    if (Highlight_GuildBankFrameVisible()) then

		local slot;
		for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB do

			-- Highlight the item or not
			local result = Highlight_CheckItem(GUILD_BANK_CONTAINER, slot, MAX_GUILDBANK_SLOTS_PER_TAB, search)

			if (result == 0 or result == 1) then
				count = count + result
			else
				-- Add appropriate error text
				Highlight_OutputMessage(result .. " in guild bank")
			end
		end

	end
	return count
end

function Highlight_CheckItem(bag, slot, maxSlots, search)
	local retOK;
	local ret1;

	retOK, ret1 = pcall(Highlight_ItemIdentified, bag, slot, search)
	if (retOK == true) then

		if (bag ~= BANK_CONTAINER and bag ~= GUILD_BANK_CONTAINER) then
			bag = bag + 1
			slot = (maxSlots + 1) - slot
		end

		-- OK the code didn't fail - now toggle the item details
		if (ret1) then
			-- Enable the item
			Highlight_EnableBagItem(bag, slot, true)
			return 1
		else
			-- Enable the item
			Highlight_EnableBagItem(bag, slot, false)
			return 0
		end
	else
		return string.format("Function failed, error text: %s when looking at slot %d",
				ret1, search, slot)
	end
end

