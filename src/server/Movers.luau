-- Movers.luau (server) — animates everything that moves, on one Heartbeat
-- loop: the riding platforms, the sweeper arms, the timed gates'
-- open/warn/closed cycles, the blink platforms' fade cycle, the crumble
-- floors' shake-fall-rebuild cycle, and the stars' spin and bob.
--
-- Carrying riders honestly: the platforms are Anchored, and an anchored
-- part's velocity does not move a standing character, so each frame this
-- module moves every rider itself — a short raycast under each character
-- finds the mover it stands on, and the character is shifted by exactly
-- that mover's frame delta. Pure presentation otherwise: it reads the
-- registry WorldBuilder made and keeps no game state of its own.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Movers = {}

local function pingPong(distance: number, speed: number, t: number): number
	local cycle = 2 * distance
	local phase = (t * speed) % cycle
	if phase <= distance then
		return phase
	end
	return cycle - phase
end

-- Shift every character standing on a moved platform by the platform's
-- frame delta, so riders are carried instead of slid out from under. The
-- raycast setup is built once in Start — the hot loop allocates nothing
-- per frame but the results it reads.
--
-- GROUNDED RIDERS ONLY — this gate is load-bearing. The character is
-- client-owned and the server's view of its root lags the real one;
-- writing that stale CFrame onto a character that just jumped snaps it
-- back down and eats the jump, feeling exactly like an invisible wall
-- (playtest bug, 2026-11-15: riders could not jump off the stage-1
-- mover at all). An airborne rider is never carried.
local function carryRiders(params: RaycastParams, deltas: { [BasePart]: Vector3 })
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			local state = humanoid:GetState()
			local grounded = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed
			if grounded and root.AssemblyLinearVelocity.Y <= 4 then
				local hit = Workspace:Raycast(root.Position, Vector3.new(0, -4, 0), params)
				if hit and deltas[hit.Instance] then
					root.CFrame += deltas[hit.Instance]
				end
			end
		end
	end
end

-- One gate door's cycle, written only when its mode actually changes.
local function updateGate(gate: { [string]: any }, t: number)
	local spec = gate.spec
	local cycle = spec.openTime + spec.warnTime + spec.closedTime
	local phase = (t + spec.phase) % cycle
	local trim = Config.Stages[spec.stage].trim
	local mode, color
	if phase < spec.openTime then
		mode, color = "open", Config.Colors.padOn
	elseif phase < spec.openTime + spec.warnTime then
		local flash = math.floor(t * 8) % 2 == 0
		mode = "warn" .. tostring(flash)
		color = if flash then Color3.fromRGB(255, 60, 60) else trim
	else
		mode, color = "closed", trim
	end
	if mode ~= gate.lastMode then
		gate.lastMode = mode
		local door = gate.part
		door.CanCollide = mode ~= "open"
		door.Transparency = if mode == "open" then 0.8 else 0
		door.Color = color
	end
end

-- Blink platforms: solid, then a flickering warning, then gone — a
-- 3.2-second cycle, out of step per platform by its Config offset.
local BLINK_CYCLE = 3.2
local BLINK_SOLID = 2.0
local BLINK_WARN = 0.45

local function updateBlink(blink: { [string]: any }, t: number)
	local phase = (t + blink.offset) % BLINK_CYCLE
	local part = blink.part
	if phase < BLINK_SOLID - BLINK_WARN then
		if blink.state ~= "solid" then
			blink.state = "solid"
			part.Transparency = 0
			part.CanCollide = true
		end
	elseif phase < BLINK_SOLID then
		-- The warning flicker: strobing before the drop, so it is told.
		local flash = math.floor(t * 10) % 2 == 0
		local state = "warn" .. tostring(flash)
		if blink.state ~= state then
			blink.state = state
			part.Transparency = if flash then 0.45 else 0
			part.CanCollide = true
		end
	else
		if blink.state ~= "gone" then
			blink.state = "gone"
			part.Transparency = 0.7
			part.CanCollide = false
		end
	end
end

-- Crumble floors: solid until a character steps on one, then half a
-- second of shaking (the tell), a fall, and a quiet rebuild a few
-- seconds later. The first step is always safe; lingering is not.
local CRUMBLE_SHAKE = 0.5
local CRUMBLE_GONE = 2.4

local function updateCrumble(crumble: { [string]: any }, t: number)
	local part = crumble.part
	if crumble.state == "shaking" then
		if t - crumble.since >= CRUMBLE_SHAKE then
			crumble.state = "gone"
			crumble.since = t
			part.CanCollide = false
			part.Transparency = 0.65
			part.CFrame = crumble.home * CFrame.new(0, -16, 0)
		else
			part.CFrame = crumble.home * CFrame.new(math.sin(t * 55) * 0.07, math.cos(t * 47) * 0.035, 0)
		end
	elseif crumble.state == "gone" then
		if t - crumble.since >= CRUMBLE_GONE then
			crumble.state = "idle"
			part.CFrame = crumble.home
			part.Transparency = 0
			part.CanCollide = true
		end
	end
end

function Movers.Start(world: { [string]: any })
	local elapsed = 0

	for _, crumble in world.Crumbles do
		crumble.state = "idle"
		crumble.since = 0
		crumble.part.Touched:Connect(function(hit)
			if crumble.state ~= "idle" then
				return
			end
			local character = hit:FindFirstAncestorOfClass("Model")
			if character and character:FindFirstChildOfClass("Humanoid") then
				crumble.state = "shaking"
				crumble.since = elapsed
			end
		end)
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	local moverParts = {}
	for _, mover in world.Movers do
		table.insert(moverParts, mover.part)
	end
	rayParams.FilterDescendantsInstances = moverParts
	local deltas: { [BasePart]: Vector3 } = {}

	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local t = elapsed

		table.clear(deltas)
		for _, mover in world.Movers do
			local offset = pingPong(mover.dist, mover.speed, t)
			local newPos = mover.from + mover.axis * offset
			local part = mover.part
			deltas[part] = newPos - part.Position
			part.CFrame = CFrame.new(newPos)
		end
		carryRiders(rayParams, deltas)

		for _, sweeper in world.Sweepers do
			local angle = sweeper.phase + t * sweeper.speed
			local center = sweeper.pivot + Vector3.new(0, 0.75, 0)
			sweeper.part.CFrame = CFrame.new(center)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(sweeper.length / 2 + 0.4, 0, 0)
		end

		for _, gate in world.Gates do
			updateGate(gate, t)
		end

		for _, blink in world.Blinks do
			updateBlink(blink, t)
		end

		for _, crumble in world.Crumbles do
			updateCrumble(crumble, t)
		end

		for i, star in world.Stars do
			local bob = math.sin(t * 2 + i * 1.3) * 0.35
			star.part.CFrame = star.home * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * 1.8 + i, 0)
		end
	end)
end

return Movers
