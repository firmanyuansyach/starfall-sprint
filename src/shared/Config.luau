-- Config.luau — every fact about the course lives here, in one place.
-- STARFALL SPRINT: a four-stage sky obby (Ember Rise, Frostbite Run, Void
-- Crown, Solar Forge) with 12 stars. WorldBuilder builds the world from
-- these tables; GameService runs the game from them. Positions are part
-- centres in studs; the course runs towards -Z and up +Y. Every hop was
-- checked on paper: no gap over 6 studs, no climb over 3.

local Config = {}

Config.GameTitle = "STARFALL SPRINT"
Config.TotalStars = 12
Config.RespawnDrop = 45 -- fall this far below your checkpoint and you respawn
Config.ParTimes = { 210, 330, 480 } -- seconds: Legend / Ace / Climber cut-offs

-- One palette per stage: a dark base stone, a lighter accent that
-- alternates with it along the course, a neon trim, and the light mood.
Config.Stages = {
	{
		name = "EMBER RISE",
		base = Color3.fromRGB(74, 50, 38),
		accent = Color3.fromRGB(133, 84, 50),
		trim = Color3.fromRGB(255, 140, 66),
		ambient = Color3.fromRGB(72, 44, 26),
		fog = Color3.fromRGB(46, 24, 12),
		clock = 17.6,
	},
	{
		name = "FROSTBITE RUN",
		base = Color3.fromRGB(39, 65, 86),
		accent = Color3.fromRGB(70, 104, 128),
		trim = Color3.fromRGB(127, 231, 255),
		ambient = Color3.fromRGB(38, 58, 78),
		fog = Color3.fromRGB(96, 140, 164),
		clock = 13.5,
	},
	{
		name = "VOID CROWN",
		base = Color3.fromRGB(46, 26, 71),
		accent = Color3.fromRGB(82, 50, 122),
		trim = Color3.fromRGB(199, 125, 255),
		ambient = Color3.fromRGB(40, 24, 66),
		fog = Color3.fromRGB(52, 28, 84),
		clock = 0.4,
	},
	{
		name = "SOLAR FORGE",
		base = Color3.fromRGB(92, 78, 54),
		accent = Color3.fromRGB(148, 126, 84),
		trim = Color3.fromRGB(255, 205, 84),
		ambient = Color3.fromRGB(84, 66, 38),
		fog = Color3.fromRGB(122, 98, 60),
		clock = 7.8,
	},
}

Config.Colors = {
	lava = Color3.fromRGB(255, 77, 0),
	ice = Color3.fromRGB(189, 239, 255),
	star = Color3.fromRGB(255, 201, 60),
	padOff = Color3.fromRGB(30, 30, 40),
	padOn = Color3.fromRGB(80, 255, 140),
	win = Color3.fromRGB(255, 215, 64),
	sign = Color3.fromRGB(16, 14, 24),
}

-- Platforms: { stage, x, y, z, sx, sy, sz, kind }.
-- kind: "solid" | "ice" (near-zero friction) | "lava" (touching it respawns you)
-- | "mover" (rides between its centre and centre + axis * dist, ping-pong)
-- | "bounce" (touching it launches you up) | "blink" (fades in and out on a
-- cycle — stand on one too long and it drops you) | "crumble" (solid until
-- stepped on, then it shakes for half a second, falls, and rebuilds itself)
-- | "glass" (a solid you can see through — the Void Crown's discs).
-- A mover's ninth field is { axis = {x,y,z}, dist, speed (studs/second) };
-- a bounce pad's is its launch speed; a blink platform's is its phase
-- offset in seconds, so neighbouring blinks are never in step. Any other
-- kind's ninth field may be "disc": a round stepping stone whose diameter
-- is sx (rows are square, so the footprint — and every checked jump gap —
-- is unchanged).
Config.Platforms = {
	-- Spawn plaza (stage 1 ground).
	{ 1, 0, 0, 26, 36, 2, 36, "solid" },
	-- Stage 1 — Ember Rise.
	{ 1, 0, 1, -2, 12, 2, 12, "solid" },
	{ 1, 0, 2, -16, 8, 1, 8, "solid", "disc" },
	{ 1, -8, 3, -27, 7, 1, 7, "solid" },
	{ 1, 5, 4, -36, 7, 1, 7, "solid", "disc" },
	{ 1, 0, 5, -48, 18, 1, 6, "solid" },
	{ 1, -11, 6, -59, 6, 1, 6, "mover", { axis = { 1, 0, 0 }, dist = 22, speed = 7 } },
	{ 1, 0, 7, -68.5, 14, 1, 10, "solid" },
	{ 1, -5, 8, -83, 5, 1, 8, "solid" },
	{ 1, 5, 8, -83, 5, 1, 8, "solid" },
	{ 1, 0, 7.7, -83, 5, 0.5, 8, "lava" },
	{ 1, 0, 10, -97, 8, 1, 8, "crumble", "disc" },
	{ 1, 0, 12, -110, 8, 1, 8, "solid" },
	{ 1, 0, 13, -124, 12, 1, 12, "solid" },
	-- Stage 2 — Frostbite Run.
	{ 2, 0, 14, -140, 10, 1, 10, "solid" },
	{ 2, 0, 15, -154, 5, 1, 14, "ice" },
	{ 2, 9, 16, -168, 7, 1, 7, "solid", "disc" },
	{ 2, 0, 18, -184, 14, 1, 14, "solid" },
	{ 2, -9, 20, -200, 6, 1, 6, "mover", { axis = { 0, 1, 0 }, dist = 6, speed = 3.5 } },
	{ 2, 0, 23, -212, 10, 1, 10, "solid" },
	{ 2, -6, 24, -224, 6, 1, 6, "ice", "disc" },
	{ 2, 5, 25, -232, 6, 1, 6, "ice" },
	{ 2, 0, 26, -244, 3, 1, 10, "solid" },
	{ 2, 0, 28, -258, 12, 1, 12, "solid" },
	{ 2, 0, 30, -274, 12, 1, 12, "solid" },
	-- Stage 3 — Void Crown.
	{ 3, 0, 31, -290, 10, 1, 10, "solid" },
	{ 3, 0, 32, -304, 8, 1, 10, "solid" },
	{ 3, 11, 33, -318, 6, 1, 6, "mover", { axis = { -1, 0, 0 }, dist = 22, speed = 8 } },
	{ 3, -11, 35, -328, 7, 1, 7, "solid" },
	{ 3, 0, 37, -344, 16, 1, 16, "solid" },
	{ 3, 0, 37.65, -350.5, 16, 0.3, 3, "lava" },
	{ 3, 0, 40, -360, 7, 1, 7, "glass", "disc" },
	{ 3, 0, 43, -372, 7, 1, 7, "crumble" },
	{ 3, 0, 46, -384, 6, 1, 6, "glass", "disc" },
	{ 3, 0, 48, -402, 18, 1, 18, "solid" },
	-- Stage 4 — Solar Forge. The old crown platform is now the doorstep;
	-- the climb runs on past it, higher and further into the dawn.
	{ 4, 0, 49, -420, 10, 1, 10, "solid" },
	{ 4, 0, 50, -434, 6, 1, 6, "bounce", 62 },
	{ 4, 0, 55, -446, 8, 1, 8, "solid", "disc" },
	{ 4, -5, 56, -458, 6, 1, 6, "blink", 0 },
	{ 4, 5, 57, -468, 6, 1, 6, "blink", 1.6 },
	{ 4, -9, 58, -478, 6, 1, 6, "mover", { axis = { 1, 0, 0 }, dist = 18, speed = 7 } },
	{ 4, 0, 60, -492, 12, 1, 12, "solid" },
	{ 4, 0, 61, -506, 8, 1, 10, "solid" },
	{ 4, 0, 63, -518, 7, 1, 7, "crumble", "disc" },
	{ 4, 0, 65, -529, 7, 1, 7, "solid", "disc" },
	{ 4, 0, 66, -544, 18, 1, 18, "solid" },
}

-- Spinning sweeper arms: { stage, x, y, z, armLength, speed } — y is the
-- platform top; the arm sweeps 0.7 studs above it. Negative speed reverses.
Config.Sweepers = {
	{ 2, 0, 18.5, -184, 6.5, 1.3 },
	{ 2, 0, 28.5, -258, 5.5, -1.7 },
	{ 3, 0, 37.5, -344, 7.5, 1.2 },
	{ 3, 0, 37.5, -344, 7.5, -1.2 },
	{ 4, 0, 60.5, -492, 5.5, 1.5 },
	-- The Crown Guardians: two arms on the crown platform itself, turning
	-- against each other around the win pad.
	{ 4, 0, 66.5, -544, 7.5, 1.4 },
	{ 4, 0, 66.5, -544, 7.5, -1.4 },
}

-- Sentinels: the course's enemies — hovering drones that patrol a
-- platform on a ping-pong path and send back anyone they touch.
-- { stage, x, y, z, axis, dist, speed }: (x, y, z) is the patrol's start,
-- y the drone's centre (it hovers just above the platform top).
Config.Sentinels = {
	{ 1, -7, 6.8, -48, { 1, 0, 0 }, 14, 5 },
	{ 2, 4.5, 29.8, -252, { 0, 0, -1 }, 10, 4 },
	{ 4, -2.5, 66.8, -529, { 1, 0, 0 }, 5, 3.5 },
}

-- Timed gates: { stage, x, y, z } is the door's centre, phase staggers the
-- cycles so the two doors are never in step. Each cycles open -> warning
-- -> closed; the door is solid unless it glows green.
Config.Gates = {
	{ stage = 3, x = 0, y = 34.5, z = -308, openTime = 2.4, warnTime = 0.7, closedTime = 2.4, phase = 0 },
	{ stage = 4, x = 0, y = 63.5, z = -506, openTime = 2.4, warnTime = 0.7, closedTime = 2.4, phase = 1.3 },
}

-- Checkpoint pads: { stage, x, y, z } — y is the pad centre (0.15 above the
-- platform top). Touching one makes it your respawn point; the first pad of
-- a new stage also clears the stage before it.
Config.Checkpoints = {
	{ 1, 0, 1.15, 26 },
	{ 1, 0, 2.15, -2 },
	{ 1, 0, 7.65, -68.5 },
	{ 2, 0, 13.65, -124 },
	{ 2, 0, 23.65, -212 },
	{ 3, 0, 30.65, -274 },
	{ 3, 0, 31.65, -290 },
	{ 4, 0, 48.65, -402 },
	{ 4, 0, 60.65, -492 },
	{ 4, 6, 66.65, -537 },
}

-- Stars: { stage, x, y, z } — one risky, shiny detour per platform cluster.
Config.Stars = {
	{ 1, -8, 6.5, -27 },
	{ 1, 0, 9.5, -59 },
	{ 1, 0, 11, -83 },
	{ 2, 0, 18.5, -160 },
	{ 2, 0, 22, -184 },
	{ 2, 5, 28.5, -232 },
	{ 3, 0, 38, -308 },
	{ 3, 0, 41, -344 },
	{ 3, 0, 49.5, -372 },
	{ 4, 0, 54, -434 },
	{ 4, 0, 61.5, -478 },
	{ 4, 0, 66, -518 },
}

-- In-world signs: { x, y, z, w, h, text, sub } — boards that face the player
-- as they run towards -Z, kept beside the running line so they never block
-- a jump. The big one over the plaza is the game's title.
Config.Signs = {
	{ 0, 12.5, 10, 22, 6, "STARFALL SPRINT", "Four stages. Twelve stars. One crown." },
	{ 13, 5.5, -8, 12, 3, "STAGE 1 · EMBER RISE", "Mind the orange floor — it burns. Cracked stone crumbles." },
	{ 13, 17.5, -128, 12, 3, "STAGE 2 · FROSTBITE RUN", "Ice is slippery. Small hops!" },
	{ 13, 34.5, -284, 12, 3, "STAGE 3 · VOID CROWN", "Time the violet gate. Green means go." },
	{ 13, 52, -414, 12, 3, "STAGE 4 · SOLAR FORGE", "Bounce high. Blinking floors vanish — keep moving!" },
	{ 0, 73, -551, 14, 4, "THE CROWN", "Past the guardian arms. Touch the gold pad." },
}

Config.WinPad = { x = 0, y = 66.65, z = -540 }
Config.Crown = { x = 0, y = 66.5, z = -548 }

return Config
