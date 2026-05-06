-- Setting directories for ImGui and scripts
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.3'
local rp = reaper
local gfx = require "gfx2imgui"

--Variables
TrackOptions = {"VENUE", "LIGHTING"}
SelectedTrackIndex = 1
SelectedTrack = TrackOptions[SelectedTrackIndex]
LightEvts = {}
CycleEvts = {}
PrevName = PrevName or ""
NextLighting = NextLighting or ""
NextTime = NextTime or 0
Offset=0
CurTime=0
LastTime = 0
EventsHash=0
DisplayedLighting = ''
Step = 1
MaxSteps = 1
StepTime = 0
local lastCycleIndex = 0
local radius= 18
local distance = 55
local bpm = reaper.Master_GetTempo()
local LoopStepTime = 0
local LoopStepDuration = 0

Stage= {Center={{1,2,3,4,6,5,5,6,4,3,2,1},
                {1,2,3,4,6,5,5,6,4,3,2,1},
                {1,2,3,4,6,6,6,6,4,3,2,1},
                {1,2,3,4,6,6,6,6,4,3,2,1}}}

local pallete = {
    {1,     1,      1,      1},      --1 white
    {0,     0,      0,      1},      --2 black
    {1,     0,      0,      1},      --3 red
    {1,     0.64,   0.1,    1},      --4 orange
    {1,     0.92,   0.3,    1},      --5 yellow
    {0,     1,      0,      1},      --6 green
    {0,     1,      1,      1},      --7 cyan
    {0,     0,      1,      1},      --8 blue
    {0.941, 0.824,  0.855,  1}       --9 pink
}

local lighting = { --each step in every lighting effect (or at least my try)
    verse =             {{2,4,2,6,4,2},{6,2,4,2,2,2}},
    chorus =            {{3,2,2,8,3,2},{8,3,8,2,2,2}},
    manual_cool =       {{2,7,2,8,7,2},{8,2,7,2,2,2}},
    manual_warm =       {{4,9,4,9,4,2},{9,4,9,2,2,2}},
    dischord =          {{2,5,6,2,2,2},{8,2,8,2,8,2}},
    stomp =             {{2,1,1,2,1,1},{2,2,2,2,2,2}},
    loop_cool =         {{2,7,2,8,7,2},{8,2,7,2,2,2}},
    loop_warm =         {{2,7,2,8,7,2},{8,2,7,2,2,2}},
    harmony =           {{2,7,2,8,7,2},{8,2,7,2,2,2}},
    frenzy =            {{2,7,2,8,7,2},{8,2,7,2,2,2}},
    silhouettes =       {{2,7,2,8,7,2},{8,2,7,2,2,2}},
    silhouettes_spot =  {{2,7,2,8,7,2},{8,2,7,2,2,2}},
    searchlights =      {{2,7,2,8,7,2},{8,2,7,2,2,2}},
    sweep =             {{2,7,2,8,7,2},{8,2,7,2,2,2}},
    strobe_slow =       {{2,1,1,2,1,1},{2,2,2,2,2,2}},
    strobe_fast =       {{2,1,1,2,1,1},{2,2,2,2,2,2}},
    blackout_slow =     {{2,2,2,2,2,2}},
    blackout_fast =     {{2,2,2,2,2,2}},
    blackout_spot =     {{2,2,2,2,2,2}},
    flare_slow =        {{1,1,1,1,1,1}},
    flare_fast =        {{1,1,1,1,1,1}},
    bre =               {{2,7,2,8,7,2},{8,2,7,2,2,2}},
    test =              {{2,2,2,2,2,2}},
    intro =             {{2,2,2,2,2,2}}
}
local pattern = ((lighting[DisplayedLighting]))

local LightingMode = {
    loop_warm = "auto",
    loop_cool = "auto",
    sweep = "auto",
    harmony = "auto",
    silhouettes = "auto",
    silhouettes_spot = "auto",
    searchlights = "auto",
    strobe_fast = "strobe_1_8",
    strobe_slow = "strobe_1_16",
    flare_slow = "pulse",  
    default = "static",
}

gfx.init("Lighting Reader", 1000, 400)


function Stringstarts(String,Start)
	return string.sub(String,1,string.len(Start))==Start
end

function FindTrack(trackName)
	local numTracks = rp.CountTracks(0)
	for i = 0, numTracks - 1 do
		local track = rp.GetTrack(0, i)
		local _, currentTrackName = rp.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
		if currentTrackName == trackName then
			return track
		end
	end
	
end


local function updEvents(take)
    
    VenueTrack = FindTrack(SelectedTrack)
    if not VenueTrack or rp.CountTrackMediaItems(VenueTrack) == 0 then
        EventsHash = "" 
        DisplayedLighting = "test"
    else
        local midi_item = nil
        for i = 0, rp.CountTrackMediaItems(VenueTrack) - 1 do
            local item = rp.GetTrackMediaItem(VenueTrack, i)
            local take = rp.GetActiveTake(item)

            if take and rp.TakeIsMIDI(take) then

                local _,hash=rp.MIDI_GetHash(take,false)
                if EventsHash~=hash then
                    --rp.ClearConsole()
                    LightEvts={}
                    _,_,_,EventCount = rp.MIDI_CountEvts(take)
                    if EventCount == 0 then
                        return
                    else
                        for i = 0, EventCount - 1 do
                            _,_,_,Epos,Etype,Msg = rp.MIDI_GetTextSysexEvt(take, i)
                            Etime = rp.MIDI_GetProjTimeFromPPQPos(take, Epos)
                            if Etype==5 or Etype==1 and Stringstarts(Msg,'[lighting') then
                                Msg = string.sub(tostring(Msg),12,-3)
                                --rp.ShowConsoleMsg("\n Found " .. Msg .." With pos: ".. Epos)
                                table.insert(LightEvts,{Etime,Msg})
                            elseif Etype==5 or Etype==1 and Msg =="[next]" or Msg=="[prev]" or Msg=="[first]" then
                                Msg = string.sub(tostring(Msg),2,-2)
                                --rp.ShowConsoleMsg("\n Found " .. Msg .." With pos: ".. Epos)
                                table.insert(CycleEvts,{Etime,Msg})
                            end
                        end
                        
                        if #LightEvts > 0 and CurTime < LightEvts[1][1] then
                            if DisplayedLighting ~= "test" then
                                DisplayedLighting = "test"
                                LastTime =0
                            end
                            return
                        end
                    end
                    EventsHash=hash
                end
            end
        end
    end
    
    
end

local function compareCycle()
    local pattern = lighting[DisplayedLighting]
    if type(pattern) ~= "table" then
        MaxSteps = 1
    else
        MaxSteps = #pattern
        for i = 1, #CycleEvts do
            local CycleTime = CycleEvts[i][1]
            if CycleTime > LastTime and CycleTime <= CurTime then
                Step = Step + 1
                if Step > MaxSteps then Step = 1 end
                --rp.ShowConsoleMsg("[next] crossed at: " .. tostring(CycleTime) .. "\n")
                LastTime = CurTime
            end
        end
    end
    
    
end

local function compareLighting()
        local activeLighting = tostring(LightEvts[1][2]) or "test"
        local nextLighting, nextTime

        -- Detect current and next lighting events
        if LightEvts=={}  then
        else
            for i = 1, #LightEvts do
                local LightingTime = LightEvts[i][1]
                local LightingName = LightEvts[i][2]
                if LightingTime <= CurTime then
                    activeLighting = LightingName
                    if i < #LightEvts then
                        nextTime, nextLighting = table.unpack(LightEvts[i + 1])
                    end
                else
                    break
                end
            end
        end

        -- Detecting where are valid transitions (2 same events and a different one)
        for i = 1, #LightEvts - 2 do
            local name1 = LightEvts[i][2]
            local name2 = LightEvts[i + 1][2]
            local name3 = LightEvts[i + 2][2]

            if name1 == name2 and name2 ~= name3 then
                FadeStartTime = LightEvts[i + 1][1]
                FadeEndTime = LightEvts[i + 2][1]
                FadeFrom = name2
                FadeTo = name3
                break
            end
        end

        -- Detect event changes
        if DisplayedLighting ~= activeLighting then
            Step = 1
            StepTime = CurTime
            LoopStepTime = CurTime
        end

        DetectedFades = {}

        for i = 1, #LightEvts - 2 do
            local name1 = LightEvts[i][2]
            local name2 = LightEvts[i + 1][2]
            local name3 = LightEvts[i + 2][2]

            if name1 == name2 and name2 ~= name3 then
                table.insert(DetectedFades, {
                    from = name2,
                    to = name3,
                    startTime = LightEvts[i + 1][1],
                    endTime = LightEvts[i + 2][1]
                })
            end
        end
        -- Update current lighting and transitions
        DisplayedLighting = activeLighting
        NextLighting = nextLighting
        NextTime = nextTime
    end

local function colorInterpolation(c1, c2, t)
    c1 = type(c1) == "table" and c1 or {0, 0, 0, 1}
    c2 = type(c2) == "table" and c2 or {0, 0, 0, 1}
    local r = c1[1] + (c2[1] - c1[1]) * t
    local g = c1[2] + (c2[2] - c1[2]) * t
    local b = c1[3] + (c2[3] - c1[3]) * t
    local a = c1[4] + (c2[4] - c1[4]) * t
    return r, g, b, a
end


local function drawDotMatrix(x0, y0, radius, spacing, mode)
    local groupTable = Stage.Center
    local pattern = lighting[DisplayedLighting]
    if type(pattern) ~= "table" or not pattern[Step] then return end
    
    local nextStep = Step + 1
    if nextStep > #pattern then nextStep = 1 end
    local t = math.min((CurTime - StepTime) / FadeDuration, 1)
    

    local stepColors = pattern[Step]
    local nextStepColors = lighting[NextLighting] and lighting[NextLighting][1] or {}


    for row = 1, #groupTable do
        for col = 1, #groupTable[row] do
            local groupID = groupTable[row][col]
            local r, g, b, a
                
            if mode == "flash" then
                local flashOn = math.floor((CurTime * bpm / 60) * 2) % 2 == 0
                local colorIndex = flashOn and stepColors[groupID] or 2 -- negro como apagado
                r, g, b, a = table.unpack(pallete[colorIndex])

            elseif mode == "pulse" then
                local pulse = 0.5 + 0.5 * math.sin(CurTime * bpm / 60 * math.pi)
                local baseColor = pallete[stepColors[groupID] or 1]
                r = baseColor[1] * pulse
                g = baseColor[2] * pulse
                b = baseColor[3] * pulse
                a = baseColor[4]

            elseif mode == "wave" then
                local wavePhase = math.sin((CurTime * bpm / 60 * math.pi) + col * 0.5)
                local intensity = 0.5 + 0.5 * wavePhase
                local baseColor = pallete[stepColors[groupID] or 1]
                r = baseColor[1] * intensity
                g = baseColor[2] * intensity
                b = baseColor[3] * intensity
                a = baseColor[4]
                
            elseif mode == "strobe_1_8" or mode == "strobe_1_16" then
                local flashesPerBeat = (mode == "strobe_1_16") and 2 or 4
                local flashOn = math.floor((CurTime * bpm / 60) * flashesPerBeat) % 2 == 0

                local colorIndex = flashOn and stepColors[groupID] or 2 -- 2 = negro o apagado
                local color = pallete[colorIndex] or {0, 0, 0, 1}

                r, g, b, a = table.unpack(color)

            elseif mode == "auto" then
                -- Auto Mode
                if CurTime - LoopStepTime >= LoopStepDuration then
                    Step = Step + 1
                    if Step > #pattern then Step = 1 end
                    LoopStepTime = CurTime
                    StepTime = CurTime
                end

                local colorA = pallete[pattern[Step][groupID] or 1]
                local colorB = pallete[pattern[nextStep][groupID] or 1]

                local bpm = rp.Master_GetTempo()
                local FadeDuration = (60 / bpm) *0.75
                local t = math.min((CurTime - StepTime) / FadeDuration, 1)

                r, g, b, a = colorInterpolation(colorA, colorB, t)
            elseif mode == "static" then-- default, static
                local colorIndex = stepColors[groupID]
                r, g, b, a = table.unpack(pallete[colorIndex])
            end

            for _, fade in ipairs(DetectedFades) do
                if DisplayedLighting == fade.from and CurTime >= fade.startTime and CurTime <= fade.endTime then
                    Fade = true
                    local colorA = pallete[stepColors[groupID] or 1]
                    local nextStepColors = lighting[fade.to] and lighting[fade.to][1] or {}
                    local colorB = pallete[nextStepColors[groupID] or 1] or {0, 0, 0, 1}

                    local t = math.min((CurTime - fade.startTime) / (fade.endTime - fade.startTime), 1)
                    r, g, b, a = colorInterpolation(colorA, colorB, t)
                    break -- solo aplicamos el primer fade activo
                end
            end

            local x = x0 + (col - 1) * spacing
            local y = y0 + (row - 1) * spacing

            -- Verifying if the light is ON (no black)
                local isLit = (r + g + b) > 0.15
                if isLit then
                    -- bloom degradado
                    local bloomLayers = 4
                    local bloomMaxRadius = radius * 1.67
                    local bloomAlphaStart = 0.12

                    for i = 1, bloomLayers do
                        local layerRadius = radius + ((bloomMaxRadius - radius) * (i / bloomLayers))
                        local layerAlpha = bloomAlphaStart * (1 - (i - 1) / bloomLayers)
                        gfx.set(r, g, b, layerAlpha)
                        gfx.circle(x, y, layerRadius, true)
                    end
                end


            gfx.set(r, g, b, a)
            gfx.circle(x, y, radius, true)
        end
    end
end

local function loop()
    updEvents()

    PlayState = rp.GetPlayState()
    if PlayState == 1 then
        CurTime = rp.GetPlayPosition() - Offset
        
    else
        CurTime = rp.GetCursorPosition()
        if CurTime < LastTime then
            LastTime = 0
            Step=1
        end
    end
    
    if not VenueTrack or rp.CountTrackMediaItems(VenueTrack) == 0 then
        return
    else
        if #LightEvts > 0 then
            compareCycle()
            compareLighting()
        end
    end
    local mode = LightingMode[DisplayedLighting] or LightingMode.default

    LoopStepDuration = (60 / bpm) * 2
    FadeDuration = (60 / bpm) *0.35



    gfx.setfont(1, "Arial", 20)
    gfx.set(0.29, 0.33, 0.41, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, 1)

    -- Track Change Button
    gfx.set(1, 1, 1, 1)
    gfx.x, gfx.y = 50, 30
    local btnText = "Track: " .. SelectedTrack
    local btnWidth = gfx.measurestr(btnText)
    gfx.rect(gfx.x - 5, gfx.y - 5, btnWidth + 10, 30, 0)
    gfx.drawstr(btnText)

    -- Input Detection
    local mouse_now = gfx.mouse_cap & 1
    if mouse_now == 1 and Mouse_last_state == 0 then
        if gfx.mouse_x > 45 and gfx.mouse_x < 45 + btnWidth + 10 and gfx.mouse_y > 25 and gfx.mouse_y < 55 then
            SelectedTrackIndex = SelectedTrackIndex + 1
            if SelectedTrackIndex > #TrackOptions then SelectedTrackIndex = 1 end
            SelectedTrack = TrackOptions[SelectedTrackIndex]
        end
    end
    Mouse_last_state = mouse_now

    -- Show current lighting state
    gfx.x, gfx.y = 220, 30
    gfx.drawstr("Current lighting: " .. tostring(DisplayedLighting))

    --gfx.x, gfx.y = 550, 30
    --gfx.drawstr("Current max steps: " .. tostring(MaxSteps))

    --show  current lighting step
    gfx.x, gfx.y = 800, 30
    gfx.drawstr("Current step: " .. tostring(Step))

    --display the lighting mode
    --gfx.x, gfx.y = 800, 60
    --gfx.drawstr("Current mode: " .. tostring(mode))

    


    -- Draw Dot Matrix
    drawDotMatrix(200, 160, radius, distance, mode)

    gfx.update()
    if gfx.getchar() ~= -1 then
        rp.defer(loop)
    end
end

rp.defer(loop)
