--!strict
--[[
	ActiveLoopsService
	The hands-on loops: mining streaks + mastery, timed refinery cycles with a charge
	multiplier, the infinitely scaling single-enemy arena, rune rolling, collectibles,
	trails and character stats. Every action is validated server-side.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local BigNum = require(Modules.BigNum)
local ConfigModule = require(Modules.IncrementalConfig)
local Network = require(Modules.Network)
local DataService = require(script.Parent.DataService)
local Evaluator = require(script.Parent.EvaluatorService)

local Config = ConfigModule.Data
local ById = ConfigModule.ById
local Tags = Config.Tags
local Attributes = Config.Attributes

type BigNum = BigNum.BigNum
type Session = DataService.Session
type StatBlock = DataService.StatBlock

local TRAIL_NAME = "IncrementalTrail"
local COLLECT_RANGE = 20

local ActiveLoops = {}
local random = Random.new()

-- Helpers ---------------------------------------------------------------------------

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function ActiveLoops.GetInstancePosition(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

local function instanceRadius(instance: Instance): number
	if instance:IsA("BasePart") then
		return instance.Size.Magnitude / 2
	elseif instance:IsA("Model") then
		local _, size = instance:GetBoundingBox()
		return size.Magnitude / 2
	end
	return 0
end

function ActiveLoops.IsPlayerNear(player: Player, instance: Instance, range: number): boolean
	local root = getRoot(player)
	local position = ActiveLoops.GetInstancePosition(instance)
	if not root or not position then
		return false
	end
	return (root.Position - position).Magnitude <= range + instanceRadius(instance)
end

-- Anything inside a tagged UnlockableZone is unusable until that zone has unfolded.
function ActiveLoops.IsInLockedZone(session: Session, instance: Instance): boolean
	local current = instance.Parent
	while current and current ~= workspace do
		if CollectionService:HasTag(current, Tags.UnlockableZone) then
			local zoneId = current:GetAttribute(Attributes.ZoneId)
			if type(zoneId) == "string" and not Evaluator.IsUnfolded(session.Profile, "Zone:" .. zoneId) then
				return true
			end
		end
		current = current.Parent
	end
	return false
end

local function currencyName(currencyId: string): string
	local currency = ById.Currencies[currencyId]
	return if currency then currency.DisplayName else currencyId
end

local function addCurrency(session: Session, currencyId: string, amount: BigNum.Value)
	local profile = session.Profile
	profile.Currencies[currencyId] = BigNum.Add(profile.Currencies[currencyId] or BigNum.Zero(), amount)
end

local function spend(session: Session, currencyId: string, amount: BigNum.Value): boolean
	local profile = session.Profile
	local held = profile.Currencies[currencyId] or BigNum.Zero()
	if BigNum.Lt(held, amount) then
		return false
	end
	profile.Currencies[currencyId] = BigNum.Sub(held, amount)
	return true
end

local function stats(session: Session): StatBlock
	local block = session.Runtime.Stats
	if next(block) == nil then
		block = Evaluator.ComputeStats(session.Profile, session.Runtime.Gamepasses)
		session.Runtime.Stats = block
	end
	return block
end

-- Mining ----------------------------------------------------------------------------

function ActiveLoops.Mine(player: Player, node: Instance, isAuto: boolean): boolean
	local mining = Config.Mining
	local session = DataService.GetSession(player)
	if not session or not mining.Enabled then
		return false
	end
	if not node:IsA("BasePart") or not CollectionService:HasTag(node, Tags.MineNode) then
		return false
	end
	local nodeTypeId = node:GetAttribute(Attributes.NodeType)
	if type(nodeTypeId) ~= "string" then
		return false
	end
	local nodeType = ById.NodeTypes[nodeTypeId]
	if not nodeType then
		return false
	end
	local profile = session.Profile
	local runtime = session.Runtime
	if not Evaluator.IsUnfolded(profile, "Node:" .. nodeTypeId) then
		if not isAuto then
			Network.Notify(
				player,
				"Locked",
				nodeType.DisplayName .. " requires: " .. ConfigModule.DescribeRequirement(nodeType.Visibility),
				"Warning"
			)
		end
		return false
	end
	if ActiveLoops.IsInLockedZone(session, node) or not ActiveLoops.IsPlayerNear(player, node, mining.Range) then
		return false
	end
	local now = os.clock()
	if not isAuto and now - runtime.LastMineAt < mining.SwingCooldown then
		return false
	end
	if not isAuto then
		runtime.LastMineAt = now
	end

	if runtime.StreakType == nodeTypeId and now - runtime.StreakLastHit <= mining.StreakTimeout then
		runtime.StreakCount += 1
	else
		runtime.StreakType = nodeTypeId
		runtime.StreakCount = 1
	end
	runtime.StreakLastHit = now
	runtime.LastNode = node

	local block = stats(session)
	local amount = Evaluator.GetMiningYield(block, nodeTypeId, runtime.StreakCount)
	addCurrency(session, nodeType.Currency, amount)

	local oldXP = profile.Mastery[nodeTypeId] or 0
	local gainedXP = nodeType.XPPerHit * BigNum.ToNumber(Evaluator.GetMult(block, "MasteryXP"))
	local newXP = oldXP + gainedXP
	profile.Mastery[nodeTypeId] = newXP
	local oldLevel = Evaluator.GetMasteryInfo(oldXP)
	local newLevel = Evaluator.GetMasteryInfo(newXP)
	if newLevel > oldLevel then
		Network.Notify(
			player,
			"Mastery Up!",
			string.format(
				"%s Mastery %d → x%.2f yield",
				nodeType.DisplayName,
				newLevel,
				Evaluator.GetMasteryMult(newXP)
			),
			"Success"
		)
	end

	local feedback: Network.MineFeedback = {
		Node = node,
		Amount = BigNum.Serialize(amount),
		CurrencyId = nodeType.Currency,
		Streak = runtime.StreakCount,
	}
	Network.FireClient(player, "MineFeedback", feedback)
	return true
end

function ActiveLoops.TickMining(session: Session, block: StatBlock, now: number)
	local mining = Config.Mining
	if not mining.Enabled then
		return
	end
	local runtime = session.Runtime
	if runtime.StreakCount > 0 and now - runtime.StreakLastHit > mining.StreakTimeout then
		runtime.StreakCount = 0
		runtime.StreakType = ""
	end
	if not Evaluator.HasFlag(block, "AutoMine") or not session.Profile.Settings.AutoMine then
		return
	end
	local node = runtime.LastNode
	if not node or not node.Parent then
		return
	end
	if now - runtime.LastAutoMine >= mining.AutoSwingInterval then
		runtime.LastAutoMine = now
		ActiveLoops.Mine(session.Player, node, true)
	end
end

-- Refinery --------------------------------------------------------------------------

function ActiveLoops.ToggleRefinery(player: Player, recipeId: string)
	local session = DataService.GetSession(player)
	if not session or not Config.Refinery.Enabled then
		return
	end
	local recipe = ById.Recipes[recipeId]
	if not recipe or not Evaluator.IsUnfolded(session.Profile, "Recipe:" .. recipeId) then
		return
	end
	local state = session.Profile.Refinery[recipeId]
	if not state then
		state = { Enabled = false, Progress = 0 }
		session.Profile.Refinery[recipeId] = state
	end
	state.Enabled = not state.Enabled
	Network.Notify(player, recipe.DisplayName, if state.Enabled then "Running" else "Paused", "Info")
end

function ActiveLoops.TickRefinery(session: Session, block: StatBlock, dt: number)
	if not Config.Refinery.Enabled then
		return
	end
	local profile = session.Profile
	local cycle = Evaluator.GetRefineryCycle(block)
	local charge = Evaluator.GetRefineryCharge(profile)
	local yieldMult = BigNum.Mul(Evaluator.GetMult(block, "RefineryYield"), charge)
	for _, recipe in Config.Refinery.Recipes do
		local state = profile.Refinery[recipe.Id]
		if state and state.Enabled and Evaluator.IsUnfolded(profile, "Recipe:" .. recipe.Id) then
			state.Progress += dt
			if state.Progress >= cycle then
				local cycles = math.floor(state.Progress / cycle)
				state.Progress -= cycles * cycle
				local maxBatches = Evaluator.GetRefineryBatches(block, recipe.BaseBatches) * math.min(cycles, 20)
				local held = profile.Currencies[recipe.Input] or BigNum.Zero()
				local available = BigNum.Floor(BigNum.Div(held, recipe.InputAmount))
				local batches = BigNum.Min(available, maxBatches)
				if BigNum.Gt(batches, 0) then
					spend(session, recipe.Input, BigNum.Mul(batches, recipe.InputAmount))
					local output = BigNum.Mul(BigNum.Mul(batches, recipe.OutputAmount), yieldMult)
					addCurrency(session, recipe.Output, output)
				end
			end
		end
	end
end

-- Combat ----------------------------------------------------------------------------

local function findArena(player: Player): Instance?
	for _, arena in CollectionService:GetTagged(Tags.CombatArena) do
		if arena:IsDescendantOf(workspace) and ActiveLoops.IsPlayerNear(player, arena, Config.Combat.Range) then
			return arena
		end
	end
	return nil
end

function ActiveLoops.ResetEnemy(session: Session)
	session.Profile.Combat.EnemyHP = Evaluator.GetEnemyMaxHP(session.Profile.Combat.Kills)
end

function ActiveLoops.Attack(player: Player, isAuto: boolean): boolean
	local combat = Config.Combat
	local session = DataService.GetSession(player)
	if not session or not combat.Enabled then
		return false
	end
	local profile = session.Profile
	local runtime = session.Runtime
	if not Evaluator.IsUnfolded(profile, "Combat:Arena") then
		if not isAuto then
			Network.Notify(
				player,
				"Locked",
				"The arena requires: " .. ConfigModule.DescribeRequirement(combat.Visibility),
				"Warning"
			)
		end
		return false
	end
	if not findArena(player) then
		return false
	end
	local now = os.clock()
	if not isAuto and now - runtime.LastAttackAt < combat.AttackCooldown then
		return false
	end
	if not isAuto then
		runtime.LastAttackAt = now
	end
	if runtime.LastEngagedAt == 0 then
		-- First hit of an engagement: give the player a full swing before the enemy answers.
		runtime.LastEnemyStrike = now
	end
	runtime.LastEngagedAt = now

	local block = stats(session)
	local damage = Evaluator.GetPlayerDamage(block)
	profile.Combat.EnemyHP = BigNum.Sub(profile.Combat.EnemyHP, damage)
	local killed = false
	local reward = BigNum.Zero()
	if BigNum.Le(profile.Combat.EnemyHP, 0) then
		killed = true
		reward = Evaluator.GetKillReward(block, profile.Combat.Kills)
		addCurrency(session, combat.RewardCurrency, reward)
		profile.Combat.Kills += 1
		ActiveLoops.ResetEnemy(session)
	end
	local feedback: Network.CombatFeedback = {
		Damage = BigNum.Serialize(damage),
		Killed = killed,
		Reward = BigNum.Serialize(reward),
		Defeated = false,
	}
	Network.FireClient(player, "CombatFeedback", feedback)
	return true
end

function ActiveLoops.TickCombat(session: Session, block: StatBlock, now: number, dt: number)
	local combat = Config.Combat
	if not combat.Enabled then
		return
	end
	local profile = session.Profile
	local runtime = session.Runtime
	local maxHP = Evaluator.GetPlayerMaxHP(block)
	local engaged = runtime.LastEngagedAt > 0 and now - runtime.LastEngagedAt <= combat.EngageTimeout

	if engaged then
		if now - runtime.LastEnemyStrike >= combat.EnemyAttackInterval then
			runtime.LastEnemyStrike = now
			runtime.PlayerHP = BigNum.Sub(runtime.PlayerHP, Evaluator.GetEnemyAttack(profile.Combat.Kills))
			if BigNum.Le(runtime.PlayerHP, 0) then
				-- Defeat is never punishing: the enemy heals, the player recovers, nothing is lost.
				runtime.PlayerHP = maxHP
				runtime.LastEngagedAt = 0
				ActiveLoops.ResetEnemy(session)
				local feedback: Network.CombatFeedback = {
					Damage = "0|0",
					Killed = false,
					Reward = "0|0",
					Defeated = true,
				}
				Network.FireClient(session.Player, "CombatFeedback", feedback)
				Network.Notify(
					session.Player,
					"Defeated",
					"The " .. combat.EnemyName .. " healed. Upgrade damage or health and try again.",
					"Warning"
				)
			end
		end
	else
		if runtime.LastEngagedAt > 0 then
			runtime.LastEngagedAt = 0
		end
		-- Out of combat: regenerate 20% of max HP per second.
		runtime.PlayerHP = BigNum.Min(BigNum.Add(runtime.PlayerHP, BigNum.Mul(maxHP, 0.2 * dt)), maxHP)
	end
	if BigNum.Gt(runtime.PlayerHP, maxHP) then
		runtime.PlayerHP = maxHP
	end

	if
		Evaluator.HasFlag(block, "AutoFight")
		and profile.Settings.AutoFight
		and now - runtime.LastAutoAttack >= combat.AutoAttackInterval
	then
		runtime.LastAutoAttack = now
		ActiveLoops.Attack(session.Player, true)
	end
end

-- Runes -----------------------------------------------------------------------------

function ActiveLoops.RollRunes(player: Player, bannerId: string, count: number): boolean
	local runes = Config.Runes
	local session = DataService.GetSession(player)
	if not session or not runes.Enabled then
		return false
	end
	if not table.find(runes.RollCounts, count) then
		return false
	end
	local banner = ById.Banners[bannerId]
	if not banner then
		return false
	end
	local profile = session.Profile
	if not Evaluator.IsUnfolded(profile, "Banner:" .. bannerId) then
		Network.Notify(
			player,
			"Locked",
			banner.DisplayName .. " requires: " .. ConfigModule.DescribeRequirement(banner.Visibility),
			"Warning"
		)
		return false
	end
	local totalCost = BigNum.Mul(banner.CostAmount, count)
	if not spend(session, banner.CostCurrency, totalCost) then
		Network.Notify(
			player,
			"Not enough " .. currencyName(banner.CostCurrency),
			string.format("%d roll(s) cost %s", count, BigNum.ToString(totalCost)),
			"Warning"
		)
		return false
	end

	local pool, totalWeight = Evaluator.GetRuneWeights(stats(session), banner)
	local results: { { RuneId: string, Kept: boolean } } = {}
	local bestRank = 0
	local bestName = ""
	for _ = 1, count do
		local roll = random:NextNumber() * totalWeight
		local picked = pool[#pool].RuneId
		for _, option in pool do
			roll -= option.Weight
			if roll <= 0 then
				picked = option.RuneId
				break
			end
		end
		local rune = ById.Runes[picked]
		local rank = ConfigModule.RarityRank[rune.Rarity] or 1
		local owned = profile.Runes[picked] or 0
		local kept = rank > profile.Settings.AutoDeleteBelow and owned < rune.MaxStack
		if kept then
			profile.Runes[picked] = owned + 1
		end
		table.insert(results, { RuneId = picked, Kept = kept })
		if rank > bestRank then
			bestRank = rank
			bestName = rune.DisplayName
		end
	end

	local payload: Network.RuneResult = { BannerId = bannerId, Results = results }
	Network.FireClient(player, "RuneResult", payload)
	if bestRank >= 4 then
		Network.Notify(player, "Rare Pull!", "You rolled " .. bestName .. "!", "Success")
	end
	return true
end

-- Collectibles ----------------------------------------------------------------------

function ActiveLoops.Collect(player: Player, part: Instance): boolean
	local session = DataService.GetSession(player)
	if not session or not CollectionService:HasTag(part, Tags.Collectible) then
		return false
	end
	local collectibleId = part:GetAttribute(Attributes.CollectibleId)
	if type(collectibleId) ~= "string" then
		return false
	end
	local collectible = ById.Collectibles[collectibleId]
	if not collectible or session.Profile.Collectibles[collectibleId] then
		return false
	end
	if ActiveLoops.IsInLockedZone(session, part) or not ActiveLoops.IsPlayerNear(player, part, COLLECT_RANGE) then
		return false
	end
	session.Profile.Collectibles[collectibleId] = true
	Network.Notify(player, "Secret Found: " .. collectible.DisplayName, collectible.Description, "Success")
	return true
end

-- Trails ----------------------------------------------------------------------------

function ActiveLoops.ApplyTrail(player: Player)
	local session = DataService.GetSession(player)
	local root = getRoot(player)
	if not session or not root then
		return
	end
	for _, child in root:GetChildren() do
		if child.Name == TRAIL_NAME or child.Name == TRAIL_NAME .. "A0" or child.Name == TRAIL_NAME .. "A1" then
			child:Destroy()
		end
	end
	local trailId = session.Profile.EquippedTrail
	local trailDef = if trailId ~= "" then ById.Trails[trailId] else nil
	if not trailDef or not session.Profile.OwnedTrails[trailId] then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = TRAIL_NAME .. "A0"
	top.Position = Vector3.new(0, 1, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = TRAIL_NAME .. "A1"
	bottom.Position = Vector3.new(0, -1, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = TRAIL_NAME
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(trailDef.ColorA, trailDef.ColorB)
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Lifetime = 0.6
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Parent = root
end

function ActiveLoops.BuyTrail(player: Player, trailId: string): boolean
	local session = DataService.GetSession(player)
	local trailDef = ById.Trails[trailId]
	if not session or not trailDef then
		return false
	end
	local profile = session.Profile
	if profile.OwnedTrails[trailId] then
		return false
	end
	if not Evaluator.IsUnfolded(profile, "Trail:" .. trailId) then
		return false
	end
	if not spend(session, trailDef.Cost.CurrencyId, trailDef.Cost.Amount) then
		Network.Notify(
			player,
			"Not enough " .. currencyName(trailDef.Cost.CurrencyId),
			trailDef.DisplayName .. " costs " .. BigNum.ToString(trailDef.Cost.Amount),
			"Warning"
		)
		return false
	end
	profile.OwnedTrails[trailId] = true
	profile.EquippedTrail = trailId
	ActiveLoops.ApplyTrail(player)
	Network.Notify(player, "Trail Unlocked", trailDef.DisplayName .. " equipped. Trails never reset.", "Success")
	return true
end

function ActiveLoops.EquipTrail(player: Player, trailId: string)
	local session = DataService.GetSession(player)
	if not session then
		return
	end
	if trailId ~= "" and not session.Profile.OwnedTrails[trailId] then
		return
	end
	session.Profile.EquippedTrail = trailId
	ActiveLoops.ApplyTrail(player)
end

-- Character -------------------------------------------------------------------------

function ActiveLoops.ApplyCharacterStats(session: Session, block: StatBlock)
	local humanoid = getHumanoid(session.Player)
	if not humanoid then
		return
	end
	local speed = Config.Settings.BaseWalkSpeed + Evaluator.GetNumber(block, "WalkSpeed")
	speed *= BigNum.ToNumber(Evaluator.GetMult(block, "WalkSpeed"))
	speed = math.clamp(speed, 0, 100)
	if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
		humanoid.WalkSpeed = speed
	end
end

function ActiveLoops.Init()
	-- Combat state from older saves may predate a config change; normalize on load.
	DataService.OnProfileLoaded(function(session)
		local combat = session.Profile.Combat
		local maxHP = Evaluator.GetEnemyMaxHP(combat.Kills)
		if BigNum.Le(combat.EnemyHP, 0) or BigNum.Gt(combat.EnemyHP, maxHP) then
			combat.EnemyHP = maxHP
		end
	end)
end

return ActiveLoops
