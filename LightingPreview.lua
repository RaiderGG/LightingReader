-- Setting directories for ImGui and scripts
Versionnum = "1.0"
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.3'
local rp = reaper
local gfx = require "gfx2imgui"
local script_folder = string.gsub(debug.getinfo(1).source:match("@?(.*[\\|/])"),"\\","/")

--Variables
TrackOptions = {"VENUE", "LIGHTING"}
SelectedTrackIndex = 1
SelectedTrack = TrackOptions[SelectedTrackIndex]
LightEvts = {}
CycleEvts = {}
PrevName = PrevName or ""
NextLighting = NextLighting or ""
NextTime = NextTime or 0
CurPos=0
LastTime = 0
EventsHash=0
DisplayedLighting = ''
Step = 1
MaxSteps = 1
StepTime = 0
local lastCycleIndex = 0
local radius= 18
local distance = 55
LoopStepTime = 0.0000000000
LoopStepDuration = 0.000000000000
Bpm=0.0000000000

Stage= {Center={{1,2,3,4,6,5,5,6,7,8,9,10},
                {1,2,3,4,6,5,5,6,7,8,9,10},
                {1,2,3,4,6,6,6,6,7,8,9,10},
                {1,2,3,4,6,6,6,6,7,8,9,10}}}

local pallete = {
    {1,     1,      1,       1},      --1 white
    {0,     0,      0,       0},      --2 black
    {1,     0.20,   0.20,    1},      --3 red
    {1,     0.74,   0.2,     1},      --4 orange
    {1,     0.92,   0.4,     1},      --5 yellow
    {0.4,   1,      0.6,     1},      --6 green
    {0.20,  1,      1,       1},      --7 cyan
    {0.20,  0.20,   1,       1},      --8 blue
    {0.941, 0.76,   0.89,    1},      --9 pink
    {0.5,   1,      0.75,    1},      --10 light_green
    {1,     0.45,   0.89,    1}       --11 magenta
}

local lighting = { --each step in every lighting effect (or at least my try)
    verse =             {{2,4,2,6,4,2,6,2,4,2},{6,2,4,2,2,2,2,4,2,6}},
    chorus =            {{3,2,2,8,3,2,8,2,2,3},{8,3,8,2,2,2,2,8,3,8}},
    manual_cool =       {{2,7,2,8,7,2,8,2,7,2},{8,2,7,2,2,2,2,7,2,8}},
    manual_warm =       {{4,9,4,9,4,2,9,4,9,4},{9,4,9,2,2,2,2,9,4,9}},
    dischord =          {{2,5,6,2,2,2,2,6,5,2},{8,2,8,2,8,2,2,8,2,8}},
    stomp =             {{2,1,1,2,1,1,2,1,1,2},{2,2,2,2,2,2,2,2,2,2}},
    loop_cool =         {{2,7,2,8,7,2,8,2,7,2},{8,2,7,2,2,2,2,7,2,8}},
    loop_warm =         {{2,9,2,4,9,2,4,2,9,2},{4,2,9,2,2,2,2,9,2,4}},
    harmony =           {{2,4,4,9,9,2,9,4,4,2},{9,4,4,2,9,9,2,4,4,9}},
    frenzy =            {{3,2,4,5,3,2,5,4,2,3},{6,4,6,6,6,2,6,6,4,6},{9,8,8,8,2,8,8,8,8,9}},
    silhouettes =       {{10,10,10,10,10,10,10,10,10,10}},
    silhouettes_spot =  {{10,10,10,10,10,10,10,10,10,10}},
    searchlights =      {{1,1,1,1,2,2,2,2,2,2},{2,2,2,2,2,2,1,1,1,1}},
    sweep =             {{11,1,2,2,2,2,2,2,1,11},{2,2,11,2,11,1,2,11,2,2},{2,2,2,11,1,2,11,2,2,2},{2,11,11,1,2,2,1,11,11,2}},
    strobe_slow =       {{1,1,2,2,2,2,2,2,1,1},{2,2,2,2,2,2,2,2,2,2},{2,2,1,1,2,2,1,1,2,2},{2,2,2,2,2,2,2,2,2,2},{2,2,2,2,1,1,2,2,2,2,2},{2,2,2,2,2,2,2,2,2,2},{1,1,2,2,2,2,2,2,1,1},{2,2,2,2,2,2,2,2,2,2}},
    strobe_fast =       {{1,1,2,2,2,2,2,2,1,1},{2,2,2,2,2,2,2,2,2,2},{2,2,1,1,2,2,1,1,2,2},{2,2,2,2,2,2,2,2,2,2},{2,2,2,2,1,1,2,2,2,2,2},{2,2,2,2,2,2,2,2,2,2},{1,1,2,2,2,2,2,2,1,1},{2,2,2,2,2,2,2,2,2,2}},
    blackout_slow =     {{2,2,2,2,2,2,2,2,2,2}},
    blackout_fast =     {{2,2,2,2,2,2,2,2,2,2}},
    blackout_spot =     {{2,2,2,2,2,2,2,2,2,2}},
    flare_slow =        {{1,1,1,1,1,1,1,1,1,1}},
    flare_fast =        {{1,1,1,1,1,1,1,1,1,1}},
    bre =               {{3,2,4,5,3,2,5,4,2,3},{6,4,6,6,6,2,6,6,4,6},{9,8,8,8,2,8,8,8,8,9}},
    none =              {{2,2,2,2,2,2,2,2,2,2}},
    intro =             {{2,2,2,2,2,2,2,2,2,2}}
}
local pattern = ((lighting[DisplayedLighting]))

local LightingMode = {
    loop_warm = "auto",
    loop_cool = "auto",
    sweep = "automid",
    harmony = "auto",
    frenzy = "autofast",
    searchlights = "automid",
    strobe_fast = "strobe_16",
    strobe_slow = "strobe_8",
    bre = "bre",
    default = "manual"
}

gfx.init("LightingPreview", 1000, 400)


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
        DisplayedLighting = "none"

    else
        local midi_item = nil
        for i = 0, rp.CountTrackMediaItems(VenueTrack) - 1 do
            local item = rp.GetTrackMediaItem(VenueTrack, i)
            local take = rp.GetActiveTake(item)

            if take and rp.TakeIsMIDI(take) then

                local _,hash=rp.MIDI_GetHash(take,false)
                if EventsHash~=hash then
                    --rp.ClearConsole()
                    rp.ShowConsoleMsg("reset\n")
                    rp.ShowConsoleMsg("hash: " .. EventsHash .. "\n")
                    CycleEvts = {}
                    LightEvts={}
                    EventCount= 0
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
                        
                    end
                    EventsHash=hash
                    
                end
            end
        end
    end
    
    
end

local function parseLighting()
        local activeLighting = tostring(LightEvts[1][2]) or "none"
        local nextLighting, nextTime

        -- Detect current and next lighting events
        if LightEvts=={}  then
        else
            for i = 1, #LightEvts do
                local LightingTime = LightEvts[i][1]
                local LightingName = LightEvts[i][2]
                if LightingTime <= CurPos then
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
            StepTime = CurPos
            LoopStepTime = CurPos
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
    c1 = type(c1) == "table" and c1 or {0, 0, 0, 0}
    c2 = type(c2) == "table" and c2 or {0, 0, 0, }
    local r = c1[1] + (c2[1] - c1[1]) * t
    local g = c1[2] + (c2[2] - c1[2]) * t
    local b = c1[3] + (c2[3] - c1[3]) * t
    local a = c1[4] + (c2[4] - c1[4]) * t
    return r, g, b, a
end

local function fadeInterpolation(c1, c2, t)
    c1 = type(c1) == "table" and c1 or {0, 0, 0, 1}
    c2 = type(c2) == "table" and c2 or {0, 0, 0, 1}
    local r = c1[1] + (c2[1] - c1[1]) * t
    local g = c1[2] + (c2[2] - c1[2]) * t
    local b = c1[3] + (c2[3] - c1[3]) * t
    local a = c1[4] + (c2[4] - c1[4]) * t
    return r, g, b, a
end
local function drawDotMatrix(x0, y0, radius, spacing, mode)
    local autoColor = {}
    local groupTable = Stage.Center
    local pattern = lighting[DisplayedLighting]
    if type(pattern) ~= "table" or not pattern[Step] then return end
    
    local nextStep = Step + 1
    if nextStep > #pattern then nextStep = 1 end
    
    

    local stepColors = pattern[Step]
    local nextStepColors = lighting[NextLighting] and lighting[NextLighting][1] or {}


    for row = 1, #groupTable do
        for col = 1, #groupTable[row] do
            local groupID = groupTable[row][col]
            local r, g, b, a
            local fcolorA
            local fcolorB
                
            if mode == "strobe_8" or mode == "strobe_16" then
                if mode == "strobe_16" then
                    LoopStepDuration = (60 / Bpm)/2.2
                else
                    LoopStepDuration = (60 / Bpm)/1.05
                end
                if CurPos - LoopStepTime >= LoopStepDuration then
                    Step = Step + 1
                    if Step > #pattern then Step = 1 end
                    LoopStepTime = CurPos
                end
                local colorIndex = stepColors[groupID]
                r, g, b, a = table.unpack(pallete[colorIndex])

            elseif mode == "auto" or mode == "autofast" or mode == "automid" or mode == "bre" then
                
                -- Auto Mode
                if mode == "autofast" then
                    LoopStepDuration = (60 / Bpm)/1.63
                    FadeDuration = (60 / Bpm*2)/5
                elseif mode == "automid" then
                    LoopStepDuration = (60 / Bpm)*1.95
                    FadeDuration = (60 / Bpm/2)*2
                elseif mode == "bre" then
                    LoopStepDuration = (60 / Bpm)/3
                    FadeDuration = (60 / Bpm*2)/8
                else
                    LoopStepDuration = (60 / Bpm)*4
                    FadeDuration = (60 / Bpm/2) *1.2
                end
                if CurPos - LoopStepTime >= LoopStepDuration then
                    Step = Step + 1
                    if Step > #pattern then Step = 1 end
                    LoopStepTime = CurPos
                    StepTime = CurPos
                end
                local colorA = pallete[pattern[Step][groupID] or 1]
                local colorB = pallete[pattern[nextStep][groupID] or 1]
                local t2 = math.min((CurPos - StepTime) / FadeDuration, 1)
                
                r, g, b, a = colorInterpolation(colorA, colorB, t2)
                autoColor = table.pack(r, g, b, a)

            elseif mode == "manual" then-- default, manual
                if type(pattern) ~= "table" then
                    MaxSteps = 1
                else
                    MaxSteps = #pattern
                    for i = 1, #CycleEvts do
                        local CycleTime = CycleEvts[i][1]
                        if CycleTime > LastTime and CycleTime <= CurPos then
                            Step = Step + 1
                            if Step > MaxSteps then Step = 1 end
                            LastTime = CurPos
                        end
                    end
                end
                local colorIndex = stepColors[groupID]
                r, g, b, a = table.unpack(pallete[colorIndex])
            end
            for _, fade in ipairs(DetectedFades) do
                if DisplayedLighting == fade.from and CurPos >= fade.startTime and CurPos <= fade.endTime then
                    Fade = true
                    if mode== "auto" then
                        fcolorA = autoColor
                    else
                        fcolorA = pallete[stepColors[groupID] or 1]
                    end
                    
                    local nextStepColorsf = lighting[fade.to] and lighting[fade.to][1] or {}
                    fcolorB = pallete[nextStepColorsf[groupID] or 1] or {0, 0, 0, 1}
                    local tf = math.min((CurPos - fade.startTime) / (fade.endTime - fade.startTime), 1)
                    r, g, b, a = fadeInterpolation(fcolorA, fcolorB, tf)
                    break
                end
            end

            local x = x0 + (col - 1) * spacing
            local y = y0 + (row - 1) * spacing

            -- Verifying if the light is ON (no black)
                local isLit = (r + g + b) > 0.1
                if isLit then
                    -- bloom effect
                    local bloomLayers = 6
                    local bloomMaxRadius = radius * 2
                    local bloomAlphaStart = 0.12

                    for i = 1, bloomLayers do
                        local layerRadius = radius + ((bloomMaxRadius - radius) * (i / bloomLayers))
                        local layerAlpha = bloomAlphaStart * (1 - (i - 1) / bloomLayers)
                        gfx.set(r, g, b, layerAlpha)
                        gfx.circle(x, y, layerRadius, true)
                    end
                end


            gfx.set(r, g, b, a*0.8)
            gfx.circle(x, y, radius, true)
        end
    end
end

local function loop()
    updEvents()

    PlayState = rp.GetPlayState()
    if PlayState == 1 then
        CurPos = rp.GetPlayPosition() 
    else
        CurPos = rp.GetCursorPosition()
        if CurPos < LastTime then
                LastTime = 0
                LoopStepTime= 0
            end
    end
    _,_,Bpm = reaper.TimeMap_GetTimeSigAtTime(0,CurPos)
    
    if not VenueTrack or rp.CountTrackMediaItems(VenueTrack) == 0 then
        return
    else
        if #LightEvts > 0 then
            parseLighting()
            if CurPos < LightEvts[1][1] or CurPos < LastTime or CurPos < LoopStepTime then
                if DisplayedLighting ~= "none" then
                    DisplayedLighting = "none"
                    LastTime = 0
                end
            end
        end
    end
    
    local mode = LightingMode[DisplayedLighting] or LightingMode.default



    gfx.setfont(1, "Arial", 20)
    --gfx.set(0.24, 0.24, 0.24, 1)
    --gfx.rect(0, 0, gfx.w, gfx.h, 1)
    local background = gfx.loadimg(1,script_folder.."assets/background.png")
    gfx.blit(1,1,0,0,0,1000,400,0,0)


    -- Track Change Button
    gfx.set(1, 1, 1, 1)
    gfx.x, gfx.y = 50, 20
    local btnText = "Track: " .. SelectedTrack
    local btnWidth = gfx.measurestr(btnText)
    gfx.rect(gfx.x - 5, gfx.y - 5, btnWidth + 10, 30, 0)
    gfx.drawstr(btnText)

    -- Input Detection
    local mouse_now = gfx.mouse_cap & 1
    if mouse_now == 1 and Mouse_last_state == 0 then
        if gfx.mouse_x > 40 and gfx.mouse_x < 45 + btnWidth + 10 and gfx.mouse_y > 10 and gfx.mouse_y < 55 then
            SelectedTrackIndex = SelectedTrackIndex + 1
            if SelectedTrackIndex > #TrackOptions then
                SelectedTrackIndex = 1
                end
            SelectedTrack = TrackOptions[SelectedTrackIndex]
            
            --rp.ClearConsole()
            --rp.ShowConsoleMsg("\nhash:" .. EventsHash)
            --rp.ShowConsoleMsg("\nEvents:" .. EventCount .. "\n")
        end
    end
    Mouse_last_state = mouse_now

    -- Show current lighting state
    gfx.x, gfx.y = 220, 20
    gfx.drawstr("Current lighting: " .. tostring(DisplayedLighting))

    gfx.x, gfx.y = 220, 50
    gfx.drawstr("Current bpm: " .. tostring(Bpm))

    --show  current lighting step
    --gfx.x, gfx.y = 750, 20
    --gfx.drawstr("Current step: " .. tostring(Step))

    --display the lighting mode
    --gfx.x, gfx.y = 750, 50
    --gfx.drawstr("Current mode: " .. tostring(mode))

    
    -- Draw Dot Matrix
    if #LightEvts > 0 then
        drawDotMatrix(200, 160, radius, distance, mode)
    else
        DisplayedLighting="none"
    end

    gfx.update()
    if gfx.getchar() ~= -1 then
        rp.defer(loop)
    end
end

rp.defer(loop)
