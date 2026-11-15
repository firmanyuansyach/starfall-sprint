-- HUD.luau (client) — the always-on layer: a top bar (stage, stars, time,
-- deaths), a progress bar, a centre banner, and a red flash on death. It
-- displays state; it never owns any — StateUpdate is the truth.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local UI = require(script.Parent.UI)

local HUD = {}

local progressFill: Frame
local stageLabel: TextLabel
local starLabel: TextLabel
local timeLabel: TextLabel
local deathLabel: TextLabel
local bannerTitle: TextLabel
local bannerSub: TextLabel
local flash: Frame
local bannerToken = 0

function HUD.Create(gui: ScreenGui)
	local bar = UI.Create("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(600, 46),
		BackgroundColor3 = Color3.fromRGB(12, 12, 22),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = gui,
	})
	UI.Corner(bar, 12)
	UI.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 26),
		Parent = bar,
	})
	local function label(text: string, color: Color3): TextLabel
		return UI.Create("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 46),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = text,
			TextColor3 = color,
			TextSize = 19,
			Parent = bar,
		}) :: TextLabel
	end
	stageLabel = label("STAGE 1 · EMBER RISE", Color3.fromRGB(255, 255, 255))
	starLabel = label("★ 0/" .. Config.TotalStars, Config.Colors.star)
	timeLabel = label("⏱ 00:00.0", Color3.fromRGB(210, 220, 235))
	deathLabel = label("☠ 0", Color3.fromRGB(255, 120, 120))

	-- The run's progress as a slim bar under the top bar: how many of
	-- the course's checkpoints stand behind you, in the stage's trim.
	local track = UI.Create("Frame", {
		Name = "ProgressTrack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(600, 6),
		BackgroundColor3 = Color3.fromRGB(12, 12, 22),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = gui,
	})
	UI.Corner(track, 3)
	progressFill = UI.Create("Frame", {
		Name = "ProgressFill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Config.Stages[1].trim,
		BorderSizePixel = 0,
		Parent = track,
	}) :: Frame
	UI.Corner(progressFill, 3)

	local banner = UI.Create("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		Size = UDim2.fromOffset(700, 110),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	bannerTitle = UI.Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 46,
		TextTransparency = 1,
		Parent = banner,
	}) :: TextLabel
	bannerSub = UI.Create("TextLabel", {
		Position = UDim2.new(0, 0, 0, 62),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "",
		TextColor3 = Config.Colors.star,
		TextSize = 22,
		TextTransparency = 1,
		Parent = banner,
	}) :: TextLabel

	flash = UI.Create("Frame", {
		Name = "DeathFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(210, 30, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = gui,
	}) :: Frame
end

function HUD.SetState(state: { [string]: any })
	local stageCfg = Config.Stages[state.stage]
	local total = #Config.Checkpoints
	local progress = if state.finished then 1 else math.clamp(((state.checkpoint or 1) - 1) / (total - 1), 0, 1)
	progressFill.Size = UDim2.fromScale(progress, 1)
	progressFill.BackgroundColor3 = stageCfg.trim
	stageLabel.Text = string.format("STAGE %d · %s", state.stage, stageCfg.name)
	starLabel.Text = string.format("★ %d/%d", state.stars, state.totalStars)
	deathLabel.Text = "☠ " .. state.deaths
	if not state.running and not state.finished then
		timeLabel.Text = "⏱ 00:00.0"
	end
end

function HUD.Tick(elapsed: number)
	timeLabel.Text = "⏱ " .. Format.Time(elapsed)
end

-- Big centre text that fades in, holds, and fades out. A token guards it
-- so a second banner cleanly replaces one still on screen.
function HUD.Banner(title: string, sub: string, hold: number?)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerSub.Text = sub
	local fadeIn = TweenInfo.new(0.25)
	TweenService:Create(bannerTitle, fadeIn, { TextTransparency = 0 }):Play()
	TweenService:Create(bannerSub, fadeIn, { TextTransparency = 0 }):Play()
	task.spawn(function()
		task.wait(hold or 1.6)
		if token ~= bannerToken then
			return
		end
		local fadeOut = TweenInfo.new(0.4)
		TweenService:Create(bannerTitle, fadeOut, { TextTransparency = 1 }):Play()
		TweenService:Create(bannerSub, fadeOut, { TextTransparency = 1 }):Play()
	end)
end

function HUD.FlashDeath()
	flash.BackgroundTransparency = 0.45
	TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
end

-- The star counter pops so a pickup is felt, not just counted.
function HUD.PopStar()
	local scale = starLabel:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = starLabel
	end
	scale.Scale = 1.4
	TweenService:Create(scale, TweenInfo.new(0.3), { Scale = 1 }):Play()
end

return HUD
