-- init.server.luau — the server bootstrap, kept to three lines on purpose:
-- build the world, start the game service on it, start the movers.

local WorldBuilder = require(script.WorldBuilder)
local GameService = require(script.GameService)
local Movers = require(script.Movers)

local world = WorldBuilder.Build()
GameService.Init(world)
Movers.Start(world)
