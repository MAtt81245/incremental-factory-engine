--!strict
--[[
	ServerMain
	Boots every service in dependency order, then runs an automated math/state self-test
	and prints the result to the Output window.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local Services = script.Parent.Services

local BigNum = require(Modules.BigNum)
local ConfigModule = require(Modules.IncrementalConfig)
local Network = require(Modules.Network)
local DataService = require(Services.DataService)
local EvaluatorService = require(Services.EvaluatorService)
local ActiveLoopsService = require(Services.ActiveLoopsService)
local IncrementalService = require(Services.IncrementalService)
local WorkspaceBootstrapper = require(Services.WorkspaceBootstrapper)

local Config = ConfigModule.Data
local ById = ConfigModule.ById

-- Self-test -------------------------------------------------------------------------

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
	else
		table.insert(failures, name .. (if detail then " (" .. detail .. ")" else ""))
	end
end

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-6) * math.max(1, math.abs(b))
end

local function testBigNum()
	check("BigNum add carry", BigNum.Eq(BigNum.Add(999, 1), 1000))
	check("BigNum sub negative", BigNum.Eq(BigNum.Sub(5, 7), -2))
	check("BigNum normalize", BigNum.From(12345).Mantissa == 1.2345 and BigNum.From(12345).Exponent == 4)
	check("BigNum past 1e308", BigNum.Mul("1e300", "1e300").Exponent == 600)
	check("BigNum pow huge", BigNum.Pow(10, 400).Exponent == 400)
	check("BigNum div", BigNum.Eq(BigNum.Div("1e500", "1e499"), 10))
	check("BigNum log10", near(BigNum.Log10("1e500"), 500))
	check("BigNum cmp", BigNum.Cmp("1e400", "1e399") == 1 and BigNum.Cmp(-5, 3) == -1 and BigNum.Cmp(0, 0) == 0)
	check("BigNum floor", BigNum.Eq(BigNum.Floor(114.99999999999), 115))
	check("BigNum format K", BigNum.ToString(1500) == "1.5K", BigNum.ToString(1500))
	check("BigNum format Qd", BigNum.ToString("2.5e15") == "2.5Qd", BigNum.ToString("2.5e15"))
	check("BigNum format Ce", BigNum.ToString("1e303") == "1Ce", BigNum.ToString("1e303"))
	check("BigNum format sci", BigNum.ToString("1e400") == "1e400", BigNum.ToString("1e400"))
	local big = BigNum.Pow(1.5, 5000)
	check("BigNum serialize roundtrip", BigNum.Eq(BigNum.Deserialize(BigNum.Serialize(big)), big))
	check("BigNum parse sci string", BigNum.Deserialize("3e450").Exponent == 450)
end

local function unfoldAll(profile: DataService.Profile)
	for _, unfoldable in EvaluatorService.GetUnfoldables() do
		profile.Unfolded[unfoldable.Key] = true
	end
end

local function testEvaluator()
	local profile = DataService.NewProfile()
	unfoldAll(profile)

	-- Math type 1: additive + multiplicative.
	profile.Upgrades.CashGen1 = 5
	profile.Upgrades.CashMult1 = 2
	local block = EvaluatorService.ComputeStats(profile, nil)
	local rates = EvaluatorService.GetCurrencyRates(profile, block)
	local cashRate = BigNum.ToNumber(rates.Cash)
	check("Additive+Multiplicative rate", near(cashRate, 6 * 1.25 ^ 2), tostring(cashRate))

	-- Math type 2: cross-currency exponent.
	profile.Upgrades.GemUnlock = 1
	profile.Upgrades.GemExponent = 2
	block = EvaluatorService.ComputeStats(profile, nil)
	rates = EvaluatorService.GetCurrencyRates(profile, block)
	local expectedGems = 0.2 * cashRate ^ 0.6
	check("Cross-currency exponent", near(EvaluatorService.GetCrossExponent(block, "Gems"), 0.6))
	check("Cross-currency rate", near(BigNum.ToNumber(rates.Gems), expectedGems), BigNum.ToString(rates.Gems))

	-- Math type 3: meta-cap.
	profile.Upgrades.PressExpansion = 2
	block = EvaluatorService.ComputeStats(profile, nil)
	check("Meta-cap raises MaxLevel", EvaluatorService.GetMaxLevel(block, ById.Upgrades.CashGen1) == 35)

	-- Math type 4: non-consumptive activation threshold.
	local vault = ById.Upgrades.VaultResonance
	profile.Currencies.Cash = BigNum.From(100)
	check("Threshold blocks purchase", not (EvaluatorService.CanPurchase(profile, block, vault)))
	profile.Currencies.Cash = BigNum.From(3000)
	check("Threshold allows purchase", (EvaluatorService.CanPurchase(profile, block, vault)))
	check("Threshold does not spend", BigNum.IsZero(EvaluatorService.GetCost(block, vault, 0)))

	-- EL automation.
	local press = ById.Upgrades.CashGen1
	check("Cost scaling", BigNum.Eq(EvaluatorService.GetCost(block, press, 5), BigNum.Floor(10 * 1.15 ^ 5)))
	profile.Upgrades.ExpendLess = 1
	block = EvaluatorService.ComputeStats(profile, nil)
	check("EL makes eligible upgrades free", BigNum.IsZero(EvaluatorService.GetCost(block, press, 5)))
	check("EL ignores ineligible upgrades", not BigNum.IsZero(EvaluatorService.GetCost(block, ById.Upgrades.Blade, 0)))

	-- Prestige.
	profile.Currencies.Cash = BigNum.From(4000)
	local rebirth = ById.Prestige.Rebirth
	check("Rebirth gain", BigNum.Eq(EvaluatorService.GetPrestigeGain(profile, block, rebirth), 2))
	local milestone = ById.Prestige.Milestone
	profile.PrestigeCounts.Milestone = 1
	check("Milestone requirement growth", BigNum.Eq(EvaluatorService.GetPrestigeRequirement(profile, milestone), 15))
	check("Milestone awards no currency", BigNum.IsZero(EvaluatorService.GetPrestigeGain(profile, block, milestone)))

	-- Preservation.
	profile.Upgrades.MemoryCrystal = 2
	block = EvaluatorService.ComputeStats(profile, nil)
	check("SaveUpToNodeIndex protects node 4", EvaluatorService.IsProtected(profile, block, ById.Upgrades.GemExponent))
	check("SaveUpToNodeIndex leaves node 5", not EvaluatorService.IsProtected(profile, block, ById.Upgrades.PressExpansion))
	profile.PermanentLocks.CashMult1 = true
	check("Permanent lock protects", EvaluatorService.IsProtected(profile, block, ById.Upgrades.CashMult1))

	-- Combat scaling and mastery.
	check("Enemy HP scaling", BigNum.Eq(EvaluatorService.GetEnemyMaxHP(10), math.floor(20 * 1.22 ^ 10)))
	local level = EvaluatorService.GetMasteryInfo(Config.Mining.MasteryBaseXP)
	check("Mastery level-up", level == 1)

	-- Visibility.
	local fresh = DataService.NewProfile()
	check("Visibility hidden", not EvaluatorService.CheckRequirement(fresh, ById.Upgrades.CashMult1.Visibility))
	fresh.Upgrades.CashGen1 = 3
	check("Visibility shown", EvaluatorService.CheckRequirement(fresh, ById.Upgrades.CashMult1.Visibility))

	-- Persistence.
	profile.Currencies.Gems = BigNum.From("4.2e512")
	local restored = DataService.Deserialize(DataService.Serialize(profile))
	check("Profile BigNum roundtrip", BigNum.Eq(restored.Currencies.Gems, "4.2e512"))
	check("Profile levels roundtrip", restored.Upgrades.CashGen1 == 5)
end

local function testConfigIntegrity()
	local function currencyExists(id: string, where: string)
		check("Currency ref " .. where, ById.Currencies[id] ~= nil, id)
	end
	local function requirementValid(requirement: ConfigModule.Requirement?, where: string)
		if not requirement then
			return
		end
		if requirement.UpgradeLevel then
			check("Upgrade ref " .. where, ById.Upgrades[requirement.UpgradeLevel.UpgradeId] ~= nil)
		end
		if requirement.PrestigeTier then
			check("Prestige ref " .. where, ById.Prestige[requirement.PrestigeTier.TierId] ~= nil)
		end
		if requirement.Currency then
			currencyExists(requirement.Currency.CurrencyId, where)
		end
	end
	for _, upgrade in Config.Upgrades do
		currencyExists(upgrade.Currency, upgrade.Id)
		requirementValid(upgrade.Visibility, upgrade.Id)
		for _, effect in upgrade.Effects do
			if effect.Type == "MetaCap" then
				check("MetaCap target " .. upgrade.Id, effect.Target ~= nil and ById.Upgrades[effect.Target] ~= nil)
			elseif effect.Type == "ExponentAdd" then
				local target = effect.Target and ById.Currencies[effect.Target]
				check("ExponentAdd target " .. upgrade.Id, target ~= nil and target.CrossCurrency ~= nil)
			end
		end
	end
	for _, currency in Config.Currencies do
		requirementValid(currency.Visibility, currency.Id)
		if currency.CrossCurrency then
			currencyExists(currency.CrossCurrency.Source, currency.Id .. " cross source")
		end
	end
	for _, tier in Config.Prestige do
		currencyExists(tier.Source, tier.Id)
		if tier.Currency then
			currencyExists(tier.Currency, tier.Id)
		end
	end
	for _, nodeType in Config.Mining.NodeTypes do
		currencyExists(nodeType.Currency, nodeType.Id)
	end
	for _, recipe in Config.Refinery.Recipes do
		currencyExists(recipe.Input, recipe.Id)
		currencyExists(recipe.Output, recipe.Id)
	end
	for _, banner in Config.Runes.Banners do
		currencyExists(banner.CostCurrency, banner.Id)
		for _, runeId in banner.Pool do
			local rune = ById.Runes[runeId]
			check("Rune ref " .. runeId, rune ~= nil and ById.Rarities[rune.Rarity] ~= nil)
		end
	end
	currencyExists(Config.Combat.RewardCurrency, "Combat")
end

local function runSelfTest()
	local ok, err = pcall(function()
		testBigNum()
		testEvaluator()
		testConfigIntegrity()
	end)
	if not ok then
		table.insert(failures, "Self-test crashed: " .. tostring(err))
	end
	if #failures == 0 then
		print(string.format("[IncrementalFactory] Self-test PASSED (%d checks).", passed))
	else
		warn(string.format("[IncrementalFactory] Self-test: %d passed, %d FAILED:", passed, #failures))
		for _, failure in failures do
			warn("  ✗ " .. failure)
		end
	end
end

-- Boot ------------------------------------------------------------------------------

Network.Init()
WorkspaceBootstrapper.Build()
DataService.Init()
ActiveLoopsService.Init()
IncrementalService.Init()
print(string.format("[IncrementalFactory] %s server online.", Config.GameName))
runSelfTest()
