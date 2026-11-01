--!strict
--[[
	IncrementalConfig — the "Game Factory" dictionary.
	Every currency, upgrade, prestige tier, loop, rune, trail, collectible and product
	is data here. A new game is a new copy of this file; the services stay unchanged.

	Amounts are strings ("1e15") or numbers; BigNum.From reads both.

	Stat keys used by effects:
		Rate.<CurrencyId>            passive gain per second (Additive = base, Multiplicative = multiplier)
		Exponent.<CurrencyId>        cross-currency exponent bonus (ExponentAdd)
		MaxLevel.<UpgradeId>         meta-cap bonus (MetaCap)
		MiningYield, MiningYield.<NodeType>, MasteryXP
		RefinerySpeed, RefineryYield, RefineryBatches
		FightDamage, FightHealth, FightReward
		WalkSpeed, Luck
		PrestigeGain.<TierId>, PassivePrestige.<TierId> (fraction of pending gain per second)
		SaveUpToNodeIndex            tier-1 upgrades with NodeIndex <= this survive resets
		ELAutomation, AutoMine, AutoFight   (Flag effects)
]]

local BigNum = require(script.Parent.BigNum)

export type Amount = string | number

export type Requirement = {
	UpgradeLevel: { UpgradeId: string, Level: number }?,
	PrestigeTier: { TierId: string, Count: number }?,
	MilestoneCount: number?,
	Currency: { CurrencyId: string, Amount: Amount }?,
}

export type EffectType = "Additive" | "Multiplicative" | "ExponentAdd" | "MetaCap" | "Flag"

export type Effect = {
	Type: EffectType,
	Stat: string?, -- Additive / Multiplicative / Flag
	Target: string?, -- ExponentAdd (CurrencyId) / MetaCap (UpgradeId)
	Value: number,
}

export type CurrencyAmount = { CurrencyId: string, Amount: Amount }

export type CurrencyDef = {
	Id: string,
	DisplayName: string,
	Icon: string,
	Color: Color3,
	BaseRate: Amount?,
	StartAmount: Amount?,
	-- EUT-style: Rate = Scale * (SourceRate ^ (Exponent + Exponent.<Id>)) * Rate.<Id> multiplier
	CrossCurrency: { Source: string, Exponent: number, Scale: Amount, RequiresUpgrade: string? }?,
	ResetTier: number, -- 0 = never resets; N = reset by prestige tiers >= N
	Visibility: Requirement?,
}

export type UpgradeDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Category: string,
	Tier: number, -- prestige tier whose reset clears it (0 = never)
	NodeIndex: number,
	Currency: string,
	BaseCost: Amount,
	CostGrowth: number,
	MaxLevel: number?, -- nil = infinite
	Effects: { Effect },
	ActivationThreshold: CurrencyAmount?, -- GI-style: must HOLD this amount; it is not spent
	ELEligible: boolean?,
	PermanentLockCost: CurrencyAmount?,
	Visibility: Requirement?,
}

export type GeneratorDef = {
	Id: string,
	DisplayName: string,
	Currency: string,
	BaseRate: Amount,
	ActivationThreshold: CurrencyAmount, -- produces only while the player holds this amount
	Visibility: Requirement?,
}

export type PrestigeBoost = { Stat: string, Source: "Currency" | "Count", PerUnit: number }

export type MilestoneDef = { DisplayName: string, Description: string, Effects: { Effect } }

export type PrestigeTierDef = {
	Id: string,
	Tier: number,
	DisplayName: string,
	Description: string,
	Currency: string?, -- nil = awards no currency (milestone reset)
	Source: string,
	Requirement: Amount, -- amount of Source that must be held
	RequirementGrowth: number, -- requirement *= growth ^ times performed
	Divisor: Amount,
	Exponent: number,
	Boosts: { PrestigeBoost },
	Milestones: { MilestoneDef }?,
	Visibility: Requirement?,
}

export type NodeTypeDef = {
	Id: string,
	DisplayName: string,
	Currency: string,
	BaseYield: Amount,
	XPPerHit: number,
	Color: Color3,
	Visibility: Requirement?,
}

export type RecipeDef = {
	Id: string,
	DisplayName: string,
	Input: string,
	InputAmount: Amount,
	Output: string,
	OutputAmount: Amount,
	BaseBatches: number,
	Visibility: Requirement?,
}

export type RarityDef = { Id: string, DisplayName: string, Weight: number, Color: Color3 }

export type RuneDef = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	MaxStack: number,
	Description: string,
	Effects: { Effect },
}

export type BannerDef = {
	Id: string,
	DisplayName: string,
	CostCurrency: string,
	CostAmount: Amount,
	Pool: { string },
	Visibility: Requirement?,
}

export type TrailDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	ColorA: Color3,
	ColorB: Color3,
	Cost: CurrencyAmount,
	Effects: { Effect },
	Visibility: Requirement?,
}

export type CollectibleDef = {
	Id: string,
	DisplayName: string,
	Hint: string,
	Description: string,
	Position: Vector3,
	Effects: { Effect },
}

export type ZoneDef = { Id: string, DisplayName: string, Visibility: Requirement? }

export type TabDef = { Id: string, DisplayName: string, Icon: string, Visibility: Requirement? }

export type GamepassDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	GamePassId: number,
	Effects: { Effect },
}

export type BoostPotionDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	ProductId: number,
	Duration: number,
	MaxStackSeconds: number,
	Effects: { Effect },
}

export type Config = {
	GameName: string,
	Settings: {
		TickRate: number,
		SyncRate: number,
		UnfoldCheckRate: number,
		AutosaveInterval: number,
		DataStoreName: string,
		BaseWalkSpeed: number,
	},
	Tags: {
		Button: string,
		MineNode: string,
		Refinery: string,
		RuneAltar: string,
		CombatArena: string,
		UnlockableZone: string,
		Collectible: string,
	},
	Attributes: {
		UpgradeId: string,
		ZoneId: string,
		NodeType: string,
		RecipeId: string,
		RuneBannerId: string,
		ArenaId: string,
		CollectibleId: string,
		IsBarrier: string,
	},
	Tabs: { TabDef },
	Currencies: { CurrencyDef },
	Upgrades: { UpgradeDef },
	Generators: { GeneratorDef },
	Automation: { AutobuyInterval: number, ELBulkPerPass: number },
	Prestige: { PrestigeTierDef },
	Mining: {
		Enabled: boolean,
		Range: number,
		SwingCooldown: number,
		AutoSwingInterval: number,
		StreakTimeout: number,
		StreakBonusPerHit: number,
		MaxStreak: number,
		MasteryBaseXP: number,
		MasteryXPGrowth: number,
		MasteryBonusPerLevel: number,
		MasteryMaxLevel: number,
		NodeTypes: { NodeTypeDef },
	},
	Refinery: {
		Enabled: boolean,
		CycleSeconds: number,
		MinCycleSeconds: number,
		ChargeSecondsToMax: number,
		MaxChargeMultiplier: number,
		Recipes: { RecipeDef },
	},
	Combat: {
		Enabled: boolean,
		Visibility: Requirement?,
		EnemyName: string,
		BaseHP: Amount,
		HPGrowth: number,
		BaseAttack: Amount,
		AttackGrowth: number,
		EnemyAttackInterval: number,
		BaseReward: Amount,
		RewardGrowth: number,
		RewardCurrency: string,
		PlayerBaseHP: Amount,
		PlayerBaseDamage: Amount,
		AttackCooldown: number,
		AutoAttackInterval: number,
		EngageTimeout: number,
		Range: number,
		ResetTier: number,
	},
	Runes: {
		Enabled: boolean,
		RollCounts: { number },
		Rarities: { RarityDef },
		Banners: { BannerDef },
		Definitions: { RuneDef },
	},
	Trails: { TrailDef },
	Collectibles: { CollectibleDef },
	Zones: { ZoneDef },
	Monetization: {
		StudioFreePurchases: boolean,
		Gamepasses: { GamepassDef },
		BoostPotions: { BoostPotionDef },
	},
	Bootstrap: {
		PadUpgrades: { string },
		ZoneContents: { [string]: { NodeTypes: { string }, Collectibles: { string }, Center: Vector3 } },
	},
}

local Config: Config = {
	GameName = "Pure Incremental Factory",

	Settings = {
		TickRate = 0.1, -- server simulation step (seconds)
		SyncRate = 0.25, -- snapshot push rate to each client
		UnfoldCheckRate = 0.5,
		AutosaveInterval = 60,
		DataStoreName = "IncrementalFactory_v1",
		BaseWalkSpeed = 16,
	},

	Tags = {
		Button = "IncrementalButton",
		MineNode = "MineNode",
		Refinery = "RefineryMachine",
		RuneAltar = "RuneAltar",
		CombatArena = "CombatArena",
		UnlockableZone = "UnlockableZone",
		Collectible = "SecretCollectible",
	},

	Attributes = {
		UpgradeId = "UpgradeId",
		ZoneId = "ZoneId",
		NodeType = "NodeType",
		RecipeId = "RecipeId",
		RuneBannerId = "RuneBannerId",
		ArenaId = "ArenaId",
		CollectibleId = "CollectibleId",
		IsBarrier = "IsBarrier",
	},

	Tabs = {
		{ Id = "Upgrades", DisplayName = "Upgrades", Icon = "⬆" },
		{ Id = "Activity", DisplayName = "Activity", Icon = "⛏" },
		{
			Id = "Prestige",
			DisplayName = "Prestige",
			Icon = "♻",
			Visibility = { Currency = { CurrencyId = "Cash", Amount = 500 } },
		},
		{
			Id = "Runes",
			DisplayName = "Runes",
			Icon = "✦",
			Visibility = { UpgradeLevel = { UpgradeId = "GemUnlock", Level = 1 } },
		},
		{
			Id = "Cosmetics",
			DisplayName = "Trails & Boosts",
			Icon = "★",
			Visibility = { Currency = { CurrencyId = "Cash", Amount = 100 } },
		},
	},

	Currencies = {
		{
			Id = "Cash",
			DisplayName = "Cash",
			Icon = "$",
			Color = Color3.fromRGB(110, 220, 120),
			BaseRate = 1,
			ResetTier = 1,
		},
		{
			Id = "Gems",
			DisplayName = "Gems",
			Icon = "◆",
			Color = Color3.fromRGB(90, 180, 255),
			CrossCurrency = { Source = "Cash", Exponent = 0.5, Scale = 0.2, RequiresUpgrade = "GemUnlock" },
			ResetTier = 1,
			Visibility = { UpgradeLevel = { UpgradeId = "GemUnlock", Level = 1 } },
		},
		{
			Id = "Stone",
			DisplayName = "Stone",
			Icon = "▪",
			Color = Color3.fromRGB(170, 170, 170),
			ResetTier = 1,
		},
		{
			Id = "CopperOre",
			DisplayName = "Copper Ore",
			Icon = "◍",
			Color = Color3.fromRGB(230, 140, 70),
			ResetTier = 1,
			Visibility = { Currency = { CurrencyId = "Stone", Amount = 10 } },
		},
		{
			Id = "Crystal",
			DisplayName = "Crystal",
			Icon = "✧",
			Color = Color3.fromRGB(200, 120, 255),
			ResetTier = 1,
			Visibility = { PrestigeTier = { TierId = "Rebirth", Count = 1 } },
		},
		{
			Id = "Bars",
			DisplayName = "Copper Bars",
			Icon = "▬",
			Color = Color3.fromRGB(255, 190, 90),
			ResetTier = 1,
			Visibility = { Currency = { CurrencyId = "CopperOre", Amount = 5 } },
		},
		{
			Id = "FightCoins",
			DisplayName = "Fight Coins",
			Icon = "⚔",
			Color = Color3.fromRGB(255, 90, 90),
			ResetTier = 2,
			Visibility = { Currency = { CurrencyId = "Cash", Amount = 300 } },
		},
		{
			Id = "RebirthPoints",
			DisplayName = "Rebirth Points",
			Icon = "♻",
			Color = Color3.fromRGB(255, 230, 90),
			ResetTier = 2,
			Visibility = { PrestigeTier = { TierId = "Rebirth", Count = 1 } },
		},
		{
			Id = "TranscendShards",
			DisplayName = "Transcend Shards",
			Icon = "✺",
			Color = Color3.fromRGB(255, 120, 220),
			ResetTier = 3,
			Visibility = { PrestigeTier = { TierId = "Transcend", Count = 1 } },
		},
	},

	Upgrades = {
		-- Tier 1 — Cash tree (math type 1: additive & multiplicative)
		{
			Id = "CashGen1",
			DisplayName = "Coin Press",
			Description = "+1 Cash/sec per level.",
			Category = "Cash",
			Tier = 1,
			NodeIndex = 1,
			Currency = "Cash",
			BaseCost = 10,
			CostGrowth = 1.15,
			MaxLevel = 25,
			Effects = { { Type = "Additive", Stat = "Rate.Cash", Value = 1 } },
			ELEligible = true,
			PermanentLockCost = { CurrencyId = "RebirthPoints", Amount = 3 },
		},
		{
			Id = "CashMult1",
			DisplayName = "Polished Coins",
			Description = "x1.25 Cash/sec per level.",
			Category = "Cash",
			Tier = 1,
			NodeIndex = 2,
			Currency = "Cash",
			BaseCost = 50,
			CostGrowth = 1.6,
			MaxLevel = 10,
			Effects = { { Type = "Multiplicative", Stat = "Rate.Cash", Value = 1.25 } },
			ELEligible = true,
			PermanentLockCost = { CurrencyId = "RebirthPoints", Amount = 5 },
			Visibility = { UpgradeLevel = { UpgradeId = "CashGen1", Level = 3 } },
		},
		-- Math type 2: cross-currency exponent (EUT-style)
		{
			Id = "GemUnlock",
			DisplayName = "Gem Refraction",
			Description = "Unlocks Gems: Gems/sec = 0.2 x (Cash/sec)^0.5.",
			Category = "Gems",
			Tier = 1,
			NodeIndex = 3,
			Currency = "Cash",
			BaseCost = 100,
			CostGrowth = 1,
			MaxLevel = 1,
			Effects = {},
			ELEligible = true,
			Visibility = { Currency = { CurrencyId = "Cash", Amount = 50 } },
		},
		{
			Id = "GemExponent",
			DisplayName = "Prismatic Lens",
			Description = "+0.05 to the Gem exponent per level.",
			Category = "Gems",
			Tier = 1,
			NodeIndex = 4,
			Currency = "Gems",
			BaseCost = 10,
			CostGrowth = 1.8,
			MaxLevel = 8,
			Effects = { { Type = "ExponentAdd", Target = "Gems", Value = 0.05 } },
			ELEligible = true,
			Visibility = { UpgradeLevel = { UpgradeId = "GemUnlock", Level = 1 } },
		},
		-- Math type 3: meta-cap (CGI-style)
		{
			Id = "PressExpansion",
			DisplayName = "Press Expansion",
			Description = "+5 max level to Coin Press per level.",
			Category = "Gems",
			Tier = 1,
			NodeIndex = 5,
			Currency = "Gems",
			BaseCost = 20,
			CostGrowth = 2.5,
			MaxLevel = 5,
			Effects = { { Type = "MetaCap", Target = "CashGen1", Value = 5 } },
			ELEligible = true,
			Visibility = { UpgradeLevel = { UpgradeId = "GemUnlock", Level = 1 } },
		},
		-- Math type 4: non-consumptive activation threshold (GI-style)
		{
			Id = "VaultResonance",
			DisplayName = "Vault Resonance",
			Description = "x2 Cash/sec. Free, but you must HOLD 2.5K Cash to activate (not spent).",
			Category = "Cash",
			Tier = 1,
			NodeIndex = 6,
			Currency = "Cash",
			BaseCost = 0,
			CostGrowth = 1,
			MaxLevel = 1,
			Effects = { { Type = "Multiplicative", Stat = "Rate.Cash", Value = 2 } },
			ActivationThreshold = { CurrencyId = "Cash", Amount = 2500 },
			ELEligible = true,
			Visibility = { Currency = { CurrencyId = "Cash", Amount = 1000 } },
		},
		-- Tier 1 — Mining & refinery
		{
			Id = "Pickaxe",
			DisplayName = "Reinforced Pickaxe",
			Description = "x1.5 mining yield per level.",
			Category = "Mining",
			Tier = 1,
			NodeIndex = 7,
			Currency = "Stone",
			BaseCost = 10,
			CostGrowth = 1.6,
			MaxLevel = 20,
			Effects = { { Type = "Multiplicative", Stat = "MiningYield", Value = 1.5 } },
			ELEligible = true,
		},
		{
			Id = "AutoSwing",
			DisplayName = "Auto-Swing Drone",
			Description = "Automatically swings at the last node you mined.",
			Category = "Mining",
			Tier = 1,
			NodeIndex = 8,
			Currency = "CopperOre",
			BaseCost = 25,
			CostGrowth = 1,
			MaxLevel = 1,
			Effects = { { Type = "Flag", Stat = "AutoMine", Value = 1 } },
			ELEligible = true,
			Visibility = { Currency = { CurrencyId = "CopperOre", Amount = 5 } },
		},
		{
			Id = "HotFurnace",
			DisplayName = "Hot Furnace",
			Description = "x1.25 refinery speed per level.",
			Category = "Refinery",
			Tier = 1,
			NodeIndex = 9,
			Currency = "Bars",
			BaseCost = 3,
			CostGrowth = 1.7,
			MaxLevel = 10,
			Effects = { { Type = "Multiplicative", Stat = "RefinerySpeed", Value = 1.25 } },
			ELEligible = true,
			Visibility = { Currency = { CurrencyId = "Bars", Amount = 1 } },
		},
		{
			Id = "BarBacking",
			DisplayName = "Bar-Backed Currency",
			Description = "x1.3 Cash/sec per level.",
			Category = "Refinery",
			Tier = 1,
			NodeIndex = 10,
			Currency = "Bars",
			BaseCost = 5,
			CostGrowth = 2,
			MaxLevel = 15,
			Effects = { { Type = "Multiplicative", Stat = "Rate.Cash", Value = 1.3 } },
			ELEligible = true,
			Visibility = { Currency = { CurrencyId = "Bars", Amount = 1 } },
		},
		-- Tier 2 — Combat (Fight Coins reset on Transcend)
		{
			Id = "Blade",
			DisplayName = "Sharpened Blade",
			Description = "x1.3 fight damage per level. No cap.",
			Category = "Combat",
			Tier = 2,
			NodeIndex = 1,
			Currency = "FightCoins",
			BaseCost = 3,
			CostGrowth = 1.45,
			Effects = { { Type = "Multiplicative", Stat = "FightDamage", Value = 1.3 } },
			Visibility = { Currency = { CurrencyId = "FightCoins", Amount = 1 } },
		},
		{
			Id = "IronSkin",
			DisplayName = "Iron Skin",
			Description = "x1.35 fight health per level. No cap.",
			Category = "Combat",
			Tier = 2,
			NodeIndex = 2,
			Currency = "FightCoins",
			BaseCost = 4,
			CostGrowth = 1.5,
			Effects = { { Type = "Multiplicative", Stat = "FightHealth", Value = 1.35 } },
			Visibility = { Currency = { CurrencyId = "FightCoins", Amount = 1 } },
		},
		{
			Id = "BattleInstinct",
			DisplayName = "Battle Instinct",
			Description = "Auto-attacks the arena enemy while you stand in the arena.",
			Category = "Combat",
			Tier = 2,
			NodeIndex = 3,
			Currency = "FightCoins",
			BaseCost = 40,
			CostGrowth = 1,
			MaxLevel = 1,
			Effects = { { Type = "Flag", Stat = "AutoFight", Value = 1 } },
			Visibility = { Currency = { CurrencyId = "FightCoins", Amount = 10 } },
		},
		{
			Id = "SpoilsOfWar",
			DisplayName = "Spoils of War",
			Description = "x1.2 Cash/sec and x1.2 fight rewards per level.",
			Category = "Combat",
			Tier = 2,
			NodeIndex = 4,
			Currency = "FightCoins",
			BaseCost = 15,
			CostGrowth = 1.6,
			MaxLevel = 20,
			Effects = {
				{ Type = "Multiplicative", Stat = "Rate.Cash", Value = 1.2 },
				{ Type = "Multiplicative", Stat = "FightReward", Value = 1.2 },
			},
			Visibility = { Currency = { CurrencyId = "FightCoins", Amount = 5 } },
		},
		-- Tier 2 — Rebirth Point tree (reset on Transcend)
		{
			Id = "RebornFortune",
			DisplayName = "Reborn Fortune",
			Description = "x2 Cash/sec per level.",
			Category = "Rebirth",
			Tier = 2,
			NodeIndex = 5,
			Currency = "RebirthPoints",
			BaseCost = 1,
			CostGrowth = 2.2,
			MaxLevel = 15,
			Effects = { { Type = "Multiplicative", Stat = "Rate.Cash", Value = 2 } },
			Visibility = { PrestigeTier = { TierId = "Rebirth", Count = 1 } },
		},
		{
			Id = "AscendedPress",
			DisplayName = "Ascended Press",
			Description = "+10 max level to Coin Press and +5 to Polished Coins per level.",
			Category = "Rebirth",
			Tier = 2,
			NodeIndex = 6,
			Currency = "RebirthPoints",
			BaseCost = 3,
			CostGrowth = 3,
			MaxLevel = 5,
			Effects = {
				{ Type = "MetaCap", Target = "CashGen1", Value = 10 },
				{ Type = "MetaCap", Target = "CashMult1", Value = 5 },
			},
			Visibility = { PrestigeTier = { TierId = "Rebirth", Count = 1 } },
		},
		{
			Id = "DeepVeins",
			DisplayName = "Deep Veins",
			Description = "x2 mining yield and x1.5 mastery XP per level.",
			Category = "Rebirth",
			Tier = 2,
			NodeIndex = 7,
			Currency = "RebirthPoints",
			BaseCost = 2,
			CostGrowth = 2.5,
			MaxLevel = 10,
			Effects = {
				{ Type = "Multiplicative", Stat = "MiningYield", Value = 2 },
				{ Type = "Multiplicative", Stat = "MasteryXP", Value = 1.5 },
			},
			Visibility = { PrestigeTier = { TierId = "Rebirth", Count = 1 } },
		},
		-- Tier 3 — Transcend Shard tree (reset only by Milestones)
		{
			Id = "ExpendLess",
			DisplayName = "Expend-Less Protocol",
			Description = "EL Automation: EL-eligible tier-1 upgrades cost 0 and are auto-bought.",
			Category = "Transcend",
			Tier = 3,
			NodeIndex = 1,
			Currency = "TranscendShards",
			BaseCost = 1,
			CostGrowth = 1,
			MaxLevel = 1,
			Effects = { { Type = "Flag", Stat = "ELAutomation", Value = 1 } },
			Visibility = { PrestigeTier = { TierId = "Transcend", Count = 1 } },
		},
		{
			Id = "MemoryCrystal",
			DisplayName = "Memory Crystal",
			Description = "Protects 2 more tier-1 upgrade nodes from resets per level.",
			Category = "Transcend",
			Tier = 3,
			NodeIndex = 2,
			Currency = "TranscendShards",
			BaseCost = 1,
			CostGrowth = 2,
			MaxLevel = 5,
			Effects = { { Type = "Additive", Stat = "SaveUpToNodeIndex", Value = 2 } },
			Visibility = { PrestigeTier = { TierId = "Transcend", Count = 1 } },
		},
		{
			Id = "TranscendWealth",
			DisplayName = "Transcendent Wealth",
			Description = "x3 Cash/sec and x1.5 Rebirth Points per level.",
			Category = "Transcend",
			Tier = 3,
			NodeIndex = 3,
			Currency = "TranscendShards",
			BaseCost = 2,
			CostGrowth = 3,
			MaxLevel = 10,
			Effects = {
				{ Type = "Multiplicative", Stat = "Rate.Cash", Value = 3 },
				{ Type = "Multiplicative", Stat = "PrestigeGain.Rebirth", Value = 1.5 },
			},
			Visibility = { PrestigeTier = { TierId = "Transcend", Count = 1 } },
		},
	},

	Generators = {
		{
			Id = "GemFont",
			DisplayName = "Gem Font",
			Currency = "Gems",
			BaseRate = 1,
			ActivationThreshold = { CurrencyId = "Cash", Amount = 5000 },
			Visibility = { UpgradeLevel = { UpgradeId = "GemUnlock", Level = 1 } },
		},
		{
			Id = "VoidEngine",
			DisplayName = "Void Engine",
			Currency = "Cash",
			BaseRate = "1e4",
			ActivationThreshold = { CurrencyId = "Bars", Amount = 50 },
			Visibility = { MilestoneCount = 2 },
		},
	},

	Automation = {
		AutobuyInterval = 0.5,
		ELBulkPerPass = 1000, -- safety ceiling per upgrade per pass; MaxLevel is the real cap
	},

	Prestige = {
		{
			Id = "Rebirth",
			Tier = 1,
			DisplayName = "Rebirth",
			Description = "Reset Cash, materials and tier-1 upgrades for Rebirth Points (+50% Cash/sec each).",
			Currency = "RebirthPoints",
			Source = "Cash",
			Requirement = 1000,
			RequirementGrowth = 1,
			Divisor = 1000,
			Exponent = 0.5,
			Boosts = { { Stat = "Rate.Cash", Source = "Currency", PerUnit = 0.5 } },
			Visibility = { Currency = { CurrencyId = "Cash", Amount = 500 } },
		},
		{
			Id = "Transcend",
			Tier = 2,
			DisplayName = "Transcend",
			Description = "Reset everything from Rebirth plus Rebirth Points and Fight Coins for Transcend Shards.",
			Currency = "TranscendShards",
			Source = "RebirthPoints",
			Requirement = 25,
			RequirementGrowth = 1,
			Divisor = 25,
			Exponent = 0.6,
			Boosts = {
				{ Stat = "Rate.Cash", Source = "Currency", PerUnit = 1 },
				{ Stat = "PrestigeGain.Rebirth", Source = "Currency", PerUnit = 0.25 },
			},
			Visibility = { PrestigeTier = { TierId = "Rebirth", Count = 2 } },
		},
		{
			Id = "Milestone",
			Tier = 3,
			DisplayName = "Milestone",
			Description = "Awards no currency. Resets tiers 1-2 (and Shard upgrades) to reach the next Milestone.",
			Source = "TranscendShards",
			Requirement = 5,
			RequirementGrowth = 3,
			Divisor = 1,
			Exponent = 1,
			Boosts = { { Stat = "Rate.Cash", Source = "Count", PerUnit = 1 } },
			Milestones = {
				{
					DisplayName = "Milestone 1",
					Description = "Generate 1% of pending Rebirth Points per second, permanent EL Automation, protect 2 nodes.",
					Effects = {
						{ Type = "Additive", Stat = "PassivePrestige.Rebirth", Value = 0.01 },
						{ Type = "Flag", Stat = "ELAutomation", Value = 1 },
						{ Type = "Additive", Stat = "SaveUpToNodeIndex", Value = 2 },
					},
				},
				{
					DisplayName = "Milestone 2",
					Description = "Unfolds the Void Engine generator and x5 Cash/sec.",
					Effects = { { Type = "Multiplicative", Stat = "Rate.Cash", Value = 5 } },
				},
				{
					DisplayName = "Milestone 3",
					Description = "x3 mining yield, x2 refinery yield, permanent Auto-Swing.",
					Effects = {
						{ Type = "Multiplicative", Stat = "MiningYield", Value = 3 },
						{ Type = "Multiplicative", Stat = "RefineryYield", Value = 2 },
						{ Type = "Flag", Stat = "AutoMine", Value = 1 },
					},
				},
			} :: { MilestoneDef },
			Visibility = { PrestigeTier = { TierId = "Transcend", Count = 1 } },
		},
	},

	Mining = {
		Enabled = true,
		Range = 18,
		SwingCooldown = 0.25,
		AutoSwingInterval = 1.0,
		StreakTimeout = 3,
		StreakBonusPerHit = 0.05,
		MaxStreak = 40,
		MasteryBaseXP = 15,
		MasteryXPGrowth = 1.35,
		MasteryBonusPerLevel = 0.1,
		MasteryMaxLevel = 100,
		NodeTypes = {
			{
				Id = "Stone",
				DisplayName = "Stone Node",
				Currency = "Stone",
				BaseYield = 1,
				XPPerHit = 1,
				Color = Color3.fromRGB(150, 150, 155),
			},
			{
				Id = "Copper",
				DisplayName = "Copper Node",
				Currency = "CopperOre",
				BaseYield = 1,
				XPPerHit = 2,
				Color = Color3.fromRGB(220, 130, 60),
				Visibility = { Currency = { CurrencyId = "Stone", Amount = 10 } },
			},
			{
				Id = "Crystal",
				DisplayName = "Crystal Node",
				Currency = "Crystal",
				BaseYield = 1,
				XPPerHit = 5,
				Color = Color3.fromRGB(190, 110, 255),
				Visibility = { PrestigeTier = { TierId = "Rebirth", Count = 1 } },
			},
		},
	},

	Refinery = {
		Enabled = true,
		CycleSeconds = 3,
		MinCycleSeconds = 0.25,
		ChargeSecondsToMax = 300, -- charge multiplier builds over 5 minutes since the last reset
		MaxChargeMultiplier = 3,
		Recipes = {
			{
				Id = "SmeltCopper",
				DisplayName = "Copper Smelter",
				Input = "CopperOre",
				InputAmount = 5,
				Output = "Bars",
				OutputAmount = 1,
				BaseBatches = 4,
				Visibility = { Currency = { CurrencyId = "CopperOre", Amount = 5 } },
			},
			{
				Id = "PolishCrystal",
				DisplayName = "Crystal Polisher",
				Input = "Crystal",
				InputAmount = 3,
				Output = "Gems",
				OutputAmount = 25,
				BaseBatches = 2,
				Visibility = { PrestigeTier = { TierId = "Rebirth", Count = 1 } },
			},
		},
	},

	Combat = {
		Enabled = true,
		Visibility = { Currency = { CurrencyId = "Cash", Amount = 300 } },
		EnemyName = "Training Golem",
		BaseHP = 20,
		HPGrowth = 1.22,
		BaseAttack = 1,
		AttackGrowth = 1.12,
		EnemyAttackInterval = 1.5,
		BaseReward = 2,
		RewardGrowth = 1.1,
		RewardCurrency = "FightCoins",
		PlayerBaseHP = 25,
		PlayerBaseDamage = 2,
		AttackCooldown = 0.2,
		AutoAttackInterval = 0.6,
		EngageTimeout = 4,
		Range = 32,
		ResetTier = 2,
	},

	Runes = {
		Enabled = true,
		RollCounts = { 1, 10 },
		Rarities = {
			{ Id = "Common", DisplayName = "Common", Weight = 60, Color = Color3.fromRGB(200, 200, 200) },
			{ Id = "Uncommon", DisplayName = "Uncommon", Weight = 25, Color = Color3.fromRGB(100, 220, 120) },
			{ Id = "Rare", DisplayName = "Rare", Weight = 10, Color = Color3.fromRGB(90, 160, 255) },
			{ Id = "Epic", DisplayName = "Epic", Weight = 4, Color = Color3.fromRGB(190, 100, 255) },
			{ Id = "Legendary", DisplayName = "Legendary", Weight = 1, Color = Color3.fromRGB(255, 190, 60) },
		},
		Banners = {
			{
				Id = "GlyphAltar",
				DisplayName = "Glyph Altar",
				CostCurrency = "Gems",
				CostAmount = 15,
				Pool = { "Swift", "Copper", "Gilded", "Keen", "Fortune", "Prism", "Resonant", "Sovereign" },
				Visibility = { UpgradeLevel = { UpgradeId = "GemUnlock", Level = 1 } },
			},
		},
		Definitions = {
			{
				Id = "Swift",
				DisplayName = "Swift Glyph",
				Rarity = "Common",
				MaxStack = 8,
				Description = "+1 WalkSpeed",
				Effects = { { Type = "Additive", Stat = "WalkSpeed", Value = 1 } },
			},
			{
				Id = "Copper",
				DisplayName = "Copper Glyph",
				Rarity = "Common",
				MaxStack = 10,
				Description = "x1.1 mining yield",
				Effects = { { Type = "Multiplicative", Stat = "MiningYield", Value = 1.1 } },
			},
			{
				Id = "Gilded",
				DisplayName = "Gilded Glyph",
				Rarity = "Uncommon",
				MaxStack = 10,
				Description = "x1.15 Cash/sec",
				Effects = { { Type = "Multiplicative", Stat = "Rate.Cash", Value = 1.15 } },
			},
			{
				Id = "Keen",
				DisplayName = "Keen Glyph",
				Rarity = "Uncommon",
				MaxStack = 10,
				Description = "x1.2 fight damage",
				Effects = { { Type = "Multiplicative", Stat = "FightDamage", Value = 1.2 } },
			},
			{
				Id = "Fortune",
				DisplayName = "Fortune Glyph",
				Rarity = "Rare",
				MaxStack = 5,
				Description = "+0.1 Luck",
				Effects = { { Type = "Additive", Stat = "Luck", Value = 0.1 } },
			},
			{
				Id = "Prism",
				DisplayName = "Prism Glyph",
				Rarity = "Rare",
				MaxStack = 5,
				Description = "x1.25 Gems/sec (cross-currency multiplier)",
				Effects = { { Type = "Multiplicative", Stat = "Rate.Gems", Value = 1.25 } },
			},
			{
				Id = "Resonant",
				DisplayName = "Resonant Glyph",
				Rarity = "Epic",
				MaxStack = 5,
				Description = "+0.02 Gem exponent",
				Effects = { { Type = "ExponentAdd", Target = "Gems", Value = 0.02 } },
			},
			{
				Id = "Sovereign",
				DisplayName = "Sovereign Glyph",
				Rarity = "Legendary",
				MaxStack = 3,
				Description = "x2 Cash/sec, x1.5 Rebirth Points",
				Effects = {
					{ Type = "Multiplicative", Stat = "Rate.Cash", Value = 2 },
					{ Type = "Multiplicative", Stat = "PrestigeGain.Rebirth", Value = 1.5 },
				},
			},
		},
	},

	Trails = {
		{
			Id = "Ember",
			DisplayName = "Ember Trail",
			Description = "x1.25 mining yield while equipped.",
			ColorA = Color3.fromRGB(255, 120, 40),
			ColorB = Color3.fromRGB(255, 220, 80),
			Cost = { CurrencyId = "Cash", Amount = 250 },
			Effects = { { Type = "Multiplicative", Stat = "MiningYield", Value = 1.25 } },
		},
		{
			Id = "Frost",
			DisplayName = "Frost Trail",
			Description = "+4 WalkSpeed while equipped.",
			ColorA = Color3.fromRGB(120, 200, 255),
			ColorB = Color3.fromRGB(230, 250, 255),
			Cost = { CurrencyId = "Gems", Amount = 50 },
			Effects = { { Type = "Additive", Stat = "WalkSpeed", Value = 4 } },
			Visibility = { UpgradeLevel = { UpgradeId = "GemUnlock", Level = 1 } },
		},
		{
			Id = "Void",
			DisplayName = "Void Trail",
			Description = "x1.5 fight damage while equipped.",
			ColorA = Color3.fromRGB(120, 40, 200),
			ColorB = Color3.fromRGB(20, 0, 40),
			Cost = { CurrencyId = "FightCoins", Amount = 100 },
			Effects = { { Type = "Multiplicative", Stat = "FightDamage", Value = 1.5 } },
			Visibility = { Currency = { CurrencyId = "FightCoins", Amount = 1 } },
		},
	},

	Collectibles = {
		{
			Id = "LostCoin",
			DisplayName = "Lost Coin",
			Hint = "Behind the upgrade pads.",
			Description = "x1.1 Cash/sec forever.",
			Position = Vector3.new(-62, 3, -14),
			Effects = { { Type = "Multiplicative", Stat = "Rate.Cash", Value = 1.1 } },
		},
		{
			Id = "AncientPickaxe",
			DisplayName = "Ancient Pickaxe",
			Hint = "Near the mine, on the far side.",
			Description = "x1.25 mining yield forever.",
			Position = Vector3.new(66, 3, 18),
			Effects = { { Type = "Multiplicative", Stat = "MiningYield", Value = 1.25 } },
		},
		{
			Id = "WarBanner",
			DisplayName = "War Banner",
			Hint = "Hidden behind the arena.",
			Description = "x1.25 fight damage forever.",
			Position = Vector3.new(0, 3, -92),
			Effects = { { Type = "Multiplicative", Stat = "FightDamage", Value = 1.25 } },
		},
		{
			Id = "FeatherCharm",
			DisplayName = "Feather Charm",
			Hint = "Deep inside the Crystal Caves.",
			Description = "+3 WalkSpeed forever.",
			Position = Vector3.new(100, 3, -70),
			Effects = { { Type = "Additive", Stat = "WalkSpeed", Value = 3 } },
		},
	},

	Zones = {
		{
			Id = "CrystalCaves",
			DisplayName = "Crystal Caves",
			Visibility = { PrestigeTier = { TierId = "Rebirth", Count = 1 } },
		},
	},

	Monetization = {
		-- In Studio, products with id 0 are granted for free so every loop can be tested.
		StudioFreePurchases = true,
		Gamepasses = {
			{
				Id = "DoubleCash",
				DisplayName = "2x Cash",
				Description = "Permanently doubles Cash/sec.",
				GamePassId = 0,
				Effects = { { Type = "Multiplicative", Stat = "Rate.Cash", Value = 2 } },
			},
			{
				Id = "SwiftMiner",
				DisplayName = "Swift Miner",
				Description = "x2 mining yield and Auto-Swing.",
				GamePassId = 0,
				Effects = {
					{ Type = "Multiplicative", Stat = "MiningYield", Value = 2 },
					{ Type = "Flag", Stat = "AutoMine", Value = 1 },
				},
			},
		},
		BoostPotions = {
			{
				Id = "CashPotion",
				DisplayName = "Cash Potion",
				Description = "x2 Cash/sec for 10 minutes. Stacks duration.",
				ProductId = 0,
				Duration = 600,
				MaxStackSeconds = 7200,
				Effects = { { Type = "Multiplicative", Stat = "Rate.Cash", Value = 2 } },
			},
			{
				Id = "LuckPotion",
				DisplayName = "Luck Potion",
				Description = "+0.5 Luck for 5 minutes. Stacks duration.",
				ProductId = 0,
				Duration = 300,
				MaxStackSeconds = 3600,
				Effects = { { Type = "Additive", Stat = "Luck", Value = 0.5 } },
			},
			{
				Id = "MinerPotion",
				DisplayName = "Miner Potion",
				Description = "x2 mining yield for 10 minutes. Stacks duration.",
				ProductId = 0,
				Duration = 600,
				MaxStackSeconds = 7200,
				Effects = { { Type = "Multiplicative", Stat = "MiningYield", Value = 2 } },
			},
		},
	},

	-- Only used by WorkspaceBootstrapper to build the greybox test zone.
	Bootstrap = {
		PadUpgrades = { "CashGen1", "CashMult1", "GemUnlock", "VaultResonance", "Pickaxe" },
		ZoneContents = {
			CrystalCaves = {
				NodeTypes = { "Crystal" },
				Collectibles = { "FeatherCharm" },
				Center = Vector3.new(100, 0, -60),
			},
		},
	},
}

-- Id lookups shared by server and client. Built once from the lists above.
local function index<T>(list: { T }): { [string]: T }
	local map: { [string]: T } = {}
	for _, item in list do
		map[(item :: any).Id] = item
	end
	return map
end

local ById = {
	Tabs = index(Config.Tabs),
	Currencies = index(Config.Currencies),
	Upgrades = index(Config.Upgrades),
	Generators = index(Config.Generators),
	Prestige = index(Config.Prestige),
	NodeTypes = index(Config.Mining.NodeTypes),
	Recipes = index(Config.Refinery.Recipes),
	Rarities = index(Config.Runes.Rarities),
	Banners = index(Config.Runes.Banners),
	Runes = index(Config.Runes.Definitions),
	Trails = index(Config.Trails),
	Collectibles = index(Config.Collectibles),
	Zones = index(Config.Zones),
	Gamepasses = index(Config.Monetization.Gamepasses),
	BoostPotions = index(Config.Monetization.BoostPotions),
}

local RarityRank: { [string]: number } = {}
for rank, rarity in Config.Runes.Rarities do
	RarityRank[rarity.Id] = rank
end

-- Requirement → readable text, used by the UI and by server notifications.
local function describeRequirement(requirement: Requirement?): string
	if requirement == nil then
		return "Always available"
	end
	local parts: { string } = {}
	if requirement.UpgradeLevel then
		local upgrade = ById.Upgrades[requirement.UpgradeLevel.UpgradeId]
		local name = if upgrade then upgrade.DisplayName else requirement.UpgradeLevel.UpgradeId
		table.insert(parts, string.format("%s Lv %d", name, requirement.UpgradeLevel.Level))
	end
	if requirement.PrestigeTier then
		local tier = ById.Prestige[requirement.PrestigeTier.TierId]
		local name = if tier then tier.DisplayName else requirement.PrestigeTier.TierId
		table.insert(parts, string.format("%s x%d", name, requirement.PrestigeTier.Count))
	end
	if requirement.MilestoneCount then
		table.insert(parts, string.format("%d Milestone(s)", requirement.MilestoneCount))
	end
	if requirement.Currency then
		local currency = ById.Currencies[requirement.Currency.CurrencyId]
		local name = if currency then currency.DisplayName else requirement.Currency.CurrencyId
		table.insert(parts, string.format("Hold %s %s", BigNum.ToString(requirement.Currency.Amount), name))
	end
	return table.concat(parts, " + ")
end

return {
	Data = Config,
	ById = ById,
	RarityRank = RarityRank,
	DescribeRequirement = describeRequirement,
}
