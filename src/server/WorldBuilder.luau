-- WorldBuilder.luau (server) — builds the whole visible world from Config
-- and returns a registry of the parts it made, so GameService can wire
-- gameplay and Movers can animate them. It owns no game state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldBuilder = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A floating text board: a dark slab with a SurfaceGui — title line on
-- top, smaller hint under it. Faces +Z, towards the arriving player.
local function sign(parent: Instance, spec: { any })
	local x, y, z, w, h, text, sub = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7]
	local board = part(
		parent,
		"Sign",
		Vector3.new(w, h, 0.6),
		CFrame.new(x, y, z),
		Config.Colors.sign,
		Enum.Material.SmoothPlastic
	)
	-- A sign is read, never stood on: a jumping player's head must pass
	-- through where it floats instead of cracking into it.
	board.CanCollide = false
	board.CanTouch = false
	board.CanQuery = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.58)
	title.BackgroundTransparency = 1
	title.Text = text
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(245, 245, 255)
	title.Parent = gui
	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.fromScale(0, 0.58)
	hint.Size = UDim2.fromScale(1, 0.42)
	hint.BackgroundTransparency = 1
	hint.Text = sub
	hint.Font = Enum.Font.Gotham
	hint.TextScaled = true
	hint.TextColor3 = Color3.fromRGB(178, 186, 205)
	hint.Parent = gui
end

-- The crown on the final platform: a gold band, five points and a gem,
-- built from plain parts so it reads from the whole last stage.
local function crown(parent: Instance, x: number, y: number, z: number)
	local gold = Color3.fromRGB(255, 190, 40)
	local band = part(parent, "CrownBand", Vector3.new(5, 1.6, 5), CFrame.new(x, y + 0.8, z), gold, Enum.Material.Neon)
	band.Shape = Enum.PartType.Cylinder
	band.CFrame = CFrame.new(x, y + 0.8, z) * CFrame.Angles(0, 0, math.rad(90))
	for i = 0, 4 do
		local angle = (i / 5) * math.pi * 2
		local px, pz = x + math.sin(angle) * 2.1, z + math.cos(angle) * 2.1
		part(parent, "CrownPoint", Vector3.new(0.9, 2.2, 0.9), CFrame.new(px, y + 2.6, pz), gold, Enum.Material.Neon)
	end
	local gem = part(
		parent,
		"CrownGem",
		Vector3.new(1.2, 1.2, 1.2),
		CFrame.new(x, y + 2, z),
		Color3.fromRGB(255, 80, 120),
		Enum.Material.Neon
	)
	gem.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 26
	light.Brightness = 2
	light.Parent = band
end

-- A sentinel drone: a dark hovering sphere with one glowing eye, welded
-- so the eye follows the body. The body joins both the mover registry
-- (it rides its patrol path) and the hazard list (touching it sends you
-- back) — an enemy built from the same two systems as everything else.
local function sentinel(parent: Instance, spec: { any }, index: number, world: { [string]: any })
	local stage = spec[1]
	local from = Vector3.new(spec[2], spec[3], spec[4])
	local body = part(
		parent,
		"Sentinel" .. index,
		Vector3.new(1.8, 1.8, 1.8),
		CFrame.new(from),
		Config.Colors.sign,
		Enum.Material.SmoothPlastic
	)
	body.Shape = Enum.PartType.Ball
	local eye = part(
		parent,
		"SentinelEye" .. index,
		Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(from + Vector3.new(0, 0.15, 0.75)),
		Config.Stages[stage].trim,
		Enum.Material.Neon
	)
	eye.Shape = Enum.PartType.Ball
	eye.CanCollide = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = eye
	weld.Parent = body
	local light = Instance.new("PointLight")
	light.Color = Config.Stages[stage].trim
	light.Range = 10
	light.Brightness = 1.4
	light.Parent = body
	table.insert(world.Hazards, body)
	table.insert(world.Movers, {
		part = body,
		from = from,
		axis = Vector3.new(spec[5][1], spec[5][2], spec[5][3]),
		dist = spec[6],
		speed = spec[7],
	})
end

function WorldBuilder.Build(): { [string]: any }
	local root = Instance.new("Folder")
	root.Name = "StarfallWorld"
	root.Parent = Workspace

	local world: { [string]: any } = {
		Checkpoints = {},
		Stars = {},
		Hazards = {},
		Movers = {},
		Sweepers = {},
		Bouncers = {},
		Blinks = {},
		Crumbles = {},
		Gates = {},
	}

	-- Platforms. Solids alternate base/accent stone along the course, some
	-- are round discs instead of slabs, every island gets a tapered root
	-- underneath so it reads as a floating island rather than a pancake,
	-- and neon trim strips mark the edges.
	for i, spec in Config.Platforms do
		local stage, kind = spec[1], spec[8]
		local stageCfg = Config.Stages[stage]
		local center = Vector3.new(spec[2], spec[3], spec[4])
		local size = Vector3.new(spec[5], spec[6], spec[7])
		local isDisc = kind ~= "mover" and spec[9] == "disc"
		local color, material = stageCfg.base, Enum.Material.SmoothPlastic
		if kind == "ice" then
			color, material = Config.Colors.ice, Enum.Material.Ice
		elseif kind == "lava" then
			color, material = Config.Colors.lava, Enum.Material.Neon
		elseif kind == "mover" then
			color = stageCfg.trim
		elseif kind == "bounce" then
			-- A bounce pad wears the checkpoint green: it reads as a
			-- friendly machine, not a hazard.
			color, material = Config.Colors.padOn, Enum.Material.Neon
		elseif kind == "glass" then
			-- Glass wears the accent stone's hue in real glass: the Void
			-- Crown's discs are windows over the drop.
			color, material = stageCfg.accent, Enum.Material.Glass
		elseif kind == "crumble" then
			-- Crumble stone is scorched towards ember-orange: cracked
			-- rock reads as fragile before it ever shakes.
			color = stageCfg.base:Lerp(Color3.fromRGB(255, 120, 60), 0.22)
		elseif kind == "blink" or i % 2 == 0 then
			-- Blink platforms always wear the accent stone, so the floor
			-- that is about to vanish never matches its neighbours.
			color = stageCfg.accent
		end
		local p: Part
		if isDisc then
			-- A cylinder's axis runs along X; rotate it upright so sx becomes
			-- the diameter and sy the thickness, footprint unchanged.
			p = part(
				root,
				"Platform" .. i,
				Vector3.new(size.Y, size.X, size.X),
				CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
				color,
				material
			)
			p.Shape = Enum.PartType.Cylinder
		else
			p = part(root, "Platform" .. i, size, CFrame.new(center), color, material)
		end
		if kind == "ice" then
			p.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.03, 0.3, 1, 1)
		end
		if kind == "glass" then
			p.Transparency = 0.35
		end
		if kind == "lava" then
			table.insert(world.Hazards, p)
		elseif kind == "mover" then
			local extra = spec[9]
			table.insert(world.Movers, {
				part = p,
				from = center,
				axis = Vector3.new(extra.axis[1], extra.axis[2], extra.axis[3]),
				dist = extra.dist,
				speed = extra.speed,
			})
		elseif kind == "bounce" then
			table.insert(world.Bouncers, { part = p, power = spec[9] })
		elseif kind == "blink" then
			table.insert(world.Blinks, { part = p, offset = spec[9] or 0 })
		elseif kind == "crumble" then
			table.insert(world.Crumbles, { part = p, home = p.CFrame })
		elseif kind == "solid" or kind == "ice" or kind == "glass" or kind == "crumble" then
			-- Island root: a darker block rotated 45 degrees under the
			-- platform. Pure scenery (no collision).
			local tail = part(
				root,
				"Tail" .. i,
				Vector3.new(size.X * 0.55, 3.2, size.Z * 0.55),
				CFrame.new(center - Vector3.new(0, size.Y / 2 + 1.5, 0)) * CFrame.Angles(0, math.rad(45), 0),
				color:Lerp(Color3.new(0, 0, 0), 0.35),
				Enum.Material.SmoothPlastic
			)
			tail.CanCollide = false
			if not isDisc then
				local trim = part(
					root,
					"Trim" .. i,
					Vector3.new(size.X, 0.25, 0.25),
					CFrame.new(center + Vector3.new(0, size.Y / 2 - 0.12, size.Z / 2)),
					stageCfg.trim,
					Enum.Material.Neon
				)
				trim.CanCollide = false
				-- Accent-stone platforms carry a second strip on the back
				-- edge, so the two tones differ in trim as well as colour.
				if color == stageCfg.accent then
					local trim2 = part(
						root,
						"TrimB" .. i,
						Vector3.new(size.X, 0.25, 0.25),
						CFrame.new(center + Vector3.new(0, size.Y / 2 - 0.12, -size.Z / 2)),
						stageCfg.trim,
						Enum.Material.Neon
					)
					trim2.CanCollide = false
				end
			end
			-- Floating crystal shards beside every third platform.
			if i % 3 == 0 then
				local side = if i % 2 == 0 then 1 else -1
				local shard = part(
					root,
					"Shard" .. i,
					Vector3.new(1.1, 1.1, 1.1),
					CFrame.new(center + Vector3.new(side * (size.X / 2 + 3.5), 2.5 + (i % 3), -2))
						* CFrame.Angles(math.rad(24), math.rad(45), math.rad(12)),
					stageCfg.trim,
					Enum.Material.Neon
				)
				shard.CanCollide = false
			end
		end
	end

	-- Plaza corner pillars: dark posts with glowing orbs, framing the
	-- start (and the title board) in the first screenshot.
	for _, px in { -15, 15 } do
		for _, pz in { 14, 38 } do
			part(
				root,
				"PlazaPost",
				Vector3.new(1.2, 7, 1.2),
				CFrame.new(px, 4.5, pz),
				Config.Colors.sign,
				Enum.Material.SmoothPlastic
			)
			local orb = part(
				root,
				"PlazaOrb",
				Vector3.new(1.6, 1.6, 1.6),
				CFrame.new(px, 8.8, pz),
				Config.Stages[1].trim,
				Enum.Material.Neon
			)
			orb.Shape = Enum.PartType.Ball
			orb.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color = Config.Stages[1].trim
			light.Range = 14
			light.Brightness = 1.2
			light.Parent = orb
		end
	end

	-- The plaza medallion: a glowing ring and disc inlaid in the spawn
	-- floor — a designed emblem, not a bare dark slab.
	local medallion = part(
		root,
		"PlazaMedallion",
		Vector3.new(0.22, 11, 11),
		CFrame.new(0, 1.06, 26) * CFrame.Angles(0, 0, math.rad(90)),
		Config.Stages[1].trim,
		Enum.Material.Neon
	)
	medallion.Shape = Enum.PartType.Cylinder
	medallion.CanCollide = false
	local medallionCore = part(
		root,
		"PlazaMedallionCore",
		Vector3.new(0.24, 6, 6),
		CFrame.new(0, 1.06, 26) * CFrame.Angles(0, 0, math.rad(90)),
		Config.Stages[1].accent,
		Enum.Material.SmoothPlastic
	)
	medallionCore.Shape = Enum.PartType.Cylinder
	medallionCore.CanCollide = false

	-- Checkpoint pads: dark until claimed, then green (GameService).
	for i, spec in Config.Checkpoints do
		local pad = part(
			root,
			"Checkpoint" .. i,
			Vector3.new(6, 0.3, 6),
			CFrame.new(spec[2], spec[3], spec[4]),
			Config.Colors.padOff,
			Enum.Material.Neon
		)
		table.insert(
			world.Checkpoints,
			{ part = pad, stage = spec[1], spawn = Vector3.new(spec[2], spec[3] + 3, spec[4]) }
		)
	end

	-- Stars: a glowing ball with a light, spun and bobbed by Movers.
	for i, spec in Config.Stars do
		local star = part(
			root,
			"Star" .. i,
			Vector3.new(1.6, 1.6, 1.6),
			CFrame.new(spec[2], spec[3], spec[4]),
			Config.Colors.star,
			Enum.Material.Neon
		)
		star.Shape = Enum.PartType.Ball
		star.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Config.Colors.star
		light.Range = 12
		light.Brightness = 1.5
		light.Parent = star
		table.insert(world.Stars, { part = star, stage = spec[1], home = star.CFrame, taken = false })
	end

	-- Sweeper arms: neon bars hovering over their platforms; Movers
	-- rotates them, GameService respawns whoever they touch.
	for i, spec in Config.Sweepers do
		local pivot = Vector3.new(spec[2], spec[3], spec[4])
		local arm = part(
			root,
			"Sweeper" .. i,
			Vector3.new(spec[5], 0.7, 0.7),
			CFrame.new(pivot),
			Config.Stages[spec[1]].trim,
			Enum.Material.Neon
		)
		table.insert(world.Hazards, arm)
		table.insert(world.Sweepers, { part = arm, pivot = pivot, length = spec[5], speed = spec[6], phase = i * 1.7 })
	end

	-- Sentinels patrol three platforms across the course.
	for i, spec in Config.Sentinels do
		sentinel(root, spec, i, world)
	end

	-- The timed gates: a neon door across the path on stages 3 and 4,
	-- each in its own stage's stone frame and trim.
	for gi, g in Config.Gates do
		local frameColor = Config.Stages[g.stage].base
		part(
			root,
			"GatePostL" .. gi,
			Vector3.new(0.8, 5, 1.2),
			CFrame.new(g.x - 4.4, g.y, g.z),
			frameColor,
			Enum.Material.SmoothPlastic
		)
		part(
			root,
			"GatePostR" .. gi,
			Vector3.new(0.8, 5, 1.2),
			CFrame.new(g.x + 4.4, g.y, g.z),
			frameColor,
			Enum.Material.SmoothPlastic
		)
		local door = part(
			root,
			"GateDoor" .. gi,
			Vector3.new(8, 4, 0.8),
			CFrame.new(g.x, g.y, g.z),
			Config.Stages[g.stage].trim,
			Enum.Material.Neon
		)
		table.insert(world.Gates, { part = door, spec = g })
	end

	-- Signs and the finish: crown prop plus the gold win pad.
	for _, spec in Config.Signs do
		sign(root, spec)
	end
	crown(root, Config.Crown.x, Config.Crown.y, Config.Crown.z)
	local winPad = part(
		root,
		"WinPad",
		Vector3.new(8, 0.3, 8),
		CFrame.new(Config.WinPad.x, Config.WinPad.y, Config.WinPad.z),
		Config.Colors.win,
		Enum.Material.Neon
	)
	world.WinPad = winPad

	return world
end

return WorldBuilder
