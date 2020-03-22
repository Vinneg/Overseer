Overseer = LibStub('AceAddon-3.0'):NewAddon('Overseer', 'AceConsole-3.0', 'AceEvent-3.0', 'AceComm-3.0', 'AceTimer-3.0');

local AceConfig = LibStub('AceConfig-3.0');
local AceConfigDialog = LibStub('AceConfigDialog-3.0');
local AceDB = LibStub('AceDB-3.0');
local L = LibStub('AceLocale-3.0'):GetLocale('Overseer');

local function get(info)
    return Overseer.store.char[info[#info]];
end

local function set(info, value)
    Overseer.store.char[info[#info]] = value;
end

local function getBanks()
    local res = { -1 };

    for i = 1, NUM_BANKBAGSLOTS do
        tinsert(res, i + NUM_BAG_SLOTS);
    end

    return res;
end

local function getGuildInfo(player)
    if not IsInGuild() then
        return nil;
    end

    --    C_GuildInfo.GuildRoster();

    local ttlMembers = GetNumGuildMembers();

    for i = 1, ttlMembers do
        local name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, GUID = GetGuildRosterInfo(i);

        name = Ambiguate(name, 'all');

        if name == player then
            return i, name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, GUID;
        end
    end
end

local function isMl()
    for i = 1, MAX_RAID_MEMBERS do
        local name, _, _, _, _, _, _, _, _, _, isML = GetRaidRosterInfo(i);

        if name then
            name = Ambiguate(name, 'all');

            if Overseer.state.name == name then
                return isML;
            end
        end
    end

    return false;
end

local function unitInRaid(player)
    for i = 1, MAX_RAID_MEMBERS do
        local name = GetRaidRosterInfo(i);

        if name then
            name = Ambiguate(name, 'all');

            if name == player then
                return true;
            end
        end
    end

    return false;
end

Overseer.messages = {
    scanEvent = 'OverseerScan',
    prefix = 'Overseer',
    demandScan = 'scan bags',
    raid = 'RAID',
    warning = 'RAID_WARNING',
    guild = 'GUILD',
    whisper = 'WHISPER',
    answer = '(.+)#(%d+)'
};

Overseer.state = {
    name = '',
    class = '',
    pass = nil,
    list = {},
    bagId = 17966,
    bagName = nil,
    bagLink = nil,
    bankBagIds = getBanks(),
    encounterId = 1084,
    looting = false,
};

Overseer.defaults = {
    char = {
        rank = '',
        bonusEnable = true,
        bonusPoints = '5',
        lastBonus = '',
        bankBags = 0,
        bonusToRaid = false,
        bonusToGuild = true,
        lootAutoOpen = true,
        lootAutoAnnounce = true,
        lootMessage = L['Default Announce Message'],
    },
};

Overseer.options = {
    name = 'Onyxia Bag Mate',
    handler = Overseer,
    type = 'group',
    args = {
        rank = {
            type = 'input',
            order = 1,
            name = L['Rank # and above'],
            get = function(info) return get(info); end,
            set = function(info, value) set(info, value); end,
        },
        bonusHeader = {
            type = 'header',
            order = 10,
            name = L['Bonuses'],
        },
        bonusEnable = {
            type = 'toggle',
            order = 20,
            name = L['Enable bonuses'],
            get = function(info) return get(info); end,
            set = function(info, value) set(info, value); end,
        },
        bonusPoints = {
            hidden = function() return not (Overseer.store.char.bonusEnable or false); end,
            type = 'input',
            order = 30,
            name = L['Roll bonus per Onyxia kill'],
            get = function(info) return get(info); end,
            set = function(info, value) set(info, value); end,
        },
        bonusToRaid = {
            hidden = function() return not (Overseer.store.char.bonusEnable or false); end,
            type = 'toggle',
            order = 40,
            name = L['Bonuses to Raid'],
            desc = L['Add bonuses to all raid members (even they are offline)'],
            get = function() return Overseer.store.char.bonusToRaid or false; end,
            set = function(_, value) value = value or false; Overseer.store.char.bonusToRaid = value; Overseer.store.char.bonusToGuild = not Overseer.store.char.bonusToRaid; end,
        },
        bonusToGuild = {
            hidden = function() return not (Overseer.store.char.bonusEnable or false); end,
            type = 'toggle',
            order = 50,
            name = L['Bonuses to Guild'],
            desc = L['Add bonuses to online guild members and all raid members (even they are offline)'],
            get = function() return Overseer.store.char.bonusToGuild or false; end,
            set = function(_, value) value = value or false; Overseer.store.char.bonusToGuild = value; Overseer.store.char.bonusToRaid = not Overseer.store.char.bonusToGuild; end,
        },
        importBonuses = {
            hidden = function() return not (Overseer.store.char.bonusEnable or false); end,
            type = 'execute',
            order = 60,
            name = L['Import csv'],
            func = function() Overseer.AttendanceFrame:Render(); end,
        },
        clearBonuses = {
            hidden = function() return not (Overseer.store.char.bonusEnable or false); end,
            type = 'execute',
            order = 70,
            name = L['Clear bonuses'],
            func = function() Overseer:ClearBonuses(); end,
        },
        lootHeader = {
            type = 'header',
            order = 80,
            name = L['Loot'],
        },
        lootAutoOpen = {
            type = 'toggle',
            order = 90,
            name = L['Auto open Roll Frame'],
            get = function(info) return get(info); end,
            set = function(info, value) set(info, value); end,
        },
        lootAutoAnnounce = {
            type = 'toggle',
            order = 100,
            name = L['Auto announce Onyxia Bag'],
            get = function(info) return get(info); end,
            set = function(info, value) set(info, value); end,
        },
        lootMessage = {
            hidden = function() return not (Overseer.store.char.lootAutoAnnounce or false); end,
            type = 'input',
            order = 110,
            name = L['Onyxia Bag announce message'],
            get = function(info) return get(info); end,
            set = function(info, value) set(info, value); end,
        },
    },
};

Overseer.store = {};

function Overseer:HandleChatCommand(input)
    local arg = strlower(input or '');

    if arg == 'test' then
        self:ENCOUNTER_END(nil, 1084, nil, nil, nil, 1);
    elseif arg == 'opts' then
        AceConfigDialog:Open('OverseerOptions');
    elseif arg == 'open' then
        self.RollFrame:Render();
    else
        self:Print('|cff33ff99', L['Usage:'], '|r');
        self:Print('opts|cff33ff99 - ', L['to open Options frame'], '|r');
        self:Print('open|cff33ff99 - ', L['to open Roll frame'], '|r');
    end
end

function Overseer:OnInitialize()
    self:RegisterChatCommand('onybm', 'HandleChatCommand');

    AceConfig:RegisterOptionsTable('OverseerOptions', self.options);
    self.store = AceDB:New('OverseerStore', self.defaults, true);

    self:RegisterComm(self.messages.scanEvent, 'handleScanEvent');

    self.state.name = UnitName('player');
    self.state.class = select(2, UnitClass("player"));
    self.state.bagName, self.state.bagLink = GetItemInfo(self.state.bagId);

    self:RegisterEvent('BANKFRAME_CLOSED');
    self:RegisterEvent('ENCOUNTER_END');
    self:RegisterEvent('LOOT_OPENED');
    self:RegisterEvent('LOOT_CLOSED');

    self:ScheduleTimer('PostInit', 10);
end

function Overseer:PostInit()
    self.state.name = UnitName('player');
    self.state.class = select(2, UnitClass("player"));
    self.state.bagName, self.state.bagLink = GetItemInfo(self.state.bagId);

    local version = GetAddOnMetadata(self.name, 'Version');

    self:Print('|cff33ff99Version ', version, ' loaded!|r');
end

function Overseer:ScanPlayer()
    local bags = 0;

    for i = 0, NUM_BAG_SLOTS do
        if i ~= 0 then
            local invID = ContainerIDToInventoryID(i);
            local itemId = GetInventoryItemID("player", invID);

            if itemId == self.state.bagId then
                bags = bags + 1;
            end
        end

        local slots = GetContainerNumSlots(i);

        if slots ~= 0 then
            for j = 1, slots do
                local itemId = GetContainerItemID(i, j);

                if itemId == self.state.bagId then
                    bags = bags + 1;
                end
            end
        end
    end

    return bags;
end

function Overseer:ScanBank()
    local bags = 0;

    for _, i in ipairs(self.state.bankBagIds) do
        local invID;

        if i == -1 then
            invID = BankButtonIDToInvSlotID(i, 1);
        else
            invID = ContainerIDToInventoryID(i);
        end

        local itemId = GetInventoryItemID("player", invID);

        if itemId == self.state.bagId then
            bags = bags + 1;
        end

        local slots = GetContainerNumSlots(i);

        if slots ~= 0 then
            for j = 1, slots do
                local itemId = GetContainerItemID(i, j);

                if itemId == self.state.bagId then
                    bags = bags + 1;
                end
            end
        end
    end

    return bags;
end

function Overseer:DemandScan()
    self:SendCommMessage(self.messages.scanEvent, self.messages.demandScan, self.messages.raid);
end

function Overseer:handleScanEvent(_, message, _, sender)
    if message == self.messages.demandScan then
        local bags = self:ScanPlayer() + (self.store.char.bankBags or 0);

        self:SendCommMessage(self.messages.scanEvent, self.state.class .. '#' .. tostring(bags), self.messages.whisper, sender);
    else
        local class, bags = string.match(message, self.messages.answer);

        if class and bags then
            local item = { name = sender, class = class, bags = tonumber(bags) };

            self:UpdateList(item);
            self:UpdatePass(item);

            self.RollFrame:RenderList();
        end
    end
end

function Overseer:ClearList()
    self.state.list = {};

    Overseer:DemandScan();
end

function Overseer:UpdateList(item)
    local result = self.state.list or {};
    local found = false;

    for _, v in ipairs(result) do
        if v.name == item.name then
            v.class = item.class;
            v.bags = item.bags;

            found = true;
        end
    end

    if not found then
        tinsert(result, item);
    end

    sort(result, function(a, b) return a.name < b.name end);

    self.state.list = result;
end

function Overseer:UpdatePass(item)
    local pass = self.state.pass;

    if (pass == nil) then
        pass = item.bags;
    else
        pass = math.min(pass, item.bags);
    end

    self.state.pass = pass;

    self.RollFrame:UpdateStatus(self.state.pass);
end

function Overseer:RollList(item)
    local result = self.state.list or {};

    for _, v in ipairs(result) do
        if (v.name == item.name and (v.roll == nil or v.roll == 0)) then
            v.roll = item.roll;
        end
    end

    sort(result, function(a, b) return (a.roll or 0) > (b.roll or 0) end);

    self.state.list = result;
end

function Overseer:GetBonus(player)
    local offNote = select(9, getGuildInfo(player));

    if offNote == nil then
        return 0;
    end

    local bonus = string.match(offNote, 'obm{(-?%d+%.?%d*)}');

    return tonumber(bonus) or 0;
end

function Overseer:SetBonus(player, bonus)
    local i, _, _, _, _, _, _, _, offNote = getGuildInfo(player);

    if offNote == nil then
        return 0;
    end

    local newBonus = 'obm{' .. (tonumber(bonus) or 0) .. '}';

    local newOffNote, subs = string.gsub(offNote, 'obm{[^}]*}', newBonus);

    if subs == 0 then
        newOffNote = (offNote .. newBonus);
    end

    GuildRosterSetOfficerNote(i, newOffNote);
end

function Overseer:ClearBonuses()
    if not IsInGuild() then
        return nil;
    end

    local ttlMembers = GetNumGuildMembers();

    for i = 1, ttlMembers do
        local name = select(8, GetGuildRosterInfo(i));

        local tmp = string.match(offNote, 'obm{(-?%d+%.?%d*)}');
        local bonus = tonumber(tmp) or 0;
        bonus = bonus + (tonumber(self.store.char.bonusPoints) or 0);

        GuildRosterSetOfficerNote(i, newOffNote);
    end

    Overseer.store.char.lastBonus = '';
end

function Overseer:AddBonusesToRaid()
    if not IsInGuild() then
        return nil;
    end

    for i = 1, MAX_RAID_MEMBERS do
        local name = GetRaidRosterInfo(i);

        if name then
            name = Ambiguate(name, 'all');

            local bonus = self:GetBonus(name);
            self:SetBonus(name, bonus + (tonumber(self.store.char.bonusPoints) or 0));
        end
    end

    SendChatMessage(L['Overseer bonuses added to all raid members!'](self.store.char.bonusPoints), self.messages.raid);
end

function Overseer:AddBonusesToGuild()
    if not IsInGuild() then
        return nil;
    end

    local ttlMembers = GetNumGuildMembers();

    for i = 1, ttlMembers do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i);

        if name then
            name = Ambiguate(name, 'all');

            if isOnline or unitInRaid(name) then
                local bonus = self:GetBonus(name);
                self:SetBonus(name, bonus + (tonumber(self.store.char.bonusPoints) or 0));
            end
        end
    end

    SendChatMessage(L['Overseer bonuses added to online guild members!'](self.store.char.bonusPoints), self.messages.guild);
end

function Overseer:BagLootIndex()
    local count = GetNumLootItems();

    for i = 1, count do
        local _, name = GetLootSlotInfo(i);

        name = strsub(name, 1, #self.state.bagName);

        if name == self.state.bagName then
            return i;
        end
    end

    return nil;
end

function Overseer:AnounceRoll()
    local msg = format(self.store.char.lootMessage, self.state.bagLink);

    SendChatMessage(msg, self.messages.warning);
end

function Overseer:CHAT_MSG_SYSTEM(_, message)
    local name, roll, min, max = string.match(message, L['Roll regexp']);

    roll = tonumber(roll);
    min = tonumber(min);
    max = tonumber(max);

    if (name and roll and min == 1 and max == 100) then
        self:RollList({ name = name, roll = roll });

        self.RollFrame:RenderList();
    end
end

function Overseer:BANKFRAME_CLOSED()
    self.store.char.bankBags = self:ScanBank();
end

function Overseer:ENCOUNTER_END(_, id, _, _, _, success)
    if id ~= self.state.encounterId or success ~= 1 then
        return;
    end

    if not self.store.char.bonusEnable then
        return;
    end

    if not isMl() then
        return;
    end

    if self.store.char.bonusToRaid then
        self:AddBonusesToRaid();
    elseif self.store.char.bonusToGuild then
        self:AddBonusesToGuild();
    end
end

function Overseer:LOOT_OPENED()
    self.state.looting = true;

    if not IsInRaid() then
        return;
    end

    if not isMl() then
        return;
    end

    if self:BagLootIndex() then
        if self.store.char.lootAutoOpen then
            self.RollFrame:Render();
        end

        if self.store.char.lootAutoAnnounce then
            self:AnounceRoll();
        end
    end
end

function Overseer:LOOT_CLOSED()
    self.state.looting = false;
end
