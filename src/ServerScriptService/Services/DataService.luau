--!strict
--[[
	DataService
	Authoritative player profiles: DataStore with session locking, retries, autosave and
	BindToClose. Falls back to an in-memory store when DataStores are unavailable (Studio
	without API access). BigNums are stored as "#BN:<mantissa>|<exponent>" strings.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local BigNum = require(Modules.BigNum)
local ConfigModule = require(Modules.IncrementalConfig)

local Config = ConfigModule.Data

type BigNum = BigNum.BigNum

export type Profile = {
	Version: number,
	Currencies: { [string]: BigNum },
	Upgrades: { [string]: number },
	PermanentLocks: { [string]: boolean },
	PrestigeCounts: { [string]: number },
	MilestoneCount: number,
	Mastery: { [string]: number },
	Refinery: { [string]: { Enabled: boolean, Progress: number } },
	Combat: { Kills: number, EnemyHP: BigNum },
	Runes: { [string]: number },
	OwnedTrails: { [string]: boolean },
	EquippedTrail: string,
	Collectibles: { [string]: boolean },
	Boosts: { [string]: number },
	Unfolded: { [string]: boolean },
	Settings: { AutoBuy: boolean, AutoMine: boolean, AutoFight: boolean, AutoDeleteBelow: number },
	RecentReceipts: { string },
	TimeSinceReset: number,
	PlayTime: number,
}

export type StatEntry = { Add: BigNum, Mult: BigNum }
export type StatBlock = { [string]: StatEntry }

export type Runtime = {
	StreakType: string,
	StreakCount: number,
	StreakLastHit: number,
	LastMineAt: number,
	LastAutoMine: number,
	LastNode: BasePart?,
	LastAttackAt: number,
	LastAutoAttack: number,
	LastEngagedAt: number,
	LastEnemyStrike: number,
	PlayerHP: BigNum,
	Gamepasses: { [string]: boolean },
	Stats: StatBlock,
	Rates: { [string]: BigNum },
	LastAutobuy: number,
	LastUnfoldCheck: number,
	LastSync: number,
	LastCharacterApply: number,
	TouchDebounce: { [string]: number },
}

export type Session = {
	Player: Player,
	Profile: Profile,
	Runtime: Runtime,
	LastSave: number,
	Released: boolean,
}

local PROFILE_VERSION = 1
local KEY_PREFIX = "Player_"
local BIGNUM_PREFIX = "#BN:"
local LOCK_TIMEOUT = 180 -- seconds before an abandoned session lock may be stolen
local LOAD_ATTEMPTS = 6
local LOAD_RETRY_DELAY = 5
local CALL_RETRIES = 4

local DataService = {}

local store: DataStore? = nil
local memoryStore: { [string]: any } = {}
local useMemory = false
local sessions: { [Player]: Session } = {}
local loadedCallbacks: { (Session) -> () } = {}
local releasingCallbacks: { (Session) -> () } = {}
local initialized = false

-- Default profile ------------------------------------------------------------------

function DataService.NewProfile(): Profile
	local currencies: { [string]: BigNum } = {}
	for _, currency in Config.Currencies do
		currencies[currency.Id] = BigNum.From(currency.StartAmount or 0)
	end
	local upgrades: { [string]: number } = {}
	for _, upgrade in Config.Upgrades do
		upgrades[upgrade.Id] = 0
	end
	local counts: { [string]: number } = {}
	for _, tier in Config.Prestige do
		counts[tier.Id] = 0
	end
	local mastery: { [string]: number } = {}
	for _, nodeType in Config.Mining.NodeTypes do
		mastery[nodeType.Id] = 0
	end
	local refinery: { [string]: { Enabled: boolean, Progress: number } } = {}
	for _, recipe in Config.Refinery.Recipes do
		refinery[recipe.Id] = { Enabled = true, Progress = 0 }
	end
	return {
		Version = PROFILE_VERSION,
		Currencies = currencies,
		Upgrades = upgrades,
		PermanentLocks = {},
		PrestigeCounts = counts,
		MilestoneCount = 0,
		Mastery = mastery,
		Refinery = refinery,
		Combat = { Kills = 0, EnemyHP = BigNum.From(Config.Combat.BaseHP) },
		Runes = {},
		OwnedTrails = {},
		EquippedTrail = "",
		Collectibles = {},
		Boosts = {},
		Unfolded = {},
		Settings = { AutoBuy = true, AutoMine = true, AutoFight = true, AutoDeleteBelow = 0 },
		RecentReceipts = {},
		TimeSinceReset = 0,
		PlayTime = 0,
	}
end

local function newRuntime(): Runtime
	return {
		StreakType = "",
		StreakCount = 0,
		StreakLastHit = 0,
		LastMineAt = 0,
		LastAutoMine = 0,
		LastNode = nil,
		LastAttackAt = 0,
		LastAutoAttack = 0,
		LastEngagedAt = 0,
		LastEnemyStrike = 0,
		PlayerHP = BigNum.From(Config.Combat.PlayerBaseHP),
		Gamepasses = {},
		Stats = {},
		Rates = {},
		LastAutobuy = 0,
		LastUnfoldCheck = 0,
		LastSync = 0,
		LastCharacterApply = 0,
		TouchDebounce = {},
	}
end

-- Serialization ---------------------------------------------------------------------

local function serializeValue(value: any): any
	if type(value) ~= "table" then
		return value
	end
	if BigNum.IsBigNum(value) then
		return BIGNUM_PREFIX .. BigNum.Serialize(value)
	end
	local out = {}
	for key, child in value do
		out[key] = serializeValue(child)
	end
	return out
end

local function deserializeValue(value: any): any
	if type(value) == "string" and string.sub(value, 1, #BIGNUM_PREFIX) == BIGNUM_PREFIX then
		return BigNum.Deserialize(string.sub(value, #BIGNUM_PREFIX + 1))
	end
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, child in value do
		out[key] = deserializeValue(child)
	end
	return out
end

function DataService.Serialize(profile: Profile): { [string]: any }
	return serializeValue(profile)
end

-- Fills keys missing from saved data with template defaults (recursively for dictionaries).
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, default in template do
		local current = target[key]
		if current == nil then
			target[key] = if type(default) == "table" and not BigNum.IsBigNum(default)
				then deserializeValue(serializeValue(default))
				else default
		elseif
			type(current) == "table"
			and type(default) == "table"
			and not BigNum.IsBigNum(default)
			and not BigNum.IsBigNum(current)
		then
			reconcile(current, default)
		elseif type(current) ~= type(default) and not (BigNum.IsBigNum(default) and BigNum.IsBigNum(current)) then
			-- Corrupt or retyped field: reset it to the default.
			target[key] = default
		end
	end
end

function DataService.Deserialize(raw: any): Profile
	local template = DataService.NewProfile()
	if type(raw) ~= "table" then
		return template
	end
	local data = deserializeValue(raw)
	reconcile(data, template)
	data.Version = PROFILE_VERSION
	return data :: Profile
end

-- Store access ----------------------------------------------------------------------

local function retry<T>(label: string, callback: () -> T): (boolean, T?)
	local lastError: any = nil
	for attempt = 1, CALL_RETRIES do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastError = result
		task.wait(2 ^ attempt * 0.5)
	end
	warn(string.format("[DataService] %s failed after %d attempts: %s", label, CALL_RETRIES, tostring(lastError)))
	return false, nil
end

local function update(key: string, transform: (any) -> any): (boolean, any)
	if useMemory then
		local result = transform(memoryStore[key])
		if result ~= nil then
			memoryStore[key] = result
		end
		return true, result
	end
	local dataStore = store :: DataStore
	return retry("UpdateAsync " .. key, function()
		return dataStore:UpdateAsync(key, transform)
	end)
end

-- Loading / saving --------------------------------------------------------------------

type LoadOutcome = "Loaded" | "Locked" | "Failed"

local function tryLoad(key: string): (LoadOutcome, any)
	local lockedElsewhere = false
	local loadedData: any = nil
	local ok = update(key, function(old: any): any
		lockedElsewhere = false
		local now = os.time()
		if type(old) == "table" and type(old.Lock) == "table" then
			local lock = old.Lock
			local lockAge = now - (tonumber(lock.Time) or 0)
			if lock.JobId ~= game.JobId and lockAge < LOCK_TIMEOUT then
				lockedElsewhere = true
				return nil -- cancel the write; another live server owns this profile
			end
		end
		loadedData = if type(old) == "table" then old.Data else nil
		return { Data = loadedData, Lock = { JobId = game.JobId, Time = now } }
	end)
	if not ok then
		return "Failed", nil
	end
	if lockedElsewhere then
		return "Locked", nil
	end
	return "Loaded", loadedData
end

function DataService.LoadProfile(player: Player): Session?
	local key = KEY_PREFIX .. player.UserId
	local rawData: any = nil
	local loaded = false
	for attempt = 1, LOAD_ATTEMPTS do
		local outcome, data = tryLoad(key)
		if outcome == "Loaded" then
			rawData = data
			loaded = true
			break
		end
		if not player.Parent then
			return nil
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(LOAD_RETRY_DELAY)
		end
	end
	if not loaded then
		player:Kick("Your data is still open in another server or could not be loaded. Please rejoin in a minute.")
		return nil
	end
	if not player.Parent then
		-- Left while loading: release the lock we just took.
		update(key, function(old: any): any
			if type(old) == "table" then
				old.Lock = nil
			end
			return old
		end)
		return nil
	end
	local session: Session = {
		Player = player,
		Profile = DataService.Deserialize(rawData),
		Runtime = newRuntime(),
		LastSave = os.clock(),
		Released = false,
	}
	sessions[player] = session
	for _, callback in loadedCallbacks do
		task.spawn(callback, session)
	end
	return session
end

function DataService.SaveProfile(player: Player, release: boolean): boolean
	local session = sessions[player]
	if not session or session.Released then
		return false
	end
	if release then
		session.Released = true
	end
	local key = KEY_PREFIX .. player.UserId
	local payload = DataService.Serialize(session.Profile)
	local stolen = false
	local ok = update(key, function(old: any): any
		stolen = false
		if type(old) == "table" and type(old.Lock) == "table" and old.Lock.JobId ~= game.JobId then
			stolen = true
			return nil -- another server took over; never overwrite its newer data
		end
		return {
			Data = payload,
			Lock = if release then nil else { JobId = game.JobId, Time = os.time() },
		}
	end)
	session.LastSave = os.clock()
	if stolen then
		warn("[DataService] Session lock lost for", player.Name, "- save skipped")
		return false
	end
	return ok
end

function DataService.GetSession(player: Player): Session?
	local session = sessions[player]
	if session and not session.Released then
		return session
	end
	return nil
end

function DataService.GetSessions(): { [Player]: Session }
	return sessions
end

function DataService.OnProfileLoaded(callback: (Session) -> ())
	table.insert(loadedCallbacks, callback)
	for _, session in sessions do
		if not session.Released then
			task.spawn(callback, session)
		end
	end
end

function DataService.OnProfileReleasing(callback: (Session) -> ())
	table.insert(releasingCallbacks, callback)
end

function DataService.IsUsingMemoryStore(): boolean
	return useMemory
end

local function releasePlayer(player: Player)
	local session = sessions[player]
	if not session or session.Released then
		return
	end
	for _, callback in releasingCallbacks do
		pcall(callback, session)
	end
	DataService.SaveProfile(player, true)
	sessions[player] = nil
end

function DataService.Init()
	if initialized then
		return
	end
	initialized = true

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Settings.DataStoreName)
	end)
	if ok and result then
		store = result
		-- A cheap read proves API access; Studio without "Enable Studio Access to API Services" fails here.
		local probeOk = pcall(function()
			(result :: DataStore):GetAsync("__probe")
		end)
		useMemory = not probeOk
	else
		useMemory = true
	end
	if useMemory then
		warn("[DataService] DataStores unavailable — using in-memory profiles (data will not persist).")
	end

	Players.PlayerAdded:Connect(function(player)
		DataService.LoadProfile(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(DataService.LoadProfile, player)
	end
	Players.PlayerRemoving:Connect(releasePlayer)

	task.spawn(function()
		while true do
			task.wait(Config.Settings.AutosaveInterval)
			for player, session in sessions do
				if not session.Released then
					task.spawn(DataService.SaveProfile, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if useMemory and RunService:IsStudio() then
			return
		end
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				releasePlayer(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
