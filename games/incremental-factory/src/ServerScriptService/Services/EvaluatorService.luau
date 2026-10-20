--!strict
--[[
	EvaluatorService
	Pure math over a profile: stat aggregation from every source, meta-caps, cross-currency
	exponents, activation thresholds, costs, prestige gains, mastery, combat scaling and
	VisibilityRequirement checks. No side effects — callers decide what to do with results.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local BigNum = require(Modules.BigNum)
local ConfigModule = require(Modules.IncrementalConfig)
local DataService = require(script.Parent.DataService)

local Config = ConfigModule.Data
local ById = ConfigModule.ById

type BigNum = BigNum.BigNum
type Profile = DataService.Profile
type StatBlock = DataService.StatBlock
type StatEntry = DataService.StatEntry
type Effect = ConfigModule.Effect
type Requirement = ConfigModule.Requirement
type UpgradeDef = ConfigModule.UpgradeDef
type PrestigeTierDef = ConfigModule.PrestigeTierDef
type GeneratorDef = ConfigModule.GeneratorDef
type BannerDef = ConfigModule.BannerDef

export type Unfoldable = { Key: string, Kind: string, DisplayName: string, Requirement: Requirement? }

local Evaluator = {}

-- Stat blocks -----------------------------------------------------------------------

local function entry(block: StatBlock, key: string): StatEntry
	local existing = block[key]
	if existing then
		return existing
	end
	local created: StatEntry = { Add = BigNum.Zero(), Mult = BigNum.One() }
	block[key] = created
	return created
end

local function statKeyFor(effect: Effect): string?
	if effect.Type == "ExponentAdd" then
		return if effect.Target then "Exponent." .. effect.Target else nil
	elseif effect.Type == "MetaCap" then
		return if effect.Target then "MaxLevel." .. effect.Target else nil
	end
	return effect.Stat
end

-- Applies an effect `stacks` times (upgrade level, rune copies, or 1).
function Evaluator.ApplyEffect(block: StatBlock, effect: Effect, stacks: number)
	if stacks <= 0 then
		return
	end
	local key = statKeyFor(effect)
	if not key then
		return
	end
	local stat = entry(block, key)
	if effect.Type == "Multiplicative" then
		stat.Mult = BigNum.Mul(stat.Mult, BigNum.Pow(effect.Value, stacks))
	elseif effect.Type == "Flag" then
		stat.Add = BigNum.Add(stat.Add, 1)
	else
		-- Additive, ExponentAdd and MetaCap all add Value per stack.
		stat.Add = BigNum.Add(stat.Add, effect.Value * stacks)
	end
end

local function applyEffects(block: StatBlock, effects: { Effect }, stacks: number)
	for _, effect in effects do
		Evaluator.ApplyEffect(block, effect, stacks)
	end
end

function Evaluator.GetMult(block: StatBlock, key: string): BigNum
	local stat = block[key]
	return if stat then stat.Mult else BigNum.One()
end

function Evaluator.GetAdd(block: StatBlock, key: string): BigNum
	local stat = block[key]
	return if stat then stat.Add else BigNum.Zero()
end

function Evaluator.GetNumber(block: StatBlock, key: string): number
	return BigNum.ToNumber(Evaluator.GetAdd(block, key))
end

function Evaluator.HasFlag(block: StatBlock, key: string): boolean
	return Evaluator.GetNumber(block, key) > 0
end

-- (Base + Additive) * Multiplier for a stat.
function Evaluator.Resolve(block: StatBlock, key: string, base: BigNum.Value): BigNum
	return BigNum.Mul(BigNum.Add(base, Evaluator.GetAdd(block, key)), Evaluator.GetMult(block, key))
end

-- Mastery ---------------------------------------------------------------------------

function Evaluator.GetMasteryInfo(xp: number): (number, number, number)
	local mining = Config.Mining
	local level = 0
	local remaining = xp
	local needed = mining.MasteryBaseXP
	while level < mining.MasteryMaxLevel and remaining >= needed do
		remaining -= needed
		level += 1
		needed = mining.MasteryBaseXP * mining.MasteryXPGrowth ^ level
	end
	return level, remaining, needed
end

function Evaluator.GetMasteryMult(xp: number): number
	local level = Evaluator.GetMasteryInfo(xp)
	return 1 + level * Config.Mining.MasteryBonusPerLevel
end

function Evaluator.GetStreakMult(count: number): number
	local mining = Config.Mining
	return 1 + math.min(count, mining.MaxStreak) * mining.StreakBonusPerHit
end

-- Requirements ----------------------------------------------------------------------

function Evaluator.CheckRequirement(profile: Profile, requirement: Requirement?): boolean
	if requirement == nil then
		return true
	end
	if requirement.UpgradeLevel then
		local level = profile.Upgrades[requirement.UpgradeLevel.UpgradeId] or 0
		if level < requirement.UpgradeLevel.Level then
			return false
		end
	end
	if requirement.PrestigeTier then
		local count = profile.PrestigeCounts[requirement.PrestigeTier.TierId] or 0
		if count < requirement.PrestigeTier.Count then
			return false
		end
	end
	if requirement.MilestoneCount then
		if profile.MilestoneCount < requirement.MilestoneCount then
			return false
		end
	end
	if requirement.Currency then
		local held = profile.Currencies[requirement.Currency.CurrencyId] or BigNum.Zero()
		if BigNum.Lt(held, requirement.Currency.Amount) then
			return false
		end
	end
	return true
end

function Evaluator.IsHolding(profile: Profile, currencyId: string, amount: BigNum.Value): boolean
	local held = profile.Currencies[currencyId] or BigNum.Zero()
	return BigNum.Ge(held, amount)
end

-- Every mechanic that can unfold, with its sticky profile.Unfolded key.
local unfoldables: { Unfoldable }? = nil
function Evaluator.GetUnfoldables(): { Unfoldable }
	if unfoldables then
		return unfoldables
	end
	local list: { Unfoldable } = {}
	local function add(kind: string, id: string, name: string, requirement: Requirement?)
		table.insert(list, { Key = kind .. ":" .. id, Kind = kind, DisplayName = name, Requirement = requirement })
	end
	for _, tab in Config.Tabs do
		add("Tab", tab.Id, tab.DisplayName, tab.Visibility)
	end
	for _, currency in Config.Currencies do
		add("Currency", currency.Id, currency.DisplayName, currency.Visibility)
	end
	for _, upgrade in Config.Upgrades do
		add("Upgrade", upgrade.Id, upgrade.DisplayName, upgrade.Visibility)
	end
	for _, generator in Config.Generators do
		add("Generator", generator.Id, generator.DisplayName, generator.Visibility)
	end
	for _, tier in Config.Prestige do
		add("Prestige", tier.Id, tier.DisplayName, tier.Visibility)
	end
	if Config.Mining.Enabled then
		for _, nodeType in Config.Mining.NodeTypes do
			add("Node", nodeType.Id, nodeType.DisplayName, nodeType.Visibility)
		end
	end
	if Config.Refinery.Enabled then
		for _, recipe in Config.Refinery.Recipes do
			add("Recipe", recipe.Id, recipe.DisplayName, recipe.Visibility)
		end
	end
	if Config.Combat.Enabled then
		add("Combat", "Arena", Config.Combat.EnemyName, Config.Combat.Visibility)
	end
	if Config.Runes.Enabled then
		for _, banner in Config.Runes.Banners do
			add("Banner", banner.Id, banner.DisplayName, banner.Visibility)
		end
	end
	for _, trail in Config.Trails do
		add("Trail", trail.Id, trail.DisplayName, trail.Visibility)
	end
	for _, zone in Config.Zones do
		add("Zone", zone.Id, zone.DisplayName, zone.Visibility)
	end
	unfoldables = list
	return list
end

function Evaluator.IsUnfolded(profile: Profile, key: string): boolean
	return profile.Unfolded[key] == true
end

-- Prestige requirement / gain -------------------------------------------------------

function Evaluator.GetPrestigeRequirement(profile: Profile, tier: PrestigeTierDef): BigNum
	local count = profile.PrestigeCounts[tier.Id] or 0
	return BigNum.Mul(tier.Requirement, BigNum.Pow(tier.RequirementGrowth, count))
end

-- Raw gain, ignoring the requirement (used for passive generation previews too).
local function rawPrestigeGain(profile: Profile, block: StatBlock, tier: PrestigeTierDef): BigNum
	local held = profile.Currencies[tier.Source] or BigNum.Zero()
	if BigNum.IsZero(held) or BigNum.Lt(held, 0) then
		return BigNum.Zero()
	end
	local base = BigNum.Pow(BigNum.Div(held, tier.Divisor), tier.Exponent)
	return BigNum.Floor(BigNum.Mul(base, Evaluator.GetMult(block, "PrestigeGain." .. tier.Id)))
end

function Evaluator.CanPrestige(profile: Profile, tier: PrestigeTierDef): boolean
	return Evaluator.IsHolding(profile, tier.Source, Evaluator.GetPrestigeRequirement(profile, tier))
end

function Evaluator.GetPrestigeGain(profile: Profile, block: StatBlock, tier: PrestigeTierDef): BigNum
	if tier.Currency == nil or not Evaluator.CanPrestige(profile, tier) then
		return BigNum.Zero()
	end
	return BigNum.Max(rawPrestigeGain(profile, block, tier), 1)
end

-- Stat aggregation ------------------------------------------------------------------

-- Gathers effects from upgrades, prestige, milestones, mastery, runes, trails,
-- collectibles, boost potions and gamepasses into one block.
function Evaluator.ComputeStats(profile: Profile, gamepasses: { [string]: boolean }?): StatBlock
	local block: StatBlock = {}

	for _, upgrade in Config.Upgrades do
		local level = profile.Upgrades[upgrade.Id] or 0
		if level > 0 then
			applyEffects(block, upgrade.Effects, level)
		end
	end

	for _, tier in Config.Prestige do
		for _, boost in tier.Boosts do
			local amount: BigNum
			if boost.Source == "Count" then
				amount = BigNum.From(profile.PrestigeCounts[tier.Id] or 0)
			elseif tier.Currency then
				amount = profile.Currencies[tier.Currency] or BigNum.Zero()
			else
				amount = BigNum.Zero()
			end
			if not BigNum.IsZero(amount) then
				local stat = entry(block, boost.Stat)
				stat.Mult = BigNum.Mul(stat.Mult, BigNum.Add(1, BigNum.Mul(amount, boost.PerUnit)))
			end
		end
		if tier.Milestones then
			for index, milestone in tier.Milestones do
				if profile.MilestoneCount >= index then
					applyEffects(block, milestone.Effects, 1)
				end
			end
		end
	end

	for _, nodeType in Config.Mining.NodeTypes do
		local mult = Evaluator.GetMasteryMult(profile.Mastery[nodeType.Id] or 0)
		if mult > 1 then
			local stat = entry(block, "MiningYield." .. nodeType.Id)
			stat.Mult = BigNum.Mul(stat.Mult, mult)
		end
	end

	for runeId, count in profile.Runes do
		local rune = ById.Runes[runeId]
		if rune and count > 0 then
			applyEffects(block, rune.Effects, math.min(count, rune.MaxStack))
		end
	end

	if profile.EquippedTrail ~= "" then
		local trail = ById.Trails[profile.EquippedTrail]
		if trail and profile.OwnedTrails[trail.Id] then
			applyEffects(block, trail.Effects, 1)
		end
	end

	for collectibleId, found in profile.Collectibles do
		local collectible = ById.Collectibles[collectibleId]
		if collectible and found then
			applyEffects(block, collectible.Effects, 1)
		end
	end

	for boostId, remaining in profile.Boosts do
		local potion = ById.BoostPotions[boostId]
		if potion and remaining > 0 then
			applyEffects(block, potion.Effects, 1)
		end
	end

	if gamepasses then
		for passId, owned in gamepasses do
			local pass = ById.Gamepasses[passId]
			if pass and owned then
				applyEffects(block, pass.Effects, 1)
			end
		end
	end

	return block
end

-- Upgrades --------------------------------------------------------------------------

-- Base MaxLevel plus Meta-Cap bonuses. math.huge when uncapped.
function Evaluator.GetMaxLevel(block: StatBlock, upgrade: UpgradeDef): number
	if upgrade.MaxLevel == nil then
		return math.huge
	end
	return upgrade.MaxLevel + math.floor(Evaluator.GetNumber(block, "MaxLevel." .. upgrade.Id))
end

function Evaluator.GetBaseCost(upgrade: UpgradeDef, level: number): BigNum
	return BigNum.Floor(BigNum.Mul(upgrade.BaseCost, BigNum.Pow(upgrade.CostGrowth, level)))
end

function Evaluator.IsELFree(block: StatBlock, upgrade: UpgradeDef): boolean
	return upgrade.ELEligible == true and Evaluator.HasFlag(block, "ELAutomation")
end

function Evaluator.GetCost(block: StatBlock, upgrade: UpgradeDef, level: number): BigNum
	if Evaluator.IsELFree(block, upgrade) then
		return BigNum.Zero()
	end
	return Evaluator.GetBaseCost(upgrade, level)
end

function Evaluator.IsThresholdMet(profile: Profile, upgrade: UpgradeDef): boolean
	local threshold = upgrade.ActivationThreshold
	if threshold == nil then
		return true
	end
	return Evaluator.IsHolding(profile, threshold.CurrencyId, threshold.Amount)
end

function Evaluator.CanPurchase(profile: Profile, block: StatBlock, upgrade: UpgradeDef): (boolean, string?)
	if not Evaluator.IsUnfolded(profile, "Upgrade:" .. upgrade.Id) then
		return false, "Locked"
	end
	local level = profile.Upgrades[upgrade.Id] or 0
	if level >= Evaluator.GetMaxLevel(block, upgrade) then
		return false, "Max level reached"
	end
	if not Evaluator.IsThresholdMet(profile, upgrade) then
		local threshold = upgrade.ActivationThreshold :: ConfigModule.CurrencyAmount
		local currency = ById.Currencies[threshold.CurrencyId]
		return false,
			string.format(
				"Hold %s %s to activate",
				BigNum.ToString(threshold.Amount),
				if currency then currency.DisplayName else threshold.CurrencyId
			)
	end
	local cost = Evaluator.GetCost(block, upgrade, level)
	if not Evaluator.IsHolding(profile, upgrade.Currency, cost) then
		return false, "Not enough " .. (if ById.Currencies[upgrade.Currency] then ById.Currencies[upgrade.Currency].DisplayName else upgrade.Currency)
	end
	return true, nil
end

function Evaluator.GetSaveUpToNodeIndex(block: StatBlock): number
	return math.floor(Evaluator.GetNumber(block, "SaveUpToNodeIndex"))
end

-- True when a tier-1 upgrade would survive a reset (node protection or permanent lock).
function Evaluator.IsProtected(profile: Profile, block: StatBlock, upgrade: UpgradeDef): boolean
	if profile.PermanentLocks[upgrade.Id] then
		return true
	end
	return upgrade.Tier == 1 and upgrade.NodeIndex <= Evaluator.GetSaveUpToNodeIndex(block)
end

-- Generators & income ---------------------------------------------------------------

function Evaluator.IsGeneratorActive(profile: Profile, generator: GeneratorDef): boolean
	if not Evaluator.IsUnfolded(profile, "Generator:" .. generator.Id) then
		return false
	end
	return Evaluator.IsHolding(profile, generator.ActivationThreshold.CurrencyId, generator.ActivationThreshold.Amount)
end

-- Per-second rates for every currency.
function Evaluator.GetCurrencyRates(profile: Profile, block: StatBlock): { [string]: BigNum }
	local rates: { [string]: BigNum } = {}

	-- Pass 1: flat income = (BaseRate + Rate.X additive + active generators) * Rate.X multiplier.
	for _, currency in Config.Currencies do
		local base = BigNum.Add(currency.BaseRate or 0, Evaluator.GetAdd(block, "Rate." .. currency.Id))
		for _, generator in Config.Generators do
			if generator.Currency == currency.Id and Evaluator.IsGeneratorActive(profile, generator) then
				base = BigNum.Add(base, generator.BaseRate)
			end
		end
		if BigNum.IsZero(base) then
			rates[currency.Id] = BigNum.Zero()
		else
			rates[currency.Id] = BigNum.Mul(base, Evaluator.GetMult(block, "Rate." .. currency.Id))
		end
	end

	-- Pass 2: cross-currency income = Scale * SourceRate ^ (Exponent + bonus) * Rate.X multiplier.
	local crossGains: { [string]: BigNum } = {}
	for _, currency in Config.Currencies do
		local cross = currency.CrossCurrency
		if cross then
			local active = cross.RequiresUpgrade == nil or (profile.Upgrades[cross.RequiresUpgrade] or 0) > 0
			local sourceRate = rates[cross.Source] or BigNum.Zero()
			if active and BigNum.Gt(sourceRate, 0) then
				local exponent = Evaluator.GetCrossExponent(block, currency.Id)
				local gain = BigNum.Mul(BigNum.Pow(sourceRate, exponent), cross.Scale)
				crossGains[currency.Id] = BigNum.Mul(gain, Evaluator.GetMult(block, "Rate." .. currency.Id))
			end
		end
	end
	for currencyId, gain in crossGains do
		rates[currencyId] = BigNum.Add(rates[currencyId] or BigNum.Zero(), gain)
	end

	-- Pass 3: passive prestige generation (e.g. Milestone: 1% of pending Rebirth Points per second).
	for _, tier in Config.Prestige do
		local fraction = Evaluator.GetNumber(block, "PassivePrestige." .. tier.Id)
		if fraction > 0 and tier.Currency then
			local pending = rawPrestigeGain(profile, block, tier)
			if BigNum.Gt(pending, 0) then
				rates[tier.Currency] = BigNum.Add(rates[tier.Currency] or BigNum.Zero(), BigNum.Mul(pending, fraction))
			end
		end
	end

	return rates
end

function Evaluator.GetCrossExponent(block: StatBlock, currencyId: string): number
	local currency = ById.Currencies[currencyId]
	if not currency or not currency.CrossCurrency then
		return 0
	end
	return currency.CrossCurrency.Exponent + Evaluator.GetNumber(block, "Exponent." .. currencyId)
end

-- Mining ----------------------------------------------------------------------------

function Evaluator.GetMiningYield(block: StatBlock, nodeTypeId: string, streakCount: number): BigNum
	local nodeType = ById.NodeTypes[nodeTypeId]
	if not nodeType then
		return BigNum.Zero()
	end
	local amount = Evaluator.Resolve(block, "MiningYield", nodeType.BaseYield)
	amount = BigNum.Mul(amount, Evaluator.GetMult(block, "MiningYield." .. nodeTypeId))
	return BigNum.Mul(amount, Evaluator.GetStreakMult(streakCount))
end

-- Refinery --------------------------------------------------------------------------

function Evaluator.GetRefineryCycle(block: StatBlock): number
	local refinery = Config.Refinery
	local speed = BigNum.ToNumber(Evaluator.GetMult(block, "RefinerySpeed"))
	return math.max(refinery.MinCycleSeconds, refinery.CycleSeconds / math.max(speed, 1e-6))
end

-- Charge builds linearly from x1 to MaxChargeMultiplier over ChargeSecondsToMax since the last reset.
function Evaluator.GetRefineryCharge(profile: Profile): number
	local refinery = Config.Refinery
	local progress = math.clamp(profile.TimeSinceReset / refinery.ChargeSecondsToMax, 0, 1)
	return 1 + progress * (refinery.MaxChargeMultiplier - 1)
end

function Evaluator.GetRefineryBatches(block: StatBlock, baseBatches: number): number
	local bonus = Evaluator.GetNumber(block, "RefineryBatches")
	return math.max(1, math.floor(baseBatches + bonus))
end

-- Combat ----------------------------------------------------------------------------

function Evaluator.GetEnemyMaxHP(kills: number): BigNum
	local combat = Config.Combat
	return BigNum.Floor(BigNum.Mul(combat.BaseHP, BigNum.Pow(combat.HPGrowth, kills)))
end

function Evaluator.GetEnemyAttack(kills: number): BigNum
	local combat = Config.Combat
	return BigNum.Mul(combat.BaseAttack, BigNum.Pow(combat.AttackGrowth, kills))
end

function Evaluator.GetKillReward(block: StatBlock, kills: number): BigNum
	local combat = Config.Combat
	local base = BigNum.Mul(combat.BaseReward, BigNum.Pow(combat.RewardGrowth, kills))
	return BigNum.Floor(BigNum.Max(BigNum.Mul(base, Evaluator.GetMult(block, "FightReward")), 1))
end

function Evaluator.GetPlayerMaxHP(block: StatBlock): BigNum
	return Evaluator.Resolve(block, "FightHealth", Config.Combat.PlayerBaseHP)
end

function Evaluator.GetPlayerDamage(block: StatBlock): BigNum
	return Evaluator.Resolve(block, "FightDamage", Config.Combat.PlayerBaseDamage)
end

-- Runes -----------------------------------------------------------------------------

-- Weighted pool; Luck multiplies each rarity's weight by (1 + Luck)^(rank - 1).
function Evaluator.GetRuneWeights(block: StatBlock, banner: BannerDef): ({ { RuneId: string, Weight: number } }, number)
	local luck = Evaluator.GetNumber(block, "Luck")
	local pool: { { RuneId: string, Weight: number } } = {}
	local total = 0
	for _, runeId in banner.Pool do
		local rune = ById.Runes[runeId]
		local rarity = if rune then ById.Rarities[rune.Rarity] else nil
		if rune and rarity then
			local rank = ConfigModule.RarityRank[rarity.Id] or 1
			local weight = rarity.Weight * (1 + luck) ^ (rank - 1)
			table.insert(pool, { RuneId = runeId, Weight = weight })
			total += weight
		end
	end
	return pool, total
end

return Evaluator
