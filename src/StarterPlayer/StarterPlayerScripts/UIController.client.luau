--!strict
--[[
	UIController
	Builds the whole dark-mode HUD from IncrementalConfig and keeps it in sync with server
	snapshots: currency bar, unfolding tabs (Upgrades, Activity, Prestige, Runes, Trails &
	Boosts), toast notifications, world billboards on tagged parts, and per-player local
	visibility (locked mechanics are transparent, non-collidable and non-interactive).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BigNum = require(Modules:WaitForChild("BigNum"))
local ConfigModule = require(Modules:WaitForChild("IncrementalConfig"))
local Network = require(Modules:WaitForChild("Network"))

local Config = ConfigModule.Data
local ById = ConfigModule.ById
local Tags = Config.Tags
local Attributes = Config.Attributes

type Snapshot = Network.Snapshot

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local Theme = {
	Background = Color3.fromRGB(16, 17, 23),
	Panel = Color3.fromRGB(24, 26, 34),
	Card = Color3.fromRGB(33, 36, 47),
	CardAlt = Color3.fromRGB(40, 44, 57),
	Stroke = Color3.fromRGB(58, 63, 80),
	Text = Color3.fromRGB(236, 238, 245),
	Muted = Color3.fromRGB(150, 156, 175),
	Accent = Color3.fromRGB(96, 165, 250),
	Good = Color3.fromRGB(74, 210, 120),
	Warn = Color3.fromRGB(250, 190, 70),
	Bad = Color3.fromRGB(240, 85, 90),
	Unfold = Color3.fromRGB(200, 130, 255),
	Disabled = Color3.fromRGB(70, 74, 90),
	BarBackground = Color3.fromRGB(20, 21, 28),
}

local snapshot: Snapshot? = nil
local activeTab: string? = nil
local refreshCallbacks: { (Snapshot) -> () } = {}

-- Generic helpers -------------------------------------------------------------------

local function new(className: string, props: { [string]: any }?): any
	local instance = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(parent: Instance, radius: number?)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function stroke(parent: Instance, color: Color3?, thickness: number?)
	new("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function pad(parent: Instance, pixels: number)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, pixels),
		PaddingRight = UDim.new(0, pixels),
		PaddingTop = UDim.new(0, pixels),
		PaddingBottom = UDim.new(0, pixels),
		Parent = parent,
	})
end

local function listLayout(parent: Instance, direction: Enum.FillDirection, spacing: number)
	new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, spacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = parent,
	})
end

local function fmt(serialized: string, decimals: number?): string
	return BigNum.ToString(BigNum.Deserialize(serialized), decimals)
end

local function currencyTag(currencyId: string): string
	local currency = ById.Currencies[currencyId]
	return if currency then currency.Icon .. " " .. currency.DisplayName else currencyId
end

local function formatTime(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

local function hex(color: Color3): string
	return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end

local function isUnfolded(key: string): boolean
	local current = snapshot
	return current ~= nil and current.Unfolded[key] == true
end

local function makeText(parent: Instance, text: string, size: number, color: Color3, bold: boolean, order: number?): TextLabel
	return new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
		TextSize = size,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order or 0,
		Parent = parent,
	})
end

local function makeButton(parent: Instance, text: string, width: number, onClick: () -> ()): TextButton
	local button: TextButton = new("TextButton", {
		Size = UDim2.fromOffset(width, 30),
		BackgroundColor3 = Theme.Accent,
		Text = text,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextWrapped = true,
		AutoButtonColor = true,
		Parent = parent,
	})
	corner(button, 6)
	button.Activated:Connect(onClick)
	return button
end

local function makeRow(parent: Instance, order: number): Frame
	local row: Frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	listLayout(row, Enum.FillDirection.Horizontal, 6)
	return row
end

local function makeBar(parent: Instance, color: Color3, order: number): Frame
	local background: Frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Theme.BarBackground,
		LayoutOrder = order,
		Parent = parent,
	})
	corner(background, 5)
	local fill: Frame = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = background,
	})
	corner(fill, 5)
	return fill
end

local function setFill(fill: Frame, fraction: number)
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
end

local function makeCard(parent: Instance, order: number): Frame
	local card: Frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Card,
		LayoutOrder = order,
		Parent = parent,
	})
	corner(card, 8)
	stroke(card)
	pad(card, 8)
	new("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = card,
	})
	return card
end

local function setButtonState(button: TextButton, enabled: boolean, color: Color3?)
	button.BackgroundColor3 = if enabled then (color or Theme.Accent) else Theme.Disabled
	button.TextColor3 = if enabled then Theme.Text else Theme.Muted
end

local function onRefresh(callback: (Snapshot) -> ())
	table.insert(refreshCallbacks, callback)
end

-- Root GUI ---------------------------------------------------------------------------

local gui: ScreenGui = new("ScreenGui", {
	Name = "IncrementalUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local scales: { UIScale } = {}
local function addScale(parent: Instance)
	table.insert(scales, new("UIScale", { Parent = parent }))
end

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local scale = math.clamp(math.min(viewport.X / 1150, viewport.Y / 680), 0.55, 1.1)
	for _, uiScale in scales do
		uiScale.Scale = scale
	end
end

-- Top currency bar ------------------------------------------------------------------

local topBar: Frame = new("Frame", {
	Name = "TopBar",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Theme.Panel,
	BackgroundTransparency = 0.1,
	Parent = gui,
})
corner(topBar, 10)
stroke(topBar)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = topBar })
listLayout(topBar, Enum.FillDirection.Horizontal, 14)
addScale(topBar)

type Chip = { Frame: Frame, Value: TextLabel, Rate: TextLabel }
local chips: { [string]: Chip } = {}
for order, currency in Config.Currencies do
	local chip: Frame = new("Frame", {
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Visible = false,
		Parent = topBar,
	})
	listLayout(chip, Enum.FillDirection.Horizontal, 4)
	new("TextLabel", {
		Size = UDim2.fromOffset(18, 32),
		BackgroundTransparency = 1,
		Text = currency.Icon,
		TextColor3 = currency.Color,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		LayoutOrder = 1,
		Parent = chip,
	})
	local value: TextLabel = new("TextLabel", {
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "0",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		LayoutOrder = 2,
		Parent = chip,
	})
	local rate: TextLabel = new("TextLabel", {
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Muted,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		LayoutOrder = 3,
		Parent = chip,
	})
	chips[currency.Id] = { Frame = chip, Value = value, Rate = rate }
end

onRefresh(function(state)
	for currencyId, chip in chips do
		chip.Frame.Visible = state.Unfolded["Currency:" .. currencyId] == true
		chip.Value.Text = fmt(state.Currencies[currencyId] or "0|0")
		local rate = BigNum.Deserialize(state.Rates[currencyId] or "0|0")
		chip.Rate.Text = if BigNum.Gt(rate, 0) then "+" .. BigNum.ToString(rate) .. "/s" else ""
	end
end)

-- Dock: tab bar + main panel --------------------------------------------------------

local dock: Frame = new("Frame", {
	Name = "Dock",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 8, 0.5, 20),
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 1,
	Parent = gui,
})
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	Parent = dock,
})
addScale(dock)

local tabBar: Frame = new("Frame", {
	Name = "Tabs",
	Size = UDim2.fromOffset(120, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 1,
	Parent = dock,
})
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabBar })

local panel: Frame = new("Frame", {
	Name = "Panel",
	Size = UDim2.fromOffset(440, 520),
	BackgroundColor3 = Theme.Panel,
	BackgroundTransparency = 0.04,
	Visible = false,
	LayoutOrder = 2,
	Parent = dock,
})
corner(panel, 12)
stroke(panel)

local panelTitle: TextLabel = new("TextLabel", {
	Size = UDim2.new(1, -60, 0, 40),
	Position = UDim2.fromOffset(14, 2),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Theme.Text,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
})

type TabEntry = { Button: TextButton, Page: ScrollingFrame, Def: ConfigModule.TabDef, Badge: Frame }
local tabs: { [string]: TabEntry } = {}

local function selectTab(tabId: string?)
	activeTab = tabId
	panel.Visible = tabId ~= nil
	for id, entry in tabs do
		local selected = id == tabId
		entry.Page.Visible = selected
		entry.Button.BackgroundColor3 = if selected then Theme.Accent else Theme.Card
		if selected then
			entry.Badge.Visible = false
			panelTitle.Text = entry.Def.Icon .. "  " .. entry.Def.DisplayName
		end
	end
end

local closeButton: TextButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 8),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = Theme.Card,
	Text = "✕",
	TextColor3 = Theme.Muted,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Parent = panel,
})
corner(closeButton, 6)
closeButton.Activated:Connect(function()
	selectTab(nil)
end)

for order, tabDef in Config.Tabs do
	local button: TextButton = new("TextButton", {
		Name = tabDef.Id,
		Size = UDim2.fromOffset(120, 38),
		BackgroundColor3 = Theme.Card,
		Text = tabDef.Icon .. "  " .. tabDef.DisplayName,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Visible = false,
		Parent = tabBar,
	})
	corner(button, 8)
	stroke(button)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = button })
	local badge: Frame = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Theme.Unfold,
		Visible = false,
		Parent = button,
	})
	corner(badge, 5)
	local page: ScrollingFrame = new("ScrollingFrame", {
		Name = tabDef.Id,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = panel,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 10),
		Parent = page,
	})
	tabs[tabDef.Id] = { Button = button, Page = page, Def = tabDef, Badge = badge }
	button.Activated:Connect(function()
		selectTab(if activeTab == tabDef.Id then nil else tabDef.Id)
	end)
end

onRefresh(function(state)
	for id, entry in tabs do
		local visible = state.Unfolded["Tab:" .. id] == true
		entry.Button.Visible = visible
		if not visible and activeTab == id then
			selectTab(nil)
		end
	end
end)

local function getPage(tabId: string): ScrollingFrame
	return tabs[tabId].Page
end

-- Toasts ----------------------------------------------------------------------------

local toastHolder: Frame = new("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -10, 1, -90),
	Size = UDim2.fromOffset(300, 400),
	BackgroundTransparency = 1,
	Parent = gui,
})
new("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Parent = toastHolder,
})
addScale(toastHolder)

local toastOrder = 0
local MAX_TOASTS = 5

local function toast(title: string, text: string, color: Color3)
	toastOrder += 1
	local frame: Frame = new("Frame", {
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1,
		LayoutOrder = toastOrder,
		Parent = toastHolder,
	})
	corner(frame, 8)
	stroke(frame, color, 1.5)
	pad(frame, 8)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	makeText(frame, title, 14, color, true, 1)
	if text ~= "" then
		makeText(frame, text, 12, Theme.Text, false, 2)
	end
	TweenService:Create(frame, TweenInfo.new(0.25), { BackgroundTransparency = 0.05 }):Play()

	local frames: { Frame } = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	table.sort(frames, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #frames - MAX_TOASTS do
		frames[index]:Destroy()
	end

	task.delay(4.5, function()
		if frame.Parent then
			local fade = TweenService:Create(frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
			fade:Play()
			for _, descendant in frame:GetDescendants() do
				if descendant:IsA("TextLabel") then
					TweenService:Create(descendant, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
				elseif descendant:IsA("UIStroke") then
					TweenService:Create(descendant, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				end
			end
			fade.Completed:Wait()
			frame:Destroy()
		end
	end)
end

local NOTIFY_COLORS: { [string]: Color3 } = {
	Info = Theme.Accent,
	Success = Theme.Good,
	Warning = Theme.Warn,
	Unfold = Theme.Unfold,
}

-- Upgrades tab ----------------------------------------------------------------------

type UpgradeRow = {
	Frame: Frame,
	Title: TextLabel,
	Status: TextLabel,
	Buy: TextButton,
	Max: TextButton,
	Lock: TextButton,
	Category: string,
}

do
	local page = getPage("Upgrades")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local autoCard = makeCard(page, nextOrder())
	autoCard.BackgroundColor3 = Theme.CardAlt
	makeText(autoCard, "<b>EL Automation active</b> — eligible upgrades are free and auto-bought.", 12, Theme.Good, false, 1)
	local autoRow = makeRow(autoCard, 2)
	local autoButton = makeButton(autoRow, "Auto-Buy: ON", 140, function()
		local current = snapshot
		if current then
			Network.FireServer("RequestSetSetting", "AutoBuy", not current.Settings.AutoBuy)
		end
	end)

	local categories: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, upgrade in Config.Upgrades do
		if not seen[upgrade.Category] then
			seen[upgrade.Category] = true
			table.insert(categories, upgrade.Category)
		end
	end

	local rows: { [string]: UpgradeRow } = {}
	local headers: { [string]: TextLabel } = {}
	for _, category in categories do
		headers[category] = makeText(page, category:upper(), 12, Theme.Muted, true, nextOrder())
		for _, upgrade in Config.Upgrades do
			if upgrade.Category == category then
				local card = makeCard(page, nextOrder())
				local title = makeText(card, upgrade.DisplayName, 15, Theme.Text, true, 1)
				makeText(card, upgrade.Description, 12, Theme.Muted, false, 2)
				local status = makeText(card, "", 12, Theme.Warn, false, 3)
				local buttons = makeRow(card, 4)
				local upgradeId = upgrade.Id
				local buy = makeButton(buttons, "Buy", 150, function()
					Network.FireServer("RequestPurchase", upgradeId, "One")
				end)
				local max = makeButton(buttons, "Max", 60, function()
					Network.FireServer("RequestPurchase", upgradeId, "Max")
				end)
				local lock = makeButton(buttons, "Lock", 120, function()
					Network.FireServer("RequestBuyLock", upgradeId)
				end)
				card.Visible = false
				rows[upgradeId] = {
					Frame = card,
					Title = title,
					Status = status,
					Buy = buy,
					Max = max,
					Lock = lock,
					Category = category,
				}
			end
		end
	end

	onRefresh(function(state)
		autoCard.Visible = state.Stats.ELAutomation
		autoButton.Text = "Auto-Buy: " .. (if state.Settings.AutoBuy then "ON" else "OFF")
		setButtonState(autoButton, true, if state.Settings.AutoBuy then Theme.Good else Theme.Disabled)

		local categoryVisible: { [string]: boolean } = {}
		for upgradeId, row in rows do
			local upgradeState = state.Upgrades[upgradeId]
			row.Frame.Visible = upgradeState ~= nil
			if upgradeState then
				categoryVisible[row.Category] = true
				local upgrade = ById.Upgrades[upgradeId]
				local levelText = if upgradeState.MaxLevel < 0
					then string.format("Lv %d", upgradeState.Level)
					else string.format("Lv %d/%d", upgradeState.Level, upgradeState.MaxLevel)
				row.Title.Text = string.format(
					"%s  <font color=\"%s\">%s</font>",
					upgrade.DisplayName,
					hex(Theme.Muted),
					levelText
				)

				local notes: { string } = {}
				if upgrade.ActivationThreshold then
					local threshold = upgrade.ActivationThreshold
					table.insert(
						notes,
						string.format(
							"%s Hold %s %s (not spent)",
							if upgradeState.ThresholdMet then "✓" else "✗",
							BigNum.ToString(threshold.Amount),
							currencyTag(threshold.CurrencyId)
						)
					)
				end
				if upgradeState.Free then
					table.insert(notes, "EL: costs nothing")
				end
				if upgradeState.Locked then
					table.insert(notes, "🔒 Permanently locked — never resets")
				elseif upgradeState.Protected then
					table.insert(notes, "🛡 Protected from resets")
				end
				row.Status.Text = table.concat(notes, "   ")
				row.Status.Visible = #notes > 0

				local maxed = upgradeState.MaxLevel >= 0 and upgradeState.Level >= upgradeState.MaxLevel
				if maxed then
					row.Buy.Text = "MAXED"
				elseif upgradeState.Free or BigNum.IsZero(BigNum.Deserialize(upgradeState.Cost)) then
					row.Buy.Text = "FREE"
				else
					row.Buy.Text = fmt(upgradeState.Cost) .. " " .. currencyTag(upgrade.Currency)
				end
				setButtonState(row.Buy, upgradeState.Affordable and not maxed)
				setButtonState(row.Max, upgradeState.Affordable and not maxed)
				row.Max.Visible = upgradeState.MaxLevel ~= 1
				row.Lock.Visible = upgradeState.CanLock
				if upgradeState.CanLock and upgrade.PermanentLockCost then
					local lockCost = upgrade.PermanentLockCost
					row.Lock.Text = "Lock: " .. BigNum.ToString(lockCost.Amount) .. " " .. ById.Currencies[lockCost.CurrencyId].Icon
					local held = BigNum.Deserialize(state.Currencies[lockCost.CurrencyId] or "0|0")
					setButtonState(row.Lock, BigNum.Ge(held, lockCost.Amount), Theme.Warn)
				end
			end
		end
		for category, header in headers do
			header.Visible = categoryVisible[category] == true
		end
	end)
end

-- Prestige tab ----------------------------------------------------------------------

do
	local page = getPage("Prestige")
	local infoCard = makeCard(page, 0)
	infoCard.BackgroundColor3 = Theme.CardAlt
	local infoText = makeText(infoCard, "", 12, Theme.Muted, false, 1)

	type PrestigeRow = { Frame: Frame, Title: TextLabel, Info: TextLabel, Button: TextButton, Milestones: { TextLabel } }
	local rows: { [string]: PrestigeRow } = {}
	local confirmAt: { [string]: number } = {}

	for order, tier in Config.Prestige do
		local card = makeCard(page, order)
		local title = makeText(card, tier.DisplayName, 16, Theme.Text, true, 1)
		makeText(card, tier.Description, 12, Theme.Muted, false, 2)
		local info = makeText(card, "", 13, Theme.Text, false, 3)
		local milestoneLabels: { TextLabel } = {}
		if tier.Milestones then
			for index, milestone in tier.Milestones do
				table.insert(
					milestoneLabels,
					makeText(card, milestone.DisplayName .. ": " .. milestone.Description, 12, Theme.Muted, false, 3 + index)
				)
			end
		end
		local buttons = makeRow(card, 100)
		local tierId = tier.Id
		local button: TextButton
		button = makeButton(buttons, tier.DisplayName, 200, function()
			local now = os.clock()
			if confirmAt[tierId] and now - confirmAt[tierId] < 3 then
				confirmAt[tierId] = nil
				Network.FireServer("RequestPrestige", tierId)
			else
				confirmAt[tierId] = now
				button.Text = "Click again to confirm"
			end
		end)
		card.Visible = false
		rows[tierId] = { Frame = card, Title = title, Info = info, Button = button, Milestones = milestoneLabels }
	end

	onRefresh(function(state)
		infoText.Text = string.format(
			"Milestones reached: <b>%d</b>   •   Protected tier-1 nodes: <b>%s</b>   •   EL Automation: <b>%s</b>",
			state.MilestoneCount,
			if state.Stats.SaveUpToNodeIndex > 0 then "#1–#" .. state.Stats.SaveUpToNodeIndex else "none",
			if state.Stats.ELAutomation then "ON" else "locked"
		)
		local now = os.clock()
		for tierId, row in rows do
			local tier = ById.Prestige[tierId]
			local tierState = state.Prestige[tierId]
			row.Frame.Visible = state.Unfolded["Prestige:" .. tierId] == true and tierState ~= nil
			if tierState then
				row.Title.Text = string.format(
					"%s  <font color=\"%s\">×%d</font>",
					tier.DisplayName,
					hex(Theme.Muted),
					tierState.Count
				)
				local lines: { string } = {}
				if tier.Currency then
					table.insert(lines, string.format("Gain: <b>+%s</b> %s", fmt(tierState.Gain), currencyTag(tier.Currency)))
				else
					table.insert(lines, string.format("Next: <b>Milestone %d</b> (awards no currency)", state.MilestoneCount + 1))
				end
				table.insert(
					lines,
					string.format(
						"%s Hold %s %s",
						if tierState.CanPrestige then "✓" else "✗",
						fmt(tierState.Requirement),
						currencyTag(tier.Source)
					)
				)
				row.Info.Text = table.concat(lines, "\n")
				for index, label in row.Milestones do
					local reached = state.MilestoneCount >= index
					label.TextColor3 = if reached then Theme.Good else Theme.Muted
					local milestone = (tier.Milestones :: { ConfigModule.MilestoneDef })[index]
					label.Text = (if reached then "✓ " else "○ ") .. milestone.DisplayName .. ": " .. milestone.Description
				end
				local confirming = confirmAt[tierId] ~= nil and now - confirmAt[tierId] < 3
				if not confirming then
					confirmAt[tierId] = nil
					row.Button.Text = tier.DisplayName
				end
				setButtonState(row.Button, tierState.CanPrestige, if confirming then Theme.Warn else Theme.Accent)
			end
		end
	end)
end

-- Runes tab -------------------------------------------------------------------------

local lastRollLabel: TextLabel
do
	local page = getPage("Runes")
	local settingsCard = makeCard(page, 0)
	local luckText = makeText(settingsCard, "", 12, Theme.Muted, false, 1)
	local settingsRow = makeRow(settingsCard, 2)
	local autoDelete = makeButton(settingsRow, "Auto-delete: Off", 240, function()
		local current = snapshot
		if current then
			local nextValue = (current.Settings.AutoDeleteBelow + 1) % #Config.Runes.Rarities
			Network.FireServer("RequestSetSetting", "AutoDeleteBelow", nextValue)
		end
	end)

	type BannerRow = { Frame: Frame, Cost: TextLabel }
	local banners: { [string]: BannerRow } = {}
	for order, banner in Config.Runes.Banners do
		local card = makeCard(page, order)
		makeText(card, banner.DisplayName, 16, Theme.Text, true, 1)
		local cost = makeText(card, "", 12, Theme.Muted, false, 2)
		local buttons = makeRow(card, 3)
		for _, count in Config.Runes.RollCounts do
			local bannerId = banner.Id
			makeButton(buttons, "Roll x" .. count, 100, function()
				Network.FireServer("RequestRollRunes", bannerId, count)
			end)
		end
		card.Visible = false
		banners[banner.Id] = { Frame = card, Cost = cost }
	end

	local resultCard = makeCard(page, 50)
	lastRollLabel = makeText(resultCard, "Roll a banner to see results here.", 12, Theme.Muted, false, 1)

	makeText(page, "OWNED GLYPHS (never reset)", 12, Theme.Muted, true, 60)
	local ownedLabels: { [string]: TextLabel } = {}
	for index, rune in Config.Runes.Definitions do
		local label = makeText(page, "", 13, ById.Rarities[rune.Rarity].Color, false, 60 + index)
		label.Visible = false
		ownedLabels[rune.Id] = label
	end

	onRefresh(function(state)
		local rank = state.Settings.AutoDeleteBelow
		autoDelete.Text = if rank <= 0
			then "Auto-delete: Off"
			else "Auto-delete: " .. Config.Runes.Rarities[rank].DisplayName .. " & below"
		setButtonState(autoDelete, true, if rank > 0 then Theme.Warn else Theme.Disabled)
		luckText.Text = string.format("Luck: <b>+%.2f</b> (rarer glyphs weigh more)", state.Stats.Luck)
		for bannerId, row in banners do
			local banner = ById.Banners[bannerId]
			row.Frame.Visible = state.Unfolded["Banner:" .. bannerId] == true
			row.Cost.Text = string.format(
				"%s %s per roll — you have %s",
				BigNum.ToString(banner.CostAmount),
				currencyTag(banner.CostCurrency),
				fmt(state.Currencies[banner.CostCurrency] or "0|0")
			)
		end
		for runeId, label in ownedLabels do
			local count = state.Runes[runeId] or 0
			local rune = ById.Runes[runeId]
			label.Visible = count > 0
			label.Text = string.format(
				"%s <font color=\"%s\">(%s)</font>  %d/%d — %s",
				rune.DisplayName,
				hex(Theme.Muted),
				rune.Rarity,
				math.min(count, rune.MaxStack),
				rune.MaxStack,
				rune.Description
			)
		end
	end)
end

-- Trails & Boosts tab ---------------------------------------------------------------

do
	local page = getPage("Cosmetics")
	makeText(page, "TRAILS (persist through every prestige)", 12, Theme.Muted, true, 1)
	type TrailRow = { Frame: Frame, Button: TextButton }
	local trailRows: { [string]: TrailRow } = {}
	for index, trail in Config.Trails do
		local card = makeCard(page, 1 + index)
		makeText(card, trail.DisplayName, 15, trail.ColorA, true, 1)
		makeText(card, trail.Description, 12, Theme.Muted, false, 2)
		local row = makeRow(card, 3)
		local trailId = trail.Id
		local button = makeButton(row, "Buy", 200, function()
			local current = snapshot
			if not current then
				return
			end
			if not current.OwnedTrails[trailId] then
				Network.FireServer("RequestBuyTrail", trailId)
			elseif current.EquippedTrail == trailId then
				Network.FireServer("RequestEquipTrail", "")
			else
				Network.FireServer("RequestEquipTrail", trailId)
			end
		end)
		card.Visible = false
		trailRows[trailId] = { Frame = card, Button = button }
	end

	makeText(page, "SECRET COLLECTIBLES", 12, Theme.Muted, true, 20)
	local collectibleLabels: { [string]: TextLabel } = {}
	for index, collectible in Config.Collectibles do
		collectibleLabels[collectible.Id] = makeText(page, "", 13, Theme.Muted, false, 20 + index)
	end

	makeText(page, "BOOST POTIONS (timers never reset)", 12, Theme.Muted, true, 40)
	type PotionRow = { Timer: TextLabel }
	local potionRows: { [string]: PotionRow } = {}
	for index, potion in Config.Monetization.BoostPotions do
		local card = makeCard(page, 40 + index)
		makeText(card, potion.DisplayName, 15, Theme.Text, true, 1)
		makeText(card, potion.Description, 12, Theme.Muted, false, 2)
		local timer = makeText(card, "", 12, Theme.Good, false, 3)
		local row = makeRow(card, 4)
		local potionId = potion.Id
		makeButton(row, if potion.ProductId > 0 then "Buy" else "Buy (test)", 120, function()
			Network.FireServer("RequestBuyBoost", potionId)
		end)
		potionRows[potionId] = { Timer = timer }
	end

	makeText(page, "GAMEPASSES", 12, Theme.Muted, true, 60)
	type PassRow = { Button: TextButton }
	local passRows: { [string]: PassRow } = {}
	for index, pass in Config.Monetization.Gamepasses do
		local card = makeCard(page, 60 + index)
		makeText(card, pass.DisplayName, 15, Theme.Text, true, 1)
		makeText(card, pass.Description, 12, Theme.Muted, false, 2)
		local row = makeRow(card, 3)
		local passId = pass.Id
		local button = makeButton(row, "Buy", 120, function()
			Network.FireServer("RequestBuyGamepass", passId)
		end)
		passRows[passId] = { Button = button }
	end

	onRefresh(function(state)
		for trailId, row in trailRows do
			local trail = ById.Trails[trailId]
			local owned = state.OwnedTrails[trailId] == true
			row.Frame.Visible = owned or state.Unfolded["Trail:" .. trailId] == true
			if not owned then
				row.Button.Text = "Buy: " .. BigNum.ToString(trail.Cost.Amount) .. " " .. currencyTag(trail.Cost.CurrencyId)
				local held = BigNum.Deserialize(state.Currencies[trail.Cost.CurrencyId] or "0|0")
				setButtonState(row.Button, BigNum.Ge(held, trail.Cost.Amount))
			elseif state.EquippedTrail == trailId then
				row.Button.Text = "Unequip"
				setButtonState(row.Button, true, Theme.Good)
			else
				row.Button.Text = "Equip"
				setButtonState(row.Button, true)
			end
		end
		for collectibleId, label in collectibleLabels do
			local collectible = ById.Collectibles[collectibleId]
			if state.Collectibles[collectibleId] then
				label.TextColor3 = Theme.Good
				label.Text = "✓ " .. collectible.DisplayName .. " — " .. collectible.Description
			else
				label.TextColor3 = Theme.Muted
				label.Text = "??? — Hint: " .. collectible.Hint
			end
		end
		for potionId, row in potionRows do
			local remaining = state.Boosts[potionId]
			row.Timer.Text = if remaining and remaining > 0 then "Active: " .. formatTime(remaining) .. " left" else "Inactive"
			row.Timer.TextColor3 = if remaining and remaining > 0 then Theme.Good else Theme.Muted
		end
		for passId, row in passRows do
			local owned = state.Gamepasses[passId] == true
			row.Button.Text = if owned then "Owned" else "Buy"
			setButtonState(row.Button, not owned, Theme.Good)
		end
	end)
end

-- Activity tab (Mining / Refinery / Combat / Generators HUD) ------------------------

local function findNearestTagged(tag: string, range: number): Instance?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local best: Instance? = nil
	local bestDistance = range
	for _, instance in CollectionService:GetTagged(tag) do
		local position: Vector3? = nil
		if instance:IsA("BasePart") then
			position = instance.Position
		elseif instance:IsA("Model") then
			position = instance:GetPivot().Position
		end
		if position and instance:IsDescendantOf(workspace) then
			local distance = (position - root.Position).Magnitude
			if distance <= bestDistance and instance:GetAttribute("IF_LocalHidden") ~= true then
				best = instance
				bestDistance = distance
			end
		end
	end
	return best
end

do
	local page = getPage("Activity")

	-- Mining
	local mineCard = makeCard(page, 1)
	makeText(mineCard, "⛏ Mining", 16, Theme.Text, true, 1)
	local streakText = makeText(mineCard, "", 13, Theme.Warn, false, 2)
	local yieldText = makeText(mineCard, "", 12, Theme.Muted, false, 3)
	type MasteryRow = { Label: TextLabel, Fill: Frame }
	local masteryRows: { [string]: MasteryRow } = {}
	local masteryOrder = 10
	for _, nodeType in Config.Mining.NodeTypes do
		local label = makeText(mineCard, "", 12, nodeType.Color, false, masteryOrder)
		local fill = makeBar(mineCard, nodeType.Color, masteryOrder + 1)
		masteryRows[nodeType.Id] = { Label = label, Fill = fill }
		masteryOrder += 2
	end
	local mineButtons = makeRow(mineCard, 100)
	makeButton(mineButtons, "Swing nearest", 140, function()
		local node = findNearestTagged(Tags.MineNode, Config.Mining.Range + 4)
		if node then
			Network.FireServer("RequestMine", node)
		else
			toast("No node in range", "Walk up to a mine node first.", Theme.Warn)
		end
	end)
	local autoMine = makeButton(mineButtons, "Auto-Swing: ON", 140, function()
		local current = snapshot
		if current then
			Network.FireServer("RequestSetSetting", "AutoMine", not current.Settings.AutoMine)
		end
	end)

	-- Refinery
	local refineryCard = makeCard(page, 2)
	makeText(refineryCard, "🏭 Refinery", 16, Theme.Text, true, 1)
	local chargeText = makeText(refineryCard, "", 12, Theme.Muted, false, 2)
	type RecipeRow = { Frame: Frame, Label: TextLabel, Fill: Frame, Toggle: TextButton }
	local recipeRows: { [string]: RecipeRow } = {}
	for index, recipe in Config.Refinery.Recipes do
		local holder: Frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 10 + index,
			Parent = refineryCard,
		})
		new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
		local label = makeText(holder, "", 12, Theme.Text, false, 1)
		local fill = makeBar(holder, Theme.Warn, 2)
		local row = makeRow(holder, 3)
		local recipeId = recipe.Id
		local toggle = makeButton(row, "Pause", 100, function()
			Network.FireServer("RequestToggleRefinery", recipeId)
		end)
		holder.Visible = false
		recipeRows[recipeId] = { Frame = holder, Label = label, Fill = fill, Toggle = toggle }
	end

	-- Combat
	local combatCard = makeCard(page, 3)
	makeText(combatCard, "⚔ Combat Arena", 16, Theme.Text, true, 1)
	local enemyText = makeText(combatCard, "", 13, Theme.Text, false, 2)
	local enemyFill = makeBar(combatCard, Theme.Bad, 3)
	local playerText = makeText(combatCard, "", 13, Theme.Text, false, 4)
	local playerFill = makeBar(combatCard, Theme.Good, 5)
	local combatStats = makeText(combatCard, "", 12, Theme.Muted, false, 6)
	local combatButtons = makeRow(combatCard, 7)
	makeButton(combatButtons, "Attack", 140, function()
		if findNearestTagged(Tags.CombatArena, Config.Combat.Range) then
			Network.FireServer("RequestAttack")
		else
			toast("Too far", "Stand inside the Combat Arena to attack.", Theme.Warn)
		end
	end)
	local autoFight = makeButton(combatButtons, "Auto-Fight: ON", 140, function()
		local current = snapshot
		if current then
			Network.FireServer("RequestSetSetting", "AutoFight", not current.Settings.AutoFight)
		end
	end)

	-- Generators
	local generatorCard = makeCard(page, 4)
	makeText(generatorCard, "⚙ Generators (activate by holding, nothing is spent)", 14, Theme.Text, true, 1)
	local generatorLabels: { [string]: TextLabel } = {}
	for index, generator in Config.Generators do
		generatorLabels[generator.Id] = makeText(generatorCard, "", 12, Theme.Muted, false, 1 + index)
	end

	onRefresh(function(state)
		local mining = state.Mining
		mineCard.Visible = Config.Mining.Enabled
		if mining.StreakCount > 0 then
			local nodeType = ById.NodeTypes[mining.StreakType]
			streakText.Text = string.format(
				"Streak: <b>%d</b> %s  (x%.2f yield)",
				mining.StreakCount,
				if nodeType then nodeType.DisplayName else mining.StreakType,
				mining.StreakMult
			)
		else
			streakText.Text = "Streak: none — hit the same node type repeatedly to build one."
		end
		yieldText.Text = "Global mining multiplier: x" .. fmt(mining.YieldMult)
		for nodeTypeId, row in masteryRows do
			local visible = state.Unfolded["Node:" .. nodeTypeId] == true
			local mastery = mining.Mastery[nodeTypeId]
			row.Label.Visible = visible
			local barBackground = row.Fill.Parent :: Frame
			barBackground.Visible = visible
			if mastery then
				local nodeType = ById.NodeTypes[nodeTypeId]
				row.Label.Text = string.format(
					"%s Mastery Lv %d  (x%.2f)  %d/%d XP",
					nodeType.DisplayName,
					mastery.Level,
					mastery.Mult,
					math.floor(mastery.XP),
					math.floor(mastery.Needed)
				)
				setFill(row.Fill, mastery.XP / math.max(mastery.Needed, 1))
			end
		end
		autoMine.Visible = state.Stats.AutoMine
		autoMine.Text = "Auto-Swing: " .. (if state.Settings.AutoMine then "ON" else "OFF")
		setButtonState(autoMine, true, if state.Settings.AutoMine then Theme.Good else Theme.Disabled)

		local anyRecipe = false
		for recipeId, row in recipeRows do
			local recipe = ById.Recipes[recipeId]
			local recipeState = state.Refinery[recipeId]
			local visible = state.Unfolded["Recipe:" .. recipeId] == true and recipeState ~= nil
			row.Frame.Visible = visible
			if visible and recipeState then
				anyRecipe = true
				row.Label.Text = string.format(
					"<b>%s</b>: %s %s → %s %s  •  %s",
					recipe.DisplayName,
					BigNum.ToString(recipe.InputAmount),
					currencyTag(recipe.Input),
					BigNum.ToString(recipe.OutputAmount),
					currencyTag(recipe.Output),
					if recipeState.Enabled then "<font color=\"#4AD278\">running</font>" else "<font color=\"#F0555A\">paused</font>"
				)
				setFill(row.Fill, recipeState.Progress)
				row.Toggle.Text = if recipeState.Enabled then "Pause" else "Start"
				setButtonState(row.Toggle, true, if recipeState.Enabled then Theme.Disabled else Theme.Good)
				chargeText.Text = string.format(
					"Cycle: %.2fs  •  Charge: x%.2f (builds for %ds after each reset)",
					recipeState.Cycle,
					recipeState.Charge,
					Config.Refinery.ChargeSecondsToMax
				)
			end
		end
		refineryCard.Visible = Config.Refinery.Enabled and anyRecipe

		local combat = state.Combat
		combatCard.Visible = Config.Combat.Enabled and state.Unfolded["Combat:Arena"] == true
		enemyText.Text = string.format(
			"%s #%d — %s / %s HP",
			Config.Combat.EnemyName,
			combat.Kills + 1,
			fmt(combat.EnemyHP),
			fmt(combat.EnemyMaxHP)
		)
		setFill(enemyFill, combat.EnemyHPFraction)
		playerText.Text = string.format("You — %s / %s HP", fmt(combat.PlayerHP), fmt(combat.PlayerMaxHP))
		setFill(playerFill, combat.PlayerHPFraction)
		combatStats.Text = string.format(
			"Damage %s  •  Enemy attack %s  •  Kill reward %s %s",
			fmt(combat.Damage),
			fmt(combat.EnemyAttack),
			fmt(combat.Reward),
			currencyTag(Config.Combat.RewardCurrency)
		)
		autoFight.Visible = state.Stats.AutoFight
		autoFight.Text = "Auto-Fight: " .. (if state.Settings.AutoFight then "ON" else "OFF")
		setButtonState(autoFight, true, if state.Settings.AutoFight then Theme.Good else Theme.Disabled)

		local anyGenerator = false
		for generatorId, label in generatorLabels do
			local generator = ById.Generators[generatorId]
			local visible = state.Unfolded["Generator:" .. generatorId] == true
			label.Visible = visible
			if visible then
				anyGenerator = true
				local active = state.Generators[generatorId] == true
				label.TextColor3 = if active then Theme.Good else Theme.Muted
				label.Text = string.format(
					"%s %s: +%s %s/s while holding %s %s",
					if active then "●" else "○",
					generator.DisplayName,
					BigNum.ToString(generator.BaseRate),
					currencyTag(generator.Currency),
					BigNum.ToString(generator.ActivationThreshold.Amount),
					currencyTag(generator.ActivationThreshold.CurrencyId)
				)
			end
		end
		generatorCard.Visible = anyGenerator
	end)
end

-- World: local visibility -----------------------------------------------------------

local VISIBILITY_TAGS = {
	Tags.UnlockableZone, -- zones first so their children can override afterwards
	Tags.Button,
	Tags.MineNode,
	Tags.Refinery,
	Tags.RuneAltar,
	Tags.CombatArena,
	Tags.Collectible,
}

local visibilityCache: { [Instance]: boolean } = {}

local function unfoldKeyFor(instance: Instance, tag: string): string?
	local function attribute(name: string): string?
		local value = instance:GetAttribute(name)
		return if type(value) == "string" then value else nil
	end
	if tag == Tags.UnlockableZone then
		local id = attribute(Attributes.ZoneId)
		return if id then "Zone:" .. id else nil
	elseif tag == Tags.Button then
		local id = attribute(Attributes.UpgradeId)
		return if id then "Upgrade:" .. id else nil
	elseif tag == Tags.MineNode then
		local id = attribute(Attributes.NodeType)
		return if id then "Node:" .. id else nil
	elseif tag == Tags.Refinery then
		local id = attribute(Attributes.RecipeId)
		return if id then "Recipe:" .. id else nil
	elseif tag == Tags.RuneAltar then
		local id = attribute(Attributes.RuneBannerId)
		return if id then "Banner:" .. id else nil
	elseif tag == Tags.CombatArena then
		return "Combat:Arena"
	end
	return nil
end

local function insideLockedZone(instance: Instance): boolean
	local current = instance.Parent
	while current and current ~= workspace do
		if CollectionService:HasTag(current, Tags.UnlockableZone) then
			local zoneId = current:GetAttribute(Attributes.ZoneId)
			if type(zoneId) == "string" and not isUnfolded("Zone:" .. zoneId) then
				return true
			end
		end
		current = current.Parent
	end
	return false
end

local function applyPartVisibility(part: BasePart, show: boolean)
	if part:GetAttribute("IF_Transparency") == nil then
		part:SetAttribute("IF_Transparency", part.Transparency)
		part:SetAttribute("IF_CanCollide", part.CanCollide)
		part:SetAttribute("IF_CanQuery", part.CanQuery)
	end
	if show then
		part.Transparency = part:GetAttribute("IF_Transparency") :: number
		part.CanCollide = part:GetAttribute("IF_CanCollide") :: boolean
		part.CanQuery = part:GetAttribute("IF_CanQuery") :: boolean
	else
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
	end
end

local function applyVisibility(root: Instance, visible: boolean)
	root:SetAttribute("IF_LocalHidden", not visible)
	local targets: { Instance } = root:GetDescendants()
	table.insert(targets, root)
	for _, item in targets do
		-- Barrier parts are the inverse: present while locked, gone once unlocked.
		local barrierOwner: Instance? = item
		local isBarrier = false
		while barrierOwner and barrierOwner ~= root.Parent do
			if barrierOwner:GetAttribute(Attributes.IsBarrier) == true then
				isBarrier = true
				break
			end
			barrierOwner = barrierOwner.Parent
		end
		local show = if isBarrier then not visible else visible
		if item:IsA("BasePart") then
			applyPartVisibility(item, show)
		elseif item:IsA("ProximityPrompt") then
			item.Enabled = show
		elseif item:IsA("ClickDetector") then
			if item:GetAttribute("IF_Distance") == nil then
				item:SetAttribute("IF_Distance", item.MaxActivationDistance)
			end
			item.MaxActivationDistance = if show then item:GetAttribute("IF_Distance") :: number else 0
		elseif item:IsA("BillboardGui") then
			item.Enabled = show
		elseif item:IsA("Sparkles") then
			item.Enabled = show
		elseif item:IsA("ParticleEmitter") then
			item.Enabled = show
		end
	end
end

local function refreshWorldVisibility(state: Snapshot)
	local changedZone = false
	for _, zone in CollectionService:GetTagged(Tags.UnlockableZone) do
		local key = unfoldKeyFor(zone, Tags.UnlockableZone)
		local visible = key == nil or state.Unfolded[key] == true
		if visibilityCache[zone] ~= visible then
			visibilityCache[zone] = visible
			applyVisibility(zone, visible)
			changedZone = true
		end
	end
	if changedZone then
		-- A zone rewrote its whole subtree; force children to re-apply their own state.
		for instance in visibilityCache do
			if not CollectionService:HasTag(instance, Tags.UnlockableZone) then
				visibilityCache[instance] = nil
			end
		end
	end
	for _, tag in VISIBILITY_TAGS do
		if tag ~= Tags.UnlockableZone then
			for _, instance in CollectionService:GetTagged(tag) do
				local visible: boolean
				if tag == Tags.Collectible then
					local id = instance:GetAttribute(Attributes.CollectibleId)
					visible = not (type(id) == "string" and state.Collectibles[id] == true)
				else
					local key = unfoldKeyFor(instance, tag)
					visible = key == nil or state.Unfolded[key] == true
				end
				visible = visible and not insideLockedZone(instance)
				if visibilityCache[instance] ~= visible then
					visibilityCache[instance] = visible
					applyVisibility(instance, visible)
				end
			end
		end
	end
end

onRefresh(refreshWorldVisibility)

for _, tag in VISIBILITY_TAGS do
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		visibilityCache[instance] = nil
	end)
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		visibilityCache[instance] = nil
		local current = snapshot
		if current then
			refreshWorldVisibility(current)
		end
	end)
end

-- World: billboards -----------------------------------------------------------------

type WorldBillboard = {
	Instance: Instance,
	Tag: string,
	Gui: BillboardGui,
	Title: TextLabel,
	Sub: TextLabel,
	Fill: Frame?,
}

local billboards: { [Instance]: WorldBillboard } = {}
local billboardFolder: Folder = new("Folder", { Name = "IncrementalBillboards", Parent = playerGui })

local function adorneeFor(instance: Instance, tag: string): BasePart?
	if tag == Tags.CombatArena then
		local enemy = instance:FindFirstChild("Enemy", true)
		if enemy and enemy:IsA("BasePart") then
			return enemy
		end
	end
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function createBillboard(instance: Instance, tag: string)
	if billboards[instance] then
		return
	end
	local adornee = adorneeFor(instance, tag)
	if not adornee then
		return
	end
	local withBar = tag == Tags.CombatArena or tag == Tags.Refinery
	local gui: BillboardGui = new("BillboardGui", {
		Name = tag .. "_" .. instance.Name,
		Adornee = adornee,
		Size = UDim2.fromOffset(200, if withBar then 66 else 50),
		StudsOffsetWorldSpace = Vector3.new(0, adornee.Size.Y / 2 + 2.5, 0),
		AlwaysOnTop = true,
		MaxDistance = 90,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = billboardFolder,
	})
	local frame: Frame = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.25,
		Parent = gui,
	})
	corner(frame, 8)
	pad(frame, 4)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	local title: TextLabel = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		LayoutOrder = 1,
		Parent = frame,
	})
	local sub: TextLabel = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Muted,
		Font = Enum.Font.Gotham,
		TextScaled = true,
		RichText = true,
		LayoutOrder = 2,
		Parent = frame,
	})
	local fill: Frame? = nil
	if withBar then
		fill = makeBar(frame, if tag == Tags.CombatArena then Theme.Bad else Theme.Warn, 3)
	end
	billboards[instance] = { Instance = instance, Tag = tag, Gui = gui, Title = title, Sub = sub, Fill = fill }
end

local function updateBillboard(entry: WorldBillboard, state: Snapshot)
	local instance = entry.Instance
	local hidden = instance:GetAttribute("IF_LocalHidden") == true
	entry.Gui.Enabled = not hidden
	if hidden then
		return
	end
	local tag = entry.Tag
	local function attribute(name: string): string
		local value = instance:GetAttribute(name)
		return if type(value) == "string" then value else ""
	end
	if tag == Tags.Button then
		local upgradeId = attribute(Attributes.UpgradeId)
		local upgrade = ById.Upgrades[upgradeId]
		local upgradeState = state.Upgrades[upgradeId]
		if upgrade and upgradeState then
			entry.Title.Text = upgrade.DisplayName
			local level = if upgradeState.MaxLevel < 0
				then "Lv " .. upgradeState.Level
				else string.format("Lv %d/%d", upgradeState.Level, upgradeState.MaxLevel)
			local maxed = upgradeState.MaxLevel >= 0 and upgradeState.Level >= upgradeState.MaxLevel
			local cost = if maxed
				then "MAXED"
				elseif upgradeState.Free then "FREE"
				else fmt(upgradeState.Cost) .. " " .. ById.Currencies[upgrade.Currency].Icon
			entry.Sub.Text = level .. "  •  " .. cost
			entry.Sub.TextColor3 = if upgradeState.Affordable then Theme.Good else Theme.Muted
		end
	elseif tag == Tags.MineNode then
		local nodeTypeId = attribute(Attributes.NodeType)
		local nodeType = ById.NodeTypes[nodeTypeId]
		local mastery = state.Mining.Mastery[nodeTypeId]
		if nodeType and mastery then
			entry.Title.Text = nodeType.DisplayName
			local streak = if state.Mining.StreakType == nodeTypeId and state.Mining.StreakCount > 0
				then string.format("  •  Streak %d (x%.2f)", state.Mining.StreakCount, state.Mining.StreakMult)
				else ""
			entry.Sub.Text = string.format("Mastery %d (x%.2f)%s", mastery.Level, mastery.Mult, streak)
		end
	elseif tag == Tags.Refinery then
		local recipeId = attribute(Attributes.RecipeId)
		local recipe = ById.Recipes[recipeId]
		local recipeState = state.Refinery[recipeId]
		if recipe and recipeState then
			entry.Title.Text = recipe.DisplayName
			entry.Sub.Text = string.format(
				"%s  •  %.1fs  •  Charge x%.2f",
				if recipeState.Enabled then "Running" else "Paused",
				recipeState.Cycle,
				recipeState.Charge
			)
			if entry.Fill then
				setFill(entry.Fill, recipeState.Progress)
			end
		end
	elseif tag == Tags.RuneAltar then
		local bannerId = attribute(Attributes.RuneBannerId)
		local banner = ById.Banners[bannerId]
		if banner then
			entry.Title.Text = banner.DisplayName
			entry.Sub.Text = BigNum.ToString(banner.CostAmount) .. " " .. currencyTag(banner.CostCurrency) .. " / roll"
		end
	elseif tag == Tags.CombatArena then
		local combat = state.Combat
		entry.Title.Text = string.format("%s #%d", Config.Combat.EnemyName, combat.Kills + 1)
		entry.Sub.Text = fmt(combat.EnemyHP) .. " / " .. fmt(combat.EnemyMaxHP) .. " HP"
		if entry.Fill then
			setFill(entry.Fill, combat.EnemyHPFraction)
		end
	end
end

local BILLBOARD_TAGS = { Tags.Button, Tags.MineNode, Tags.Refinery, Tags.RuneAltar, Tags.CombatArena }
for _, tag in BILLBOARD_TAGS do
	for _, instance in CollectionService:GetTagged(tag) do
		createBillboard(instance, tag)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		createBillboard(instance, tag)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		local entry = billboards[instance]
		if entry then
			entry.Gui:Destroy()
			billboards[instance] = nil
		end
	end)
end

onRefresh(function(state)
	for _, entry in billboards do
		updateBillboard(entry, state)
	end
end)

-- Floating feedback -----------------------------------------------------------------

local function floatText(adornee: BasePart, text: string, color: Color3)
	local floating: BillboardGui = new("BillboardGui", {
		Adornee = adornee,
		Size = UDim2.fromOffset(160, 30),
		StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, adornee.Size.Y / 2 + 1, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = billboardFolder,
	})
	local label: TextLabel = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		TextStrokeTransparency = 0.4,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		Parent = floating,
	})
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(floating, info, { StudsOffsetWorldSpace = floating.StudsOffsetWorldSpace + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1, function()
		floating:Destroy()
	end)
end

local function enemyPart(): BasePart?
	for _, arena in CollectionService:GetTagged(Tags.CombatArena) do
		local enemy = arena:FindFirstChild("Enemy", true)
		if enemy and enemy:IsA("BasePart") then
			return enemy
		end
	end
	return nil
end

-- Network ---------------------------------------------------------------------------

local function applySnapshot(state: Snapshot)
	snapshot = state
	for _, callback in refreshCallbacks do
		xpcall(callback, function(err)
			warn("[UIController] refresh failed:", err)
		end, state)
	end
end

Network.OnClientEvent("StateSync", function(state: any)
	applySnapshot(state :: Snapshot)
end)

Network.OnClientEvent("Notify", function(payload: any)
	local data = payload :: Network.NotifyPayload
	toast(data.Title, data.Text, NOTIFY_COLORS[data.Kind] or Theme.Accent)
end)

local UNFOLD_LABELS: { [string]: string } = {
	Tab = "New tab",
	Currency = "New currency",
	Upgrade = "New upgrade",
	Generator = "New generator",
	Prestige = "New prestige layer",
	Node = "New mine node",
	Recipe = "New refinery recipe",
	Combat = "Combat arena opened",
	Banner = "New rune banner",
	Trail = "New trail",
	Zone = "New zone",
}

Network.OnClientEvent("Unfold", function(payload: any)
	local data = payload :: Network.UnfoldPayload
	toast("✦ Unfolded: " .. data.DisplayName, UNFOLD_LABELS[data.Kind] or data.Kind, Theme.Unfold)
	if data.Kind == "Tab" then
		local tabId = string.sub(data.Key, 5)
		local entry = tabs[tabId]
		if entry and activeTab ~= tabId then
			entry.Badge.Visible = true
		end
	end
end)

Network.OnClientEvent("MineFeedback", function(payload: any)
	local data = payload :: Network.MineFeedback
	if data.Node and data.Node:IsA("BasePart") then
		local currency = ById.Currencies[data.CurrencyId]
		floatText(
			data.Node,
			"+" .. fmt(data.Amount) .. " " .. (if currency then currency.Icon else ""),
			if currency then currency.Color else Theme.Text
		)
	end
end)

Network.OnClientEvent("CombatFeedback", function(payload: any)
	local data = payload :: Network.CombatFeedback
	local enemy = enemyPart()
	if not enemy then
		return
	end
	if data.Defeated then
		floatText(enemy, "DEFEATED", Theme.Bad)
	elseif data.Killed then
		floatText(enemy, "KO! +" .. fmt(data.Reward) .. " " .. ById.Currencies[Config.Combat.RewardCurrency].Icon, Theme.Warn)
	else
		floatText(enemy, "-" .. fmt(data.Damage), Theme.Text)
	end
end)

Network.OnClientEvent("RuneResult", function(payload: any)
	local data = payload :: Network.RuneResult
	local parts: { string } = {}
	local kept = 0
	for _, result in data.Results do
		local rune = ById.Runes[result.RuneId]
		if rune then
			local color = ById.Rarities[rune.Rarity].Color
			if result.Kept then
				kept += 1
				table.insert(parts, string.format("<font color=\"%s\">%s</font>", hex(color), rune.DisplayName))
			else
				table.insert(parts, string.format("<font color=\"%s\"><s>%s</s></font>", hex(Theme.Disabled), rune.DisplayName))
			end
		end
	end
	lastRollLabel.Text = string.format("Last roll: %d kept, %d deleted\n%s", kept, #data.Results - kept, table.concat(parts, ", "))
	if #data.Results == 1 and kept == 1 then
		local rune = ById.Runes[data.Results[1].RuneId]
		toast("Rolled " .. rune.DisplayName, rune.Description, ById.Rarities[rune.Rarity].Color)
	end
end)

-- Boot ------------------------------------------------------------------------------

updateScale()
local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

task.spawn(function()
	-- The profile may still be loading; StateSync will arrive on its own once it is ready.
	for _ = 1, 10 do
		local ok, result = pcall(function(): any
			return Network.InvokeServer("GetSnapshot")
		end)
		if ok and result then
			applySnapshot(result :: Snapshot)
			return
		end
		if snapshot then
			return
		end
		task.wait(1)
	end
end)
