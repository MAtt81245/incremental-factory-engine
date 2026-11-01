--!strict
--[[
	IncrementalService
	Core server loop: fixed-step simulation on Heartbeat, upgrade purchasing, EL autobuyers,
	3-tier prestige with preservation, unfold detection, client snapshots, CollectionService
	workspace binding (prompts, clicks, touch pads) and MarketplaceService hooks.
]]

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local BigNum = require(Modules.BigNum)
local ConfigModule = require(Modules.IncrementalConfig)
local Network = require(Modules.Network)
local DataService = require(script.Parent.DataService)
local Evaluator = require(script.Parent.EvaluatorService)
local ActiveLoops = require(script.Parent.ActiveLoopsService)

local Config = ConfigModule.Data
local ById = ConfigModule.ById
local Tags = Config.Tags
local Attributes = Config.Attributes

type BigNum = BigNum.BigNum
type Session = DataService.Session
type Profile = DataService.Profile
type StatBlock = DataService.StatBlock
type UpgradeDef = ConfigModule.UpgradeDef
type PrestigeTierDef = ConfigModule.PrestigeTierDef

local PROMPT_NAME = "IncrementalPrompt"
local CLICK_NAME = "IncrementalClick"
local MAX_BULK_PURCHASE = 1000
local MAX_TICKS_PER_FRAME = 5
local RECEIPT_HISTORY = 50
local PAD_TOUCH_COOLDOWN = 0.6

local IncrementalService = {}
local accumulator = 0
local initialized = false

-- Helpers ---------------------------------------------------------------------------

local function currencyName(currencyId: string): string
	local currency = ById.Currencies[currencyId]
	return if currency then currency.DisplayName else currencyId
end

local function refreshStats(session: Session): StatBlock
	local block = Evaluator.ComputeStats(session.Profile, session.Runtime.Gamepasses)
	session.Runtime.Stats = block
	return block
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

-- Unfolding -------------------------------------------------------------------------

function IncrementalService.CheckUnfolds(session: Session, silent: boolean)
	local profile = session.Profile
	for _, unfoldable in Evaluator.GetUnfoldables() do
		if not profile.Unfolded[unfoldable.Key] and Evaluator.CheckRequirement(profile, unfoldable.Requirement) then
			profile.Unfolded[unfoldable.Key] = true
			if not silent and unfoldable.Requirement ~= nil then
				local payload: Network.UnfoldPayload = {
					Key = unfoldable.Key,
					Kind = unfoldable.Kind,
					DisplayName = unfoldable.DisplayName,
				}
				Network.FireClient(session.Player, "Unfold", payload)
			end
		end
	end
end

-- Upgrades --------------------------------------------------------------------------

-- Buys up to `limit` levels. Returns levels bought and the reason the loop stopped.
local function buyLevels(session: Session, upgrade: UpgradeDef, limit: number): (number, string?)
	local profile = session.Profile
	local block = session.Runtime.Stats
	if next(block) == nil then
		block = refreshStats(session)
	end
	local bought = 0
	local reason: string? = nil
	while bought < limit do
		local ok, failReason = Evaluator.CanPurchase(profile, block, upgrade)
		if not ok then
			reason = failReason
			break
		end
		local level = profile.Upgrades[upgrade.Id] or 0
		local cost = Evaluator.GetCost(block, upgrade, level)
		if not BigNum.IsZero(cost) then
			profile.Currencies[upgrade.Currency] = BigNum.Sub(profile.Currencies[upgrade.Currency], cost)
		end
		profile.Upgrades[upgrade.Id] = level + 1
		bought += 1
	end
	if bought > 0 then
		refreshStats(session)
	end
	return bought, reason
end

function IncrementalService.Purchase(player: Player, upgradeId: string, mode: string): number
	local session = DataService.GetSession(player)
	local upgrade = ById.Upgrades[upgradeId]
	if not session or not upgrade then
		return 0
	end
	local limit = if mode == "Max" then MAX_BULK_PURCHASE else 1
	local bought, reason = buyLevels(session, upgrade, limit)
	if bought == 0 and reason then
		Network.Notify(player, upgrade.DisplayName, reason, "Warning")
	end
	return bought
end

function IncrementalService.BuyPermanentLock(player: Player, upgradeId: string): boolean
	local session = DataService.GetSession(player)
	local upgrade = ById.Upgrades[upgradeId]
	if not session or not upgrade or not upgrade.PermanentLockCost then
		return false
	end
	local profile = session.Profile
	if profile.PermanentLocks[upgradeId] or not Evaluator.IsUnfolded(profile, "Upgrade:" .. upgradeId) then
		return false
	end
	local lockCost = upgrade.PermanentLockCost
	local held = profile.Currencies[lockCost.CurrencyId] or BigNum.Zero()
	if BigNum.Lt(held, lockCost.Amount) then
		Network.Notify(
			player,
			"Permanent Lock",
			string.format("Needs %s %s", BigNum.ToString(lockCost.Amount), currencyName(lockCost.CurrencyId)),
			"Warning"
		)
		return false
	end
	profile.Currencies[lockCost.CurrencyId] = BigNum.Sub(held, lockCost.Amount)
	profile.PermanentLocks[upgradeId] = true
	Network.Notify(player, "Permanent Lock", upgrade.DisplayName .. " will never reset again.", "Success")
	return true
end

-- EL Automation: eligible upgrades cost 0 and are bought up to their (meta-capped) max.
local function runAutobuyers(session: Session, block: StatBlock)
	if not Evaluator.HasFlag(block, "ELAutomation") or not session.Profile.Settings.AutoBuy then
		return
	end
	for _, upgrade in Config.Upgrades do
		if upgrade.ELEligible and Evaluator.IsUnfolded(session.Profile, "Upgrade:" .. upgrade.Id) then
			buyLevels(session, upgrade, Config.Automation.ELBulkPerPass)
		end
	end
end

-- Prestige --------------------------------------------------------------------------

local function resetForTier(session: Session, tier: number, block: StatBlock)
	local profile = session.Profile
	for _, currency in Config.Currencies do
		if currency.ResetTier > 0 and currency.ResetTier <= tier then
			profile.Currencies[currency.Id] = BigNum.From(currency.StartAmount or 0)
		end
	end
	for _, upgrade in Config.Upgrades do
		if upgrade.Tier > 0 and upgrade.Tier <= tier and not Evaluator.IsProtected(profile, block, upgrade) then
			profile.Upgrades[upgrade.Id] = 0
		end
	end
	for _, state in profile.Refinery do
		state.Progress = 0
	end
	if Config.Combat.ResetTier > 0 and Config.Combat.ResetTier <= tier then
		profile.Combat.Kills = 0
		profile.Combat.EnemyHP = Evaluator.GetEnemyMaxHP(0)
	end
	profile.TimeSinceReset = 0
	local runtime = session.Runtime
	runtime.StreakCount = 0
	runtime.StreakType = ""
	runtime.LastEngagedAt = 0
end

function IncrementalService.Prestige(player: Player, tierId: string): boolean
	local session = DataService.GetSession(player)
	local tierDef: PrestigeTierDef? = ById.Prestige[tierId]
	if not session or not tierDef then
		return false
	end
	local tier = tierDef :: PrestigeTierDef
	local profile = session.Profile
	if not Evaluator.IsUnfolded(profile, "Prestige:" .. tier.Id) then
		return false
	end
	if not Evaluator.CanPrestige(profile, tier) then
		Network.Notify(
			player,
			tier.DisplayName,
			string.format(
				"Hold %s %s first",
				BigNum.ToString(Evaluator.GetPrestigeRequirement(profile, tier)),
				currencyName(tier.Source)
			),
			"Warning"
		)
		return false
	end
	-- Protection (SaveUpToNodeIndex) is evaluated before the reset so the upgrades granting it still count.
	local block = refreshStats(session)
	local gain = Evaluator.GetPrestigeGain(profile, block, tier)
	resetForTier(session, tier.Tier, block)
	if tier.Currency then
		profile.Currencies[tier.Currency] = BigNum.Add(profile.Currencies[tier.Currency] or BigNum.Zero(), gain)
	end
	profile.PrestigeCounts[tier.Id] = (profile.PrestigeCounts[tier.Id] or 0) + 1
	if tier.Milestones then
		profile.MilestoneCount += 1
		local milestone = tier.Milestones[profile.MilestoneCount]
		Network.Notify(
			player,
			if milestone then milestone.DisplayName .. " reached!" else "Milestone " .. profile.MilestoneCount,
			if milestone then milestone.Description else "Beyond the last configured milestone.",
			"Success"
		)
	else
		Network.Notify(
			player,
			tier.DisplayName .. " complete!",
			string.format("+%s %s", BigNum.ToString(gain), currencyName(tier.Currency :: string)),
			"Success"
		)
	end
	block = refreshStats(session)
	session.Runtime.PlayerHP = Evaluator.GetPlayerMaxHP(block)
	IncrementalService.CheckUnfolds(session, false)
	return true
end

-- Snapshot --------------------------------------------------------------------------

function IncrementalService.BuildSnapshot(session: Session): Network.Snapshot
	local profile = session.Profile
	local runtime = session.Runtime
	local block = runtime.Stats
	if next(block) == nil then
		block = refreshStats(session)
	end
	local rates = runtime.Rates
	if next(rates) == nil then
		rates = Evaluator.GetCurrencyRates(profile, block)
	end

	local currencies: { [string]: string } = {}
	local rateText: { [string]: string } = {}
	for _, currency in Config.Currencies do
		currencies[currency.Id] = BigNum.Serialize(profile.Currencies[currency.Id] or BigNum.Zero())
		rateText[currency.Id] = BigNum.Serialize(rates[currency.Id] or BigNum.Zero())
	end

	local upgrades: { [string]: Network.UpgradeState } = {}
	for _, upgrade in Config.Upgrades do
		if profile.Unfolded["Upgrade:" .. upgrade.Id] then
			local level = profile.Upgrades[upgrade.Id] or 0
			local maxLevel = Evaluator.GetMaxLevel(block, upgrade)
			local cost = Evaluator.GetCost(block, upgrade, level)
			local thresholdMet = Evaluator.IsThresholdMet(profile, upgrade)
			upgrades[upgrade.Id] = {
				Level = level,
				MaxLevel = if maxLevel == math.huge then -1 else maxLevel,
				Cost = BigNum.Serialize(cost),
				Affordable = level < maxLevel
					and thresholdMet
					and Evaluator.IsHolding(profile, upgrade.Currency, cost),
				Free = Evaluator.IsELFree(block, upgrade),
				ThresholdMet = thresholdMet,
				Locked = profile.PermanentLocks[upgrade.Id] == true,
				CanLock = upgrade.PermanentLockCost ~= nil and not profile.PermanentLocks[upgrade.Id],
				Protected = Evaluator.IsProtected(profile, block, upgrade),
			}
		end
	end

	local prestige: { [string]: Network.PrestigeState } = {}
	for _, tier in Config.Prestige do
		prestige[tier.Id] = {
			Count = profile.PrestigeCounts[tier.Id] or 0,
			Gain = BigNum.Serialize(Evaluator.GetPrestigeGain(profile, block, tier)),
			Requirement = BigNum.Serialize(Evaluator.GetPrestigeRequirement(profile, tier)),
			CanPrestige = Evaluator.CanPrestige(profile, tier),
		}
	end

	local generators: { [string]: boolean } = {}
	for _, generator in Config.Generators do
		generators[generator.Id] = Evaluator.IsGeneratorActive(profile, generator)
	end

	local mastery: { [string]: Network.MasteryState } = {}
	for _, nodeType in Config.Mining.NodeTypes do
		local xp = profile.Mastery[nodeType.Id] or 0
		local level, current, needed = Evaluator.GetMasteryInfo(xp)
		mastery[nodeType.Id] = {
			Level = level,
			XP = current,
			Needed = needed,
			Mult = Evaluator.GetMasteryMult(xp),
		}
	end

	local cycle = Evaluator.GetRefineryCycle(block)
	local charge = Evaluator.GetRefineryCharge(profile)
	local refinery: { [string]: Network.RefineryState } = {}
	for _, recipe in Config.Refinery.Recipes do
		local state = profile.Refinery[recipe.Id]
		refinery[recipe.Id] = {
			Enabled = state ~= nil and state.Enabled,
			Progress = if state then math.clamp(state.Progress / cycle, 0, 1) else 0,
			Cycle = cycle,
			Charge = charge,
		}
	end

	local kills = profile.Combat.Kills
	local enemyMax = Evaluator.GetEnemyMaxHP(kills)
	local playerMax = Evaluator.GetPlayerMaxHP(block)
	local function fraction(current: BigNum, maximum: BigNum): number
		if BigNum.Le(maximum, 0) then
			return 0
		end
		return math.clamp(BigNum.ToNumber(BigNum.Div(current, maximum)), 0, 1)
	end

	return {
		Currencies = currencies,
		Rates = rateText,
		Upgrades = upgrades,
		Unfolded = profile.Unfolded,
		Prestige = prestige,
		MilestoneCount = profile.MilestoneCount,
		Generators = generators,
		Mining = {
			StreakType = runtime.StreakType,
			StreakCount = runtime.StreakCount,
			StreakMult = Evaluator.GetStreakMult(runtime.StreakCount),
			YieldMult = BigNum.Serialize(Evaluator.GetMult(block, "MiningYield")),
			Mastery = mastery,
		},
		Refinery = refinery,
		Combat = {
			Kills = kills,
			EnemyHP = BigNum.Serialize(profile.Combat.EnemyHP),
			EnemyMaxHP = BigNum.Serialize(enemyMax),
			EnemyHPFraction = fraction(profile.Combat.EnemyHP, enemyMax),
			EnemyAttack = BigNum.Serialize(Evaluator.GetEnemyAttack(kills)),
			PlayerHP = BigNum.Serialize(runtime.PlayerHP),
			PlayerMaxHP = BigNum.Serialize(playerMax),
			PlayerHPFraction = fraction(runtime.PlayerHP, playerMax),
			Damage = BigNum.Serialize(Evaluator.GetPlayerDamage(block)),
			Reward = BigNum.Serialize(Evaluator.GetKillReward(block, kills)),
		},
		Runes = profile.Runes,
		OwnedTrails = profile.OwnedTrails,
		EquippedTrail = profile.EquippedTrail,
		Collectibles = profile.Collectibles,
		Boosts = profile.Boosts,
		Gamepasses = runtime.Gamepasses,
		Settings = profile.Settings,
		Stats = {
			ELAutomation = Evaluator.HasFlag(block, "ELAutomation"),
			AutoMine = Evaluator.HasFlag(block, "AutoMine"),
			AutoFight = Evaluator.HasFlag(block, "AutoFight"),
			SaveUpToNodeIndex = Evaluator.GetSaveUpToNodeIndex(block),
			Luck = Evaluator.GetNumber(block, "Luck"),
			WalkSpeed = Config.Settings.BaseWalkSpeed + Evaluator.GetNumber(block, "WalkSpeed"),
		},
	}
end

local function sendSnapshot(session: Session)
	Network.FireClient(session.Player, "StateSync", IncrementalService.BuildSnapshot(session))
end

-- Simulation ------------------------------------------------------------------------

local function tickBoosts(session: Session, dt: number)
	local boosts = session.Profile.Boosts
	for boostId, remaining in boosts do
		local left = remaining - dt
		if left <= 0 then
			boosts[boostId] = nil
			local potion = ById.BoostPotions[boostId]
			Network.Notify(
				session.Player,
				"Boost Expired",
				(if potion then potion.DisplayName else boostId) .. " has worn off.",
				"Info"
			)
		else
			boosts[boostId] = left
		end
	end
end

local function tickPlayer(session: Session, dt: number, now: number)
	local profile = session.Profile
	local runtime = session.Runtime
	local block = refreshStats(session)

	local rates = Evaluator.GetCurrencyRates(profile, block)
	runtime.Rates = rates
	for currencyId, rate in rates do
		if not BigNum.IsZero(rate) then
			profile.Currencies[currencyId] =
				BigNum.Add(profile.Currencies[currencyId] or BigNum.Zero(), BigNum.Mul(rate, dt))
		end
	end
	profile.TimeSinceReset += dt
	profile.PlayTime += dt
	tickBoosts(session, dt)

	ActiveLoops.TickRefinery(session, block, dt)
	ActiveLoops.TickMining(session, block, now)
	ActiveLoops.TickCombat(session, block, now, dt)

	if now - runtime.LastAutobuy >= Config.Automation.AutobuyInterval then
		runtime.LastAutobuy = now
		runAutobuyers(session, block)
	end
	if now - runtime.LastUnfoldCheck >= Config.Settings.UnfoldCheckRate then
		runtime.LastUnfoldCheck = now
		IncrementalService.CheckUnfolds(session, false)
	end
	if now - runtime.LastCharacterApply >= 1 then
		runtime.LastCharacterApply = now
		ActiveLoops.ApplyCharacterStats(session, runtime.Stats)
	end
	if now - runtime.LastSync >= Config.Settings.SyncRate then
		runtime.LastSync = now
		sendSnapshot(session)
	end
end

local function step(deltaTime: number)
	local tickRate = Config.Settings.TickRate
	accumulator = math.min(accumulator + deltaTime, tickRate * MAX_TICKS_PER_FRAME)
	while accumulator >= tickRate do
		accumulator -= tickRate
		local now = os.clock()
		for _, session in DataService.GetSessions() do
			if not session.Released then
				xpcall(tickPlayer, function(err)
					warn("[IncrementalService] Tick failed for", session.Player.Name, err)
				end, session, tickRate, now)
			end
		end
	end
end

-- Monetization ----------------------------------------------------------------------

local function grantPotion(session: Session, potion: ConfigModule.BoostPotionDef)
	local boosts = session.Profile.Boosts
	boosts[potion.Id] = math.min((boosts[potion.Id] or 0) + potion.Duration, potion.MaxStackSeconds)
	Network.Notify(
		session.Player,
		potion.DisplayName,
		string.format("Active for %d min. Boost timers never reset.", math.floor(boosts[potion.Id] / 60)),
		"Success"
	)
end

local function processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local session = if player then DataService.GetSession(player) else nil
	if not player or not session then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receiptInfo.PurchaseId)
	local receipts = session.Profile.RecentReceipts
	if table.find(receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local potion: ConfigModule.BoostPotionDef? = nil
	for _, candidate in Config.Monetization.BoostPotions do
		if candidate.ProductId == receiptInfo.ProductId then
			potion = candidate
			break
		end
	end
	if not potion then
		warn("[IncrementalService] Unknown product id", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grantPotion(session, potion)
	table.insert(receipts, purchaseId)
	while #receipts > RECEIPT_HISTORY do
		table.remove(receipts, 1)
	end
	if not DataService.SaveProfile(player, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function canGrantFreeInStudio(): boolean
	return RunService:IsStudio() and Config.Monetization.StudioFreePurchases
end

local function requestBoost(player: Player, boostId: string)
	local session = DataService.GetSession(player)
	local potion = ById.BoostPotions[boostId]
	if not session or not potion then
		return
	end
	if potion.ProductId > 0 then
		MarketplaceService:PromptProductPurchase(player, potion.ProductId)
	elseif canGrantFreeInStudio() then
		grantPotion(session, potion)
	else
		Network.Notify(player, potion.DisplayName, "This product is not configured yet.", "Warning")
	end
end

local function requestGamepass(player: Player, passId: string)
	local session = DataService.GetSession(player)
	local pass = ById.Gamepasses[passId]
	if not session or not pass or session.Runtime.Gamepasses[passId] then
		return
	end
	if pass.GamePassId > 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
	elseif canGrantFreeInStudio() then
		session.Runtime.Gamepasses[passId] = true
		refreshStats(session)
		Network.Notify(player, pass.DisplayName, "Granted for this Studio session (test mode).", "Success")
	else
		Network.Notify(player, pass.DisplayName, "This gamepass is not configured yet.", "Warning")
	end
end

local function loadGamepasses(session: Session)
	for _, pass in Config.Monetization.Gamepasses do
		if pass.GamePassId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(session.Player.UserId, pass.GamePassId)
			end)
			if ok and owns then
				session.Runtime.Gamepasses[pass.Id] = true
			end
		end
	end
end

-- Workspace binding -----------------------------------------------------------------

local function bindTag(tag: string, binder: (Instance) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(binder, instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(binder)
end

local function makePrompt(parent: Instance, name: string, action: string, object: string, key: Enum.KeyCode): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function makeClick(parent: Instance, distance: number): ClickDetector
	local existing = parent:FindFirstChild(CLICK_NAME)
	if existing and existing:IsA("ClickDetector") then
		return existing
	end
	local detector = Instance.new("ClickDetector")
	detector.Name = CLICK_NAME
	detector.MaxActivationDistance = distance
	detector.Parent = parent
	return detector
end

local function bindButton(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local upgradeId = instance:GetAttribute(Attributes.UpgradeId)
	local upgrade = if type(upgradeId) == "string" then ById.Upgrades[upgradeId] else nil
	if not upgrade then
		warn("[IncrementalService] IncrementalButton without a valid UpgradeId:", instance:GetFullName())
		return
	end
	local upgradeDef = upgrade :: UpgradeDef
	instance.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		local session = if player then DataService.GetSession(player) else nil
		if not player or not session then
			return
		end
		local now = os.clock()
		local last = session.Runtime.TouchDebounce[upgradeDef.Id] or 0
		if now - last < PAD_TOUCH_COOLDOWN then
			return
		end
		session.Runtime.TouchDebounce[upgradeDef.Id] = now
		if Evaluator.IsUnfolded(session.Profile, "Upgrade:" .. upgradeDef.Id) then
			IncrementalService.Purchase(player, upgradeDef.Id, "One")
		end
	end)
	local prompt = makePrompt(instance, PROMPT_NAME, "Buy Max", upgradeDef.DisplayName, Enum.KeyCode.E)
	prompt.Triggered:Connect(function(player)
		IncrementalService.Purchase(player, upgradeDef.Id, "Max")
	end)
end

local function bindMineNode(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local detector = makeClick(instance, Config.Mining.Range + 6)
	detector.MouseClick:Connect(function(player)
		ActiveLoops.Mine(player, instance, false)
	end)
	local nodeTypeId = instance:GetAttribute(Attributes.NodeType)
	local nodeType = if type(nodeTypeId) == "string" then ById.NodeTypes[nodeTypeId] else nil
	local prompt = makePrompt(
		instance,
		PROMPT_NAME,
		"Mine",
		if nodeType then nodeType.DisplayName else "Node",
		Enum.KeyCode.E
	)
	prompt.Triggered:Connect(function(player)
		ActiveLoops.Mine(player, instance, false)
	end)
end

local function bindRefinery(instance: Instance)
	local recipeId = instance:GetAttribute(Attributes.RecipeId)
	local recipe = if type(recipeId) == "string" then ById.Recipes[recipeId] else nil
	if not recipe then
		warn("[IncrementalService] RefineryMachine without a valid RecipeId:", instance:GetFullName())
		return
	end
	local recipeDef = recipe :: ConfigModule.RecipeDef
	local prompt = makePrompt(instance, PROMPT_NAME, "Toggle", recipeDef.DisplayName, Enum.KeyCode.E)
	prompt.Triggered:Connect(function(player)
		ActiveLoops.ToggleRefinery(player, recipeDef.Id)
	end)
end

local function bindAltar(instance: Instance)
	local bannerId = instance:GetAttribute(Attributes.RuneBannerId)
	local banner = if type(bannerId) == "string" then ById.Banners[bannerId] else nil
	if not banner then
		warn("[IncrementalService] RuneAltar without a valid RuneBannerId:", instance:GetFullName())
		return
	end
	local bannerDef = banner :: ConfigModule.BannerDef
	local keys = { Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.T }
	for index, count in Config.Runes.RollCounts do
		local prompt = makePrompt(
			instance,
			PROMPT_NAME .. count,
			"Roll x" .. count,
			bannerDef.DisplayName,
			keys[index] or Enum.KeyCode.E
		)
		prompt.UIOffset = Vector2.new(0, (index - 1) * 72)
		prompt.Triggered:Connect(function(player)
			ActiveLoops.RollRunes(player, bannerDef.Id, count)
		end)
	end
end

local function bindArena(instance: Instance)
	local enemy = instance:FindFirstChild("Enemy", true)
	local target: Instance = if enemy and enemy:IsA("BasePart") then enemy else instance
	local detector = makeClick(target, Config.Combat.Range + 10)
	detector.MouseClick:Connect(function(player)
		ActiveLoops.Attack(player, false)
	end)
	local prompt = makePrompt(target, PROMPT_NAME, "Attack", Config.Combat.EnemyName, Enum.KeyCode.E)
	prompt.MaxActivationDistance = 16
	prompt.Triggered:Connect(function(player)
		ActiveLoops.Attack(player, false)
	end)
end

local function bindCollectible(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local detector = makeClick(instance, 24)
	detector.MouseClick:Connect(function(player)
		ActiveLoops.Collect(player, instance)
	end)
	instance.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player then
			ActiveLoops.Collect(player, instance)
		end
	end)
end

local function bindWorkspace()
	bindTag(Tags.Button, bindButton)
	bindTag(Tags.MineNode, bindMineNode)
	bindTag(Tags.Refinery, bindRefinery)
	bindTag(Tags.RuneAltar, bindAltar)
	bindTag(Tags.CombatArena, bindArena)
	bindTag(Tags.Collectible, bindCollectible)
	-- UnlockableZone visibility is per player, so the client renders it; the server gates
	-- every action inside a zone through the same unfold keys.
end

-- Remotes ---------------------------------------------------------------------------

local function bindRemotes()
	Network.OnServerEvent("RequestPurchase", function(player, upgradeId: any, mode: any)
		if type(upgradeId) == "string" then
			IncrementalService.Purchase(player, upgradeId, if mode == "Max" then "Max" else "One")
		end
	end)
	Network.OnServerEvent("RequestBuyLock", function(player, upgradeId: any)
		if type(upgradeId) == "string" then
			IncrementalService.BuyPermanentLock(player, upgradeId)
		end
	end)
	Network.OnServerEvent("RequestPrestige", function(player, tierId: any)
		if type(tierId) == "string" then
			IncrementalService.Prestige(player, tierId)
		end
	end)
	Network.OnServerEvent("RequestMine", function(player, node: any)
		if typeof(node) == "Instance" then
			ActiveLoops.Mine(player, node, false)
		end
	end)
	Network.OnServerEvent("RequestAttack", function(player)
		ActiveLoops.Attack(player, false)
	end)
	Network.OnServerEvent("RequestToggleRefinery", function(player, recipeId: any)
		if type(recipeId) == "string" then
			ActiveLoops.ToggleRefinery(player, recipeId)
		end
	end)
	Network.OnServerEvent("RequestRollRunes", function(player, bannerId: any, count: any)
		if type(bannerId) == "string" and type(count) == "number" then
			ActiveLoops.RollRunes(player, bannerId, count)
		end
	end)
	Network.OnServerEvent("RequestSetSetting", function(player, key: any, value: any)
		local session = DataService.GetSession(player)
		if not session then
			return
		end
		local settings = session.Profile.Settings
		if key == "AutoBuy" and type(value) == "boolean" then
			settings.AutoBuy = value
		elseif key == "AutoMine" and type(value) == "boolean" then
			settings.AutoMine = value
		elseif key == "AutoFight" and type(value) == "boolean" then
			settings.AutoFight = value
		elseif key == "AutoDeleteBelow" and type(value) == "number" then
			-- Legendary (highest rank) can never be auto-deleted.
			settings.AutoDeleteBelow = math.clamp(math.floor(value), 0, #Config.Runes.Rarities - 1)
		end
	end)
	Network.OnServerEvent("RequestBuyTrail", function(player, trailId: any)
		if type(trailId) == "string" then
			ActiveLoops.BuyTrail(player, trailId)
		end
	end)
	Network.OnServerEvent("RequestEquipTrail", function(player, trailId: any)
		if type(trailId) == "string" then
			ActiveLoops.EquipTrail(player, trailId)
		end
	end)
	Network.OnServerEvent("RequestBuyBoost", function(player, boostId: any)
		if type(boostId) == "string" then
			requestBoost(player, boostId)
		end
	end)
	Network.OnServerEvent("RequestBuyGamepass", function(player, passId: any)
		if type(passId) == "string" then
			requestGamepass(player, passId)
		end
	end)
	Network.OnServerInvoke("GetSnapshot", function(player)
		local session = DataService.GetSession(player)
		if not session then
			return nil
		end
		return IncrementalService.BuildSnapshot(session)
	end)
end

-- Lifecycle -------------------------------------------------------------------------

local function onProfileLoaded(session: Session)
	local player = session.Player
	loadGamepasses(session)
	IncrementalService.CheckUnfolds(session, true)
	local block = refreshStats(session)
	session.Runtime.PlayerHP = Evaluator.GetPlayerMaxHP(block)
	local function onCharacter(_character: Model)
		task.defer(function()
			ActiveLoops.ApplyTrail(player)
			ActiveLoops.ApplyCharacterStats(session, session.Runtime.Stats)
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	sendSnapshot(session)
	Network.Notify(
		player,
		"Welcome to " .. Config.GameName,
		if DataService.IsUsingMemoryStore()
			then "Studio test mode: progress is not saved."
			else "Your progress is saved automatically.",
		"Info"
	)
end

function IncrementalService.Init()
	if initialized then
		return
	end
	initialized = true
	bindRemotes()
	bindWorkspace()
	DataService.OnProfileLoaded(onProfileLoaded)
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then
			return
		end
		local session = DataService.GetSession(player)
		if not session then
			return
		end
		for _, pass in Config.Monetization.Gamepasses do
			if pass.GamePassId == gamePassId then
				session.Runtime.Gamepasses[pass.Id] = true
				Network.Notify(player, pass.DisplayName, "Thank you! Gamepass active.", "Success")
			end
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return IncrementalService
