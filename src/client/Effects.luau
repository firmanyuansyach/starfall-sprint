-- Effects.luau (client) — everything felt rather than read: the lighting
-- mood per stage, a camera shake on death, and the per-player look of
-- progress (your claimed pads glow, your stars vanish) — cosmetic copies
-- of state the server owns.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Effects = {}

local worldFolder: Folder? = nil
local currentStage = 0
local shake = 0
local claimed: { [number]: boolean } = {}

function Effects.Init()
	-- If this client is ever early, keep looking for the world folder
	-- instead of silently losing every pad/star visual.
	task.spawn(function()
		for _ = 1, 45 do
			worldFolder = Workspace:FindFirstChild("StarfallWorld") :: Folder?
			if worldFolder then
				return
			end
			task.wait(2)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if shake <= 0 then
			return
		end
		shake = math.max(0, shake - dt)
		local camera = Workspace.CurrentCamera
		if camera then
			local strength = (shake / 0.3) * 0.02
			camera.CFrame *= CFrame.Angles(
				math.sin(os.clock() * 70) * strength,
				math.cos(os.clock() * 63) * strength,
				0
			)
		end
	end)
end

-- Tween the whole scene's light to the stage's mood from Config.
function Effects.SetStage(stage: number)
	if stage == currentStage then
		return
	end
	currentStage = stage
	local mood = Config.Stages[stage]
	local info = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(Lighting, info, {
		Ambient = mood.ambient,
		FogColor = mood.fog,
		ClockTime = mood.clock,
	}):Play()
	Lighting.FogEnd = 300
end

function Effects.OnDeath()
	shake = 0.3
end

function Effects.OnCheckpoint(index: number)
	claimed[index] = true
	if not worldFolder then
		return
	end
	for i in claimed do
		local pad = worldFolder:FindFirstChild("Checkpoint" .. i)
		if pad then
			(pad :: Part).Color = if i == index then Config.Colors.padOn else Color3.fromRGB(38, 140, 84)
		end
	end
	-- The pad you just claimed flashes white and settles into its lit
	-- colour — the checkpoint reads as an event, not a quiet recolour.
	local pad = worldFolder:FindFirstChild("Checkpoint" .. index)
	if pad then
		(pad :: Part).Color = Color3.fromRGB(235, 255, 240)
		TweenService:Create(pad, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Config.Colors.padOn,
		}):Play()
	end
end

-- Remembered so the pickup pop can restore exactly what it borrowed.
local starSizes: { [number]: Vector3 } = {}

function Effects.OnStar(index: number)
	if not worldFolder then
		return
	end
	local star = worldFolder:FindFirstChild("Star" .. index) :: Part?
	if not star then
		return
	end
	-- The pop: the star swells and its light flares, then it is gone —
	-- all local, so a star you took still spins for everyone else.
	if not starSizes[index] then
		starSizes[index] = star.Size
	end
	local light = star:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = 5
	end
	TweenService:Create(star, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = starSizes[index] * 1.7,
	}):Play()
	task.delay(0.14, function()
		star.Transparency = 1
		star.Size = starSizes[index]
		if light then
			light.Enabled = false
			light.Brightness = 1.5
		end
	end)
end

function Effects.OnReset()
	table.clear(claimed)
	currentStage = 0
	if not worldFolder then
		return
	end
	for i = 1, #Config.Checkpoints do
		local pad = worldFolder:FindFirstChild("Checkpoint" .. i)
		if pad then
			(pad :: Part).Color = Config.Colors.padOff
		end
	end
	for i = 1, #Config.Stars do
		local star = worldFolder:FindFirstChild("Star" .. i) :: Part?
		if star then
			star.Transparency = 0
			if starSizes[i] then
				star.Size = starSizes[i]
			end
			local light = star:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = true
				light.Brightness = 1.5
			end
		end
	end
end

return Effects
