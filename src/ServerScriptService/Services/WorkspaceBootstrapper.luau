--!strict
--[[
	WorkspaceBootstrapper
	Builds a color-coded greybox test zone in Workspace on server start (only if it is not
	already there), with every CollectionService tag and Attribute the engine hooks into.
	Delete Workspace.IncrementalTestZone and replace it with your own tagged map at any time.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local ConfigModule = require(Modules.IncrementalConfig)

local Config = ConfigModule.Data
local ById = ConfigModule.ById
local Tags = Config.Tags
local Attributes = Config.Attributes

local ZONE_NAME = "IncrementalTestZone"

local Colors = {
	Ground = Color3.fromRGB(46, 48, 56),
	Path = Color3.fromRGB(70, 72, 82),
	Upgrades = Color3.fromRGB(80, 200, 110),
	Mining = Color3.fromRGB(120, 120, 130),
	Refinery = Color3.fromRGB(240, 150, 50),
	Runes = Color3.fromRGB(150, 90, 230),
	Combat = Color3.fromRGB(200, 60, 60),
	Enemy = Color3.fromRGB(110, 70, 60),
	Collectible = Color3.fromRGB(255, 240, 120),
	Zone = Color3.fromRGB(70, 40, 110),
	Barrier = Color3.fromRGB(255, 60, 90),
}

local WorkspaceBootstrapper = {}

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function addLabel(parent: BasePart, text: string, color: Color3, height: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "AreaLabel"
	billboard.Size = UDim2.fromOffset(260, 44)
	billboard.StudsOffset = Vector3.new(0, height, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 140
	billboard.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard
	billboard.Parent = parent
end

local function makeSign(parent: Instance, position: Vector3, text: string, color: Color3)
	local post = makePart({
		Name = "Sign",
		Size = Vector3.new(1, 6, 1),
		Position = position + Vector3.new(0, 3, 0),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	addLabel(post, text, color, 4.5)
end

local function buildGround(root: Folder)
	makePart({
		Name = "Ground",
		Size = Vector3.new(300, 2, 300),
		Position = Vector3.new(20, -1, -20),
		Color = Colors.Ground,
		Material = Enum.Material.Concrete,
		Parent = root,
	})
	if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.Position = Vector3.new(0, 0.5, 0)
		spawn.Color = Colors.Path
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Duration = 0
		spawn.Parent = root
	end
end

local function buildUpgradePads(root: Folder)
	local area = Instance.new("Folder")
	area.Name = "UpgradePads"
	area.Parent = root
	makeSign(area, Vector3.new(-40, 0, -30), "Upgrade Pads — step on to buy", Colors.Upgrades)
	local row = 0
	for _, upgradeId in Config.Bootstrap.PadUpgrades do
		local upgrade = ById.Upgrades[upgradeId]
		if upgrade then
			local pad = makePart({
				Name = "Pad_" .. upgradeId,
				Size = Vector3.new(7, 1, 7),
				Position = Vector3.new(-40, 0.5, -20 + row * 10),
				Color = Colors.Upgrades,
				Material = Enum.Material.Neon,
				Parent = area,
			})
			pad:SetAttribute(Attributes.UpgradeId, upgradeId)
			CollectionService:AddTag(pad, Tags.Button)
			row += 1
		else
			warn("[WorkspaceBootstrapper] PadUpgrades lists an unknown upgrade:", upgradeId)
		end
	end
end

local function makeMineNode(parent: Instance, nodeTypeId: string, position: Vector3): Part?
	local nodeType = ById.NodeTypes[nodeTypeId]
	if not nodeType then
		warn("[WorkspaceBootstrapper] Unknown node type:", nodeTypeId)
		return nil
	end
	local node = makePart({
		Name = nodeTypeId .. "Node",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		Position = position + Vector3.new(0, 2.5, 0),
		Color = nodeType.Color,
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	node:SetAttribute(Attributes.NodeType, nodeTypeId)
	CollectionService:AddTag(node, Tags.MineNode)
	return node
end

local function zoneNodeTypes(): { [string]: boolean }
	local inZone: { [string]: boolean } = {}
	for _, contents in Config.Bootstrap.ZoneContents do
		for _, nodeTypeId in contents.NodeTypes do
			inZone[nodeTypeId] = true
		end
	end
	return inZone
end

local function buildMine(root: Folder)
	local area = Instance.new("Folder")
	area.Name = "Mine"
	area.Parent = root
	makePart({
		Name = "MineFloor",
		Size = Vector3.new(34, 0.2, 34),
		Position = Vector3.new(44, 0.1, -2),
		Color = Colors.Mining,
		Material = Enum.Material.Slate,
		Parent = area,
	})
	makeSign(area, Vector3.new(44, 0, -22), "Mine — click nodes, keep a streak", Colors.Mining)
	local inZone = zoneNodeTypes()
	local row = 0
	for _, nodeType in Config.Mining.NodeTypes do
		if not inZone[nodeType.Id] then
			for column = 0, 2 do
				makeMineNode(area, nodeType.Id, Vector3.new(34 + column * 10, 0, -12 + row * 10))
			end
			row += 1
		end
	end
end

local function buildRefinery(root: Folder)
	local area = Instance.new("Folder")
	area.Name = "Refinery"
	area.Parent = root
	makeSign(area, Vector3.new(0, 0, 34), "Refinery — timed cycles", Colors.Refinery)
	local count = #Config.Refinery.Recipes
	for index, recipe in Config.Refinery.Recipes do
		local x = (index - (count + 1) / 2) * 14
		local machine = makePart({
			Name = "Machine_" .. recipe.Id,
			Size = Vector3.new(8, 6, 8),
			Position = Vector3.new(x, 3, 45),
			Color = Colors.Refinery,
			Material = Enum.Material.DiamondPlate,
			Parent = area,
		})
		machine:SetAttribute(Attributes.RecipeId, recipe.Id)
		CollectionService:AddTag(machine, Tags.Refinery)
		makePart({
			Name = "Chimney",
			Size = Vector3.new(2, 4, 2),
			Position = Vector3.new(x + 2, 8, 47),
			Color = Colors.Path,
			Parent = machine,
		})
	end
end

local function buildRuneAltar(root: Folder)
	local area = Instance.new("Folder")
	area.Name = "RuneAltars"
	area.Parent = root
	makeSign(area, Vector3.new(-40, 0, 34), "Rune Altar — roll glyphs", Colors.Runes)
	for index, banner in Config.Runes.Banners do
		local altar = makePart({
			Name = "Altar_" .. banner.Id,
			Size = Vector3.new(6, 4, 6),
			Position = Vector3.new(-40 + (index - 1) * 12, 2, 45),
			Color = Colors.Runes,
			Material = Enum.Material.Marble,
			Parent = area,
		})
		altar:SetAttribute(Attributes.RuneBannerId, banner.Id)
		CollectionService:AddTag(altar, Tags.RuneAltar)
		local crystal = makePart({
			Name = "Glyph",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.5, 2.5, 2.5),
			Position = altar.Position + Vector3.new(0, 3.5, 0),
			Color = Color3.fromRGB(220, 180, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = altar,
		})
		crystal.Name = "Glyph"
	end
end

local function buildArena(root: Folder)
	local arena = Instance.new("Model")
	arena.Name = "CombatArena"
	local floor = makePart({
		Name = "ArenaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 50, 50),
		CFrame = CFrame.new(0, 0.5, -60) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Colors.Combat,
		Material = Enum.Material.Fabric,
		Parent = arena,
	})
	makePart({
		Name = "Enemy",
		Size = Vector3.new(6, 9, 6),
		Position = Vector3.new(0, 5.5, -66),
		Color = Colors.Enemy,
		Material = Enum.Material.Rock,
		Parent = arena,
	})
	arena.PrimaryPart = floor
	arena:SetAttribute(Attributes.ArenaId, "Main")
	arena.Parent = root
	CollectionService:AddTag(arena, Tags.CombatArena)
	makeSign(root, Vector3.new(0, 0, -32), "Combat Arena — infinite golem", Colors.Combat)
end

local function makeCollectible(parent: Instance, collectibleId: string): Part?
	local collectible = ById.Collectibles[collectibleId]
	if not collectible then
		warn("[WorkspaceBootstrapper] Unknown collectible:", collectibleId)
		return nil
	end
	local orb = makePart({
		Name = "Secret_" .. collectibleId,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		Position = collectible.Position,
		Color = Colors.Collectible,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	orb:SetAttribute(Attributes.CollectibleId, collectibleId)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Colors.Collectible
	sparkles.Parent = orb
	CollectionService:AddTag(orb, Tags.Collectible)
	return orb
end

local function buildZones(root: Folder): { [string]: boolean }
	local placedCollectibles: { [string]: boolean } = {}
	for _, zone in Config.Zones do
		local contents = Config.Bootstrap.ZoneContents[zone.Id]
		if contents then
			local center = contents.Center
			local model = Instance.new("Model")
			model.Name = "Zone_" .. zone.Id
			local floor = makePart({
				Name = "ZoneFloor",
				Size = Vector3.new(44, 0.4, 44),
				Position = center + Vector3.new(0, 0.2, 0),
				Color = Colors.Zone,
				Material = Enum.Material.Glass,
				Parent = model,
			})
			for index, nodeTypeId in contents.NodeTypes do
				for column = 0, 2 do
					makeMineNode(
						model,
						nodeTypeId,
						center + Vector3.new(-10 + column * 10, 0.4, -6 + (index - 1) * 10)
					)
				end
			end
			for _, collectibleId in contents.Collectibles do
				if makeCollectible(model, collectibleId) then
					placedCollectibles[collectibleId] = true
				end
			end
			-- Visible and solid only while the zone is locked (client inverts IsBarrier parts).
			local barrier = makePart({
				Name = "Barrier",
				Size = Vector3.new(46, 16, 46),
				Position = center + Vector3.new(0, 8, 0),
				Color = Colors.Barrier,
				Material = Enum.Material.ForceField,
				Transparency = 0.4,
				Parent = model,
			})
			barrier:SetAttribute(Attributes.IsBarrier, true)
			addLabel(barrier, "🔒 " .. zone.DisplayName .. " — " .. ConfigModule.DescribeRequirement(zone.Visibility), Colors.Barrier, 10)
			model.PrimaryPart = floor
			model:SetAttribute(Attributes.ZoneId, zone.Id)
			model.Parent = root
			CollectionService:AddTag(model, Tags.UnlockableZone)
		end
	end
	return placedCollectibles
end

function WorkspaceBootstrapper.Build(): Instance
	local existing = workspace:FindFirstChild(ZONE_NAME)
	if existing then
		return existing
	end
	local root = Instance.new("Folder")
	root.Name = ZONE_NAME
	buildGround(root)
	buildUpgradePads(root)
	if Config.Mining.Enabled then
		buildMine(root)
	end
	if Config.Refinery.Enabled then
		buildRefinery(root)
	end
	if Config.Runes.Enabled then
		buildRuneAltar(root)
	end
	if Config.Combat.Enabled then
		buildArena(root)
	end
	local placed = buildZones(root)
	local secrets = Instance.new("Folder")
	secrets.Name = "Secrets"
	secrets.Parent = root
	for _, collectible in Config.Collectibles do
		if not placed[collectible.Id] then
			makeCollectible(secrets, collectible.Id)
		end
	end
	root.Parent = workspace
	return root
end

return WorkspaceBootstrapper
