-- Sound.luau (client) — every sound the game makes, in one place.
--
-- The assets are public-domain sounds from the Creator Store, each one
-- verified against Roblox's economy API on 2026-11-15 (IsPublicDomain =
-- true), because an unverified id is a silent game: since the 2022 audio
-- privacy change, a sound that is not public domain simply never plays
-- in someone else's experience. The win jingle is three plays of the
-- checkpoint chime at rising PlaybackSpeed — a small arpeggio built from
-- one verified asset instead of a fourth unverified one.

local SoundService = game:GetService("SoundService")

local Sound = {}

local ASSETS = {
	click = "rbxassetid://6895079853", -- "UI Click"
	checkpoint = "rbxassetid://6042053626", -- "Button Click", a bright ding
	star = "rbxassetid://131323304", -- "Coin"
	death = "rbxassetid://138186576", -- "Explosion", detuned to a soft thud
}

local sounds: { [string]: Sound } = {}

local function make(name: string, asset: string, volume: number, speed: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = "Starfall_" .. name
	sound.SoundId = asset
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.Parent = SoundService
	return sound
end

function Sound.Init()
	sounds.click = make("click", ASSETS.click, 0.5, 1)
	sounds.checkpoint = make("checkpoint", ASSETS.checkpoint, 0.6, 1)
	sounds.star = make("star", ASSETS.star, 0.55, 1)
	sounds.death = make("death", ASSETS.death, 0.22, 0.55)
	-- The bounce pad's spring: the same verified ding, dropped in pitch
	-- so it reads as a boing next to the checkpoint's brighter chime.
	sounds.bounce = make("bounce", ASSETS.checkpoint, 0.5, 0.6)
	sounds.winHigh = make("winHigh", ASSETS.checkpoint, 0.6, 1.5)
end

local function play(sound: Sound?)
	if sound then
		-- A sound that failed to load (asset pulled, slow network) must
		-- never break the effect it decorates.
		pcall(function()
			sound:Play()
		end)
	end
end

function Sound.Play(name: string)
	if name == "win" then
		-- The arpeggio: the checkpoint chime at three rising pitches.
		play(sounds.checkpoint)
		task.delay(0.09, function()
			play(sounds.star)
		end)
		task.delay(0.18, function()
			play(sounds.winHigh)
		end)
		return
	end
	play(sounds[name])
end

return Sound
