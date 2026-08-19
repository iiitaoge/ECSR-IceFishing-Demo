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
	Searching = "雷达探索",
	ReadyToReturn = "准备返港",
	Returning = "返航中",
	DockedWithCatch = "港口结算",
}

local OBJECTIVES = {
	"01  出航",
	"02  雷达寻找",
	"03  发现鱼群",
	"04  按 E 获取",
	"05  回港出售",
	"06  升级货舱",
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

local oldEffects = Workspace:FindFirstChild("ECSRFishingEffects")
if oldEffects ~= nil then
	oldEffects:Destroy()
end
local effects = Instance.new("Folder")
effects.Name = "ECSRFishingEffects"
effects.Parent = Workspace

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

local objectiveRail = panel("ObjectiveRail", UDim2.new(0.5, -425, 0, 20), UDim2.fromOffset(850, 52))
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
	pill.Size = UDim2.fromOffset(if index == 6 then 132 else 112, 32)
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
local fuelLabel = textLabel("Fuel", "破冰燃料", UDim2.fromOffset(17, 47), UDim2.new(0.52, -17, 0, 18), resources, Enum.Font.GothamMedium, 11)
fuelLabel.TextColor3 = COLORS.muted
local cargoLevelLabel = textLabel("CargoLevel", "货舱 Lv.0", UDim2.new(0.52, 0, 0, 47), UDim2.new(0.48, -17, 0, 18), resources, Enum.Font.GothamBold, 11)
cargoLevelLabel.TextXAlignment = Enum.TextXAlignment.Right
cargoLevelLabel.TextColor3 = COLORS.cyan
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
local cargoCount = textLabel("CargoCount", "0 / 7", UDim2.new(0.5, 0, 0, 10), UDim2.new(0.5, -17, 0, 22), cargoPanel, Enum.Font.GothamBold, 13)
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
local mapHint = textLabel("MapHint", "雷达锁定未发现鱼群 · 彩色为已发现", UDim2.fromOffset(15, 32), UDim2.new(1, -30, 0, 18), mapPanel, Enum.Font.Gotham, 10)
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

local radarPanel = panel("Radar", UDim2.new(1, -250, 1, -320), UDim2.fromOffset(228, 160))
local radarTitle = textLabel("RadarTitle", "雷达 · 未发现鱼群", UDim2.fromOffset(15, 10), UDim2.new(1, -30, 0, 22), radarPanel, Enum.Font.GothamBold, 13)
radarTitle.TextColor3 = COLORS.cyan
local radarDisc = Instance.new("Frame")
radarDisc.Position = UDim2.fromOffset(15, 43)
radarDisc.Size = UDim2.fromOffset(92, 92)
radarDisc.BackgroundColor3 = Color3.fromRGB(12, 72, 83)
radarDisc.BackgroundTransparency = 0.12
radarDisc.Parent = radarPanel
rounded(radarDisc, 46)
stroke(radarDisc, COLORS.cyan, 1.2, 0.2)
local radarCrossH = Instance.new("Frame")
radarCrossH.AnchorPoint = Vector2.new(0.5, 0.5)
radarCrossH.Position = UDim2.fromScale(0.5, 0.5)
radarCrossH.Size = UDim2.new(1, -14, 0, 1)
radarCrossH.BackgroundColor3 = COLORS.cyan
radarCrossH.BackgroundTransparency = 0.65
radarCrossH.Parent = radarDisc
local radarCrossV = Instance.new("Frame")
radarCrossV.AnchorPoint = Vector2.new(0.5, 0.5)
radarCrossV.Position = UDim2.fromScale(0.5, 0.5)
radarCrossV.Size = UDim2.new(0, 1, 1, -14)
radarCrossV.BackgroundColor3 = COLORS.cyan
radarCrossV.BackgroundTransparency = 0.65
radarCrossV.Parent = radarDisc
local radarNeedle = Instance.new("Frame")
radarNeedle.AnchorPoint = Vector2.new(0.5, 1)
radarNeedle.Position = UDim2.fromScale(0.5, 0.5)
radarNeedle.Size = UDim2.fromOffset(3, 33)
radarNeedle.BackgroundColor3 = COLORS.green
radarNeedle.Visible = false
radarNeedle.Parent = radarDisc
local radarDot = Instance.new("Frame")
radarDot.AnchorPoint = Vector2.new(0.5, 0.5)
radarDot.Position = UDim2.fromScale(0.5, 0.5)
radarDot.Size = UDim2.fromOffset(10, 10)
radarDot.BackgroundColor3 = COLORS.green
radarDot.Parent = radarDisc
rounded(radarDot, 5)
local radarDistanceLabel = textLabel("RadarDistance", "暂无目标", UDim2.fromOffset(120, 48), UDim2.new(1, -132, 0, 28), radarPanel, Enum.Font.GothamBold, 15)
radarDistanceLabel.TextColor3 = COLORS.white
local radarDirectionLabel = textLabel("RadarDirection", "探索航区后自动锁定", UDim2.fromOffset(120, 78), UDim2.new(1, -132, 0, 24), radarPanel, Enum.Font.Gotham, 11)
radarDirectionLabel.TextColor3 = COLORS.muted
radarDirectionLabel.TextWrapped = true
local radarStrengthLabel = textLabel("RadarStrength", "信号强度  --", UDim2.fromOffset(120, 108), UDim2.new(1, -132, 0, 22), radarPanel, Enum.Font.GothamMedium, 11)
radarStrengthLabel.TextColor3 = COLORS.green

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
actionLayout.CellSize = UDim2.fromOffset(140, 44)
actionLayout.FillDirectionMaxCells = 6
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
makeButton("North", "向北  [W]", "Move", { dx = 0, dz = 1 }, 2)
makeButton("West", "向西  [A]", "Move", { dx = -1, dz = 0 }, 3)
makeButton("East", "向东  [D]", "Move", { dx = 1, dz = 0 }, 4)
makeButton("South", "向南  [S]", "Move", { dx = 0, dz = -1 }, 5)
makeButton("Collect", "获取鱼群  [E]", "Collect", nil, 6, Color3.fromRGB(25, 145, 126))
makeButton("Return", "返港出售  [R]", "Return", nil, 7, Color3.fromRGB(164, 111, 36))
makeButton("SellAll", "出售货舱", "SellAll", nil, 8, Color3.fromRGB(173, 111, 28))
makeButton("KeepRare", "收藏珍稀鱼", "KeepRare", nil, 9, Color3.fromRGB(124, 69, 177))
makeButton("UpgradeCargo", "升级货舱", "UpgradeCargo", nil, 10, Color3.fromRGB(37, 104, 179))

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
local introTitle = textLabel("IntroTitle", "雷达，找到一片片鱼群", UDim2.fromOffset(36, 58), UDim2.new(1, -72, 0, 58), introCard, Enum.Font.GothamBold, 36)
introTitle.ZIndex = 102
local introBody = textLabel("IntroBody", "航区里会同时生成多个鱼群。看右下角雷达探索，进入发现范围后按 E 获取；货舱装满就沿破开的航道返港出售，再升级货舱继续下一轮。", UDim2.fromOffset(36, 120), UDim2.new(1, -72, 0, 62), introCard, Enum.Font.Gotham, 15)
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
	{ "01", "雷达", "自动指向最近鱼群" },
	{ "02", "探索", "航行并撞开浮冰" },
	{ "03", "发现", "靠近显示价值" },
	{ "04", "获取", "按 E 占用一个货舱格" },
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

local function createOcean(bounds)
	local columns = bounds.maxX - bounds.minX + 1
	local rows = bounds.maxZ - bounds.minZ + 1
	local centerX = (bounds.minX + bounds.maxX) * CELL_SIZE * 0.5
	local centerZ = (bounds.minZ + bounds.maxZ) * CELL_SIZE * 0.5
	local oceanWidth = columns * CELL_SIZE + 24
	local oceanDepth = rows * CELL_SIZE + 24
	part("OceanDeep", Vector3.new(oceanWidth, 2.5, oceanDepth), CFrame.new(centerX, -2.4, centerZ), Color3.fromRGB(15, 91, 128), Enum.Material.Glass, 0.08)
	part("OceanSurface", Vector3.new(oceanWidth - 4, 0.18, oceanDepth - 4), CFrame.new(centerX, -0.82, centerZ), Color3.fromRGB(39, 144, 178), Enum.Material.Glass, 0.28)
	local waveCount = math.max(14, rows * 2)
	local waveStartZ = centerZ - oceanDepth * 0.5 + 7
	local waveStep = (oceanDepth - 14) / (waveCount + 1)
	for index = 1, waveCount do
		local z = waveStartZ + index * waveStep
		local wave = part(
			"Wave",
			Vector3.new(oceanWidth - 22 - (index % 3) * 7, 0.08, 0.22),
			CFrame.new(centerX + (index % 2) * 3 - 1.5, -0.58, z),
			Color3.fromRGB(185, 235, 246),
			Enum.Material.Neon,
			0.72
		)
		table.insert(presentation.animated, { kind = "wave", part = wave, phase = index * 0.45 })
	end
	local icebergCount = math.max(8, math.floor(rows * 0.9))
	local icebergStep = (oceanDepth - 18) / (icebergCount + 1)
	for index = 1, icebergCount do
		local side = if index % 2 == 0 then -1 else 1
		local x = centerX + side * (oceanWidth * 0.5 - 6 - (index % 3) * 1.8)
		local z = centerZ - oceanDepth * 0.5 + 9 + index * icebergStep
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

local FISH_STYLES: { [string]: { body: Color3, accent: Color3, length: number, width: number } } = {
	IceHerring = {
		body = Color3.fromRGB(132, 201, 218),
		accent = Color3.fromRGB(226, 248, 250),
		length = 2.05,
		width = 0.72,
	},
	ArcticCod = {
		body = Color3.fromRGB(73, 142, 177),
		accent = Color3.fromRGB(168, 224, 232),
		length = 2.35,
		width = 0.92,
	},
	AuroraSalmon = {
		body = Color3.fromRGB(66, 142, 225),
		accent = Color3.fromRGB(224, 101, 210),
		length = 2.45,
		width = 0.82,
	},
	CrystalHalibut = {
		body = Color3.fromRGB(174, 111, 231),
		accent = Color3.fromRGB(218, 240, 255),
		length = 2.1,
		width = 1.25,
	},
}

local function createFishModel(name: string, fish, scale: number, parent: Instance): Model
	local style = FISH_STYLES[fish.species] or FISH_STYLES.IceHerring
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local body = part(
		"Body",
		Vector3.new(style.width, 0.68, style.length) * scale,
		CFrame.new(),
		style.body,
		Enum.Material.SmoothPlastic,
		0,
		model
	)
	body.Shape = Enum.PartType.Ball
	local belly = part(
		"Belly",
		Vector3.new(style.width * 0.7, 0.22, style.length * 0.68) * scale,
		CFrame.new(0, -0.27 * scale, -0.05 * scale),
		style.accent,
		Enum.Material.SmoothPlastic,
		0.12,
		model
	)
	belly.Shape = Enum.PartType.Ball
	part(
		"SpineGlow",
		Vector3.new(style.width * 0.22, 0.08, style.length * 0.7) * scale,
		CFrame.new(0, 0.35 * scale, 0),
		style.accent,
		Enum.Material.Neon,
		0.18,
		model
	)

	for side = -1, 1, 2 do
		part(
			"TailFin",
			Vector3.new(0.52, 0.12, 0.88) * scale,
			CFrame.new(side * 0.25 * scale, 0, style.length * 0.58 * scale)
				* CFrame.Angles(0, math.rad(side * 34), math.rad(side * 8)),
			style.accent,
			Enum.Material.SmoothPlastic,
			0.04,
			model,
			"WedgePart"
		)
		part(
			"SideFin",
			Vector3.new(0.38, 0.1, 0.62) * scale,
			CFrame.new(side * style.width * 0.5 * scale, -0.02 * scale, 0.08 * scale)
				* CFrame.Angles(0, math.rad(side * 42), math.rad(-side * 8)),
			style.accent,
			Enum.Material.SmoothPlastic,
			0.08,
			model,
			"WedgePart"
		)
		local eye = part(
			"Eye",
			Vector3.new(0.13, 0.13, 0.13) * scale,
			CFrame.new(side * style.width * 0.36 * scale, 0.23 * scale, -style.length * 0.34 * scale),
			Color3.fromRGB(8, 23, 31),
			Enum.Material.SmoothPlastic,
			0,
			model
		)
		eye.Shape = Enum.PartType.Ball
	end

	part(
		"DorsalFin",
		Vector3.new(0.16, 0.5, 0.62) * scale,
		CFrame.new(0, 0.48 * scale, 0.16 * scale) * CFrame.Angles(math.rad(-10), 0, 0),
		style.accent,
		Enum.Material.SmoothPlastic,
		0.05,
		model,
		"WedgePart"
	)
	model.PrimaryPart = body
	return model
end

local function createFishSchool(x: number, z: number, school)
	local stock = school.stock or 1
	local tier = school.tier or 0
	local origin = worldPosition(x, z, -0.42)
	local schoolColor = if school.rarity == "Epic"
		then COLORS.epic
		elseif school.rarity == "Rare"
		then COLORS.rare
		else COLORS.cyan
	local fishCount = math.clamp(math.max(4, stock * 2), 4, 7)
	for index = 1, fishCount do
		local phase = (index / fishCount) * math.pi * 2
		local radius = 1.25 + (index % 3) * 0.52
		local fishModel = createFishModel(
			"SchoolFish",
			school,
			0.62 + (index % 3) * 0.06,
			scene
		)
		local position = origin + Vector3.new(math.cos(phase) * radius, (index % 2) * 0.16, math.sin(phase) * radius * 0.68)
		local tangent = Vector3.new(-math.sin(phase), 0, math.cos(phase) * 0.68).Unit
		fishModel:PivotTo(CFrame.lookAt(position, position + tangent))
		table.insert(presentation.animated, {
			kind = "fish",
			model = fishModel,
			center = origin,
			phase = phase,
			radius = radius,
			speed = 0.42 + (index % 3) * 0.07,
		})
	end
	for index = 1, 5 do
		local bubble = part("Bubble", Vector3.new(0.25, 0.25, 0.25), CFrame.new(origin + Vector3.new((index - 3) * 0.7, 0.4 + index * 0.18, (index % 2) * 0.6)), COLORS.white, Enum.Material.Glass, 0.25)
		bubble.Shape = Enum.PartType.Ball
	end
	local marker = part("SchoolMarker", Vector3.new(0.3, 0.3, 0.3), CFrame.new(worldPosition(x, z, 1.1)), schoolColor, Enum.Material.Neon, 0.15)
	local displayName = school.displayName
	if displayName == nil then
		displayName = if tier > 0 then string.format("%d 级外海鱼群", tier) else "鱼群"
	end
	billboard(marker, string.format("%s · %d 金 · 按 E", displayName, school.value or 0), schoolColor)
end

local function playAndDestroy(object: Instance, tween)
	tween.Completed:Connect(function()
		if object.Parent ~= nil then
			object:Destroy()
		end
	end)
	tween:Play()
end

local function createWaterRipple(center: Vector3, delayTime: number, diameter: number)
	task.delay(delayTime, function()
		if effects.Parent == nil then
			return
		end
		local ripple = part(
			"IceBreakRipple",
			Vector3.new(0.06, 2.2, 2.2),
			CFrame.new(center + Vector3.new(0, -0.7, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(206, 247, 255),
			Enum.Material.Neon,
			0.28,
			effects
		)
		ripple.Shape = Enum.PartType.Cylinder
		playAndDestroy(ripple, TweenService:Create(
			ripple,
			TweenInfo.new(0.82, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = Vector3.new(0.03, diameter, diameter),
				Transparency = 1,
			}
		))
	end)
end

local function createSplashDroplets(center: Vector3)
	for index = 1, 11 do
		local angle = (index / 11) * math.pi * 2 + 0.24
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local radius = 0.16 + (index % 3) * 0.055
		local droplet = part(
			"IceBreakDroplet",
			Vector3.new(radius, radius * 1.7, radius),
			CFrame.new(center + direction * 0.8 - Vector3.new(0, 0.35, 0)),
			Color3.fromRGB(211, 249, 255),
			Enum.Material.Glass,
			0.08,
			effects
		)
		droplet.Shape = Enum.PartType.Ball
		local apex = center + direction * (2.1 + (index % 4) * 0.35) + Vector3.new(0, 1.5 + (index % 3) * 0.42, 0)
		local rise = TweenService:Create(
			droplet,
			TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = apex }
		)
		rise.Completed:Connect(function()
			if droplet.Parent == nil then
				return
			end
			local landing = center + direction * (3.4 + (index % 4) * 0.42) - Vector3.new(0, 1.25, 0)
			playAndDestroy(droplet, TweenService:Create(
				droplet,
				TweenInfo.new(0.46, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = landing,
					Transparency = 1,
					Size = Vector3.new(radius * 0.45, radius * 0.7, radius * 0.45),
				}
			))
		end)
		rise:Play()
	end
end

local function createSinkingIce(center: Vector3)
	local pieces = {
		{ offset = Vector3.new(-2.05, 0, -1.8), size = Vector3.new(3.65, 0.68, 3.15), yaw = -0.10, pitch = -0.34, roll = 0.21 },
		{ offset = Vector3.new(1.85, 0, -2.0), size = Vector3.new(3.35, 0.68, 3.5), yaw = 0.13, pitch = -0.25, roll = -0.30 },
		{ offset = Vector3.new(-1.85, 0, 1.75), size = Vector3.new(3.4, 0.68, 3.25), yaw = 0.08, pitch = 0.31, roll = 0.25 },
		{ offset = Vector3.new(2.0, 0, 1.8), size = Vector3.new(3.55, 0.68, 3.2), yaw = -0.14, pitch = 0.27, roll = -0.23 },
		{ offset = Vector3.new(0, 0.08, 0), size = Vector3.new(2.15, 0.72, 2.25), yaw = 0.28, pitch = 0.42, roll = 0.16 },
	}

	for index, definition in ipairs(pieces) do
		local outward = Vector3.new(definition.offset.X, 0, definition.offset.Z)
		if outward.Magnitude < 0.1 then
			outward = Vector3.new(0.25, 0, -1)
		else
			outward = outward.Unit
		end
		local startCFrame = CFrame.new(center + definition.offset) * CFrame.Angles(0, definition.yaw, 0)
		local slab = part(
			"SinkingIceSlab",
			definition.size,
			startCFrame,
			Color3.fromRGB(202, 234, 244),
			Enum.Material.Glacier,
			0,
			effects
		)
		local kickCFrame = startCFrame
			* CFrame.new(outward.X * 0.32, 0.18 + (index % 2) * 0.08, outward.Z * 0.32)
			* CFrame.Angles(definition.pitch * 0.32, definition.yaw * 0.4, definition.roll * 0.32)
		local kick = TweenService:Create(
			slab,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = kickCFrame }
		)
		kick.Completed:Connect(function()
			if slab.Parent == nil then
				return
			end
			local sinkCFrame = kickCFrame
				* CFrame.new(outward.X * 0.7, -4.5 - index * 0.18, outward.Z * 0.7)
				* CFrame.Angles(definition.pitch, definition.yaw, definition.roll)
			playAndDestroy(slab, TweenService:Create(
				slab,
				TweenInfo.new(1.12 + index * 0.055, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					CFrame = sinkCFrame,
					Color = Color3.fromRGB(94, 169, 195),
					Transparency = 1,
				}
			))
		end)
		kick:Play()
	end
end

local function createIceBreakBurst(x: number, z: number)
	local center = worldPosition(x, z, 0.22)
	createSinkingIce(center)
	createSplashDroplets(center)
	createWaterRipple(center, 0, 8.5)
	createWaterRipple(center, 0.14, 12.5)

	local flash = part(
		"IceBreakFlash",
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(center + Vector3.new(0, 0.25, 0)),
		Color3.fromRGB(225, 251, 255),
		Enum.Material.Neon,
		0.18,
		effects
	)
	flash.Shape = Enum.PartType.Ball
	playAndDestroy(flash, TweenService:Create(
		flash,
		TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(5.2, 2.1, 5.2),
			Transparency = 1,
		}
	))

	for index = 1, 9 do
		local angle = (index / 9) * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local shard = part(
			"IceShard",
			Vector3.new(0.65 + (index % 3) * 0.18, 0.22 + (index % 2) * 0.08, 0.9 + (index % 4) * 0.18),
			CFrame.new(center + direction * 0.9) * CFrame.Angles(0, angle, 0),
			Color3.fromRGB(220, 244, 250),
			Enum.Material.Glacier,
			0,
			effects
		)
		local apex = center + direction * (3.2 + (index % 3) * 0.55) + Vector3.new(0, 1.6 + (index % 2) * 0.7, 0)
		local burst = TweenService:Create(
			shard,
			TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = apex,
				Orientation = Vector3.new(index * 23, index * 41, index * 17),
			}
		)
		burst.Completed:Connect(function()
			if shard.Parent == nil then
				return
			end
			local landing = center + direction * (4.1 + (index % 3) * 0.65) - Vector3.new(0, 2.4, 0)
			playAndDestroy(shard, TweenService:Create(
				shard,
				TweenInfo.new(0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = landing,
					Orientation = Vector3.new(index * 61, index * 79, index * 43),
					Transparency = 1,
				}
			))
		end)
		burst:Play()
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

local function createCatchHaul(x: number, z: number, fish, vessel)
	local haul = Instance.new("Model")
	haul.Name = "CatchHaulRig"
	haul.Parent = effects
	local anchor = part(
		"CatchHaulRoot",
		Vector3.new(0.15, 0.15, 0.15),
		CFrame.new(),
		COLORS.cyan,
		Enum.Material.Neon,
		1,
		haul
	)
	haul.PrimaryPart = anchor

	local ropeColor = Color3.fromRGB(195, 221, 214)
	local function netLine(name: string, from: Vector3, to: Vector3, width: number)
		local distance = (to - from).Magnitude
		part(
			name,
			Vector3.new(width, width, distance),
			CFrame.lookAt((from + to) * 0.5, to),
			ropeColor,
			Enum.Material.Fabric,
			0.08,
			haul
		)
	end

	local corners = {
		Vector3.new(-1.35, 0, -1.35),
		Vector3.new(1.35, 0, -1.35),
		Vector3.new(1.35, 0, 1.35),
		Vector3.new(-1.35, 0, 1.35),
	}
	for index, corner in ipairs(corners) do
		local nextCorner = corners[(index % #corners) + 1]
		netLine("NetHoop", corner, nextCorner, 0.11)
		netLine("NetBasket", corner, Vector3.new(0, -1.35, 0), 0.065)
		netLine("NetRope", corner, Vector3.new(0, 2.25, 0), 0.07)
	end
	netLine("HoistCable", Vector3.new(0, 2.25, 0), Vector3.new(0, 4.3, 0), 0.09)

	for index = 1, 3 do
		local caughtFish = createFishModel("CaughtFish", fish, 0.48 + index * 0.025, haul)
		caughtFish:PivotTo(
			CFrame.new((index - 2) * 0.64, -0.52 - (index % 2) * 0.22, (index % 2) * 0.5 - 0.25)
				* CFrame.Angles(math.rad(index * 11), math.rad(60 + index * 47), math.rad(index * 8))
		)
	end

	local source = worldPosition(x, z, -0.28)
	local destination = boatPivot(vessel) * CFrame.new(0, 3.0, 3.05)
	haul:PivotTo(CFrame.new(source))
	createWaterRipple(source, 0.02, 7.2)

	local driver = Instance.new("CFrameValue")
	driver.Value = CFrame.new(source)
	driver.Parent = haul
	local connection = driver:GetPropertyChangedSignal("Value"):Connect(function()
		if haul.Parent ~= nil then
			haul:PivotTo(driver.Value)
		end
	end)
	local lift = TweenService:Create(
		driver,
		TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = CFrame.new(source + Vector3.new(0, 5.2, 0)) * CFrame.Angles(0, math.rad(-8), math.rad(4)) }
	)
	lift.Completed:Connect(function()
		if haul.Parent == nil or driver.Parent == nil then
			connection:Disconnect()
			return
		end
		local land = TweenService:Create(
			driver,
			TweenInfo.new(0.72, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
			{ Value = destination * CFrame.Angles(0, math.rad(12), math.rad(-5)) }
		)
		land.Completed:Connect(function()
			connection:Disconnect()
			if driver.Parent ~= nil then
				driver:Destroy()
			end
			for _, descendant in ipairs(haul:GetDescendants()) do
				if descendant:IsA("BasePart") then
					TweenService:Create(
						descendant,
						TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{ Transparency = 1 }
					):Play()
				end
			end
			task.delay(0.3, function()
				if haul.Parent ~= nil then
					haul:Destroy()
				end
			end)
		end)
		land:Play()
	end)
	lift:Play()
end

local function createBoat(vessel, previousVessel, hold)
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
	for index, fish in ipairs(hold or {}) do
		if index > 7 then
			break
		end
		local column = (index - 1) % 3
		local row = math.floor((index - 1) / 3)
		local cargoFish = createFishModel("CargoFish", fish, 0.27, model)
		cargoFish:PivotTo(
			CFrame.new((column - 1) * 1.02, 2.18 + row * 0.05, 2.55 + row * 0.76)
				* CFrame.Angles(math.rad(-6), math.rad(82 + index * 7), math.rad((index % 2) * 8 - 4))
		)
	end
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

local function removedSchoolCell(previous, nextState)
	local currentCells = cellMap(nextState)
	for _, cell in ipairs(previous.cells) do
		local current = currentCells[tostring(cell.x) .. ":" .. tostring(cell.z)]
		if cell.school ~= nil and (current == nil or current.school == nil) then
			return cell
		end
	end
	return nil
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
	if state.mode == "Docked" then return if state.round == 0 then 1 else 6 end
	if state.mode == "Searching" then
		if state.nearbySchool ~= nil then return 4 end
		return 2
	end
	if state.mode == "ReadyToReturn" or state.mode == "Returning" or state.mode == "DockedWithCatch" then return 5 end
	return 6
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
	local bounds = state.bounds or { minX = -5, maxX = 5, minZ = 0, maxZ = 10 }
	local columns = bounds.maxX - bounds.minX + 1
	local rows = bounds.maxZ - bounds.minZ + 1
	local gap = 2
	local tileSize = math.max(12, math.floor((196 - gap * (math.max(columns, rows) - 1)) / math.max(columns, rows)))
	for _, cell in ipairs(state.cells) do
		local tile = Instance.new("Frame")
		tile.Name = tostring(cell.x) .. ":" .. tostring(cell.z)
		tile.Position = UDim2.fromOffset(
			4 + (cell.x - bounds.minX) * (tileSize + gap),
			4 + (bounds.maxZ - cell.z) * (tileSize + gap)
		)
		tile.Size = UDim2.fromOffset(tileSize, tileSize)
		tile.BorderSizePixel = 0
		tile.BackgroundColor3 = if cell.isPort
			then COLORS.gold
			elseif cell.ice
			then if cell.ice > 1 then Color3.fromRGB(112, 166, 190) else Color3.fromRGB(199, 230, 239)
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
			stroke(tile, if cell.school.rarity == "Epic" then COLORS.epic elseif cell.school.rarity == "Rare" then COLORS.rare else COLORS.green, 2, 0)
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
	buttons.North.Visible = mode == "Searching" or mode == "ReadyToReturn" or mode == "Returning"
	buttons.West.Visible = buttons.North.Visible
	buttons.East.Visible = buttons.North.Visible
	buttons.South.Visible = buttons.North.Visible
	buttons.Collect.Visible = mode == "Searching" and state.nearbySchool ~= nil
	buttons.Collect.Active = buttons.Collect.Visible
	buttons.Collect.Text = if state.nearbySchool ~= nil
		then string.format("获取鱼群  [E]  %d金", state.nearbySchool.value)
		else "获取鱼群  [E]"
	buttons.Return.Visible = (mode == "Searching" or mode == "ReadyToReturn") and #state.hold > 0
	buttons.SellAll.Visible = mode == "DockedWithCatch"
	buttons.KeepRare.Visible = mode == "DockedWithCatch"
	local cargoUpgrade = state.cargoUpgrade
	local canCargoUpgrade = cargoUpgrade.cargoLevel < cargoUpgrade.maxCargoLevel
	buttons.UpgradeCargo.Visible = mode == "Docked"
	buttons.UpgradeCargo.Active = canCargoUpgrade
	buttons.UpgradeCargo.AutoButtonColor = canCargoUpgrade
	buttons.UpgradeCargo.Text = if canCargoUpgrade
		then string.format("升级货舱  %d 金", cargoUpgrade.nextCargoCost)
		else "货舱已满级"
	buttons.UpgradeCargo.BackgroundColor3 = if canCargoUpgrade then Color3.fromRGB(37, 104, 179) else Color3.fromRGB(57, 75, 84)
end

local function updateRadar(state)
	local radar = state.radar
	if radar == nil or radar.target == nil then
		radarTitle.Text = "雷达 · 暂无目标"
		radarDistanceLabel.Text = "暂无目标"
		radarDirectionLabel.Text = if state.schoolsRemaining == 0 then "本轮鱼群已全部获取" else "探索航区后自动锁定"
		radarStrengthLabel.Text = "信号强度  --"
		radarDot.BackgroundTransparency = 0.35
		radarNeedle.Visible = false
		return
	end
	local intensity = math.clamp(radar.intensity or 0, 0, 1)
	radarTitle.Text = string.format("雷达 · %d 个未发现", radar.remaining or 0)
	radarDistanceLabel.Text = string.format("距离目标 %d 格", radar.distance or 0)
	radarDirectionLabel.Text = "方向  " .. tostring(radar.direction or "未知")
	radarStrengthLabel.Text = string.format("信号强度  %d%%", math.floor(intensity * 100 + 0.5))
	radarDot.BackgroundTransparency = 0.75 - intensity * 0.7
	radarNeedle.Visible = true
	radarNeedle.Rotation = math.deg(math.atan2(radar.target.z - state.vessel.z, radar.target.x - state.vessel.x))
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

	createOcean(nextState.bounds or { minX = -5, maxX = 5, minZ = 0, maxZ = 10 })
	createPort()
	for _, cell in ipairs(nextState.cells) do
		local base = worldPosition(cell.x, cell.z, -0.58)
		part("SeaGrid", Vector3.new(9.2, 0.08, 9.2), CFrame.new(base), Color3.fromRGB(54, 151, 184), Enum.Material.Glass, 0.58)
		if cell.ice then createIceFloe(cell) end
		if cell.signal ~= nil then createBirds(cell.x, cell.z) end
		if cell.school ~= nil and cell.school.stock > 0 then createFishSchool(cell.x, cell.z, cell.school) end
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
	createBoat(nextState.vessel, if previous ~= nil then previous.vessel else nil, nextState.hold)
	if previous ~= nil and #nextState.hold > #previous.hold then
		local fish = nextState.hold[#nextState.hold]
		local sourceCell = removedSchoolCell(previous, nextState)
		createCatchHaul(
			if sourceCell ~= nil then sourceCell.x else previous.vessel.x,
			if sourceCell ~= nil then sourceCell.z else previous.vessel.z,
			fish,
			nextState.vessel
		)
	end
	updateCamera(nextState)

	modeLabel.Text = (MODE_NAMES[nextState.mode] or nextState.mode) .. "  ·  ECSR TICK " .. tostring(nextState.tick)
	coinLabel.Text = "金币  " .. tostring(nextState.coins)
	roundLabel.Text = "航次  " .. tostring(nextState.round)
	fuelLabel.Text = string.format("破冰燃料  %d / %d", nextState.vessel.fuel, nextState.vessel.maxFuel)
	cargoLevelLabel.Text = string.format(
		"货舱 Lv.%d / %d",
		nextState.cargoUpgrade.cargoLevel,
		nextState.cargoUpgrade.maxCargoLevel
	)
	local ratio = math.clamp(nextState.vessel.fuel / math.max(1, nextState.vessel.maxFuel), 0, 1)
	TweenService:Create(fuelFill, TweenInfo.new(0.35), { Size = UDim2.fromScale(ratio, 1), BackgroundColor3 = if ratio < 0.3 then Color3.fromRGB(255, 112, 78) else COLORS.green }):Play()
	cargoCount.Text = string.format("%d / %d", #nextState.hold, nextState.vessel.capacity)
	holdLabel.Text = fishSummary(nextState.hold)
	collectionLabel.Text = fishSummary(nextState.collection)
	messageLabel.Text = nextState.message
	updateObjectives(nextState)
	updateMiniMap(nextState)
	updateRadar(nextState)
	updateButtons(nextState)

	if not presentation.introDismissed and nextState.round == 0 and nextState.mode == "Docked" then
		intro.Visible = true
		TweenService:Create(introScale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	elseif not presentation.introDismissed then
		dismissIntro(false)
	end

	if previous ~= nil and #nextState.hold > #previous.hold then
		local fish = nextState.hold[#nextState.hold]
		showRewardToast(string.format("获取鱼群  ·  %s  ·  %d 金币", fish.displayName, fish.value))
	elseif previous ~= nil and previous.mode == "DockedWithCatch" and nextState.mode == "Docked" then
		local coins = nextState.coins - previous.coins
		local trophies = #nextState.collection - #previous.collection
		showRewardToast(string.format("航次结算完成  ·  +%d 金币  ·  +%d 珍稀收藏", coins, trophies))
	end
end

RunService.RenderStepped:Connect(function(deltaTime)
	presentation.clock += deltaTime
	for _, item in ipairs(presentation.animated) do
		if item.kind == "fish" then
			if item.model.Parent ~= nil then
				local angle = presentation.clock * item.speed + item.phase
				local position = item.center + Vector3.new(
					math.cos(angle) * item.radius,
					math.sin(presentation.clock * 1.8 + item.phase) * 0.18,
					math.sin(angle) * item.radius * 0.68
				)
				local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle) * 0.68).Unit
				item.model:PivotTo(CFrame.lookAt(position, position + tangent))
			end
		elseif item.part.Parent ~= nil then
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
	elseif key == Enum.KeyCode.E then
		send("Collect")
	elseif key == Enum.KeyCode.R then
		send("Return")
	end
end)

commandEvent:FireServer("Sync", {})

end

return start
