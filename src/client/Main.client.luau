-- Main.client.luau — the client bootstrap, the counterpart of GameService:
-- it builds the GUI once, then just routes what the server says. StateUpdate
-- refreshes the HUD (and opens the win screen on a finish), Effect events
-- trigger their one piece of feedback, and the buttons on the screens fire
-- the matching RemoteEvent back. The run's clock ticks here from the
-- server's own start time, so every screen shows the same number.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local HUD = require(script.Parent.HUD)
local Screens = require(script.Parent.Screens)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("StarfallRemotes")

local gui = Instance.new("ScreenGui")
gui.Name = "StarfallGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

HUD.Create(gui)
Effects.Init()
Sound.Init()

local state: { [string]: any }? = nil
local winShown = false

Screens.Create(gui, {
	onPlay = function()
		remotes.ChooseStage:FireServer(1)
	end,
	onStage = function(stage: number)
		remotes.ChooseStage:FireServer(stage)
	end,
	onRestart = function()
		winShown = false
		remotes.RestartRun:FireServer()
	end,
	onFreeRoam = function() end,
})
Screens.ShowStart()

remotes.StateUpdate.OnClientEvent:Connect(function(newState: { [string]: any })
	state = newState
	HUD.SetState(newState)
	Effects.SetStage(newState.stage)
	if newState.finished and not winShown then
		winShown = true
		Sound.Play("win")
		if newState.finishElapsed then
			HUD.Tick(newState.finishElapsed)
		end
		Screens.ShowWin(newState)
	elseif not newState.finished then
		winShown = false
	end
end)

remotes.Effect.OnClientEvent:Connect(function(name: string, data: any)
	if name == "death" then
		HUD.FlashDeath()
		Effects.OnDeath()
		Sound.Play("death")
		HUD.Banner("SENT BACK", "Your checkpoint holds your place", 0.9)
	elseif name == "checkpoint" then
		Effects.OnCheckpoint(data)
		Sound.Play("checkpoint")
		HUD.Banner("CHECKPOINT SET", "", 0.8)
	elseif name == "stageclear" then
		local stageCfg = Config.Stages[data]
		HUD.Banner("STAGE " .. data, stageCfg.name, 1.8)
	elseif name == "star" then
		Effects.OnStar(data)
		Sound.Play("star")
		HUD.PopStar()
	elseif name == "bounce" then
		Sound.Play("bounce")
	elseif name == "reset" then
		Effects.OnReset()
		Screens.ShowStart()
	end
end)

-- The clock: while a run is live, count up from the server's start time;
-- while idle, poll slowly — there is nothing to refresh.
task.spawn(function()
	while true do
		if state and state.running and state.startedAt then
			HUD.Tick(Workspace:GetServerTimeNow() - state.startedAt)
			task.wait(0.05)
		else
			task.wait(0.3)
		end
	end
end)
