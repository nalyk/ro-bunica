--!strict
-- Dirijorul satului: muzica adaptivă și efectele pe ritm, dintr-un singur atlas audio.
--
-- Toate straturile (zi, noapte, pericol, urmărire) cântă în buclă, sincron, de la pornire; starea jocului
-- doar le deschide sau închide volumul, pe limita următoarei măsuri. Hora are tempo propriu (crește cu
-- numărul de dansatori) și pornește pe grila ei. Efectele sunt programate pe șaisprezecime cu
-- AudioPlayer:Play(atTime) (precizie de eșantion, ceasul mixerului) și acordate pe acordul curent.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AudioAtlas = require(Shared.Config.AudioAtlas)
local GameState = require(Shared.GameState)
local MusicClock = require(Shared.Domain.MusicClock)
local MusicState = require(Shared.Domain.MusicState)

local Music = {}

local LEAD = 0.05 -- cât de departe în viitor programăm (mixerul are nevoie de puțin timp)
local MAX_SFX_DELAY = 0.09 -- o acțiune a jucătorului nu așteaptă mai mult de atât după ritm
local SFX_VOICES = 16
local FADE = TweenInfo.new(1.2, Enum.EasingStyle.Sine)

type Voice = { player: AudioPlayer, busyUntil: number }

local root: Folder? = nil
local buses: { [string]: AudioFader } = {}
local layers: { [string]: { player: AudioPlayer, fader: AudioFader } } = {}
local hora: { players: { AudioPlayer }, fader: AudioFader, tempo: number?, active: number } = nil :: any
local voices: { Voice } = {}
local grid: MusicClock.Grid = MusicClock.grid(0, 120)
local horaGrid: MusicClock.Grid? = nil
local inputs = { alarmUntil = 0, chaseUntil = 0 }
local enabled = false

local function now(): number
	return SoundService:GetMixerTime()
end

local function wire(source: Instance, target: Instance)
	local w = Instance.new("Wire")
	w.SourceInstance = source
	w.TargetInstance = target
	w.Parent = source
end

local function fader(name: string, volume: number, target: Instance): AudioFader
	local f = Instance.new("AudioFader")
	f.Name = name
	f.Volume = volume
	f.Parent = root
	wire(f, target)
	return f
end

local function newPlayer(name: string, target: Instance): AudioPlayer
	local p = Instance.new("AudioPlayer")
	p.Name = name
	p.Asset = "rbxassetid://" .. AudioAtlas.assetId
	p.Parent = root
	wire(p, target)
	return p
end

local function region(key: string): AudioAtlas.Region?
	return AudioAtlas.regions[key]
end

-- Pregătește un player să cânte o regiune (în buclă sau o dată) de la `offset` secunde în regiune
local function arm(p: AudioPlayer, r: AudioAtlas.Region, offset: number, looping: boolean)
	local range = NumberRange.new(r.start, r.start + r.length)
	p.PlaybackRegion = range
	p.LoopRegion = range
	p.Looping = looping
	p.TimePosition = r.start + offset
end

local function setVolume(f: AudioFader, volume: number)
	if math.abs(f.Volume - volume) < 0.01 then
		return
	end
	TweenService:Create(f, FADE, { Volume = volume }):Play()
end

local function countDancers(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character:GetAttribute("Dancing") == true then
			count += 1
		end
	end
	for _, child in Workspace:GetChildren() do -- boți (teste)
		if
			child:IsA("Model")
			and child:GetAttribute("Dancing") == true
			and not Players:GetPlayerFromCharacter(child)
		then
			count += 1
		end
	end
	return count
end

local function startHora(tempo: number, at: number)
	local key = "music.hora." .. tempo
	local r = region(key)
	if not r then
		return
	end
	-- două playere care se alternează: noul tempo intră exact când se termină bucla curentă
	local nextIndex = 3 - hora.active
	local p = hora.players[nextIndex]
	arm(p, r, 0, true)
	p:Play(at)
	local old = hora.players[hora.active]
	if old.IsPlaying then
		old:Stop(at)
	end
	hora.active = nextIndex
	hora.tempo = tempo
	horaGrid = MusicClock.grid(at, tempo)
end

local function update()
	if not enabled then
		return
	end
	local character = Players.LocalPlayer.Character
	local mix, tempo = MusicState.mix({
		phase = GameState.get(GameState.Attributes.Phase) or "Day",
		now = os.clock(),
		alarmUntil = inputs.alarmUntil,
		chaseUntil = inputs.chaseUntil,
		dancing = character ~= nil and character:GetAttribute("Dancing") == true,
		dancers = countDancers(),
	})
	for name, layer in layers do
		setVolume(layer.fader, mix[name] or 0)
	end
	local t = now()
	if tempo then
		if hora.tempo ~= tempo then
			-- prima intrare: pe următoarea măsură; schimbarea de tempo: la capătul buclei de horă
			local at = if hora.tempo and horaGrid
				then MusicClock.nextBoundary(horaGrid, t, horaGrid.eighthsPerLoop, LEAD)
				else MusicClock.nextBoundary(grid, t, 4, LEAD)
			if not hora.tempo then
				setVolume(hora.fader, 1)
			end
			startHora(tempo, at)
		end
	elseif hora.tempo then
		local at = MusicClock.nextBoundary(horaGrid or grid, t, 4, LEAD)
		hora.players[hora.active]:Stop(at)
		hora.tempo = nil
		horaGrid = nil
	end
end

-- Grila activă: a horei, dacă se dansează, altfel cea a satului
local function activeGrid(): MusicClock.Grid
	return horaGrid or grid
end

export type CueOptions = {
	volume: number?,
	pitch: number?, -- semitonuri în plus
	quantize: boolean?, -- implicit: da
	harmonize: boolean?, -- transpune pe fundamentala acordului curent
}

-- Cântă un efect din atlas (de exemplu „pleosc”, „coin”). Întoarce momentul (mixer) în care sună.
function Music.cue(name: string, options: CueOptions?): number?
	if not enabled then
		return nil
	end
	local r = region("sfx." .. name)
	if not r then
		warn("[Music] efect lipsă:", name)
		return nil
	end
	local opts: CueOptions = options or {}
	local t = now()
	local g = activeGrid()
	local at = if opts.quantize == false then t + LEAD else MusicClock.quantize(g, t, LEAD, MAX_SFX_DELAY)
	local semitones = opts.pitch or 0
	if opts.harmonize then
		semitones += MusicClock.chordRoot(AudioAtlas.harmony, grid, at)
	end
	local speed = MusicClock.speedForSemitones(semitones)
	local chosen: Voice? = nil
	for _, voice in voices do
		if voice.busyUntil <= t then
			chosen = voice
			break
		end
	end
	if not chosen then
		return nil -- prea multe sunete simultan: îl sărim, nu întrerupem altul
	end
	local voice = chosen :: Voice
	arm(voice.player, r, 0, false)
	voice.player.PlaybackSpeed = speed
	voice.player.Volume = opts.volume or 1
	voice.player:Play(at)
	voice.busyUntil = at + r.length / speed + 0.05
	return at
end

-- Semnale din joc
function Music.alarm(seconds: number?)
	inputs.alarmUntil = os.clock() + (seconds or 25)
	update()
end

function Music.chase(seconds: number?)
	inputs.chaseUntil = math.max(inputs.chaseUntil, os.clock() + (seconds or 8))
	update()
end

function Music.calm()
	inputs.alarmUntil = 0
	inputs.chaseUntil = 0
	update()
end

-- Coboară muzica (de exemplu cât vorbește Bunica)
function Music.duck(seconds: number)
	local bus = buses.Music
	if not bus then
		return
	end
	TweenService:Create(bus, TweenInfo.new(0.15), { Volume = 0.35 }):Play()
	task.delay(seconds, function()
		TweenService:Create(bus, TweenInfo.new(0.6), { Volume = 1 }):Play()
	end)
end

function Music.isEnabled(): boolean
	return enabled
end

function Music.start()
	if AudioAtlas.assetId == 0 then
		warn("[Music] atlasul audio nu e încărcat încă (assetId = 0); muzica e oprită")
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "BunicaAudio"
	folder.Parent = SoundService
	root = folder
	local output = Instance.new("AudioDeviceOutput")
	output.Parent = folder
	local master = fader("Master", 1, output)
	buses.Music = fader("Music", 1, master)
	buses.Sfx = fader("Sfx", 1, master)
	for _, name in MusicState.LAYERS do
		local f = fader("Layer_" .. name, 0, buses.Music)
		layers[name] = { player = newPlayer("Layer_" .. name, f), fader = f }
	end
	local horaFader = fader("Layer_hora", 0, buses.Music)
	hora = {
		players = { newPlayer("Hora_A", horaFader), newPlayer("Hora_B", horaFader) },
		fader = horaFader,
		tempo = nil,
		active = 1,
	}
	for i = 1, SFX_VOICES do
		table.insert(voices, { player = newPlayer("Sfx_" .. i, buses.Sfx), busyUntil = 0 })
	end
	task.spawn(function()
		local first = layers.zi.player
		local deadline = os.clock() + 20
		while not first.IsReady and os.clock() < deadline do
			task.wait(0.1)
		end
		-- toate straturile pornesc în același moment de mixer: rămân sincrone pentru totdeauna
		local origin = now() + 0.2
		grid = MusicClock.grid(origin, 120)
		for name, layer in layers do
			local r = region("music." .. name)
			if r then
				arm(layer.player, r, 0, true)
				layer.player:Play(origin)
			end
		end
		enabled = true
		update()
	end)
	GameState.changed(GameState.Attributes.Phase, function()
		update()
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		character:GetAttributeChangedSignal("Dancing"):Connect(update)
	end)
	if Players.LocalPlayer.Character then
		Players.LocalPlayer.Character:GetAttributeChangedSignal("Dancing"):Connect(update)
	end
	-- expirarea alarmelor și numărul de dansatori se schimbă fără evenimente: verificăm des
	task.spawn(function()
		while true do
			task.wait(0.5)
			update()
		end
	end)
end

return Music
