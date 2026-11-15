-- Screens.luau (client) — the two full screens: start (title, how to
-- play, Play, stage select as practice mode) and win (time, stars, deaths,
-- rank). Buttons only report clicks through Main's callbacks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local UI = require(script.Parent.UI)
local Sound = require(script.Parent.Sound)

local Screens = {}

type Callbacks = {
	onPlay: () -> (),
	onStage: (number) -> (),
	onRestart: () -> (),
	onFreeRoam: () -> (),
}

-- The session's best timed finish, kept so the win screen can hold a
-- run up against your own best instead of only the par times.
local bestTime: number? = nil

local startScreen: Frame
local winScreen: Frame
local winStats: TextLabel
local winRank: TextLabel
local winSplits: TextLabel

-- Each screen's card and where it rests, so showing a screen can be a
-- small rise-and-settle instead of a hard cut.
local cardHome: { [Frame]: { card: Frame, position: UDim2 } } = {}

local function showScreen(dim: Frame)
	local home = cardHome[dim]
	dim.Visible = true
	if home then
		home.card.Position = home.position + UDim2.fromOffset(0, 36)
		home.card.BackgroundTransparency = 0.5
		local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(home.card, info, {
			Position = home.position,
			BackgroundTransparency = 0.05,
		}):Play()
	end
end

local function panel(gui: ScreenGui, height: number): Frame
	local dim = UI.Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 6, 14),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = gui,
	}) :: Frame
	local card = UI.Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, height),
		BackgroundColor3 = Color3.fromRGB(15, 15, 27),
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = dim,
	}) :: Frame
	UI.Corner(card, 16)
	UI.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		Parent = card,
	})
	cardHome[dim] = { card = card, position = card.Position }
	return dim
end

local function line(parent: Instance, text: string, size: number, color: Color3, bold: boolean): TextLabel
	return UI.Create("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -32, 0, 0),
		BackgroundTransparency = 1,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
		Text = text,
		TextColor3 = color,
		TextSize = size,
		TextWrapped = true,
		ZIndex = 12,
		Parent = parent,
	}) :: TextLabel
end

function Screens.Create(gui: ScreenGui, callbacks: Callbacks)
	-- Start screen.
	startScreen = panel(gui, 478)
	local card = startScreen:GetChildren()[1]
	line(card, "STARFALL SPRINT", 40, Color3.fromRGB(255, 255, 255), true)
	line(card, "Four stages. Twelve stars. One crown.", 17, Config.Colors.star, false)
	line(
		card,
		"🏃  WASD to move · SPACE to jump · hold RIGHT-CLICK + drag to look · SHIFT = mouse lock",
		15,
		Color3.fromRGB(205, 212, 226),
		false
	)
	line(
		card,
		"⭐  Green pads set your checkpoint. Grab every star you pass.",
		15,
		Color3.fromRGB(205, 212, 226),
		false
	)
	line(
		card,
		"🔥  Cracked floors crumble under you — keep moving. Drone sentinels patrol the course: never let one touch you.",
		15,
		Color3.fromRGB(205, 212, 226),
		false
	)
	line(card, "👑  Climb to the Crown at the top of Stage 4 to finish.", 15, Color3.fromRGB(205, 212, 226), false)
	local play = UI.Button(card, "▶  PLAY — FROM STAGE 1", Color3.fromRGB(42, 158, 88), UDim2.fromOffset(330, 52))
	play.ZIndex = 12
	play.Activated:Connect(function()
		Sound.Play("click")
		Screens.HideStart()
		callbacks.onPlay()
	end)
	local row = UI.Create("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = card,
	})
	UI.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		Parent = row,
	})
	for stage = 1, #Config.Stages do
		local button = UI.Button(row, "STAGE " .. stage, Config.Stages[stage].base, UDim2.fromOffset(104, 40))
		button.ZIndex = 12
		button.Activated:Connect(function()
			Sound.Play("click")
			Screens.HideStart()
			callbacks.onStage(stage)
		end)
	end
	line(
		card,
		"Stage buttons are practice mode — a ranked run starts at Stage 1.",
		13,
		Color3.fromRGB(150, 158, 175),
		false
	)

	-- Win screen, hidden until the crown is claimed.
	winScreen = panel(gui, 450)
	local winCard = winScreen:GetChildren()[1]
	line(winCard, "👑 CROWN CLAIMED!", 34, Config.Colors.win, true)
	winRank = line(winCard, "", 26, Color3.fromRGB(255, 255, 255), true)
	winStats = line(winCard, "", 18, Color3.fromRGB(205, 212, 226), false)
	winSplits = line(winCard, "", 15, Color3.fromRGB(150, 158, 175), false)
	local again = UI.Button(winCard, "↻  PLAY AGAIN", Color3.fromRGB(42, 158, 88), UDim2.fromOffset(240, 48))
	again.ZIndex = 12
	again.Activated:Connect(function()
		Sound.Play("click")
		Screens.HideWin()
		callbacks.onRestart()
	end)
	local roam = UI.Button(winCard, "FREE ROAM", Color3.fromRGB(70, 70, 95), UDim2.fromOffset(240, 44))
	roam.ZIndex = 12
	roam.Activated:Connect(function()
		Sound.Play("click")
		Screens.HideWin()
		callbacks.onFreeRoam()
	end)
	winScreen.Visible = false
end

function Screens.ShowStart()
	showScreen(startScreen)
end

function Screens.HideStart()
	startScreen.Visible = false
end

function Screens.ShowWin(state: { [string]: any })
	if state.finishElapsed then
		if bestTime == nil or state.finishElapsed < bestTime then
			bestTime = state.finishElapsed
		end
		winRank.Text =
			Format.Rank(state.finishElapsed, state.stars, state.startStage, Config.ParTimes, Config.TotalStars)
		winStats.Text = string.format(
			"Time  %s      ★  %d/%d      ☠  %d deaths\nSession best  %s",
			Format.Time(state.finishElapsed),
			state.stars,
			state.totalStars,
			state.deaths,
			Format.Time(bestTime)
		)
		-- The splits: when this run first reached each later stage, so a
		-- climber can see which stage ate their time.
		local splits = state.splits or {}
		local parts = {}
		for stage = 2, #Config.Stages do
			if splits[stage] then
				table.insert(parts, "Stage " .. stage .. " · " .. Format.Time(splits[stage]))
			end
		end
		winSplits.Text = if #parts > 0 then "Splits — " .. table.concat(parts, "    ") else ""
	else
		-- The crown reached without a timer: a free climb, named as one.
		winRank.Text = "FREE CLIMB"
		winStats.Text = string.format(
			"No timer was running.      ★  %d/%d      ☠  %d deaths",
			state.stars,
			state.totalStars,
			state.deaths
		)
		winSplits.Text = ""
	end
	showScreen(winScreen)
end

function Screens.HideWin()
	winScreen.Visible = false
end

return Screens
