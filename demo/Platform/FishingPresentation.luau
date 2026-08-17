--!strict

local function start()

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local commandEvent = ReplicatedStorage:WaitForChild("ECSRFishingCommand") :: RemoteEvent
local stateEvent = ReplicatedStorage:WaitForChild("ECSRFishingState") :: RemoteEvent

local CELL_SIZE = 10
local COLORS = {
	ink = Color3.fromRGB(8, 27, 41),
	panel = Color3.fromRGB(11, 37, 54),
	panelSoft = Color3.fromRGB(20, 61, 78),
	cyan = Color3.fromRGB(65, 226, 231),
	green = Color3.fromRGB(69, 245, 164),
	gold = Color3.fromRGB(255, 202, 88),
	white = Color3.fromRGB(237, 250, 255),
	muted = Color3.fromRGB(161, 210, 222),
	common = Color3.fromRGB(101, 187, 218),
	rare = Color3.fromRGB(76, 145, 255),
	epic = Color3.fromRGB(202, 91, 255),
}

local MODE_NAMES = {
	Docked = "停靠港口",
	Searching = "追踪鱼群",
	AtSchool = "抵达鱼群",
	ReadyToReturn = "满载待返",
	Returning = "返航中",
	DockedWithCatch = "港口结算",
}

local OBJECTIVES = {
	"01  出航",
	"02  找线索",
	"03  破冰",
	"04  下网",
	"05  返港结算",
}

local presentation = {
	latestState = nil,
	lastState = nil,
	introDismissed = false,
	catchOpen = false,
	clock = 0,
	animated = {},
}

local oldScene = Workspace:FindFirstChild("ECSRFishingScene")
if oldScene ~= nil then
	oldScene:Destroy()
end
local scene = Instance.new("Folder")
scene.Name = "ECSRFishingScene"
scene.Parent = Workspace

local function ensureLighting(className: string, name: string, properties)
	local instance = Lighting:FindFirstChild(name)
	if instance == nil or instance.ClassName ~= className then
		if instance ~= nil then
			instance:Destroy()
		end
		instance = Instance.new(className)
		instance.Name = name
		instance.Parent = Lighting
	end
	for key, value in pairs(properties) do
		instance[key] = value
	end
	return instance
end

Lighting.ClockTime = 10.8
Lighting.Brightness = 2.3
Lighting.Ambient = Color3.fromRGB(105, 151, 177)
Lighting.OutdoorAmbient = Color3.fromRGB(146, 188, 207)
Lighting.EnvironmentDiffuseScale = 0.35
Lighting.EnvironmentSpecularScale = 0.75
ensureLighting("Atmosphere", "ECSRFishingAtmosphere", {
	Density = 0.26,
	Offset = 0.12,
	Color = Color3.fromRGB(205, 236, 250),
	Decay = Color3.fromRGB(82, 137, 169),
	Glare = 0.15,
	Haze = 1.25,
})
ensureLighting("BloomEffect", "ECSRFishingBloom", { Intensity = 0.35, Size = 30, Threshold = 1.35 })
ensureLighting("ColorCorrectionEffect", "ECSRFishingGrade", {
	Brightness = 0.015,
	Contrast = 0.08,
	Saturation = -0.04,
	TintColor = Color3.fromRGB(225, 247, 255),
})
ensureLighting("SunRaysEffect", "ECSRFishingSunRays", { Intensity = 0.035, Spread = 0.72 })
ensureLighting("DepthOfFieldEffect", "ECSRFishingDepth", {
	FarIntensity = 0.08,
	FocusDistance = 48,
	InFocusRadius = 40,
	NearIntensity = 0.12,
})

local clouds = Workspace.Terrain:FindFirstChild("ECSRFishingClouds")
if clouds == nil or not clouds:IsA("Clouds") then
	if clouds ~= nil then
		clouds:Destroy()
	end
	clouds = Instance.new("Clouds")
	clouds.Name = "ECSRFishingClouds"
	clouds.Parent = Workspace.Terrain
end
(clouds :: Clouds).Cover = 0.34
(clouds :: Clouds).Density = 0.28
(clouds :: Clouds).Color = Color3.fromRGB(222, 239, 246)

local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("ECSRFishingUI")
if oldGui ~= nil then
	oldGui:Destroy()
end
local gui = Instance.new("ScreenGui")
gui.Name = "ECSRFishingUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "PresentationRoot"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui
local uiScale = Instance.new("UIScale")
uiScale.Parent = root

local function rounded(instance: GuiObject, radius: number)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = instance
end

local function stroke(instance: GuiObject, color: Color3, thickness: number, transparency: number?)
	local value = Instance.new("UIStroke")
	value.Color = color
	value.Thickness = thickness
	value.Transparency = transparency or 0
	value.Parent = instance
end

local function gradient(instance: GuiObject, first: Color3, second: Color3, rotation: number?)
	local value = Instance.new("UIGradient")
	value.Color = ColorSequence.new(first, second)
	value.Rotation = rotation or 0
	value.Parent = instance
end

local function panel(name: string, position: UDim2, size: UDim2, parent: Instance?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = COLORS.panel
	frame.BackgroundTransparency = 0.06
	frame.Parent = parent or root
	rounded(frame, 14)
	stroke(frame, Color3.fromRGB(82, 173, 194), 1.5, 0.32)
	return frame
end

local function textLabel(name: string, text: string, position: UDim2, size: UDim2, parent: Instance, font, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = text
	label.TextColor3 = COLORS.white
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local brand = panel("Brand", UDim2.fromOffset(22, 20), UDim2.fromOffset(360, 92))
gradient(brand, Color3.fromRGB(13, 49, 67), Color3.fromRGB(10, 31, 47), 18)
local brandEyebrow = textLabel("Eyebrow", "ECSR PLAYABLE VERTICAL SLICE", UDim2.fromOffset(18, 10), UDim2.new(1, -36, 0, 20), brand, Enum.Font.GothamBold, 10)
brandEyebrow.TextColor3 = COLORS.cyan
brandEyebrow.TextTransparency = 0.08
textLabel("Title", "破冰捕鱼", UDim2.fromOffset(18, 28), UDim2.new(1, -36, 0, 38), brand, Enum.Font.GothamBold, 28)
local modeLabel = textLabel("Mode", "等待状态", UDim2.fromOffset(20, 65), UDim2.new(1, -40, 0, 18), brand, Enum.Font.GothamMedium, 12)
modeLabel.TextColor3 = COLORS.muted

local objectiveRail = panel("ObjectiveRail", UDim2.new(0.5, -350, 0, 20), UDim2.fromOffset(700, 52))
objectiveRail.BackgroundTransparency = 0.12
local objectiveLayout = Instance.new("UIListLayout")
objectiveLayout.FillDirection = Enum.FillDirection.Horizontal
objectiveLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
objectiveLayout.VerticalAlignment = Enum.VerticalAlignment.Center
objectiveLayout.Padding = UDim.new(0, 7)
objectiveLayout.Parent = objectiveRail
local objectivePills = {}
for index, objective in ipairs(OBJECTIVES) do
	local pill = Instance.new("TextLabel")
	pill.Name = "Objective" .. tostring(index)
	pill.Size = UDim2.fromOffset(if index == 5 then 142 else 122, 32)
	pill.BackgroundColor3 = Color3.fromRGB(27, 66, 82)
	pill.BackgroundTransparency = 0.3
	pill.Font = Enum.Font.GothamBold
	pill.Text = objective
	pill.TextColor3 = COLORS.muted
	pill.TextSize = 11
	pill.Parent = objectiveRail
	rounded(pill, 16)
	objectivePills[index] = pill
end

local resources = panel("Resources", UDim2.new(1, -282, 0, 20), UDim2.fromOffset(260, 92))
local coinLabel = textLabel("Coins", "金币  0", UDim2.fromOffset(17, 11), UDim2.new(0.5, -20, 0, 28), resources, Enum.Font.GothamBold, 16)
coinLabel.TextColor3 = COLORS.gold
local roundLabel = textLabel("Round", "航次  0", UDim2.new(0.5, 5, 0, 11), UDim2.new(0.5, -20, 0, 28), resources, Enum.Font.GothamBold, 14)
roundLabel.TextXAlignment = Enum.TextXAlignment.Right
local fuelLabel = textLabel("Fuel", "破冰燃料", UDim2.fromOffset(17, 47), UDim2.new(1, -34, 0, 18), resources, Enum.Font.GothamMedium, 11)
fuelLabel.TextColor3 = COLORS.muted
local fuelTrack = Instance.new("Frame")
fuelTrack.Position = UDim2.fromOffset(17, 70)
fuelTrack.Size = UDim2.new(1, -34, 0, 9)
fuelTrack.BackgroundColor3 = Color3.fromRGB(38, 77, 91)
fuelTrack.Parent = resources
rounded(fuelTrack, 5)
local fuelFill = Instance.new("Frame")
fuelFill.Size = UDim2.fromScale(1, 1)
fuelFill.BackgroundColor3 = COLORS.green
fuelFill.Parent = fuelTrack
rounded(fuelFill, 5)
gradient(fuelFill, COLORS.cyan, COLORS.green)

local cargoPanel = panel("Cargo", UDim2.fromOffset(22, 128), UDim2.fromOffset(360, 165))
textLabel("CargoTitle", "本航次渔获", UDim2.fromOffset(17, 10), UDim2.new(0.5, -20, 0, 22), cargoPanel, Enum.Font.GothamBold, 13)
local cargoCount = textLabel("CargoCount", "0 / 6", UDim2.new(0.5, 0, 0, 10), UDim2.new(0.5, -17, 0, 22), cargoPanel, Enum.Font.GothamBold, 13)
cargoCount.TextXAlignment = Enum.TextXAlignment.Right
cargoCount.TextColor3 = COLORS.cyan
local holdLabel = textLabel("Hold", "渔舱为空", UDim2.fromOffset(17, 40), UDim2.new(1, -34, 0, 52), cargoPanel, Enum.Font.Gotham, 12)
holdLabel.TextWrapped = true
holdLabel.TextYAlignment = Enum.TextYAlignment.Top
holdLabel.TextColor3 = COLORS.muted
local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(17, 98)
divider.Size = UDim2.new(1, -34, 0, 1)
divider.BackgroundColor3 = Color3.fromRGB(63, 117, 133)
divider.BackgroundTransparency = 0.45
divider.Parent = cargoPanel
textLabel("CollectionTitle", "珍稀收藏", UDim2.fromOffset(17, 105), UDim2.new(0.35, 0, 0, 20), cargoPanel, Enum.Font.GothamBold, 12)
local collectionLabel = textLabel("Collection", "尚未收藏", UDim2.new(0.35, 0, 0, 105), UDim2.new(0.65, -17, 0, 42), cargoPanel, Enum.Font.Gotham, 11)
collectionLabel.TextWrapped = true
collectionLabel.TextYAlignment = Enum.TextYAlignment.Top
collectionLabel.TextColor3 = COLORS.muted

local mapPanel = panel("MiniMap", UDim2.new(1, -250, 0, 128), UDim2.fromOffset(228, 255))
textLabel("MapTitle", "航区态势", UDim2.fromOffset(15, 10), UDim2.new(1, -30, 0, 24), mapPanel, Enum.Font.GothamBold, 13)
local mapHint = textLabel("MapHint", "海鸟是线索 · 绿色为目标", UDim2.fromOffset(15, 32), UDim2.new(1, -30, 0, 18), mapPanel, Enum.Font.Gotham, 10)
mapHint.TextColor3 = COLORS.muted
local mapGrid = Instance.new("Frame")
mapGrid.Name = "Grid"
mapGrid.Position = UDim2.fromOffset(16, 54)
mapGrid.Size = UDim2.fromOffset(196, 196)
mapGrid.BackgroundColor3 = Color3.fromRGB(17, 68, 91)
mapGrid.BackgroundTransparency = 0.22
mapGrid.ClipsDescendants = true
mapGrid.Parent = mapPanel
rounded(mapGrid, 10)

local messagePanel = panel("Message", UDim2.new(0.5, -310, 1, -214), UDim2.fromOffset(620, 58))
messagePanel.BackgroundColor3 = Color3.fromRGB(10, 47, 65)
local messageAccent = Instance.new("Frame")
messageAccent.Size = UDim2.fromOffset(5, 36)
messageAccent.Position = UDim2.fromOffset(12, 11)
messageAccent.BackgroundColor3 = COLORS.cyan
messageAccent.Parent = messagePanel
rounded(messageAccent, 3)
local messageLabel = textLabel("MessageText", "正在连接状态演化……", UDim2.fromOffset(28, 7), UDim2.new(1, -42, 1, -14), messagePanel, Enum.Font.GothamMedium, 13)
messageLabel.TextWrapped = true

local actions = panel("Actions", UDim2.new(0.5, -455, 1, -142), UDim2.fromOffset(910, 118))
actions.BackgroundTransparency = 0.03
local actionLayout = Instance.new("UIGridLayout")
actionLayout.CellPadding = UDim2.fromOffset(8, 8)
actionLayout.CellSize = UDim2.fromOffset(170, 44)
actionLayout.FillDirectionMaxCells = 5
actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionLayout.Parent = actions

local buttons = {}
local function send(action: string, payload)
	commandEvent:FireServer(action, payload or {})
end

local function makeButton(key: string, caption: string, action: string, payload, order: number, accent: Color3?)
	local button = Instance.new("TextButton")
	button.Name = key
	button.LayoutOrder = order
	button.BackgroundColor3 = accent or Color3.fromRGB(26, 102, 123)
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.Text = caption
	button.TextColor3 = COLORS.white
	button.TextSize = 13
	button.Parent = actions
	rounded(button, 10)
	stroke(button, Color3.fromRGB(126, 226, 237), 1, 0.45)
	button.Activated:Connect(function()
		if not presentation.catchOpen then
			send(action, payload)
		end
	end)
	buttons[key] = button
end

makeButton("Sail", "开始新航次", "Sail", nil, 1, Color3.fromRGB(25, 139, 139))
makeButton("Scan", "声呐扫描  [Q]", "Scan", nil, 2, Color3.fromRGB(32, 118, 156))
makeButton("North", "向北  [W]", "Move", { dx = 0, dz = 1 }, 3)
makeButton("West", "向西  [A]", "Move", { dx = -1, dz = 0 }, 4)
makeButton("East", "向东  [D]", "Move", { dx = 1, dz = 0 }, 5)
makeButton("South", "向南  [S]", "Move", { dx = 0, dz = -1 }, 6)
makeButton("Net", "下网捕捞  [F]", "Net", nil, 7, Color3.fromRGB(25, 145, 126))
makeButton("Return", "封舱返港  [R]", "Return", nil, 8, Color3.fromRGB(164, 111, 36))
makeButton("SellAll", "全部出售", "SellAll", nil, 9, Color3.fromRGB(173, 111, 28))
makeButton("KeepRare", "收藏珍稀鱼", "KeepRare", nil, 10, Color3.fromRGB(124, 69, 177))

local intro = Instance.new("Frame")
intro.Name = "Intro"
intro.Size = UDim2.fromScale(1, 1)
intro.BackgroundColor3 = Color3.fromRGB(5, 22, 34)
intro.BackgroundTransparency = 0.08
intro.ZIndex = 100
intro.Parent = root
local introGradient = Instance.new("UIGradient")
introGradient.Color = ColorSequence.new(Color3.fromRGB(7, 32, 49), Color3.fromRGB(17, 78, 96))
introGradient.Rotation = 25
introGradient.Parent = intro
local introCard = panel("IntroCard", UDim2.new(0.5, -390, 0.5, -225), UDim2.fromOffset(780, 450), intro)
introCard.ZIndex = 101
introCard.BackgroundTransparency = 0.02
gradient(introCard, Color3.fromRGB(12, 47, 66), Color3.fromRGB(8, 29, 45), 22)
local introScale = Instance.new("UIScale")
introScale.Scale = 0.94
introScale.Parent = introCard
local introKicker = textLabel("Kicker", "A PLAYABLE ECSR STORY", UDim2.fromOffset(36, 30), UDim2.new(1, -72, 0, 24), introCard, Enum.Font.GothamBold, 12)
introKicker.ZIndex = 102
introKicker.TextColor3 = COLORS.cyan
local introTitle = textLabel("IntroTitle", "破冰，找到那片鱼群", UDim2.fromOffset(36, 58), UDim2.new(1, -72, 0, 58), introCard, Enum.Font.GothamBold, 36)
introTitle.ZIndex = 102
local introBody = textLabel("IntroBody", "海鸟和水面信号会暴露鱼群踪迹。规划最省燃料的航线，撞开浮冰，下网捕捞，再决定把珍稀渔获卖掉还是留进收藏。", UDim2.fromOffset(36, 120), UDim2.new(1, -72, 0, 62), introCard, Enum.Font.Gotham, 15)
introBody.ZIndex = 102
introBody.TextWrapped = true
introBody.TextColor3 = COLORS.muted

local loopFrame = Instance.new("Frame")
loopFrame.Position = UDim2.fromOffset(36, 206)
loopFrame.Size = UDim2.new(1, -72, 0, 92)
loopFrame.BackgroundTransparency = 1
loopFrame.ZIndex = 102
loopFrame.Parent = introCard
local loopLayout = Instance.new("UIListLayout")
loopLayout.FillDirection = Enum.FillDirection.Horizontal
loopLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
loopLayout.Padding = UDim.new(0, 10)
loopLayout.Parent = loopFrame
for index, data in ipairs({
	{ "01", "追踪", "循海鸟与声呐找鱼" },
	{ "02", "破冰", "选择路线控制燃料" },
	{ "03", "收获", "下网并筛选珍稀鱼" },
	{ "04", "结算", "出售或永久收藏" },
}) do
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(166, 88)
	card.BackgroundColor3 = Color3.fromRGB(22, 67, 82)
	card.BackgroundTransparency = 0.18
	card.ZIndex = 102
	card.Parent = loopFrame
	rounded(card, 12)
	local number = textLabel("Number", data[1], UDim2.fromOffset(12, 9), UDim2.fromOffset(36, 22), card, Enum.Font.GothamBold, 13)
	number.ZIndex = 103
	number.TextColor3 = COLORS.cyan
	local heading = textLabel("Heading", data[2], UDim2.fromOffset(48, 8), UDim2.new(1, -58, 0, 24), card, Enum.Font.GothamBold, 14)
	heading.ZIndex = 103
	local body = textLabel("Body", data[3], UDim2.fromOffset(12, 38), UDim2.new(1, -24, 0, 38), card, Enum.Font.Gotham, 11)
	body.ZIndex = 103
	body.TextWrapped = true
	body.TextColor3 = COLORS.muted
end

local introButton = Instance.new("TextButton")
introButton.Position = UDim2.new(0.5, -150, 1, -102)
introButton.Size = UDim2.fromOffset(300, 56)
introButton.BackgroundColor3 = Color3.fromRGB(36, 165, 155)
introButton.Font = Enum.Font.GothamBold
introButton.Text = "开始第一趟航次"
introButton.TextColor3 = COLORS.white
introButton.TextSize = 16
introButton.ZIndex = 103
introButton.Parent = introCard
rounded(introButton, 13)
stroke(introButton, COLORS.green, 1.5, 0.25)

local catchOverlay = Instance.new("Frame")
catchOverlay.Name = "CatchReveal"
catchOverlay.Size = UDim2.fromScale(1, 1)
catchOverlay.BackgroundColor3 = Color3.fromRGB(3, 17, 27)
catchOverlay.BackgroundTransparency = 0.32
catchOverlay.Visible = false
catchOverlay.ZIndex = 80
catchOverlay.Parent = root
local catchPanel = panel("CatchPanel", UDim2.new(0.5, -360, 0.5, -205), UDim2.fromOffset(720, 410), catchOverlay)
catchPanel.ZIndex = 81
catchPanel.BackgroundTransparency = 0.01
gradient(catchPanel, Color3.fromRGB(14, 56, 72), Color3.fromRGB(8, 31, 47), 18)
local catchScale = Instance.new("UIScale")
catchScale.Parent = catchPanel
local catchTitle = textLabel("CatchTitle", "收网！本航次渔获", UDim2.fromOffset(28, 24), UDim2.new(1, -56, 0, 38), catchPanel, Enum.Font.GothamBold, 26)
catchTitle.ZIndex = 82
local catchSubtitle = textLabel("CatchSubtitle", "珍稀鱼可以返港收藏，也可以高价出售。", UDim2.fromOffset(28, 60), UDim2.new(1, -56, 0, 24), catchPanel, Enum.Font.Gotham, 12)
catchSubtitle.ZIndex = 82
catchSubtitle.TextColor3 = COLORS.muted
local catchCards = Instance.new("Frame")
catchCards.Position = UDim2.fromOffset(28, 104)
catchCards.Size = UDim2.new(1, -56, 0, 190)
catchCards.BackgroundTransparency = 1
catchCards.ZIndex = 82
catchCards.Parent = catchPanel
local catchLayout = Instance.new("UIListLayout")
catchLayout.FillDirection = Enum.FillDirection.Horizontal
catchLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
catchLayout.Padding = UDim.new(0, 12)
catchLayout.Parent = catchCards
local catchContinue = Instance.new("TextButton")
catchContinue.Position = UDim2.new(0.5, -150, 1, -78)
catchContinue.Size = UDim2.fromOffset(300, 50)
catchContinue.BackgroundColor3 = Color3.fromRGB(31, 137, 128)
catchContinue.Font = Enum.Font.GothamBold
catchContinue.Text = "封舱，立即返港"
catchContinue.TextColor3 = COLORS.white
catchContinue.TextSize = 15
catchContinue.ZIndex = 82
catchContinue.Parent = catchPanel
rounded(catchContinue, 12)

local function dismissIntro(startVoyage: boolean)
	if presentation.introDismissed then
		return
	end
	presentation.introDismissed = true
	TweenService:Create(intro, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(introScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.88 }):Play()
	task.delay(0.38, function()
		intro.Visible = false
	end)
	if startVoyage then
		send("Sail")
	end
end

introButton.Activated:Connect(function()
	dismissIntro(true)
end)

catchContinue.Activated:Connect(function()
	presentation.catchOpen = false
	catchOverlay.Visible = false
	send("Return")
end)

local function worldPosition(x: number, z: number, y: number?): Vector3
	return Vector3.new(x * CELL_SIZE, y or 0, z * CELL_SIZE)
end

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, transparency: number?, parent: Instance?, className: string?): BasePart
	local object = Instance.new(className or "Part") :: BasePart
	object.Name = name
	object.Anchored = true
	object.CanCollide = false
	object.CastShadow = true
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material
	object.Transparency = transparency or 0
	object.Parent = parent or scene
	return object
end

local function billboard(adornee: BasePart, caption: string, color: Color3)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(126, 34)
	board.StudsOffset = Vector3.new(0, 2.7, 0)
	board.AlwaysOnTop = true
	board.Adornee = adornee
	board.Parent = scene
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = COLORS.ink
	label.BackgroundTransparency = 0.16
	label.Font = Enum.Font.GothamBold
	label.Text = caption
	label.TextColor3 = color
	label.TextSize = 13
	label.Parent = board
	rounded(label, 10)
	stroke(label, color, 1, 0.55)
end

local function lineBetween(name: string, from: Vector3, to: Vector3, width: number, color: Color3, transparency: number): BasePart?
	local distance = (to - from).Magnitude
	if distance < 0.05 then
		return nil
	end
	local value = part(name, Vector3.new(width, 0.12, distance), CFrame.lookAt((from + to) * 0.5, to), color, Enum.Material.Neon, transparency)
	table.insert(presentation.animated, { kind = "radar", part = value, phase = #presentation.animated * 0.7 })
	return value
end

local function createOcean()
	part("OceanDeep", Vector3.new(100, 2.5, 104), CFrame.new(0, -2.4, 30), Color3.fromRGB(15, 91, 128), Enum.Material.Glass, 0.08)
	part("OceanSurface", Vector3.new(96, 0.18, 100), CFrame.new(0, -0.82, 30), Color3.fromRGB(39, 144, 178), Enum.Material.Glass, 0.28)
	for index = 1, 14 do
		local z = -4 + index * 5
		local wave = part(
			"Wave",
			Vector3.new(82 - (index % 3) * 7, 0.08, 0.22),
			CFrame.new((index % 2) * 3 - 1.5, -0.58, z),
			Color3.fromRGB(185, 235, 246),
			Enum.Material.Neon,
			0.72
		)
		table.insert(presentation.animated, { kind = "wave", part = wave, phase = index * 0.45 })
	end
	for index = 1, 8 do
		local side = if index % 2 == 0 then -1 else 1
		local x = side * (42 + (index % 3) * 4)
		local z = index * 9 - 4
		part("DistantIce", Vector3.new(11 + index % 4, 4 + index % 3, 9), CFrame.new(x, 0.5, z) * CFrame.Angles(0, index * 0.41, 0), Color3.fromRGB(202, 231, 241), Enum.Material.Glacier)
	end
end

local function createPort()
	local origin = worldPosition(0, 0, 0)
	part("Dock", Vector3.new(12, 0.9, 11), CFrame.new(origin), Color3.fromRGB(93, 67, 48), Enum.Material.WoodPlanks)
	part("DockStripe", Vector3.new(12.2, 0.2, 1), CFrame.new(origin + Vector3.new(0, 0.55, 5)), COLORS.gold, Enum.Material.Metal)
	local warehouse = part("Warehouse", Vector3.new(11, 6, 7), CFrame.new(origin + Vector3.new(-10, 3, -1)), Color3.fromRGB(49, 93, 113), Enum.Material.Metal)
	part("WarehouseRoof", Vector3.new(12, 0.8, 8), warehouse.CFrame * CFrame.new(0, 3.3, 0), Color3.fromRGB(25, 55, 72), Enum.Material.Metal)
	part("WarehouseDoor", Vector3.new(4, 4, 0.25), warehouse.CFrame * CFrame.new(0, -0.8, 3.63), Color3.fromRGB(31, 61, 72), Enum.Material.Metal)
	for index = 1, 3 do
		part("CargoCrate", Vector3.new(2.1, 2.1, 2.1), CFrame.new(origin + Vector3.new(6 + index * 2.3, 1.2, -2 + (index % 2) * 2.5)), Color3.fromRGB(67, 105, 126), Enum.Material.Metal)
	end
	part("CranePost", Vector3.new(0.8, 8, 0.8), CFrame.new(origin + Vector3.new(8, 4, -6)), Color3.fromRGB(42, 57, 63), Enum.Material.Metal)
	part("CraneArm", Vector3.new(8, 0.7, 0.7), CFrame.new(origin + Vector3.new(4.5, 7.6, -6)), Color3.fromRGB(42, 57, 63), Enum.Material.Metal)
	part("CraneHook", Vector3.new(0.18, 4, 0.18), CFrame.new(origin + Vector3.new(1, 5.6, -6)), Color3.fromRGB(32, 38, 40), Enum.Material.Metal)
	local lamp = part("PortLamp", Vector3.new(0.55, 0.55, 0.55), CFrame.new(origin + Vector3.new(8, 7.3, -6)), COLORS.gold, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = COLORS.gold
	light.Range = 18
	light.Brightness = 1.3
	light.Parent = lamp
	local marker = part("PortMarker", Vector3.new(0.3, 0.3, 0.3), CFrame.new(origin + Vector3.new(0, 1, 0)), COLORS.gold, Enum.Material.Neon, 0.2)
	billboard(marker, "极地港口", COLORS.gold)
end

local function createIceFloe(cell)
	local signature = math.abs(cell.x * 31 + cell.z * 19)
	local rotation = math.rad(signature % 14 - 7)
	local center = worldPosition(cell.x, cell.z, 0)
	local main = part(
		"IceFloe",
		Vector3.new(8.1 + (signature % 4) * 0.18, 0.68, 8.2 - (signature % 3) * 0.2),
		CFrame.new(center) * CFrame.Angles(0, rotation, 0),
		Color3.fromRGB(202, 234, 244),
		Enum.Material.Glacier
	)
	part("SnowCap", Vector3.new(main.Size.X - 0.6, 0.18, main.Size.Z - 0.7), main.CFrame * CFrame.new(0, 0.43, 0), Color3.fromRGB(239, 249, 252), Enum.Material.Snow)
	part("IceCrack", Vector3.new(0.14, 0.06, 4.6), main.CFrame * CFrame.new(0.5, 0.55, 0.3) * CFrame.Angles(0, 0.35, 0), Color3.fromRGB(67, 140, 165), Enum.Material.Neon, 0.48)
	part("IceCrack", Vector3.new(0.12, 0.06, 2.8), main.CFrame * CFrame.new(-0.9, 0.55, -1.1) * CFrame.Angles(0, -0.72, 0), Color3.fromRGB(67, 140, 165), Enum.Material.Neon, 0.55)
end

local function createBirds(x: number, z: number)
	local origin = worldPosition(x, z, 7.5)
	for index = 1, 3 do
		local center = origin + Vector3.new((index - 2) * 2.4, (index % 2) * 0.8, (index - 2) * 0.9)
		part("BirdWing", Vector3.new(2.2, 0.12, 0.32), CFrame.new(center) * CFrame.Angles(0, 0.22, 0.34), COLORS.white, Enum.Material.SmoothPlastic)
		part("BirdWing", Vector3.new(2.2, 0.12, 0.32), CFrame.new(center) * CFrame.Angles(0, -0.22, -0.34), COLORS.white, Enum.Material.SmoothPlastic)
	end
end

local function createFishSchool(x: number, z: number, stock: number)
	local origin = worldPosition(x, z, -0.25)
	for index = 1, math.max(3, stock * 2) do
		local fish = part(
			"FishSignal",
			Vector3.new(1.8, 0.26, 0.72),
			CFrame.new(origin + Vector3.new(((index - 1) % 3 - 1) * 1.8, 0, (math.floor((index - 1) / 3) - 0.5) * 2.1)) * CFrame.Angles(0, math.rad(90), 0),
			if index % 2 == 0 then COLORS.cyan else Color3.fromRGB(75, 173, 255),
			Enum.Material.Neon,
			0.08
		)
		fish.Shape = Enum.PartType.Block
	end
	for index = 1, 5 do
		local bubble = part("Bubble", Vector3.new(0.25, 0.25, 0.25), CFrame.new(origin + Vector3.new((index - 3) * 0.7, 0.4 + index * 0.18, (index % 2) * 0.6)), COLORS.white, Enum.Material.Glass, 0.25)
		bubble.Shape = Enum.PartType.Ball
	end
	local marker = part("SchoolMarker", Vector3.new(0.3, 0.3, 0.3), CFrame.new(worldPosition(x, z, 1.1)), COLORS.green, Enum.Material.Neon, 0.15)
	billboard(marker, "鱼群 · 可下网", COLORS.green)
end

local function createIceBreakBurst(x: number, z: number)
	local center = worldPosition(x, z, 0.45)
	for index = 1, 7 do
		local angle = (index / 7) * math.pi * 2
		local shard = part("IceShard", Vector3.new(1.1, 0.28, 1.5), CFrame.new(center) * CFrame.Angles(0, angle, 0), Color3.fromRGB(220, 244, 250), Enum.Material.Glacier)
		local destination = center + Vector3.new(math.cos(angle) * 4.5, 1.2 + (index % 2), math.sin(angle) * 4.5)
		local tween = TweenService:Create(shard, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = destination,
			Transparency = 1,
			Orientation = Vector3.new(index * 31, index * 47, index * 23),
		})
		tween:Play()
		tween.Completed:Connect(function()
			if shard.Parent ~= nil then
				shard:Destroy()
			end
		end)
	end
end

local function boatPivot(vessel): CFrame
	local position = worldPosition(vessel.x, vessel.z, 2.05)
	local direction = Vector3.new(vessel.headingX, 0, vessel.headingZ)
	if direction.Magnitude == 0 then
		direction = Vector3.new(0, 0, 1)
	end
	return CFrame.lookAt(position, position + direction)
end

local function createBoat(vessel, previousVessel)
	local model = Instance.new("Model")
	model.Name = "FishingVessel"
	model.Parent = scene
	local hull = part("Hull", Vector3.new(7.4, 1.6, 8.8), CFrame.new(), Color3.fromRGB(16, 48, 66), Enum.Material.Metal, 0, model)
	part("HullStripe", Vector3.new(7.55, 0.55, 8.95), CFrame.new(0, 0.58, 0), Color3.fromRGB(226, 101, 30), Enum.Material.Metal, 0, model)
	part("Bow", Vector3.new(7.2, 1.55, 3.2), CFrame.new(0, 0, -5.35) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(18, 55, 72), Enum.Material.Metal, 0, model, "WedgePart")
	part("Cabin", Vector3.new(5.1, 3.1, 3.7), CFrame.new(0, 2.25, 0.7), Color3.fromRGB(218, 91, 22), Enum.Material.Metal, 0, model)
	part("CabinRoof", Vector3.new(5.6, 0.45, 4.2), CFrame.new(0, 3.95, 0.7), Color3.fromRGB(37, 51, 58), Enum.Material.Metal, 0, model)
	part("FrontWindow", Vector3.new(3.7, 1.18, 0.15), CFrame.new(0, 2.55, -1.18), Color3.fromRGB(74, 188, 220), Enum.Material.Glass, 0.14, model)
	part("CargoBay", Vector3.new(3.8, 1.4, 2.8), CFrame.new(0, 1.35, 3.05), Color3.fromRGB(47, 89, 113), Enum.Material.Metal, 0, model)
	part("Mast", Vector3.new(0.17, 3.1, 0.17), CFrame.new(0, 5.05, 0.65), Color3.fromRGB(31, 37, 40), Enum.Material.Metal, 0, model)
	local beacon = part("Beacon", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 6.62, 0.65), COLORS.gold, Enum.Material.Neon, 0, model)
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = COLORS.gold
	beaconLight.Range = 12
	beaconLight.Brightness = 1.1
	beaconLight.Parent = beacon
	for side = -1, 1, 2 do
		part("Rail", Vector3.new(0.12, 0.9, 7.6), CFrame.new(side * 3.75, 1.4, 0), Color3.fromRGB(173, 194, 199), Enum.Material.Metal, 0, model)
	end
	part("NetDrum", Vector3.new(1.2, 1.2, 2.5), CFrame.new(-2.2, 1.9, 2.8) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(51, 59, 62), Enum.Material.Metal, 0, model)
	part("Wake", Vector3.new(5.7, 0.1, 5.6), CFrame.new(0, -1.02, 6.1), COLORS.white, Enum.Material.Neon, 0.54, model)
	model.PrimaryPart = hull

	local destination = boatPivot(vessel)
	local start = if previousVessel ~= nil then boatPivot(previousVessel) else destination
	model:PivotTo(start)
	if start ~= destination then
		local driver = Instance.new("CFrameValue")
		driver.Value = start
		driver.Parent = model
		local connection = driver:GetPropertyChangedSignal("Value"):Connect(function()
			if model.Parent ~= nil then
				model:PivotTo(driver.Value)
			end
		end)
		local tween = TweenService:Create(driver, TweenInfo.new(0.62, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Value = destination })
		tween:Play()
		tween.Completed:Connect(function()
			connection:Disconnect()
			if driver.Parent ~= nil then
				driver:Destroy()
			end
		end)
	end
end

local function cellMap(state)
	local result = {}
	if state ~= nil then
		for _, cell in ipairs(state.cells) do
			result[tostring(cell.x) .. ":" .. tostring(cell.z)] = cell
		end
	end
	return result
end

local function fishSummary(fishList)
	if #fishList == 0 then
		return "渔舱为空"
	end
	local names = {}
	for _, fish in ipairs(fishList) do
		local marker = if fish.rarity == "Epic" then "◆" elseif fish.rarity == "Rare" then "●" else "·"
		table.insert(names, marker .. fish.displayName)
	end
	return table.concat(names, "  ")
end

local function activeObjective(state): number
	if state.mode == "Docked" then return 1 end
	if state.mode == "Searching" then return if state.revealed then 3 else 2 end
	if state.mode == "AtSchool" then return 4 end
	return 5
end

local function updateObjectives(state)
	local active = activeObjective(state)
	for index, pill in ipairs(objectivePills) do
		local completed = index < active
		pill.BackgroundColor3 = if index == active then Color3.fromRGB(27, 130, 137) elseif completed then Color3.fromRGB(27, 86, 94) else Color3.fromRGB(27, 66, 82)
		pill.BackgroundTransparency = if index == active then 0.02 else 0.3
		pill.TextColor3 = if index == active then COLORS.white elseif completed then COLORS.green else COLORS.muted
	end
end

local function updateMiniMap(state)
	for _, child in ipairs(mapGrid:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, cell in ipairs(state.cells) do
		local tile = Instance.new("Frame")
		tile.Name = tostring(cell.x) .. ":" .. tostring(cell.z)
		tile.Position = UDim2.fromOffset(5 + (cell.x + 3) * 27, 5 + (6 - cell.z) * 27)
		tile.Size = UDim2.fromOffset(24, 24)
		tile.BorderSizePixel = 0
		tile.BackgroundColor3 = if cell.isPort
			then COLORS.gold
			elseif cell.ice
			then Color3.fromRGB(199, 230, 239)
			else Color3.fromRGB(38, 124, 158)
		tile.BackgroundTransparency = if cell.ice then 0.05 else 0.2
		tile.Parent = mapGrid
		rounded(tile, 4)
		if cell.signal ~= nil then
			local signal = Instance.new("Frame")
			signal.AnchorPoint = Vector2.new(0.5, 0.5)
			signal.Position = UDim2.fromScale(0.5, 0.5)
			signal.Size = UDim2.fromOffset(7, 7)
			signal.BackgroundColor3 = COLORS.white
			signal.Parent = tile
			rounded(signal, 4)
		end
		if cell.school ~= nil then
			stroke(tile, COLORS.green, 2, 0)
		end
		if cell.x == state.vessel.x and cell.z == state.vessel.z then
			local boat = Instance.new("Frame")
			boat.AnchorPoint = Vector2.new(0.5, 0.5)
			boat.Position = UDim2.fromScale(0.5, 0.5)
			boat.Size = UDim2.fromOffset(10, 10)
			boat.Rotation = 45
			boat.BackgroundColor3 = Color3.fromRGB(239, 103, 35)
			boat.Parent = tile
			rounded(boat, 2)
			stroke(boat, COLORS.white, 1, 0.1)
		end
	end
end

local function updateButtons(state)
	local mode = state.mode
	buttons.Sail.Visible = mode == "Docked"
	buttons.Scan.Visible = mode == "Searching"
	buttons.North.Visible = mode == "Searching" or mode == "Returning"
	buttons.West.Visible = buttons.North.Visible
	buttons.East.Visible = buttons.North.Visible
	buttons.South.Visible = buttons.North.Visible
	buttons.Net.Visible = mode == "AtSchool"
	buttons.Return.Visible = mode == "ReadyToReturn"
	buttons.SellAll.Visible = mode == "DockedWithCatch"
	buttons.KeepRare.Visible = mode == "DockedWithCatch"
end

local function showCatchReveal(fishList)
	for _, child in ipairs(catchCards:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	presentation.catchOpen = true
	catchOverlay.Visible = true
	catchOverlay.BackgroundTransparency = 1
	catchScale.Scale = 0.82
	TweenService:Create(catchOverlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.32 }):Play()
	TweenService:Create(catchScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	for index, fish in ipairs(fishList) do
		local rarityColor = if fish.rarity == "Epic" then COLORS.epic elseif fish.rarity == "Rare" then COLORS.rare else COLORS.common
		local card = Instance.new("Frame")
		card.Size = UDim2.fromOffset(198, 180)
		card.BackgroundColor3 = Color3.fromRGB(18, 50, 68)
		card.BackgroundTransparency = 1
		card.ZIndex = 83
		card.Parent = catchCards
		rounded(card, 14)
		stroke(card, rarityColor, 2, 0.15)
		local glow = Instance.new("Frame")
		glow.AnchorPoint = Vector2.new(0.5, 0)
		glow.Position = UDim2.new(0.5, 0, 0, 18)
		glow.Size = UDim2.fromOffset(72, 72)
		glow.BackgroundColor3 = rarityColor
		glow.BackgroundTransparency = 1
		glow.ZIndex = 84
		glow.Parent = card
		rounded(glow, 36)
		local icon = textLabel("Fish", "<°)))><", UDim2.fromOffset(20, 34), UDim2.new(1, -40, 0, 34), card, Enum.Font.Code, 20)
		icon.ZIndex = 85
		icon.TextXAlignment = Enum.TextXAlignment.Center
		icon.TextColor3 = rarityColor
		icon.TextTransparency = 1
		local name = textLabel("Name", fish.displayName, UDim2.fromOffset(12, 94), UDim2.new(1, -24, 0, 26), card, Enum.Font.GothamBold, 15)
		name.ZIndex = 85
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTransparency = 1
		local rarity = textLabel("Rarity", fish.rarity .. "  ·  " .. tostring(fish.value) .. " 金币", UDim2.fromOffset(10, 127), UDim2.new(1, -20, 0, 24), card, Enum.Font.GothamBold, 11)
		rarity.ZIndex = 85
		rarity.TextXAlignment = Enum.TextXAlignment.Center
		rarity.TextColor3 = rarityColor
		rarity.TextTransparency = 1
		task.delay(0.08 + (index - 1) * 0.12, function()
			if card.Parent ~= nil then
				TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 0.04 }):Play()
				TweenService:Create(glow, TweenInfo.new(0.35), { BackgroundTransparency = 0.78 }):Play()
				TweenService:Create(icon, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
				TweenService:Create(name, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
				TweenService:Create(rarity, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
			end
		end)
	end
end

local function showRewardToast(caption: string)
	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, -70)
	toast.Size = UDim2.fromOffset(470, 54)
	toast.BackgroundColor3 = Color3.fromRGB(16, 78, 83)
	toast.Font = Enum.Font.GothamBold
	toast.Text = caption
	toast.TextColor3 = COLORS.white
	toast.TextSize = 14
	toast.ZIndex = 70
	toast.Parent = root
	rounded(toast, 14)
	stroke(toast, COLORS.green, 1.5, 0.15)
	TweenService:Create(toast, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 88) }):Play()
	task.delay(2.6, function()
		if toast.Parent ~= nil then
			local tween = TweenService:Create(toast, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -70), TextTransparency = 1, BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Connect(function()
				if toast.Parent ~= nil then toast:Destroy() end
			end)
		end
	end)
end

local function updateCamera(state)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local boat = worldPosition(state.vessel.x, state.vessel.z, 1.5)
	local focus = boat + Vector3.new(0, 0, 8)
	local range = 0
	if state.target ~= nil then
		local target = worldPosition(state.target.x, state.target.z, 0)
		range = (target - boat).Magnitude
		focus = boat:Lerp(target, 0.28)
	end
	local height = 40 + math.min(18, range * 0.28)
	local desired = CFrame.lookAt(focus + Vector3.new(35, height, -43), focus)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 48
	TweenService:Create(camera, TweenInfo.new(0.72, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = desired }):Play()
end

local function render(nextState)
	local previous = presentation.lastState
	presentation.latestState = nextState
	presentation.lastState = nextState
	presentation.animated = {}
	for _, child in ipairs(scene:GetChildren()) do
		child:Destroy()
	end

	createOcean()
	createPort()
	for _, cell in ipairs(nextState.cells) do
		local base = worldPosition(cell.x, cell.z, -0.58)
		part("SeaGrid", Vector3.new(9.2, 0.08, 9.2), CFrame.new(base), Color3.fromRGB(54, 151, 184), Enum.Material.Glass, 0.58)
		if cell.ice then createIceFloe(cell) end
		if cell.signal ~= nil then createBirds(cell.x, cell.z) end
		if cell.school ~= nil and cell.school.stock > 0 then createFishSchool(cell.x, cell.z, cell.school.stock) end
	end

	if nextState.target ~= nil then
		local from = worldPosition(nextState.vessel.x, nextState.vessel.z, 0.75)
		local target = worldPosition(nextState.target.x, nextState.target.z, 0.75)
		local direction = target - from
		if direction.Magnitude > 0.05 then
			local side = Vector3.new(-direction.Z, 0, direction.X).Unit * 2.4
			lineBetween("RadarCenter", from, target, 0.72, COLORS.green, 0.48)
			lineBetween("RadarLeft", from, target + side, 0.32, COLORS.green, 0.68)
			lineBetween("RadarRight", from, target - side, 0.32, COLORS.green, 0.68)
		end
	end

	if previous ~= nil then
		local previousCells = cellMap(previous)
		for _, cell in ipairs(nextState.cells) do
			local oldCell = previousCells[tostring(cell.x) .. ":" .. tostring(cell.z)]
			if oldCell ~= nil and oldCell.ice and not cell.ice then
				createIceBreakBurst(cell.x, cell.z)
			end
		end
	end
	createBoat(nextState.vessel, if previous ~= nil then previous.vessel else nil)
	updateCamera(nextState)

	modeLabel.Text = (MODE_NAMES[nextState.mode] or nextState.mode) .. "  ·  ECSR TICK " .. tostring(nextState.tick)
	coinLabel.Text = "金币  " .. tostring(nextState.coins)
	roundLabel.Text = "航次  " .. tostring(nextState.round)
	fuelLabel.Text = string.format("破冰燃料  %d / %d", nextState.vessel.fuel, nextState.vessel.maxFuel)
	local ratio = math.clamp(nextState.vessel.fuel / math.max(1, nextState.vessel.maxFuel), 0, 1)
	TweenService:Create(fuelFill, TweenInfo.new(0.35), { Size = UDim2.fromScale(ratio, 1), BackgroundColor3 = if ratio < 0.3 then Color3.fromRGB(255, 112, 78) else COLORS.green }):Play()
	cargoCount.Text = string.format("%d / %d", #nextState.hold, nextState.vessel.capacity)
	holdLabel.Text = fishSummary(nextState.hold)
	collectionLabel.Text = fishSummary(nextState.collection)
	messageLabel.Text = nextState.message
	updateObjectives(nextState)
	updateMiniMap(nextState)
	updateButtons(nextState)

	if not presentation.introDismissed and nextState.round == 0 and nextState.mode == "Docked" then
		intro.Visible = true
		TweenService:Create(introScale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	elseif not presentation.introDismissed then
		dismissIntro(false)
	end

	if previous ~= nil and previous.mode == "AtSchool" and nextState.mode == "ReadyToReturn" then
		showCatchReveal(nextState.hold)
	elseif previous ~= nil and previous.mode == "DockedWithCatch" and nextState.mode == "Docked" then
		local coins = nextState.coins - previous.coins
		local trophies = #nextState.collection - #previous.collection
		showRewardToast(string.format("航次结算完成  ·  +%d 金币  ·  +%d 珍稀收藏", coins, trophies))
	end
end

RunService.RenderStepped:Connect(function(deltaTime)
	presentation.clock += deltaTime
	for _, item in ipairs(presentation.animated) do
		if item.part.Parent ~= nil then
			if item.kind == "wave" then
				item.part.Transparency = 0.68 + math.sin(presentation.clock * 1.4 + item.phase) * 0.1
			elseif item.kind == "radar" then
				item.part.Transparency = 0.5 + math.sin(presentation.clock * 3 + item.phase) * 0.14
			end
		end
	end
end)

local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		uiScale.Scale = math.clamp(camera.ViewportSize.X / 1536, 0.72, 1)
	end
end
updateScale()
if Workspace.CurrentCamera ~= nil then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

stateEvent.OnClientEvent:Connect(render)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or presentation.latestState == nil or presentation.catchOpen or not presentation.introDismissed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.W then
		send("Move", { dx = 0, dz = 1 })
	elseif key == Enum.KeyCode.S then
		send("Move", { dx = 0, dz = -1 })
	elseif key == Enum.KeyCode.A then
		send("Move", { dx = -1, dz = 0 })
	elseif key == Enum.KeyCode.D then
		send("Move", { dx = 1, dz = 0 })
	elseif key == Enum.KeyCode.Q then
		send("Scan")
	elseif key == Enum.KeyCode.F then
		send("Net")
	elseif key == Enum.KeyCode.R then
		send("Return")
	end
end)

commandEvent:FireServer("Sync", {})

end

return start
