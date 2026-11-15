-- GameService.luau (server) — the game's one state owner, in the style of
-- a Knit service: every player's run lives in one table here, and nothing
-- else keeps score. It wires the world's parts to that state, respawns
-- fallen players, and talks to the client through four RemoteEvents:
-- StateUpdate and Effect out, ChooseStage and RestartRun in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)

local GameService = {}

type RunState = {
	checkpoint: number,
	stage: number,
	stars: { boolean },
	starCount: number,
	deaths: number,
	startedAt: number?,
	startStage: number,
	finished: boolean,
	finishElapsed: number?,
	splits: { [number]: number },
}

local runs: { [Player]: RunState } = {}
local lastHazard: { [Player]: number } = {}
local remotes: { [string]: RemoteEvent } = nil
local world: { [string]: any } = nil

local function newRun(): RunState
	return {
		checkpoint = 1,
		stage = 1,
		stars = {},
		starCount = 0,
		deaths = 0,
		startedAt = nil,
		startStage = 1,
		finished = false,
		finishElapsed = nil,
		splits = {},
	}
end

local function sendState(player: Player)
	local run = runs[player]
	if not run then
		return
	end
	remotes.StateUpdate:FireClient(player, {
		stage = run.stage,
		checkpoint = run.checkpoint,
		stars = run.starCount,
		totalStars = Config.TotalStars,
		deaths = run.deaths,
		running = run.startedAt ~= nil and not run.finished,
		startedAt = run.startedAt,
		startStage = run.startStage,
		finished = run.finished,
		finishElapsed = run.finishElapsed,
		splits = run.splits,
	})
end

local function effect(player: Player, name: string, data: any)
	remotes.Effect:FireClient(player, name, data)
end

-- Move a player's character to a world position, upright and stopped.
-- Returns false when there is no character to move (still spawning).
local function teleport(player: Player, position: Vector3): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = CFrame.new(position)
		return true
	end
	return false
end

local lastRespawn: { [Player]: number } = {}

local function respawn(player: Player, why: string)
	local run = runs[player]
	if not run then
		return
	end
	-- A respawn counts only when it actually moves someone: overlapping
	-- hazard/fall triggers inside the debounce window are one death.
	local now = os.clock()
	if lastRespawn[player] and now - lastRespawn[player] < 0.75 then
		return
	end
	local checkpoint = world.Checkpoints[run.checkpoint]
	if not teleport(player, checkpoint.spawn) then
		return
	end
	lastRespawn[player] = now
	run.deaths += 1
	effect(player, "death", why)
	sendState(player)
end

local function beginRun(player: Player, stage: number)
	local run = runs[player]
	run.startedAt = Workspace:GetServerTimeNow()
	run.startStage = stage
	run.finished = false
	run.finishElapsed = nil
end

local function onCheckpoint(player: Player, index: number)
	local run = runs[player]
	local checkpoint = world.Checkpoints[index]
	if not run or not checkpoint then
		return
	end
	if run.startedAt == nil and index > 1 then
		beginRun(player, checkpoint.stage)
	end
	if index > run.checkpoint then
		run.checkpoint = index
		effect(player, "checkpoint", index)
		if checkpoint.stage > run.stage then
			run.stage = checkpoint.stage
			-- The split: the moment a timed run first reaches a new
			-- stage, kept per stage for the win screen's breakdown.
			if run.startedAt ~= nil and run.splits[checkpoint.stage] == nil then
				run.splits[checkpoint.stage] = Workspace:GetServerTimeNow() - run.startedAt
			end
			effect(player, "stageclear", checkpoint.stage)
		end
		sendState(player)
	end
end

-- A bounce pad sets the character's upward speed outright, keeping its
-- sideways drift, so a running jump onto the pad carries its momentum
-- up and over the gap the pad guards.
local function onBounce(player: Player, power: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, power, velocity.Z)
		effect(player, "bounce", nil)
	end
end

local function onStar(player: Player, index: number)
	local run = runs[player]
	if not run or run.stars[index] then
		return
	end
	run.stars[index] = true
	run.starCount += 1
	if run.startedAt == nil then
		beginRun(player, world.Stars[index].stage)
	end
	effect(player, "star", index)
	sendState(player)
end

local function onHazard(player: Player)
	local now = os.clock()
	if lastHazard[player] and now - lastHazard[player] < 1 then
		return
	end
	lastHazard[player] = now
	respawn(player, "hazard")
end

local function onWin(player: Player)
	local run = runs[player]
	if not run or run.finished then
		return
	end
	run.finished = true
	-- An untimed finish is reported as one: finishElapsed stays nil and
	-- the win screen says FREE CLIMB instead of a fabricated 0.0 time.
	if run.startedAt ~= nil then
		run.finishElapsed = Workspace:GetServerTimeNow() - run.startedAt
	end
	effect(player, "win", nil)
	sendState(player)
end

-- Whichever character part touched, find the player it belongs to.
local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return Players:GetPlayerFromCharacter(character)
	end
	return nil
end

local function wireTouch(part: BasePart, handler: (Player) -> ())
	part.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player then
			handler(player)
		end
	end)
end

local function onPlayerAdded(player: Player)
	runs[player] = newRun()
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		teleport(player, world.Checkpoints[runs[player].checkpoint].spawn)
		sendState(player)
		humanoid.Died:Connect(function()
			local diedRun = runs[player]
			if not diedRun then
				return
			end
			diedRun.deaths += 1
			task.wait(0.6)
			if runs[player] then
				-- LoadCharacter errors if the player left mid-wait; the
				-- run is already gone then, so it has nothing to fix.
				pcall(function()
					player:LoadCharacter()
				end)
			end
		end)
	end)
	-- Guarded like the Died path: a player who leaves during the join
	-- handshake must not turn this into an error.
	pcall(function()
		player:LoadCharacter()
	end)
end

function GameService.Init(w: { [string]: any })
	world = w

	Lighting.Brightness = 2
	-- Open on stage 1's own mood (golden dusk) from the first frame, so
	-- the start screen never shows a flat midday sky the stage then has
	-- to correct; Effects tweens on from here as stages change.
	Lighting.ClockTime = Config.Stages[1].clock
	Lighting.Ambient = Config.Stages[1].ambient
	Lighting.FogEnd = 420
	-- FallenPartsDestroyHeight is set in the place file itself (the project
	-- file's Workspace properties): a live server script may not write it
	-- (the engine refuses with a capability error), and this game's own
	-- fall check below respawns fallen players long before it matters.

	local folder = Instance.new("Folder")
	folder.Name = "StarfallRemotes"
	for _, name in { "StateUpdate", "Effect", "ChooseStage", "RestartRun" } do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	remotes = {
		StateUpdate = folder.StateUpdate,
		Effect = folder.Effect,
		ChooseStage = folder.ChooseStage,
		RestartRun = folder.RestartRun,
	}

	for i, checkpoint in world.Checkpoints do
		wireTouch(checkpoint.part, function(player)
			onCheckpoint(player, i)
		end)
	end
	for i, star in world.Stars do
		wireTouch(star.part, function(player)
			onStar(player, i)
		end)
	end
	for _, hazard in world.Hazards do
		wireTouch(hazard, onHazard)
	end
	for _, bouncer in world.Bouncers do
		wireTouch(bouncer.part, function(player)
			onBounce(player, bouncer.power)
		end)
	end
	wireTouch(world.WinPad, onWin)

	remotes.ChooseStage.OnServerEvent:Connect(function(player, stage)
		if typeof(stage) ~= "number" or stage < 1 or stage > #Config.Stages then
			return
		end
		local run = runs[player]
		if not run then
			return
		end
		for i, checkpoint in world.Checkpoints do
			if checkpoint.stage == stage then
				run.checkpoint = i
				run.stage = stage
				beginRun(player, stage)
				teleport(player, checkpoint.spawn)
				effect(player, "stageclear", stage)
				sendState(player)
				return
			end
		end
	end)

	remotes.RestartRun.OnServerEvent:Connect(function(player)
		runs[player] = newRun()
		teleport(player, world.Checkpoints[1].spawn)
		effect(player, "reset", nil)
		sendState(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
		lastHazard[player] = nil
		lastRespawn[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- The fall check: below your checkpoint by RespawnDrop means you fell.
	task.spawn(function()
		while true do
			task.wait(0.3)
			for player, run in runs do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Y < world.Checkpoints[run.checkpoint].spawn.Y - Config.RespawnDrop then
					respawn(player, "fall")
				end
			end
		end
	end)
end

return GameService
