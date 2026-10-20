--!strict
--[[
	Network
	Creates (server) or waits for (client) every RemoteEvent / RemoteFunction in one folder,
	and exposes typed helpers plus the shared Snapshot types sent to clients.
	Server handlers are rate-limited per player per remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type EventName =
	-- client -> server
	"RequestPurchase"
	| "RequestPrestige"
	| "RequestBuyLock"
	| "RequestMine"
	| "RequestAttack"
	| "RequestToggleRefinery"
	| "RequestRollRunes"
	| "RequestSetSetting"
	| "RequestBuyTrail"
	| "RequestEquipTrail"
	| "RequestBuyBoost"
	| "RequestBuyGamepass"
	-- server -> client
	| "StateSync"
	| "Notify"
	| "Unfold"
	| "MineFeedback"
	| "CombatFeedback"
	| "RuneResult"

export type FunctionName = "GetSnapshot"

export type UpgradeState = {
	Level: number,
	MaxLevel: number, -- -1 = infinite
	Cost: string,
	Affordable: boolean,
	Free: boolean,
	ThresholdMet: boolean,
	Locked: boolean,
	CanLock: boolean,
	Protected: boolean,
}

export type PrestigeState = {
	Count: number,
	Gain: string,
	Requirement: string,
	CanPrestige: boolean,
}

export type MasteryState = { Level: number, XP: number, Needed: number, Mult: number }

export type RefineryState = { Enabled: boolean, Progress: number, Cycle: number, Charge: number }

export type CombatState = {
	Kills: number,
	EnemyHP: string,
	EnemyMaxHP: string,
	EnemyHPFraction: number,
	EnemyAttack: string,
	PlayerHP: string,
	PlayerMaxHP: string,
	PlayerHPFraction: number,
	Damage: string,
	Reward: string,
}

export type Snapshot = {
	Currencies: { [string]: string },
	Rates: { [string]: string },
	Upgrades: { [string]: UpgradeState },
	Unfolded: { [string]: boolean },
	Prestige: { [string]: PrestigeState },
	MilestoneCount: number,
	Generators: { [string]: boolean },
	Mining: {
		StreakType: string,
		StreakCount: number,
		StreakMult: number,
		YieldMult: string,
		Mastery: { [string]: MasteryState },
	},
	Refinery: { [string]: RefineryState },
	Combat: CombatState,
	Runes: { [string]: number },
	OwnedTrails: { [string]: boolean },
	EquippedTrail: string,
	Collectibles: { [string]: boolean },
	Boosts: { [string]: number },
	Gamepasses: { [string]: boolean },
	Settings: { AutoBuy: boolean, AutoMine: boolean, AutoFight: boolean, AutoDeleteBelow: number },
	Stats: {
		ELAutomation: boolean,
		AutoMine: boolean,
		AutoFight: boolean,
		SaveUpToNodeIndex: number,
		Luck: number,
		WalkSpeed: number,
	},
}

export type NotifyKind = "Info" | "Success" | "Warning" | "Unfold"
export type NotifyPayload = { Title: string, Text: string, Kind: NotifyKind }
export type UnfoldPayload = { Key: string, Kind: string, DisplayName: string }
export type MineFeedback = { Node: BasePart, Amount: string, CurrencyId: string, Streak: number }
export type CombatFeedback = { Damage: string, Killed: boolean, Reward: string, Defeated: boolean }
export type RuneResult = { BannerId: string, Results: { { RuneId: string, Kept: boolean } } }

local EVENT_NAMES: { EventName } = {
	"RequestPurchase",
	"RequestPrestige",
	"RequestBuyLock",
	"RequestMine",
	"RequestAttack",
	"RequestToggleRefinery",
	"RequestRollRunes",
	"RequestSetSetting",
	"RequestBuyTrail",
	"RequestEquipTrail",
	"RequestBuyBoost",
	"RequestBuyGamepass",
	"StateSync",
	"Notify",
	"Unfold",
	"MineFeedback",
	"CombatFeedback",
	"RuneResult",
}

local FUNCTION_NAMES: { FunctionName } = { "GetSnapshot" }

-- Max requests per second per player per remote (token bucket).
local RATE_LIMIT_PER_SECOND = 20
local FOLDER_NAME = "IncrementalNetwork"

local Network = {}

local folder: Folder? = nil
local events: { [string]: RemoteEvent } = {}
local functions: { [string]: RemoteFunction } = {}
local buckets: { [Player]: { [string]: { Tokens: number, Last: number } } } = {}

local function ensureInit()
	if folder then
		return
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		local root: Folder
		if existing and existing:IsA("Folder") then
			root = existing
		else
			root = Instance.new("Folder")
			root.Name = FOLDER_NAME
			root.Parent = ReplicatedStorage
		end
		for _, name in EVENT_NAMES do
			local remote = root:FindFirstChild(name)
			if not (remote and remote:IsA("RemoteEvent")) then
				local created = Instance.new("RemoteEvent")
				created.Name = name
				created.Parent = root
				remote = created
			end
			events[name] = remote :: RemoteEvent
		end
		for _, name in FUNCTION_NAMES do
			local remote = root:FindFirstChild(name)
			if not (remote and remote:IsA("RemoteFunction")) then
				local created = Instance.new("RemoteFunction")
				created.Name = name
				created.Parent = root
				remote = created
			end
			functions[name] = remote :: RemoteFunction
		end
		Players.PlayerRemoving:Connect(function(player)
			buckets[player] = nil
		end)
		folder = root
	else
		local root = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
		for _, name in EVENT_NAMES do
			events[name] = root:WaitForChild(name) :: RemoteEvent
		end
		for _, name in FUNCTION_NAMES do
			functions[name] = root:WaitForChild(name) :: RemoteFunction
		end
		folder = root
	end
end

function Network.Init()
	ensureInit()
end

function Network.GetEvent(name: EventName): RemoteEvent
	ensureInit()
	return events[name]
end

function Network.GetFunction(name: FunctionName): RemoteFunction
	ensureInit()
	return functions[name]
end

local function allow(player: Player, name: string): boolean
	local now = os.clock()
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local bucket = perPlayer[name]
	if not bucket then
		bucket = { Tokens = RATE_LIMIT_PER_SECOND, Last = now }
		perPlayer[name] = bucket
	end
	bucket.Tokens = math.min(RATE_LIMIT_PER_SECOND, bucket.Tokens + (now - bucket.Last) * RATE_LIMIT_PER_SECOND)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

-- Server: listen to a client request. Handler errors are caught so one bad request cannot break the remote.
function Network.OnServerEvent(name: EventName, handler: (Player, ...any) -> ())
	Network.GetEvent(name).OnServerEvent:Connect(function(player: Player, ...: any)
		if not allow(player, name) then
			return
		end
		xpcall(handler, function(err)
			warn(string.format("[Network] %s handler failed for %s: %s", name, player.Name, tostring(err)))
		end, player, ...)
	end)
end

function Network.OnServerInvoke(name: FunctionName, handler: (Player, ...any) -> any)
	Network.GetFunction(name).OnServerInvoke = function(player: Player, ...: any): any
		if not allow(player, name) then
			return nil
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[Network] %s invoke failed for %s: %s", name, player.Name, tostring(result)))
			return nil
		end
		return result
	end
end

function Network.FireClient(player: Player, name: EventName, ...: any)
	Network.GetEvent(name):FireClient(player, ...)
end

function Network.FireAllClients(name: EventName, ...: any)
	Network.GetEvent(name):FireAllClients(...)
end

function Network.Notify(player: Player, title: string, text: string, kind: NotifyKind?)
	local payload: NotifyPayload = { Title = title, Text = text, Kind = kind or "Info" }
	Network.FireClient(player, "Notify", payload)
end

-- Client helpers
function Network.FireServer(name: EventName, ...: any)
	Network.GetEvent(name):FireServer(...)
end

function Network.OnClientEvent(name: EventName, handler: (...any) -> ())
	Network.GetEvent(name).OnClientEvent:Connect(handler)
end

function Network.InvokeServer(name: FunctionName, ...: any): any
	return Network.GetFunction(name):InvokeServer(...)
end

return Network
