local repo = 'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/'
local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/lelo0002/hai../refs/heads/main/roxylinoria.lua'))()
local ThemeManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/lelo0002/hai../refs/heads/main/theme.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
local Options = Library.Options
local Toggles = Library.Toggles
local Window = Library:CreateWindow({
    Title = "                     $$ roxy.win $$                                                  TWW", Center = true, AutoShow = true, MenuFadeTime = 0.1, Resizable = true,
    ShowCustomCursor = false, NotifySide = "Bottom", Size = UDim2.new(0, 750, 0, 480)
})
for _, v in ipairs(Window.Holder:GetDescendants()) do
    if v:IsA("TextLabel") and v.Text:find("roxy.win") then v.RichText = true break end
end
local Tabs = { Combat = Window:AddTab("Combat"), Visuals = Window:AddTab("Visuals"), Misc = Window:AddTab("Misc"), Players = Window:AddTab("Players"), ["UI Settings"] = Window:AddTab("Configs") }
local S = setmetatable({}, {__index = function(t, k) local s = game:GetService(k); t[k] = s; return s end})
local P, RS, TS, WS = S.Players, S.RunService, S.TweenService, workspace
local C = workspace.CurrentCamera
while not P.LocalPlayer do task.wait() end
local LP = P.LocalPlayer
print("roxy.win | LocalPlayer found: " .. LP.Name)

local function checkCharData()
    local root = WS:FindFirstChild("WORKSPACE_Entities")
    local folder = root and root:FindFirstChild("Players")
    local char = folder and folder:FindFirstChild(LP.Name) or LP.Character
    return char and char:FindFirstChild("HumanoidRootPart") ~= nil
end

local isLoaded = checkCharData()
if not isLoaded then
    local NotifyData = Library:Notify("roxy.win | synchronizing with world data... 00.0%", 15)
    local startTime = os.clock()
    local duration = 5.5
    local promptedSpawn = false

    while true do
        local currentlyLoaded = checkCharData()
        local elapsed = os.clock() - startTime
        local targetPercent = math.min(99.9, (elapsed / duration) * 100)
        
        if currentlyLoaded and targetPercent >= 99.9 then
            targetPercent = 100.0
        end
        
        if targetPercent >= 99.9 and not currentlyLoaded then
            targetPercent = 99.9
            if not promptedSpawn then
                promptedSpawn = true
                Library:Notify("roxy.win | deployment paused. please spawn character to continue.", 10)
            end
        end
        
        if NotifyData and NotifyData.ChangeDescription then
            -- %04.1f ensures 00.0 to 99.9 have the exact same string length, preventing UI width jitter
            NotifyData:ChangeDescription(string.format("roxy.win | synchronizing with world data... %04.1f%%", targetPercent))
        end
        
        if targetPercent >= 100.0 then
            break
        end
        
        task.wait() 
    end

    if NotifyData and NotifyData.ChangeDescription then
        NotifyData:ChangeDescription("roxy.win | synchronizing with world data... 100.0%")
    end
    task.wait(0.2)
    Library:Notify("roxy.win | initializing modules.", 3)
end
print("roxy.win | World sync complete.")
local espCache, SA_State = {}, { Transparency = 0, LerpPos = nil, CurrentTarget = nil, SmoothedFOV = 130 }
local Aim_State = { Transparency = 0, LerpPos = nil, CurrentTarget = nil, SmoothedFOV = 130 }
local crosshairLines = {}
for i = 1, 8 do
    local l = Drawing.new("Line")
    l.Visible = false
    l.ZIndex = i <= 4 and 998 or 999
    l.Thickness = i <= 4 and 3 or 1
    l.Color = i <= 4 and Color3.new(0,0,0) or Color3.new(1,1,1)
    l.Transparency = 1
    crosshairLines[i] = l
end

local MBF_RingLines = {}
local MBF_RingOutlineLines = {}
for i = 1, 73 do
    local l = Drawing.new("Line")
    l.Visible = false
    l.Thickness = 1
    l.Transparency = 1
    l.Color = Color3.new(1, 1, 1)
    l.ZIndex = 2
    MBF_RingLines[i] = l
    
    local o = Drawing.new("Line")
    o.Visible = false
    o.Thickness = 2 -- Outline slightly thicker for visibility
    o.Transparency = 1
    o.Color = Color3.new(0, 0, 0)
    o.ZIndex = 1
    MBF_RingOutlineLines[i] = o
end
local MBF_CurrentPos = Vector3.new(0, 0, 0)

Library:SetWatermarkVisibility(true)
local FrameTimer, FrameCounter, FPS = tick(), 0, 60
local GetPing = function() 
    local success, val = pcall(function() return game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue() end)
    return success and math.floor(val) or 0 
end
local CanDoPing = true
local CombatLogs = { Logs = {} }
function CombatLogs:Add(text, color)
    local log = { Text = text, Color = color or Color3.new(1, 1, 1), Time = M.clock() }
    M.insert(self.Logs, 1, log)
    if #self.Logs > 10 then M.remove(self.Logs) end
end
local function renderCombatLogs()
    for i, log in ipairs(CombatLogs.Logs) do
        local alpha = M.clamp(1 - (M.clock() - log.Time) / 5, 0, 1)
        if alpha <= 0 then M.remove(CombatLogs.Logs, i) continue end
    end
end
local M = { v2 = Vector2.new, v3 = Vector3.new, c3 = Color3.new, rgb = Color3.fromRGB, floor = math.floor, abs = math.abs, min = math.min, max = math.max, clamp = math.clamp, exp = math.exp, clock = os.clock, insert = table.insert, remove = table.remove, lower = string.lower, upper = string.upper, sin = math.sin, cos = math.cos, pi = math.pi }
local function getLocalCharacter()
    local root = WS:FindFirstChild("WORKSPACE_Entities")
    local folder = root and root:FindFirstChild("Players")
    return folder and folder:FindFirstChild(LP.Name) or LP.Character
end

local function playEmote(animObj)
    local char = getLocalCharacter()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or not animObj then return end
    if currentEmoteTrack then currentEmoteTrack:Stop(); currentEmoteTrack:Destroy(); currentEmoteTrack = nil end
    local anim = Instance.new("Animation")
    local found = false
    local function process(obj)
        if obj:IsA("Animation") then
            anim.AnimationId = obj.AnimationId
            found = true
        elseif obj:IsA("KeyframeSequence") then
            local s, res = pcall(function() return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(obj) end)
            if s and res then
                anim.AnimationId = res
                found = true
            end
        end
    end
    process(animObj)
    if not found then
        local child = animObj:FindFirstChildOfClass("Animation") or animObj:FindFirstChildOfClass("KeyframeSequence")
        if child then process(child) end
    end
    if not found then return end
    local animator = hum:FindFirstChildOfClass("Animator") or hum
    local success, track = pcall(function() return animator:LoadAnimation(anim) end)
    if success and track then
        currentEmoteTrack = track
        currentEmoteTrack.Priority = Enum.AnimationPriority.Action4
        
        -- Temporarily disable TWW's custom animation joints so native Roblox emotes can play properly
        pcall(function()
            local animHandlerMod = require(game:GetService("ReplicatedStorage").Modules.Character.AnimationHandler)
            local handler = animHandlerMod:GetHandler(char)
            if handler then handler:SetJointsEnabled(false) end
        end)
        
        track.Stopped:Connect(function()
            pcall(function()
                local animHandlerMod = require(game:GetService("ReplicatedStorage").Modules.Character.AnimationHandler)
                local handler = animHandlerMod:GetHandler(char)
                if handler then handler:SetJointsEnabled(true) end
            end)
        end)
        
        currentEmoteTrack:Play()
    end
end

task.spawn(function()
    while not Global do task.wait() end
    local function hook(t)
        if type(t) ~= "table" then return end
        if t.EnterRagdoll and t.ExitRagdoll then
            local oldEnter = t.EnterRagdoll
            t.EnterRagdoll = function(self, char, ...)
                if L.NoRagdoll and char == getLocalCharacter() then
                    return
                end
                return oldEnter(self, char, ...)
            end
        end
        if t.CreateRagdollForce then
            local oldForce = t.CreateRagdollForce
            t.CreateRagdollForce = function(self, part, ...)
                local char = getLocalCharacter()
                if L.NoRagdoll and char and part and part:IsDescendantOf(char) then
                    return
                end
                return oldForce(self, part, ...)
            end
        end
    end
    for k, v in pairs(Global) do hook(v) end
    pcall(function()
        local ragHandler = require(game:GetService("ReplicatedStorage").SharedModules.RagdollHandler)
        hook(ragHandler)
    end)
end)
local function getEntities(type)
    local root = WS:FindFirstChild("WORKSPACE_Entities")
    local folder = root and root:FindFirstChild(type or "Players")
    if not folder then return {} end
    if type == "NPCs" then
        local ents = {}
        for _, group in ipairs(folder:GetChildren()) do
            local model = group:FindFirstChild("Model")
            if model and model:IsA("Model") then table.insert(ents, model) end
        end
        return ents
    elseif type == "Animals" then
        local ents = {}
        for _, item in ipairs(folder:GetChildren()) do 
            if item:IsA("Model") then 
                if string.find(string.lower(item.Name), "horse") then continue end
                local owner = item:FindFirstChild("Owner")
                if not (owner and owner:IsA("StringValue") and owner.Value == LP.Name) then
                    table.insert(ents, item) 
                end
            end 
        end
        return ents
    end
    return folder:GetChildren()
end
local ragdollNames = {
    "RagdollConstraintUpperTorso", "RagdollConstraintHead", "RagdollConstraintLeftFoot",
    "RagdollConstraintLeftHand", "RagdollConstraintLeftLowerArm", "RagdollConstraintLeftLowerLeg",
    "RagdollConstraintLeftUpperArm", "RagdollConstraintLeftUpperLeg", "RagdollConstraintRightFoot",
    "RagdollConstraintRightHand", "RagdollConstraintRightLowerArm", "RagdollConstraintRightLowerLeg",
    "RagdollConstraintRightUpperArm", "RagdollConstraintRightUpperLeg"
}
local function isRagdolled(m)
    local data = espCache[m]
    if data and data.lastRagCheck and os.clock() - data.lastRagCheck < 0.1 then return data.ragdolled end
    local target = m:FindFirstChild("NPCTemplateNoHumanV4") or m
    local count = 0
    local total = #ragdollNames
    for i = 1, total do
        local c = target:FindFirstChild(ragdollNames[i])
        if c and c:IsA("BallSocketConstraint") and c.Enabled then
            count = count + 1
        end
    end
    local res = false
    if data and data.type == "NPCs" then
        res = (count == total)
    else
        res = (count >= 3)
    end
    if data then data.lastRagCheck, data.ragdolled = os.clock(), res end
    return res
end
local L = {
    Master = false, DMax = 2000, DistMode = "Studs", FIn = 0.15, FOut = 0.15, Font = 2, CB = "AlwaysOnTop", 
    NTC = Color3.fromRGB(255, 255, 255), WTC = Color3.fromRGB(255, 255, 255), 
    DTC = Color3.fromRGB(255, 255, 255), BC = Color3.fromRGB(255, 255, 255), 
    BFC = Color3.fromRGB(255, 255, 255), BFTrans = 0.5, HHC = Color3.fromRGB(0, 255, 0), HLC = Color3.fromRGB(255, 0, 0), HTC = Color3.fromRGB(255, 255, 255),
    SKC = Color3.fromRGB(255, 255, 255), CC = Color3.fromRGB(255, 255, 255), CFC = Color3.fromRGB(65, 169, 255),
    CTrans = 0.5, CFTrans = 0.5, SKTrans = 0, NPC_SKTrans = 0, Animal_SKTrans = 0, 
    LG_Enabled = false, LG_Color = Color3.fromRGB(65, 102, 158), LG_Trans = 0, LG_Mat = "ForceField", LG_FFAnim = "None",
    LG_HideHolsters = false, LG_HideGuns = false,
    LC_Enabled = false, LC_Color = Color3.fromRGB(255, 255, 255), LC_Trans = 0, LC_Mat = "ForceField", LC_FFAnim = "None",
    LH_Enabled = false, LH_Color = Color3.fromRGB(255, 255, 255), LH_Trans = 0, LH_Mat = "ForceField", LH_FFAnim = "None",
    VisOnly = false, FCase = "Normal",
    NPC_Master = false, NPC_DMax = 2000, NPC_DistMode = "Studs", NPC_CB = "AlwaysOnTop", 
    NPC_NTC = Color3.fromRGB(255, 255, 255), NPC_WTC = Color3.fromRGB(255, 255, 255), 
    NPC_DTC = Color3.fromRGB(255, 255, 255), NPC_BC = Color3.fromRGB(255, 255, 255), 
    NPC_BFC = Color3.fromRGB(255, 255, 255), NPC_BFTrans = 0.5, NPC_HHC = Color3.fromRGB(0, 255, 0), NPC_HLC = Color3.fromRGB(255, 0, 0), NPC_HTC = Color3.fromRGB(255, 255, 255),
    NPC_SKC = Color3.fromRGB(255, 255, 255), NPC_CC = Color3.fromRGB(255, 255, 255), NPC_CFC = Color3.fromRGB(65, 169, 255),
    NPC_CTrans = 0.5, NPC_CFTrans = 0.5, NPC_FCase = "Normal",
    Animal_Master = false, Animal_DMax = 2000, Animal_DistMode = "Studs", Animal_CB = "AlwaysOnTop", 
    Animal_NTC = Color3.fromRGB(255, 255, 255), Animal_WTC = Color3.fromRGB(255, 255, 255), 
    Animal_DTC = Color3.fromRGB(255, 255, 255), Animal_BC = Color3.fromRGB(255, 255, 255), 
    Animal_BFC = Color3.fromRGB(255, 255, 255), Animal_BFTrans = 0.5, Animal_HHC = Color3.fromRGB(94, 139, 255), Animal_HLC = Color3.fromRGB(255, 0, 0), Animal_HTC = Color3.fromRGB(255, 255, 255),
    Animal_SKC = Color3.fromRGB(255, 255, 255), Animal_CC = Color3.fromRGB(255, 255, 255), Animal_CFC = Color3.fromRGB(65, 169, 255),
    Animal_CTrans = 0.5, Animal_CFTrans = 0.5, Animal_FCase = "Normal", Animal_FS = 13,
    Animal_LegendaryOnly = false, Animal_LegendaryOverride = true, Animal_LegendaryColor = Color3.fromRGB(255, 255, 0),
    HGR = true, NPC_HGR = true, Animal_HGR = true, HGR_Anim = false, NPC_HGR_Anim = false, Animal_HGR_Anim = false, HGRS = 4, HGR_Type = "Pulsing Glow", NPC_HGR_Type = "Pulsing Glow", Animal_HGR_Type = "Pulsing Glow",
    ND = {}, WD = {}, DD = {}, BD = {}, BOD = {}, BFD = {}, HD = {}, HOD = {}, HTD = {}, HSD = {}, AC = {}, SKD = {},
    VH = {}, HTFC = {}, State = {TargetFade = {}}, Connections = {},
    SK_N = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}, SK_C = {{1, 2}, {2, 3}, {2, 4}, {2, 5}, {2, 6}},
    R15_N = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"},
    R15_C = {{1,2}, {2,3}, {2,4}, {4,5}, {5,6}, {2,7}, {7,8}, {8,9}, {3,10}, {10,11}, {11,12}, {3,13}, {13,14}, {14,15}},
    SA_Enabled = false, SA_Backtrack = false, SA_MaxDist = 1000, SA_FOV = 130, SA_FOV_Vis = false, SA_HitChance = 100, SA_TargetPart = "Head", SA_ClosestPart = false, SA_WallCheck = false,
    SA_Snapline = false, SA_Snapline_Color = Color3.fromRGB(255, 255, 255), SA_Targets = {Players = true, NPCs = false, Animals = false},
    SA_FOV_Gradient = false, SA_FOV_Grad1 = Color3.new(1, 1, 1), SA_FOV_Grad2 = Color3.fromRGB(125, 151, 255), SA_FOV_Speed = 1,
    SA_FOV_Color = Color3.new(1,1,1), SA_FOV_Transparency = 0, SA_FOV_Rot = 0, SA_FOV_Thickness = 1.5,
    SA_HighlightTarget = false, SA_Highlight_Color = Color3.fromRGB(255, 0, 0), HideProtected = false, FS = 13, SA_Dynamic_FOV = false,
    Aim_Enabled = false, Aim_Type = "Mouse", Aim_Smoothness = 1, Aim_MaxDist = 1000, Aim_BulletDrop = false, Aim_BulletLead = false, Aim_FOV = 130, Aim_FOV_Vis = false, Aim_TargetPart = "Head", Aim_WallCheck = false, Aim_StickyAim = false, Aim_DuelOnly = false,
    Aim_Snapline = false, Aim_Snapline_Color = Color3.fromRGB(255, 255, 255), Aim_Targets = {Players = true, NPCs = false, Animals = false},
    Aim_FOV_Gradient = false, Aim_FOV_Grad1 = Color3.new(1, 1, 1), Aim_FOV_Grad2 = Color3.fromRGB(125, 151, 255), Aim_FOV_Speed = 1,
    Aim_FOV_Color = Color3.new(1,1,1), Aim_FOV_Transparency = 0, Aim_FOV_Rot = 0, Aim_FOV_Thickness = 1.5, Aim_Dynamic_FOV = false,
    Aim_HighlightTarget = false, Aim_Highlight_Color = Color3.fromRGB(255, 0, 0), OverwriteDuelOpponent = false, OverwriteDuelColor = Color3.fromRGB(255, 0, 0), SA_DuelOnly = false,
    FE = false, FCOC = Color3.fromRGB(0, 255, 0), PE = false, PCOC = Color3.fromRGB(255, 0, 0), WFE = false, Friendlies = {}, Priorities = {},
    GM_NoRecoil = false, GM_RecoilAmount = 0, GM_NoSpread = false, GM_SpreadAmount = 0, GM_InstantReload = false, GM_ReloadSpeedModifier = false, GM_ReloadSpeedAmount = 2, GM_InfWallbang = false, GM_RapidFire = false, GM_AutoReload = false, GM_AutoSwap = false, GM_NoScope = false,
    OriginalStats = {}, ActiveShots = {},
    DI_Enabled = false, DI_Name = false, DI_NameColor = Color3.fromRGB(255, 255, 255), DI_Distance = false, DI_DistanceColor = Color3.fromRGB(255, 255, 255), DI_Measuring = "Studs", DI_Sort = {Ore = true, Gems = true, ["Animal Drops"] = true, Others = true},
    DI_LegendaryOverride = true, DI_LegendaryColor = Color3.fromRGB(255, 255, 0), DI_Font = 2, DI_FontCase = "Normal", DI_FontSize = 13, DI_MaxDistance = 10000,
    DI_Labels = {}, DI_Cache = {},
    TS_Enabled = false, TS_Name = false, TS_NameColor = Color3.fromRGB(255, 0, 0), TS_Distance = false, TS_DistanceColor = Color3.fromRGB(255, 255, 255), TS_Measuring = "Studs", TS_Sort = {Tree = true, Cactus = true}, TS_Notify = false, TS_Font = 2, TS_FontCase = "Normal", TS_FontSize = 13, TS_MaxDistance = 10000, TS_Cache = {},
    SpeedEnabled = false, SpeedAmount = 25, FlyEnabled = false, FlySpeed = 50, NoJumpDelay = false, NoRagdoll = false, InfStamina = false, NoFallDamage = false, AutoGetUp = false, AutoBreakFree = false, EmotePackEnabled = false, ClapSpeedMultiplier = false, ClapSpeedAmount = 3, RollSpeedModifier = false, RollSpeedAmount = 1.25,
    BulletTracers = false, BulletTracersColor = Color3.fromRGB(136, 159, 255), BulletTracersColor2 = Color3.fromRGB(255, 255, 255), BulletTracersSize = 0.2, BulletTracersDuration = 1, BulletTracersStyle = "None",
    EnemyBulletTracers = false, EnemyBulletTracersColor = Color3.fromRGB(118, 52, 52), EnemyBulletTracersColor2 = Color3.fromRGB(255, 255, 255), EnemyBulletTracersSize = 0.2, EnemyBulletTracersDuration = 1, EnemyBulletTracersStyle = "None",
    NoFog = false, FullBright = false, AtmosphereOverride = false, ColorCorrectionOverride = false, BloomOverride = false, TimeOfDayEnabled = false, AmbientOverride = false,
    MBF_Enabled = false, MBF_Radius = 25, MBF_ShowRadius = false, MBF_RadiusColor = Color3.fromRGB(255, 255, 255), MBF_Status = "Inactive"
}
local UIS = game:GetService("UserInputService")
local O = { Stamina = {}, Kick = {}, Roll = {}, Stats = {} }
local State = { esp = {}, SA = { Transparency = 0, LerpPos = nil, CurrentTarget = nil, SmoothedFOV = 130 }, Aim = { Transparency = 0, LerpPos = nil, CurrentTarget = nil, SmoothedFOV = 130 }, crossLines = {}, circlePts = {} }
local Global, Network = nil, nil
pcall(function() Global = require(game:GetService("ReplicatedStorage").SharedModules.Global); Network = Global.Network end)
local Modules = {}
pcall(function()
    if Global and Global.LoadModule then
        local loadModule = Global.LoadModule
        Modules.Network = Global.Network
        Modules.plrCharacter = loadModule("PlayerCharacter")
        Modules.repState = loadModule("ReplicatedState")
    end
end)

local function wwguard(p270, p271)
    return function(...)
        local success, v272 = pcall(debug.getconstants, 2)
        if success and not table.find(v272, "StackSize") then
            return p271(...)
        end
        return p270(...)
    end
end
local UI = {
    fovO = Drawing.new("Circle"), fov = Drawing.new("Circle"), fovL = {}, fovOL = {},
    aimFovO = Drawing.new("Circle"), aimFov = Drawing.new("Circle"), aimFovL = {}, aimFovOL = {},
    snapO = Drawing.new("Line"), snap = Drawing.new("Line"),
    aimSnapO = Drawing.new("Line"), aimSnap = Drawing.new("Line")
}
UI.fovO.Thickness = 3; UI.fovO.NumSides = 100; UI.fovO.Radius = 130; UI.fovO.Filled = false; UI.fovO.Visible = false; UI.fovO.ZIndex = 998; UI.fovO.Transparency = 1; UI.fovO.Color = Color3.new(0,0,0)
UI.fov.Thickness = 1; UI.fov.NumSides = 100; UI.fov.Radius = 130; UI.fov.Filled = false; UI.fov.Visible = false; UI.fov.ZIndex = 999; UI.fov.Transparency = 1; UI.fov.Color = Color3.fromRGB(255, 255, 255)
for i = 1, 120 do
    local l = Drawing.new("Line")
    l.Thickness = 2.5; l.Visible = false; l.ZIndex = 1000; l.Transparency = 1
    UI.fovL[i] = l
end
for i = 1, 120 do
    local l = Drawing.new("Line")
    l.Thickness = 4.5; l.Visible = false; l.ZIndex = 999; l.Transparency = 1; l.Color = Color3.new(0,0,0)
    UI.fovOL[i] = l
end
local circlePoints = {}
for i = 1, 121 do
    local angle = (i - 1) * ((math.pi * 2) / 120)
    circlePoints[i] = {x = math.cos(angle), y = math.sin(angle)}
end
UI.snapO.Thickness = 3; UI.snapO.ZIndex = 998; UI.snapO.Visible = false; UI.snapO.Color = Color3.new(0,0,0)
UI.snap.Thickness = 1; UI.snap.ZIndex = 999; UI.snap.Visible = false; UI.snap.Color = Color3.fromRGB(255, 255, 255)

UI.aimFovO.Thickness = 3; UI.aimFovO.NumSides = 100; UI.aimFovO.Radius = 130; UI.aimFovO.Filled = false; UI.aimFovO.Visible = false; UI.aimFovO.ZIndex = 998; UI.aimFovO.Transparency = 1; UI.aimFovO.Color = Color3.new(0,0,0)
UI.aimFov.Thickness = 1; UI.aimFov.NumSides = 100; UI.aimFov.Radius = 130; UI.aimFov.Filled = false; UI.aimFov.Visible = false; UI.aimFov.ZIndex = 999; UI.aimFov.Transparency = 1; UI.aimFov.Color = Color3.fromRGB(255, 255, 255)
for i = 1, 120 do
    local l = Drawing.new("Line")
    l.Thickness = 2.5; l.Visible = false; l.ZIndex = 1000; l.Transparency = 1
    UI.aimFovL[i] = l
end
for i = 1, 120 do
    local l = Drawing.new("Line")
    l.Thickness = 4.5; l.Visible = false; l.ZIndex = 999; l.Transparency = 1; l.Color = Color3.new(0,0,0)
    UI.aimFovOL[i] = l
end
UI.aimSnapO.Thickness = 3; UI.aimSnapO.ZIndex = 998; UI.aimSnapO.Visible = false; UI.aimSnapO.Color = Color3.new(0,0,0)
UI.aimSnap.Thickness = 1; UI.aimSnap.ZIndex = 999; UI.aimSnap.Visible = false; UI.aimSnap.Color = Color3.fromRGB(255, 255, 255)
local v3_T, v3_B = Vector3.new(0, 3, 0), Vector3.new(0, 3.5, 0)
local FM = { ['UI'] = 0, ['System'] = 1, ['Plex'] = 2, ['Monospace'] = 3 }
local function getTargetPart(ent, mode)
    mode = mode or "SA"
    local data = espCache[ent]
    local target = ent:FindFirstChild("NPCTemplateNoHumanV4") or ent
    if mode == "SA" and L.SA_ClosestPart then
        local closest, minDist = nil, 9999
        local mousePos = UIS:GetMouseLocation()
        if not data.hitboxParts then 
            data.hitboxParts = {}
            for _, p in ipairs(target:GetDescendants()) do
                if p:IsA("BasePart") and (p.Name == "Head" or p.Name:find("Torso") or p.Name:find("Arm") or p.Name:find("Leg") or p.Name:find("Hand") or p.Name:find("Foot")) then
                    M.insert(data.hitboxParts, p)
                end
            end
            if #data.hitboxParts == 0 then
                for _, p in ipairs(target:GetDescendants()) do
                    if p:IsA("BasePart") then M.insert(data.hitboxParts, p) end
                end
            end
        end
        for _, p in ipairs(data.hitboxParts) do
            if p.Parent and p.Transparency < 1 then
                local sP, oS = C:WorldToViewportPoint(p.Position)
                if oS then
                    local dist = (M.v2(sP.X, sP.Y) - mousePos).Magnitude
                    if dist < minDist then closest = p; minDist = dist end
                end
            end
        end
        local res = closest or target:FindFirstChild("Head", true) or target:FindFirstChild("HumanoidRootPart", true)
        if data then data["targetPart_"..mode] = res end
        return res
    else
        local pName = mode == "SA" and L.SA_TargetPart or L.Aim_TargetPart
        local now = M.clock()
        
        if data and data["targetPart_"..mode] and data["targetPart_"..mode].Parent and data["lastTargetSetting_"..mode] == pName then
            if pName ~= "Random" then
                local cachedName = data["targetPart_"..mode].Name
                if cachedName == pName or (pName == "Torso" and (cachedName == "UpperTorso" or cachedName == "LowerTorso")) then
                    return data["targetPart_"..mode]
                end
            elseif data["lastRandomUpdate_"..mode] and (now - data["lastRandomUpdate_"..mode]) < 0.1 then
                return data["targetPart_"..mode]
            end
        end
        
        local res = nil
        if pName == "Random" then
            local parts = {"Head", "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart"}
            local validParts = {}
            for _, name in ipairs(parts) do
                local p = target:FindFirstChild(name, true)
                if p and p:IsA("BasePart") then M.insert(validParts, p) end
            end
            if #validParts > 0 then
                res = validParts[math.random(1, #validParts)]
            end
            if data then data["lastRandomUpdate_"..mode] = now end
        else
            res = target:FindFirstChild(pName, true)
            if not res then
                if pName == "Torso" then
                    res = target:FindFirstChild("UpperTorso", true) or target:FindFirstChild("LowerTorso", true)
                elseif pName == "UpperTorso" or pName == "LowerTorso" then
                    res = target:FindFirstChild("Torso", true)
                end
            end
        end
        
        if not res then
            res = target:FindFirstChild("HumanoidRootPart", true) or target:FindFirstChild("Head", true) or target:FindFirstChild("Torso", true) or target:FindFirstChildOfClass("BasePart")
        end
        
        if data then
            data["targetPart_"..mode] = res
            data["lastTargetSetting_"..mode] = pName
        end
        return res
    end
end
local function isVisible(part, origin)
    if not L.SA_WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LP.Character, part.Parent}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local res = WS:Raycast(origin, part.Position - origin, params)
    return res == nil
end
local ProjectileHandlerHooked = false
local ProjectileHandlerHooked = false
local function updateGunMods()
    if not ProjectileHandlerHooked then
        pcall(function()
            local projHandler = game:GetService("ReplicatedStorage"):FindFirstChild('ProjectileHandler', true)
            if projHandler then
                local env = getsenv(projHandler)
                local oldRaycast = env.Raycast
                if oldRaycast then
                    env.Raycast = function(...)
                        local args = {...}
                        local self = args[1]
                        if L.GM_InfWallbang and type(self) == "table" and self.IsOwner then
                            local ignore = args[4]
                            local geometryFolders = {
                                workspace.Terrain,
                                workspace:FindFirstChild("WORKSPACE_Geometry"),
                                workspace:FindFirstChild("WORKSPACE_Interactables"),
                                workspace:FindFirstChild("Ignore"),
                                workspace:FindFirstChild("WORKSPACE_Debris")
                            }
                            
                            if type(ignore) == "table" then
                                for _, folder in ipairs(geometryFolders) do
                                    if folder and not table.find(ignore, folder) then
                                        table.insert(ignore, folder)
                                    end
                                end
                            elseif typeof(ignore) == "RaycastParams" then
                                local list = ignore.FilterDescendantsInstances
                                local changed = false
                                for _, folder in ipairs(geometryFolders) do
                                    if folder and not table.find(list, folder) then
                                        table.insert(list, folder)
                                        changed = true
                                    end
                                end
                                if changed then ignore.FilterDescendantsInstances = list end
                            end
                        end
                        return oldRaycast(unpack(args))
                    end
                    ProjectileHandlerHooked = true
                end
            end
        end)
    end
    local success, Global = pcall(function() return require(game:GetService("ReplicatedStorage").SharedModules.Global) end)
    if not success or not Global or not Global.SharedData then return end
    local PlayerItems = Global.SharedData.PlayerItems
    if not PlayerItems then return end
    for itemName, data in pairs(PlayerItems) do
        if typeof(data) == "table" and data.Weapon == true then
            if not L.OriginalStats[itemName] then
                L.OriginalStats[itemName] = {
                    BaseRecoil = data.BaseRecoil,
                    ProjectileAccuracy = data.ProjectileAccuracy,
                    HorseAccuracyModifier = data.HorseAccuracyModifier,
                    FanAccuracyModifier = data.FanAccuracyModifier or 1,
                    ReloadSpeed = data.ReloadSpeed,
                    LoadSpeed = data.LoadSpeed,
                    LoadEndSpeed = data.LoadEndSpeed,
                    ProjectilePenetration = data.ProjectilePenetration,
                    FireRate = data.FireRate or 1,
                    ShotCooldown = data.ShotCooldown or 1,
                    TriggerDelay = data.TriggerDelay or 0,
                    HammerSpeed = data.HammerSpeed or 1,
                    BurstCooldown = data.BurstCooldown or 0,
                    EquipTime = data.EquipTime or 0,
                    RecoilWait = data.RecoilWait or 0,
                    ShootWait = data.ShootWait or 0,
                    Cooldown = data.Cooldown or 0,
                    CanBeHipFired = data.CanBeHipFired,
                    FireSpeed = data.FireSpeed,
                    FanSpeed = data.FanSpeed,
                    CustomShootingSpeed = data.CustomShootingSpeed,
                    BurstInterval = data.BurstInterval,
                    BurstDelay = data.BurstDelay,
                    LoadStartSpeed = data.LoadStartSpeed
                }
            end
            local orig = L.OriginalStats[itemName]
            if orig.BaseRecoil ~= nil then
                if L.GM_NoRecoil then
                    data.BaseRecoil = orig.BaseRecoil * (L.GM_RecoilAmount / 100)
                else
                    data.BaseRecoil = orig.BaseRecoil
                end
            end
            if L.GM_NoSpread then
                local spreadScale = L.GM_SpreadAmount / 100
                if orig.ProjectileAccuracy ~= nil then data.ProjectileAccuracy = 1 - (1 - orig.ProjectileAccuracy) * spreadScale end
                if orig.HorseAccuracyModifier ~= nil then data.HorseAccuracyModifier = 1 - (1 - orig.HorseAccuracyModifier) * spreadScale end
                if orig.FanAccuracyModifier ~= nil then data.FanAccuracyModifier = spreadScale == 0 and 1 or (1 - (1 - orig.FanAccuracyModifier) * spreadScale) end
            else
                data.ProjectileAccuracy = orig.ProjectileAccuracy
                data.HorseAccuracyModifier = orig.HorseAccuracyModifier
                data.FanAccuracyModifier = orig.FanAccuracyModifier
            end
            if L.GM_InstantReload then
                if orig.ReloadSpeed ~= nil then data.ReloadSpeed = 100 end
                if orig.LoadSpeed ~= nil then data.LoadSpeed = 100 end
                if orig.LoadEndSpeed ~= nil then data.LoadEndSpeed = 100 end
            elseif L.GM_ReloadSpeedModifier then
                local m = L.GM_ReloadSpeedAmount or 1
                if orig.ReloadSpeed ~= nil then data.ReloadSpeed = orig.ReloadSpeed * m end
                if orig.LoadSpeed ~= nil then data.LoadSpeed = orig.LoadSpeed * m end
                if orig.LoadEndSpeed ~= nil then data.LoadEndSpeed = orig.LoadEndSpeed * m end
            else
                data.ReloadSpeed = orig.ReloadSpeed
                data.LoadSpeed = orig.LoadSpeed
                data.LoadEndSpeed = orig.LoadEndSpeed
            end
            if L.GM_RapidFire then
                data.FireRate = 999; data.ShotCooldown = 0; data.TriggerDelay = 0; data.HammerSpeed = 999; data.BurstCooldown = 0; data.EquipTime = 0; data.RecoilWait = 0; data.ShootWait = 0; data.Cooldown = 0
                data.FireSpeed = 9999; data.FanSpeed = 9999; data.CustomShootingSpeed = 0; data.BurstInterval = 0; data.BurstDelay = 0; data.LoadStartSpeed = 9999
            else
                data.FireRate = orig.FireRate
                data.ShotCooldown = orig.ShotCooldown
                data.TriggerDelay = orig.TriggerDelay
                data.HammerSpeed = orig.HammerSpeed
                data.BurstCooldown = orig.BurstCooldown
                data.EquipTime = orig.EquipTime
                data.RecoilWait = orig.RecoilWait
                data.ShootWait = orig.ShootWait
                data.Cooldown = orig.Cooldown
                data.FireSpeed = orig.FireSpeed
                data.FanSpeed = orig.FanSpeed
                data.CustomShootingSpeed = orig.CustomShootingSpeed
                data.BurstInterval = orig.BurstInterval
                data.BurstDelay = orig.BurstDelay
                data.LoadStartSpeed = (L.GM_ReloadSpeedModifier and not L.GM_InstantReload) and (orig.LoadStartSpeed or 1) * L.GM_ReloadSpeedAmount or orig.LoadStartSpeed
            end
            if orig.ProjectilePenetration ~= nil then
                data.ProjectilePenetration = L.GM_InfWallbang and 9e9 or orig.ProjectilePenetration
            end
            if orig.CanBeHipFired ~= nil then
                data.CanBeHipFired = L.GM_NoScope and true or orig.CanBeHipFired
            end
        end
    end
    pcall(function()
        local sharpsMod = require(game:GetService("ReplicatedStorage").Modules.Character.Items.Guns.SharpsRifleItem)
        if not L.OriginalStats["SharpsRifleMod"] then L.OriginalStats["SharpsRifleMod"] = { CanBeHipFired = sharpsMod.CanBeHipFired } end
        sharpsMod.CanBeHipFired = L.GM_NoScope and true or L.OriginalStats["SharpsRifleMod"].CanBeHipFired
    end)
    pcall(function()
        local Global = require(game:GetService("ReplicatedStorage").SharedModules.Global)
        local GunItemType = Global:LoadModule("GunItemType")
        if not GunItemType._RoxyHooked then
            GunItemType._RoxyHooked = true
            local oldCanShoot = GunItemType.CanShoot
            GunItemType.CanShoot = function(self, ...)
                if L.GM_RapidFire then
                    self.LastEquipped = 0
                    self.StartedAiming = 0
                    self.NonIdleAnimStarted = 0
                    if type(self.BurstShooting) == "number" then self.BurstShooting = nil end
                    self.IsLoading = false
                    self.UnequipBlocked = false
                end
                return oldCanShoot(self, ...)
            end
        end
    end)
    pcall(function()
        local Global = require(game:GetService("ReplicatedStorage").SharedModules.Global)
        if Global.PlayerCharacter and Global.PlayerCharacter.Items then
            for _, item in pairs(Global.PlayerCharacter.Items) do
                if item.SharedData and item.SharedData.Weapon and Global.SharedData.PlayerItems then
                    local template = Global.SharedData.PlayerItems[item.ItemName or item.Name]
                    if template then
                        for k, v in pairs(template) do
                            if item.SharedData[k] ~= nil or v ~= nil then
                                item.SharedData[k] = v
                            end
                        end
                    end
                end
            end
        end
    end)
end

local worldOriginals = {}
local updatingWorld = false
local function updateWorldVisuals()
    if updatingWorld then return end
    updatingWorld = true
    
    local lighting = S.Lighting
    
    if L.NoFog then
        if not worldOriginals.Fog then worldOriginals.Fog = {End = lighting.FogEnd, Start = lighting.FogStart} end
        if lighting.FogEnd ~= 100000 then lighting.FogEnd = 100000 end
        if lighting.FogStart ~= 0 then lighting.FogStart = 0 end
        local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere then
            if not worldOriginals.AtmosphereDensity then worldOriginals.AtmosphereDensity = atmosphere.Density end
            if atmosphere.Density ~= 0 then atmosphere.Density = 0 end
        end
    else
        if worldOriginals.Fog then 
            lighting.FogEnd = worldOriginals.Fog.End; lighting.FogStart = worldOriginals.Fog.Start; worldOriginals.Fog = nil 
        end
        local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere and worldOriginals.AtmosphereDensity then 
            atmosphere.Density = worldOriginals.AtmosphereDensity; worldOriginals.AtmosphereDensity = nil 
        end
    end

    if L.FullBright then
        if not worldOriginals.Bright then worldOriginals.Bright = {Ambient = lighting.Ambient, OutdoorAmbient = lighting.OutdoorAmbient, Brightness = lighting.Brightness} end
        local white = Color3.new(1, 1, 1)
        if lighting.Ambient ~= white then lighting.Ambient = white end
        if lighting.OutdoorAmbient ~= white then lighting.OutdoorAmbient = white end
        if lighting.Brightness ~= 2 then lighting.Brightness = 2 end
    else
        if worldOriginals.Bright then 
            lighting.Ambient = worldOriginals.Bright.Ambient; lighting.OutdoorAmbient = worldOriginals.Bright.OutdoorAmbient; lighting.Brightness = worldOriginals.Bright.Brightness; worldOriginals.Bright = nil 
        end
    end

    if L.AtmosphereOverride then
        local atm = lighting:FindFirstChildOfClass("Atmosphere")
        if atm then
            if not worldOriginals.AtmosphereColor then worldOriginals.AtmosphereColor = atm.Color end
            local target = Options.AtmosphereColor.Value
            if atm.Color ~= target then atm.Color = target end
        end
    end

    if L.ColorCorrectionOverride then
        local cc = lighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if cc then
            if not worldOriginals.ColorCorrectionTintColor then worldOriginals.ColorCorrectionTintColor = cc.TintColor end
            local target = Options.ColorCorrectionColor.Value
            if cc.TintColor ~= target then cc.TintColor = target end
        end
    end

    if L.BloomOverride then
        local bloom = lighting:FindFirstChildOfClass("BloomEffect")
        if bloom then
            if not worldOriginals.Bloom then worldOriginals.Bloom = {Intensity = bloom.Intensity, Threshold = bloom.Threshold, Size = bloom.Size} end
            local i, t, s = Options.BloomIntensity.Value, Options.BloomThreshold.Value, Options.BloomSize.Value
            if bloom.Intensity ~= i then bloom.Intensity = i end
            if bloom.Threshold ~= t then bloom.Threshold = t end
            if bloom.Size ~= s then bloom.Size = s end
        end
        local tint = lighting:FindFirstChild("ROXY_BloomTint") or Instance.new("ColorCorrectionEffect", lighting)
        tint.Name = "ROXY_BloomTint"
        local target = Options.BloomColor.Value
        if tint.TintColor ~= target then tint.TintColor = target end
        if not tint.Enabled then tint.Enabled = true end
    else
        local tint = lighting:FindFirstChild("ROXY_BloomTint")
        if tint then tint:Destroy() end
    end

    if L.TimeOfDayEnabled then
        if not worldOriginals.ClockTime then worldOriginals.ClockTime = lighting.ClockTime end
        local target = Options.WorldClockTime.Value
        if lighting.ClockTime ~= target then lighting.ClockTime = target end
    end

    if L.AmbientOverride then
        if not worldOriginals.Ambient then worldOriginals.Ambient = lighting.Ambient end
        if not worldOriginals.OutdoorAmbient then worldOriginals.OutdoorAmbient = lighting.OutdoorAmbient end
        local aC, oC = Options.AmbientColor.Value, Options.OutdoorAmbientColor.Value
        if lighting.Ambient ~= aC then lighting.Ambient = aC end
        if lighting.OutdoorAmbient ~= oC then lighting.OutdoorAmbient = oC end
    end
    
    updatingWorld = false
end

task.spawn(function()
    while task.wait(1) do
        if Library.Unloaded then break end
        if L.NoFog or L.FullBright or L.TimeOfDayEnabled or L.AmbientOverride or L.ColorCorrectionOverride or L.BloomOverride then
            updateWorldVisuals()
        end
    end
end)
local WeaponProfiles = {
    ["SharpsRifle"] = { Speed = 1800, Drop = 0.5 },
    ["SpitfireRevolvingSniper"] = { Speed = 1800, Drop = 0.5 },
    ["HartfordRifle"] = { Speed = 1400, Drop = 10 },
    ["YellowBoyRifle"] = { Speed = 1250, Drop = 10 },
    ["Peacekeeper"] = { Speed = 1000, Drop = 34 },
    ["Model3"] = { Speed = 1000, Drop = 34 },
    ["Cattleman"] = { Speed = 1000, Drop = 34 },
    ["NavyRevolver"] = { Speed = 1000, Drop = 34 },
    ["LeMat"] = { Speed = 1000, Drop = 34 },
}

local function getWeaponStats()
    if not Global then 
        pcall(function() 
            Global = require(game:GetService("ReplicatedStorage").SharedModules.Global)
        end)
    end
    if not Global then return nil, nil end

    local char = getLocalCharacter()
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return nil, nil end
    
    local toolName = tool.Name
    local toolId = toolName:gsub(" ", "")

    -- 1. Try to get SharedData directly from the equipped item object (Live data)
    local success, data = pcall(function()
        if Global.PlayerCharacter and Global.PlayerCharacter.GetEquippedItem then
            local item = Global.PlayerCharacter:GetEquippedItem()
            if item and item.SharedData then
                return item.SharedData
            end
        end
        return nil
    end)
    
    if success and data then return data, toolId end

    -- 2. Fallback: Look up in PlayerItems using sanitized ID
    if Global.SharedData and Global.SharedData.PlayerItems then
        return Global.SharedData.PlayerItems[toolId] or Global.SharedData.PlayerItems[toolName], toolId
    end

    return nil, toolId
end

local function getAccurateAimPosition(target, origin, stats, toolId)
    local success, res, t_out = pcall(function()
        local part = getTargetPart(target)
        if not part then return nil, 0 end
        
        local targetPos = part.Position
        local data = espCache[target]
        
        -- Robust velocity calculation
        local targetVel = M.v3(0, 0, 0)
        local hrp = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso") or target:FindFirstChild("Head")
        if hrp and hrp:IsA("BasePart") then
            targetVel = hrp.AssemblyLinearVelocity or hrp.Velocity or M.v3(0, 0, 0)
        end
        
        if targetVel.Magnitude < 0.1 and data and data.velocity then
            targetVel = data.velocity
        end
        
        -- TRUE BACKTRACK: If backtrack is on, force velocity to 0 to aim EXACTLY at their past position
        if L.SA_Backtrack then
            targetVel = M.v3(0, 0, 0)
        end
        
        local speed = 1000
        local gravity = 34
        
        -- Step 1: Always extract EXACT speed from Live Game Data for mathematically perfect lead
        if stats then
            speed = stats.ProjectileSpeed or stats.ProjectileVelocity or stats.BulletSpeed or stats.Speed or 1000
        end
        
        -- Step 2: Use WeaponProfiles to override Drop/Gravity to fix long-range overshooting
        local profile = toolId and WeaponProfiles and WeaponProfiles[toolId]
        if profile then
            -- Only use profile speed if live data failed
            if speed == 1000 and profile.Speed then speed = profile.Speed end
            -- Always trust profile Drop to prevent sniper overshooting
            gravity = profile.Drop or 34
        elseif stats then
            gravity = stats.ProjectileDrop or stats.ProjectileGravity or stats.BulletDrop or stats.Gravity or 34
        end
        
        local function SolveTime(p1, s, p2, grav)
            local diff = p2 - p1
            local horiz = M.v3(diff.X, 0, diff.Z)
            local t2 = horiz.Magnitude / math.max(s, 1)
            if t2 == 0 then t2 = 0.001 end
            local vY = (diff.Y + 0.5 * math.abs(grav) * t2 * t2) / t2
            local vHoriz = horiz.Unit * s
            return M.v3(vHoriz.X, vY, vHoriz.Z), t2
        end

        local aimPos = targetPos
        local reqVel = M.v3(0, 0, 0)
        local t = 0
        
        for i = 1, 5 do
            aimPos = targetPos + (targetVel * t)
            reqVel, t = SolveTime(origin, speed, aimPos, gravity)
        end
        
        return origin + reqVel, t
    end)
    
    if success and res then
        return res, t_out
    end
    return nil, 0
end
local function isProtected(ent)
    local data = espCache[ent]
    if not data then return false end
    if data.lastProtCheck and os.clock() - data.lastProtCheck < 0.25 then return data.isProt end
    data.lastProtCheck = os.clock()
    local frame = data.hF
    if not frame or not frame.Parent then
        local head = ent:FindFirstChild("Head")
        local status = head and head:FindFirstChild("PlayerStatus")
        local container = status and status:FindFirstChild("HealthBarContainer")
        local bar = container and container:FindFirstChild("HealthBar")
        frame = bar and bar:FindFirstChild("HealthProgressFrame")
        data.hF = frame
    end
    if frame then
        local color = frame.BackgroundColor3
        local r, g, b = M.floor(color.R * 255), M.floor(color.G * 255), M.floor(color.B * 255)
        if (r == 255 and g == 219 and b == 147) or (r == 195 and g == 77 and b == 61) then
            data.isProt = true; return true
        end
    end
    data.isProt = false; return false
end
local function getClosestPlayerToMouse()
    return SA_State.CurrentTarget
end
local ManagedBullets = {}
local oldFireServer
task.spawn(function()
    while true do
        if Network and Network.FireServer and not oldFireServer then
            oldFireServer = hookfunction(Network.FireServer, function(...)
                local args = {...}
                if args[2] == "LowerStamina" and L.InfStamina then return end
                if (args[2] == "DamageSelf" or args[2] == "TrainSmack") and L.NoFallDamage then return end
                if args[2] == "ProjectileEvent" or args[2] == "RemoveProjectile" then
                    if ManagedBullets[args[3]] then return end
                    if args[5] == "Final" and args[6] == nil then return end
                end

                local isInit = false
                for i = 1, #args do
                    if args[i] == "InitProjectiles" then
                        isInit = true
                        break
                    end
                end

                if L.SA_Enabled and isInit then
                    local Target = SA_State.CurrentTarget
                    if Target and math.random(1, 100) <= L.SA_HitChance then
                        local data
                        local bullets
                        for i = 1, #args do
                            if type(args[i]) == "table" and args[i].origin then
                                data = args[i]
                                bullets = args[i+1]
                                break
                            end
                        end
                        
                        if data then
                            local stats, toolId = getWeaponStats()
                            local speed = 1000
                            if stats then
                                speed = stats.ProjectileSpeed or stats.ProjectileVelocity or stats.BulletSpeed or stats.Speed or 1000
                            end
                            local targetPart = getTargetPart(Target, "SA")
                            local aimPos, timeOfFlight = getAccurateAimPosition(Target, data.origin, stats, toolId)
                            if aimPos then
                                data.direction = (aimPos - data.origin).Unit
                                if L.SA_Backtrack then
                                    if type(bullets) == "table" then
                                        for _, bId in pairs(bullets) do ManagedBullets[bId] = true end
                                        
                                        oldFireServer(unpack(args))
                                        
                                        local targetHitPos = targetPart.Position
                                        local targetCF = targetPart.CFrame
                                        local isPlayer = game.Players:GetPlayerFromCharacter(Target) ~= nil
                                        local isNPC = Target:IsDescendantOf(workspace:WaitForChild("WORKSPACE_Entities"):WaitForChild("NPCs"))
                                        local isAnimal = Target:IsDescendantOf(workspace:WaitForChild("WORKSPACE_Entities"):WaitForChild("Animals"))
                                        
                                        task.spawn(function()
                                            task.wait(timeOfFlight)
                                            local SyncedTime = os.time()
                                            pcall(function()
                                                local g = require(game:GetService("ReplicatedStorage").SharedModules.Global)
                                                SyncedTime = g.SyncedTime:GetTime()
                                            end)
                                            
                                            for _, bId in pairs(bullets) do
                                                local ref = nil
                                                pcall(function() ref = Network:GetReference(targetPart, 'CharacterPart') end)
                                                if not isPlayer or ref then
                                                    if isNPC then
                                                        ref = {Target.Parent.Parent, Target.Name}
                                                    elseif isAnimal then
                                                        ref = targetPart or ref
                                                    end
                                                    
                                                    oldFireServer(args[1], "ProjectileEvent", bId, SyncedTime, "Final", ref or Target,
                                                        targetCF:PointToObjectSpace(targetHitPos),
                                                        targetCF:VectorToObjectSpace(Vector3.FromNormalId(Enum.NormalId.Front)),
                                                        targetCF:VectorToObjectSpace(data.direction),
                                                        targetHitPos,
                                                        Vector3.FromNormalId(Enum.NormalId.Front),
                                                        targetPart.Material.Name)
                                                    
                                                    task.defer(oldFireServer, args[1], "RemoveProjectile", bId)
                                                    ManagedBullets[bId] = nil
                                                end
                                            end
                                        end)
                                        return
                                    end
                                end
                            end
                        end
                    end
                end
                return oldFireServer(...)
            end)
            break
        elseif not Network then
            pcall(function() 
                local g = require(game:GetService("ReplicatedStorage").SharedModules.Global)
                Network = g and g.Network
            end)
        end
        task.wait(1)
    end
end)



local oldNewIndex
oldNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
    if not checkcaller() then
        if L.NoJumpDelay and key == "Jump" and value == false then
            local char = getLocalCharacter()
            if self:IsA("Humanoid") and self.Parent == char and UIS:IsKeyDown(Enum.KeyCode.Space) and self.FloorMaterial ~= Enum.Material.Air then
                return oldNewIndex(self, key, true)
            end
        end
        if L.NoRagdoll then
            if self:IsA("Humanoid") and key == "PlatformStand" and value == true then
                local char = getLocalCharacter()
                if self.Parent == char then return end
            end
        end
    end
    return oldNewIndex(self, key, value)
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if not checkcaller() and L.NoRagdoll and method == "ChangeState" and self:IsA("Humanoid") then
        local char = getLocalCharacter()
        if self.Parent == char and (args[1] == Enum.HumanoidStateType.Physics or args[1] == 14) then
            return
        end
    end
    return oldNamecall(self, ...)
end)
local function gP(o)
    if not o then return nil end
    local data = espCache[o]
    if data and data.root and data.root.Parent then return data.root.Position end
    if o:IsA("Model") then
        local target = o:FindFirstChild("NPCTemplateNoHumanV4") or o
        local hrp = target:FindFirstChild("HumanoidRootPart", true) or target:FindFirstChild("Head", true) or target:FindFirstChild("Torso", true) or target:FindFirstChildOfClass("BasePart")
        if hrp then if data then data.root = hrp end return hrp.Position end
        if o.PrimaryPart then if data then data.root = o.PrimaryPart end return o.PrimaryPart.Position end
        local pivot = o:GetPivot()
        return pivot.Position
    end
    return o.Position
end
local function aFC(t)
    if not t or typeof(t) ~= "string" then return tostring(t or "") end
    local c = L.FCase or "Normal"
    if c == "Lowercase" then return string.lower(t) elseif c == "Uppercase" then return string.upper(t) end
    return (string.lower(t):gsub("^%l", string.upper):gsub("[%s%p]%l", string.upper))
end
local function uAF(id)
    L.Font = id
    for _, t in pairs(L.ND) do t.Font = id end for _, t in pairs(L.DD) do t.Font = id end
    for _, t in pairs(L.WD) do t.Font = id end for _, t in pairs(L.HTD) do t.Font = id end
end
local function gT(m) 
    local data = espCache[m]
    if data and data.root and data.root.Parent then return data.root end
    local t = m:FindFirstChild("NPCTemplateNoHumanV4") or m
    local res = t:FindFirstChild("HumanoidRootPart", true) or t:FindFirstChild("Torso", true) or t:FindFirstChild("UpperTorso", true) or t:FindFirstChild("Head", true) or t:FindFirstChildOfClass("BasePart")
    if data and res then data.root = res end
    return res
end
local nC = {}
local function gPN(m)
    if nC[m] then return nC[m] end
    local data = espCache[m]
    if data and (data.type == "NPCs" or data.type == "Animals") then
        if m.Parent and m.Parent.Parent and m.Parent.Parent.Name == data.type then
            nC[m] = m.Parent.Name
            return m.Parent.Name
        end
    end
    local tag = m:FindFirstChild("PlayerTag", true)
    if tag and tag:IsA("TextLabel") then nC[m] = tag.Text return tag.Text end
    for _, v in ipairs(m:GetDescendants()) do if v:IsA("TextLabel") and v.Name == "PlayerTag" then nC[m] = v.Text return v.Text end end
    return m.Name
end
local vP = RaycastParams.new()
vP.FilterType = Enum.RaycastFilterType.Exclude
vP.IgnoreWater = true
local function iV(o, t, to)
    if not t or not t.Parent then return false end
    vP.FilterDescendantsInstances = {LP.Character, t, C}
    if to and to:IsA("BasePart") then
        if WS:Raycast(o, (to.Position - o), vP) == nil then return true end
    end
    local data = espCache[t]
    local h = data and data.headPart
    if not h or not h.Parent then
        local target = t:FindFirstChild("NPCTemplateNoHumanV4") or t
        h = target:FindFirstChild("Head", true)
        if data then data.headPart = h end
    end
    if h and h ~= to then
        if WS:Raycast(o, (h.Position - o), vP) == nil then return true end
    end
    return false
end
local function cProp(d, k, v) if d[k] ~= v then d[k] = v end end
local function cPropV2(d, k, x, y) local c = d[k] if c.X ~= x or c.Y ~= y then d[k] = M.v2(x, y) end end
local function hAll(m)
    local tN, tWp, tD, bx, ou, fl, hB, hO, hT, aCList, hSolid = L.ND[m], L.WD[m], L.DD[m], L.BD[m], L.BOD[m], L.BFD[m], L.HD[m], L.HOD[m], L.HTD[m], L.AC[m], L.HSD[m]
    if tN and tN.Visible then tN.Visible = false end if tWp and tWp.Visible then tWp.Visible = false end 
    if tD and tD.Visible then tD.Visible = false end 
    if bx and bx.Visible then bx.Visible = false end if ou and ou.Visible then ou.Visible = false end 
    if fl and fl.Visible then fl.Visible = false end if hO and hO.Visible then hO.Visible = false end 
    if hT and hT.Visible then hT.Visible = false L.HTFC[m] = nil end
    if hB then for i = 1, 65 do if hB[i] and hB[i].Visible then hB[i].Visible = false end end end
    if hSolid and hSolid.Visible then hSolid.Visible = false end
    if aCList and aCList.Enabled then aCList.Enabled = false end
    if L.SKD[m] then for i = 1, 40 do local l = L.SKD[m][i] if l.Visible then l.Visible = false end end end
end
local function cD(m) if L.DD[m] then return end local d = Drawing.new("Text") d.Center = true d.Outline = true d.Size = 13 d.Font = L.Font d.Visible = false L.DD[m] = d end
local function cW(m) if L.WD[m] then return end local d = Drawing.new("Text") d.Center = true d.Outline = true d.Size = 13 d.Font = L.Font d.Visible = false L.WD[m] = d end
local function cN(m) if L.ND[m] then return end local d = Drawing.new("Text") d.Center = true d.Outline = true d.Size = 13 d.Font = L.Font d.Visible = false L.ND[m] = d end
local function cB1(m) if L.BD[m] then return end local o = Drawing.new("Square") o.Color = Color3.new(0, 0, 0) o.Thickness = 3 o.Filled = false o.Visible = false local b = Drawing.new("Square") b.Thickness = 1 b.Filled = false b.Visible = false local f = Drawing.new("Square") f.Thickness = 0 f.Filled = true f.Visible = false L.BFD[m] = f L.BOD[m] = o L.BD[m] = b end
local function cH(m) 
    if L.HD[m] then return end 
    local o = Drawing.new("Square") o.Color = Color3.new(0, 0, 0) o.Thickness = 1 o.Filled = true o.ZIndex = 10 o.Visible = false 
    local ss = {} for i = 1, 65 do local b = Drawing.new("Square") b.Thickness = 0 b.Filled = true b.ZIndex = 11 b.Visible = false ss[i] = b end 
    local solid = Drawing.new("Square") solid.Thickness = 0 solid.Filled = true solid.ZIndex = 11 solid.Visible = false
    local t = Drawing.new("Text") t.Size = 13 t.Outline = true t.Center = true t.ZIndex = 12 t.Font = L.Font t.Visible = false 
    L.HOD[m] = o L.HD[m] = ss L.HTD[m] = t L.HSD[m] = solid
end
local function cC(m)
    local h = L.AC[m]
    if h then if h.Parent then h:Destroy() end L.AC[m] = nil end
end
local function aC(m, prefix)
    if not m or m == LP.Character or (m.Name == LP.Name and (not espCache[m] or espCache[m].type == "Players")) then return end
    if L.AC[m] then return end
    local h = Instance.new("Highlight")
    h.Adornee = m
    local p = prefix or (espCache[m] and espCache[m].type == "NPCs" and "NPC_" or (espCache[m] and espCache[m].type == "Animals" and "Animal_" or ""))
    h.FillColor = L[p .. "CFC"]
    h.FillTransparency = L[p .. "CFTrans"]
    h.OutlineColor = L[p .. "CC"]
    h.OutlineTransparency = L[p .. "CTrans"]
    h.DepthMode = Enum.HighlightDepthMode[L[p .. "CB"]]
    h.Parent = workspace.Terrain
    L.AC[m] = h
end
local function uAC(prefix)
    for m, h in pairs(L.AC) do 
        if h then
            local p = prefix or (espCache[m] and espCache[m].type == "NPCs" and "NPC_" or (espCache[m] and espCache[m].type == "Animals" and "Animal_" or ""))
            h.FillColor = L[p .. "CFC"]; h.FillTransparency = L[p .. "CFTrans"]
            h.OutlineColor = L[p .. "CC"]; h.OutlineTransparency = L[p .. "CTrans"]
            h.DepthMode = Enum.HighlightDepthMode[L[p .. "CB"]]
        end 
    end
end
local function rHE(m, rm, type)
    if not m or m == LP.Character or (m.Name == LP.Name and type == "Players") then return end
    if type == "Animals" then
        if string.find(string.lower(m.Name), "horse") then return end
        local owner = m:FindFirstChild("Owner")
        if owner and owner:IsA("StringValue") and owner.Value == LP.Name then return end
    end
    if rm then
        if L.ND[m] then hAll(m) end
        if L.AC[m] then cC(m) end
        local d = espCache[m]
        if d then
            espCache[m] = nil
        end
        return 
    end
    if espCache[m] then return end
    espCache[m] = {to = m, fA = 0, sS = true, type = type or "Players"}
    cN(m) cW(m) cD(m) cB1(m) cH(m) 
    if L[(type == "NPCs" and "NPC_" or (type == "Animals" and "Animal_" or "")) .. "CE"] then aC(m, type == "NPCs" and "NPC_" or (type == "Animals" and "Animal_" or "")) end
end
local ESPPreview = { Enabled = false, UserMoved = false, Container = nil, MainFrame = nil, stickyUpdating = false }
function ESPPreview:UpdateAesthetics()
    if not self.MainFrame then return end
    local Main = self.MainFrame
    
    Main.BackgroundColor3 = Library.BackgroundColor
    Main.Outline.BackgroundColor3 = Library.OutlineColor
    Main.Accent.BackgroundColor3 = Library.AccentColor
    if self.Glow then self.Glow.ImageColor3 = Library.AccentColor end
    self.Title.Font = Library.Font
    self.Title.TextColor3 = Library.FontColor
    
    self.Inner.BackgroundColor3 = Library.MainColor
    self.Inner.BorderColor3 = Library.OutlineColor
    
    local Master = L.Master
    local PreviewEnabled = self.Enabled and Master and Library.MainOuterFrame.Visible
    Main.Visible = PreviewEnabled
    
    if PreviewEnabled and self.DummyBox then
        local font = Enum.Font.BuilderSans
        local fontSize = L.FS or 13
        local case = L.FCase or "Normal"
        local function applyCase(str)
            if case == "Uppercase" then return M.upper(str)
            elseif case == "Lowercase" then return M.lower(str)
            end
            return str
        end

        -- Box & Outlines (UIStroke)
        local boxColor = typeof(L.BC) == "Color3" and L.BC or Color3.new(1,1,1)
        self.DummyBox.Visible = L.BE
        self.DummyBoxMain.Color = boxColor
        self.DummyBoxFill.Visible = L.BFE
        self.DummyBoxFill.BackgroundColor3 = typeof(L.BFC) == "Color3" and L.BFC or Color3.new(1,1,1)
        self.DummyBoxFill.BackgroundTransparency = L.BFTrans or 0.5
        
        self.DummyName.Visible = L.NE
        self.DummyName.TextColor3 = typeof(L.NTC) == "Color3" and L.NTC or Color3.new(1,1,1)
        self.DummyName.Font = font
        self.DummyName.TextSize = fontSize
        self.DummyName.Text = applyCase("Player")
        
        self.DummyWeapon.Visible = L.WE
        self.DummyWeapon.TextColor3 = typeof(L.WTC) == "Color3" and L.WTC or Color3.new(1,1,1)
        self.DummyWeapon.Font = font
        self.DummyWeapon.TextSize = fontSize - 2
        self.DummyWeapon.Text = applyCase("Winchester")
        
        local dUnit = L.DistMode == "Meters" and "m" or "s"
        local dVal = L.DistMode == "Meters" and "42" or "150"
        self.DummyDist.Visible = L.DE
        self.DummyDist.TextColor3 = typeof(L.DTC) == "Color3" and L.DTC or Color3.new(1,1,1)
        self.DummyDist.Font = font
        self.DummyDist.TextSize = fontSize - 2
        self.DummyDist.Text = applyCase(dVal .. dUnit)
        
        if L.WE then
            self.DummyDist.Position = UDim2.new(0.5, -45, 0.5, 87)
        else
            self.DummyDist.Position = UDim2.new(0.5, -45, 0.5, 75)
        end
        
        local chamAlpha = L.CFTrans or 0.5
        self.DummyCharChams.Visible = L.CE
        self.DummyCharChams.ImageColor3 = typeof(L.CFC) == "Color3" and L.CFC or Color3.new(1,1,1)
        self.DummyCharChams.ImageTransparency = chamAlpha
        
        self.DummyChar.ImageTransparency = 0
        
        if self.DummyCharHighlight then
            self.DummyCharHighlight.Visible = L.CE
            self.DummyCharHighlight.ImageColor3 = typeof(L.CC) == "Color3" and L.CC or Color3.new(1,1,1)
            self.DummyCharHighlight.ImageTransparency = L.CTrans or 0.5
        end

        local health = (math.sin(M.clock() * math.pi * 2 / 6) + 1) / 2
        local t = M.clock() * (L.HGRS or 4)
        local hlc = typeof(L.HLC) == "Color3" and L.HLC or Color3.fromRGB(255, 0, 0)
        local hhc = typeof(L.HHC) == "Color3" and L.HHC or Color3.fromRGB(0, 255, 0)
        
        self.DummyHealthBar.Visible = L.HE
        self.DummyHealthText.Visible = L.HE and L.HTE
        self.DummyHealthText.Text = tostring(math.floor(health * 100))
        self.DummyHealthText.Position = UDim2.new(0, -22, 1 - health, -6)
        self.DummyHealthText.TextColor3 = typeof(L.HTC) == "Color3" and L.HTC or Color3.new(1,1,1)
        self.DummyHealthText.Font = font
        self.DummyHealthText.TextSize = fontSize - 2
        
        self.DummyHealthSolid.Visible = true
        self.DummyHealthSolid.Size = UDim2.new(1, 0, health, 0)
        self.DummyHealthSolid.Position = UDim2.new(0, 0, 1 - health, 0)
        
        if L.HGR then
            local mode = L.HGR_Type
            local animated = L.HGR_Anim
            
            if animated then
                if mode == "Pulsing Glow" then
                    local pulse = math.clamp(0.5 + math.sin(t) * 0.5, 0, 1)
                    self.DummyHealthGradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, hhc),
                        ColorSequenceKeypoint.new(0.5, hlc:Lerp(hhc, pulse)),
                        ColorSequenceKeypoint.new(1, hlc)
                    })
                elseif mode == "Wave Bounce" then
                    local wave = math.abs(math.sin(t))
                    self.DummyHealthGradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, hlc),
                        ColorSequenceKeypoint.new(0.5, hlc:Lerp(hhc, wave)),
                        ColorSequenceKeypoint.new(1, hhc)
                    })
                end
            else
                self.DummyHealthGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, hhc),
                    ColorSequenceKeypoint.new(1, hlc)
                })
            end
        else
            local mainHColor = hlc:Lerp(hhc, health)
            self.DummyHealthGradient.Color = ColorSequence.new(mainHColor)
        end
    end
end

function ESPPreview:Create()
    if self.Container then return end
    local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "ROXY_ESPPreview"; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global; ScreenGui.DisplayOrder = 1005
    self.Container = ScreenGui
    
    local Main = Instance.new("Frame"); Main.Name = "Main"; Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15); Main.BorderColor3 = Color3.fromRGB(0, 0, 0); Main.BorderSizePixel = 1; Main.Size = UDim2.fromOffset(200, 250); Main.Visible = false; Main.Parent = ScreenGui; Main.ClipsDescendants = false
    self.MainFrame = Main
    
    local Outline = Instance.new("Frame"); Outline.Name = "Outline"; Outline.BackgroundColor3 = Color3.fromRGB(30, 30, 30); Outline.BorderSizePixel = 0; Outline.Position = UDim2.new(0, -1, 0, -1); Outline.Size = UDim2.new(1, 2, 1, 2); Outline.ZIndex = 0; Outline.Parent = Main
    local Accent = Instance.new("Frame"); Accent.Name = "Accent"; Accent.BackgroundColor3 = Library.AccentColor; Accent.BorderSizePixel = 0; Accent.Size = UDim2.new(1, 0, 0, 1); Accent.ZIndex = 2; Accent.Parent = Main
    self.AccentLine = Accent
    
    local Glow = Instance.new("ImageLabel"); Glow.Name = "Glow"; Glow.BackgroundTransparency = 1; Glow.Image = "rbxassetid://1316045217"; Glow.ImageColor3 = Library.AccentColor; Glow.ImageTransparency = 0.7; Glow.Position = UDim2.new(0, -15, 0, -15); Glow.Size = UDim2.new(1, 30, 1, 30); Glow.ZIndex = -1; Glow.Parent = Main
    Library:AddToRegistry(Glow, { ImageColor3 = "AccentColor" })
    if Library.AddGlow then Library:AddGlow(Glow, 0.7) end
    
    local Title = Instance.new("TextLabel"); Title.Name = "Title"; Title.BackgroundTransparency = 1; Title.Position = UDim2.new(0, 5, 0, 2); Title.Size = UDim2.new(1, -10, 0, 15); Title.Font = Library.Font; Title.Text = "ESP Preview"; Title.TextColor3 = Color3.fromRGB(255, 255, 255); Title.TextSize = 12; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.Parent = Main
    
    local Inner = Instance.new("Frame"); Inner.Name = "Inner"; Inner.BackgroundColor3 = Color3.fromRGB(10, 10, 10); Inner.BorderColor3 = Color3.fromRGB(35, 35, 35); Inner.Position = UDim2.new(0, 5, 0, 20); Inner.Size = UDim2.new(1, -10, 1, -25); Inner.Parent = Main
    
    local InnerContainer = Instance.new("Frame"); InnerContainer.Name = "InnerContainer"; InnerContainer.BackgroundTransparency = 1; InnerContainer.Position = UDim2.new(0.5, 0, 0.5, 0); InnerContainer.Size = UDim2.fromOffset(190, 225); InnerContainer.AnchorPoint = Vector2.new(0.5, 0.5); InnerContainer.Parent = Inner
    local InnerScale = Instance.new("UIScale"); InnerScale.Parent = InnerContainer
    Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        InnerScale.Scale = Main.AbsoluteSize.Y / 250
    end)
    
    local CharImage = "rbxassetid://114212401043507"
    local DummyChar = Instance.new("ImageLabel"); DummyChar.Name = "DummyChar"; DummyChar.BackgroundTransparency = 1; DummyChar.Position = UDim2.new(0.5, -50, 0.5, -75); DummyChar.Size = UDim2.fromOffset(100, 150); DummyChar.Image = CharImage; DummyChar.Parent = InnerContainer
    self.DummyChar = DummyChar
    
    local DummyCharChams = Instance.new("ImageLabel"); DummyCharChams.Name = "DummyCharChams"; DummyCharChams.BackgroundTransparency = 1; DummyCharChams.Position = UDim2.new(0, 0, 0, 0); DummyCharChams.Size = UDim2.new(1, 0, 1, 0); DummyCharChams.Image = CharImage; DummyCharChams.ZIndex = 2; DummyCharChams.Parent = DummyChar
    self.DummyCharChams = DummyCharChams
    
    local DummyCharHighlight = Instance.new("ImageLabel"); DummyCharHighlight.Name = "DummyCharHighlight"; DummyCharHighlight.BackgroundTransparency = 1; DummyCharHighlight.Position = UDim2.new(0, -2, 0, -2); DummyCharHighlight.Size = UDim2.new(1, 4, 1, 4); DummyCharHighlight.Image = CharImage; DummyCharHighlight.ZIndex = 1; DummyCharHighlight.Parent = DummyChar
    self.DummyCharHighlight = DummyCharHighlight

    local Box = Instance.new("Frame"); Box.Name = "DummyBox"; Box.BackgroundTransparency = 1; Box.BorderSizePixel = 0; Box.Position = UDim2.new(0.5, -45, 0.5, -70); Box.Size = UDim2.fromOffset(90, 140); Box.ZIndex = 10; Box.Parent = InnerContainer
    self.DummyBox = Box
    
    local BoxStroke = Instance.new("UIStroke"); BoxStroke.Thickness = 1; BoxStroke.LineJoinMode = Enum.LineJoinMode.Miter; BoxStroke.Parent = Box
    self.DummyBoxMain = BoxStroke
    
    local BoxOuter = Instance.new("Frame"); BoxOuter.Name = "Outer"; BoxOuter.BackgroundTransparency = 1; BoxOuter.Position = UDim2.new(0, -1, 0, -1); BoxOuter.Size = UDim2.new(1, 2, 1, 2); BoxOuter.ZIndex = 10; BoxOuter.Parent = Box
    local OuterStroke = Instance.new("UIStroke"); OuterStroke.Color = Color3.new(0,0,0); OuterStroke.Thickness = 1; OuterStroke.LineJoinMode = Enum.LineJoinMode.Miter; OuterStroke.Parent = BoxOuter
    
    local BoxInnerF = Instance.new("Frame"); BoxInnerF.Name = "Inner"; BoxInnerF.BackgroundTransparency = 1; BoxInnerF.Position = UDim2.new(0, 1, 0, 1); BoxInnerF.Size = UDim2.new(1, -2, 1, -2); BoxInnerF.ZIndex = 10; BoxInnerF.Parent = Box
    local InnerStroke = Instance.new("UIStroke"); InnerStroke.Color = Color3.new(0,0,0); InnerStroke.Thickness = 1; InnerStroke.LineJoinMode = Enum.LineJoinMode.Miter; InnerStroke.Parent = BoxInnerF
    
    local BoxFill = Instance.new("Frame"); BoxFill.Name = "Fill"; BoxFill.BorderSizePixel = 0; BoxFill.Position = UDim2.new(0, 0, 0, 0); BoxFill.Size = UDim2.new(1, 0, 1, 0); BoxFill.ZIndex = 2; BoxFill.Parent = Box
    self.DummyBoxFill = BoxFill

    local bFont = Enum.Font.BuilderSans
    local Name = Instance.new("TextLabel"); Name.Name = "DummyName"; Name.BackgroundTransparency = 1; Name.Position = UDim2.new(0.5, -45, 0.5, -85); Name.Size = UDim2.fromOffset(90, 12); Name.Font = bFont; Name.Text = "Player"; Name.TextSize = 13; Name.ZIndex = 11; Name.Parent = InnerContainer
    local NameStroke = Instance.new("UIStroke"); NameStroke.Thickness = 1; NameStroke.Color = Color3.new(0,0,0); NameStroke.LineJoinMode = Enum.LineJoinMode.Miter; NameStroke.Parent = Name
    
    local Weapon = Instance.new("TextLabel"); Weapon.Name = "DummyWeapon"; Weapon.BackgroundTransparency = 1; Weapon.Position = UDim2.new(0.5, -45, 0.5, 75); Weapon.Size = UDim2.fromOffset(90, 12); Weapon.Font = bFont; Weapon.Text = "Winchester"; Weapon.TextSize = 11; Weapon.ZIndex = 11; Weapon.Parent = InnerContainer
    local WeaponStroke = Instance.new("UIStroke"); WeaponStroke.Thickness = 1; WeaponStroke.Color = Color3.new(0,0,0); WeaponStroke.LineJoinMode = Enum.LineJoinMode.Miter; WeaponStroke.Parent = Weapon
    
    local Dist = Instance.new("TextLabel"); Dist.Name = "DummyDist"; Dist.BackgroundTransparency = 1; Dist.Position = UDim2.new(0.5, -45, 0.5, 87); Dist.Size = UDim2.fromOffset(90, 12); Dist.Font = bFont; Dist.Text = "[ 150m ]"; Dist.TextSize = 11; Dist.ZIndex = 11; Dist.Parent = InnerContainer
    local DistStroke = Instance.new("UIStroke"); DistStroke.Thickness = 1; DistStroke.Color = Color3.new(0,0,0); DistStroke.LineJoinMode = Enum.LineJoinMode.Miter; DistStroke.Parent = Dist
    
    local HealthBar = Instance.new("Frame"); HealthBar.Name = "DummyHealth"; HealthBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0); HealthBar.BorderSizePixel = 0; HealthBar.Position = UDim2.new(0.5, -53, 0.5, -71); HealthBar.Size = UDim2.fromOffset(4, 142); HealthBar.ZIndex = 12; HealthBar.Parent = InnerContainer
    self.DummyHealthBar = HealthBar
    
    local HealthStroke = Instance.new("UIStroke"); HealthStroke.Thickness = 1; HealthStroke.Color = Color3.new(0,0,0); HealthStroke.LineJoinMode = Enum.LineJoinMode.Miter; HealthStroke.Parent = HealthBar
    local HealthSolid = Instance.new("Frame"); HealthSolid.Name = "Solid"; HealthSolid.BorderSizePixel = 0; HealthSolid.BackgroundColor3 = Color3.new(1,1,1); HealthSolid.ZIndex = 13; HealthSolid.Parent = HealthBar
    self.DummyHealthSolid = HealthSolid
    local HealthGradient = Instance.new("UIGradient"); HealthGradient.Rotation = -90; HealthGradient.Parent = HealthSolid
    self.DummyHealthGradient = HealthGradient
    
    local HealthText = Instance.new("TextLabel"); HealthText.Name = "HealthText"; HealthText.BackgroundTransparency = 1; HealthText.Font = bFont; HealthText.TextSize = 11; HealthText.Size = UDim2.fromOffset(20, 12); HealthText.TextXAlignment = Enum.TextXAlignment.Right; HealthText.ZIndex = 14; HealthText.Parent = HealthBar
    local HealthTextStroke = Instance.new("UIStroke"); HealthTextStroke.Thickness = 1; HealthTextStroke.Color = Color3.new(0,0,0); HealthTextStroke.LineJoinMode = Enum.LineJoinMode.Miter; HealthTextStroke.Parent = HealthText
    self.DummyHealthText = HealthText


    
    self.Glow = Glow
    self.Inner = Inner
    self.DummyName = Name
    self.DummyDist = Dist
    self.DummyWeapon = Weapon
    self.Title = Title
    
    if typeof(syn) == "table" and syn.protect_gui then syn.protect_gui(ScreenGui) end
    ScreenGui.Parent = gethui() or game:GetService("CoreGui")
    
    Library:MakeDraggable(Main, 15, false, true)
    if Library.MakeResizable then Library:MakeResizable(Main, Vector2.new(150, 180)) end
    Main:GetPropertyChangedSignal("Position"):Connect(function() if self.Enabled and not self.stickyUpdating then self.UserMoved = true end end)
    
    RS.RenderStepped:Connect(function()
        if self.Enabled and Library.MainOuterFrame then
            if not self.UserMoved then
                self.stickyUpdating = true
                local pos = Library.MainOuterFrame.AbsolutePosition
                Main.Position = UDim2.new(0, pos.X - 215, 0, pos.Y)
                self.stickyUpdating = false
            end
            self:UpdateAesthetics()
        end
    end)
    
    Library.MainOuterFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        self:UpdateAesthetics()
    end)
end

function ESPPreview:Toggle(state)
    self.Enabled = state
    if state then
        if not self.Container then self:Create() end
        if not self.MainFrame then return end
        
        self:UpdateAesthetics()
        
        if Library.MainOuterFrame and not self.UserMoved then
            local pos = Library.MainOuterFrame.AbsolutePosition
            self.MainFrame.Position = UDim2.new(0, pos.X - 215, 0, pos.Y)
        end
        
        self.MainFrame.Visible = true
        
        if not self.TCCache then
            self.TCCache = {}
            for _, desc in ipairs(self.MainFrame:GetDescendants()) do
                if desc:IsA("ImageLabel") then self.TCCache[desc] = {Prop = "ImageTransparency", Val = desc.ImageTransparency}
                elseif desc:IsA("TextLabel") then self.TCCache[desc] = {Prop = "TextTransparency", Val = desc.TextTransparency}
                elseif desc:IsA("UIStroke") then self.TCCache[desc] = {Prop = "Transparency", Val = desc.Transparency}
                elseif desc:IsA("Frame") then self.TCCache[desc] = {Prop = "BackgroundTransparency", Val = desc.BackgroundTransparency}
                end
            end
            self.TCCache[self.MainFrame] = {Prop = "BackgroundTransparency", Val = self.MainFrame.BackgroundTransparency}
        else
            for desc, data in pairs(self.TCCache) do
                if desc:IsA("ImageLabel") and desc.Name == "Glow" then
                    data.Val = math.clamp(1 - ((1 - 0.7) * Library.GlowAmount), 0, 1)
                elseif desc:IsA("ImageLabel") and desc.Name == "DummyCharChams" then
                    data.Val = (L.Player_CE and (L.Player_CFC and L.Player_CFC.A or 0.5) or 1)
                elseif desc:IsA("ImageLabel") and desc.Name == "DummyCharHighlight" then
                    data.Val = (L.Player_CE and (L.Player_CC and L.Player_CC.A or 0.5) or 1)
                end
            end
        end

        for desc, data in pairs(self.TCCache) do
            if data.Val == 1 then continue end
            local cur = desc[data.Prop]
            desc[data.Prop] = 1
            TS:Create(desc, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {[data.Prop] = data.Val}):Play()
        end
    else
        if self.MainFrame and self.TCCache then
            local longest
            for desc, data in pairs(self.TCCache) do
                if data.Val == 1 then continue end
                longest = TS:Create(desc, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {[data.Prop] = 1})
                longest:Play()
            end
            if longest then
                longest.Completed:Connect(function()
                    if not self.Enabled then self.MainFrame.Visible = false end
                end)
            else
                self.MainFrame.Visible = false
            end
        end
    end
end

local function setupESP(tab, prefix, hideSkeleton, isAnimal)
    local ME = tab:AddToggle(prefix .. 'MasterESP', {Text = 'Enable ESP', Default = false, Callback = function(v) 
        L[prefix .. "Master"] = v 
        if prefix == "" and Toggles.ESPPreview then
            ESPPreview:Toggle(v and Toggles.ESPPreview.Value)
        end
    end})
    local D_Chams = tab:AddDependencyBox(); D_Chams:SetupDependencies({{ME, true}})
    if prefix == "" then
        D_Chams:AddToggle('ESPPreview', {Text = 'ESP Preview', Default = true, Callback = function(v) 
            ESPPreview:Toggle(v and L["Master"]) 
        end})
    end
    if not isAnimal then
        local CE1 = D_Chams:AddToggle(prefix .. 'ChamsESP', {Text = 'Chams', Default = false, Callback = function(v) 
            L[prefix .. "CE"] = v 
            local type = (prefix == "NPC_" and "NPCs" or (prefix == "Animal_" and "Animals" or "Players"))
            if v then 
                for _, m in ipairs(getEntities(type)) do if m:IsA("Model") and m ~= LP.Character then aC(m, prefix) end end 
            else 
                local toRemove = {}
                for m, h in pairs(L.AC) do 
                    local d = espCache[m] 
                    if d and d.type == type then table.insert(toRemove, m) end 
                end 
                for _, m in ipairs(toRemove) do cC(m) end
            end 
        end})
        CE1:AddColorPicker(prefix .. "ChamsESPCP", {Default = L[prefix .. "CC"], Title = "Highlight Core", Transparency = 0.5, Callback = function(v) L[prefix .. "CC"] = v L[prefix .. "CTrans"] = (Options[prefix .. "ChamsESPCP"] and Options[prefix .. "ChamsESPCP"].Transparency or 0.5) uAC(prefix) end})
        CE1:AddColorPicker(prefix .. "ChamsFillCP", {Default = L[prefix .. "CFC"], Title = "Main Body Fill", Transparency = 0.5, Callback = function(v) L[prefix .. "CFC"] = v L[prefix .. "CFTrans"] = (Options[prefix .. "ChamsFillCP"] and Options[prefix .. "ChamsFillCP"].Transparency or 0.5) uAC(prefix) end})
        local D_ChamsSub = tab:AddDependencyBox(); D_ChamsSub:SetupDependencies({{ME, true}, {CE1, true}})
        D_ChamsSub:AddDropdown(prefix .. 'ChamsBehavior', {Values = {'AlwaysOnTop', 'Occluded'}, Default = 1, Multi = false, Text = 'Chams Behavior', Callback = function(v) L[prefix .. "CB"] = v uAC(prefix) end})
    end
    local D_Name = tab:AddDependencyBox(); D_Name:SetupDependencies({{ME, true}})
    local NV = D_Name:AddToggle(prefix .. 'ShowPlayerTags', {Text = 'Name', Default = false, Callback = function(v) L[prefix .. "NE"] = v end})
    NV:AddColorPicker(prefix .. 'NameTagColor', {Default = L[prefix .. "NTC"], Title = 'Name Text Color', Transparency = 0, Callback = function(c) L[prefix .. "NTC"] = c end})
    local D_Box = tab:AddDependencyBox(); D_Box:SetupDependencies({{ME, true}})
    if not isAnimal then
        local BV = D_Box:AddToggle(prefix .. "BoxESP", {Text = "Box", Default = false, Callback = function(v) L[prefix .. "BE"] = v end})
        BV:AddColorPicker(prefix .. "BoxESPColor", {Default = L[prefix .. "BC"], Title = "Box Color", Transparency = 0, Callback = function(c) L[prefix .. "BC"] = c end})
        local D_BoxSub = tab:AddDependencyBox(); D_BoxSub:SetupDependencies({{ME, true}, {BV, true}})
        D_BoxSub:AddToggle(prefix .. "BoxFillToggle", {Text = "Box Fill", Default = false, Callback = function(v) L[prefix .. "BFE"] = v end}):AddColorPicker(prefix .. "BoxFillColorPicker", {Default = L[prefix .. "BFC"], Title = "Box Fill Color", Transparency = 0.5, Callback = function(c) L[prefix .. "BFC"] = c L[prefix .. "BFTrans"] = (Options[prefix .. "BoxFillColorPicker"] and Options[prefix .. "BoxFillColorPicker"].Transparency or 0.5) end})
    end
    local D_Health = tab:AddDependencyBox(); D_Health:SetupDependencies({{ME, true}})
    local HV = D_Health:AddToggle(prefix .. "HealthESP", {Text = "Health", Default = false, Callback = function(v) L[prefix .. "HE"] = v if not v then for m, d in pairs(espCache) do if d.type == (prefix == "NPC_" and "NPCs" or (prefix == "Animal_" and "Animals" or "Players")) then L.VH[m] = 0 end end end end})
    HV:AddColorPicker(prefix .. "HealthESPHigh", {Default = L[prefix .. "HHC"], Title = "High", Callback = function(c) L[prefix .. "HHC"] = c end})
    HV:AddColorPicker(prefix .. "HealthESPLow", {Default = L[prefix .. "HLC"], Title = "Low", Callback = function(c) L[prefix .. "HLC"] = c end})
    if not isAnimal then
        local D_HealthSub = tab:AddDependencyBox(); D_HealthSub:SetupDependencies({{ME, true}, {HV, true}})
        D_HealthSub:AddToggle(prefix .. "HealthTextToggle", {Text = "Health Text", Default = false, Callback = function(v) L[prefix .. "HTE"] = v end}):AddColorPicker(prefix .. "HealthTextColor", {Default = L[prefix .. "HTC"], Title = "Color", Callback = function(c) L[prefix .. "HTC"] = c end})
        local HGRT = D_HealthSub:AddToggle(prefix .. "HealthRotationToggle", {Text = "Rotation", Default = false, Callback = function(v) L[prefix .. "HGR_Anim"] = v end})
        local D_HealthGrad = tab:AddDependencyBox(); D_HealthGrad:SetupDependencies({{ME, true}, {HV, true}, {HGRT, true}})
        D_HealthGrad:AddDropdown(prefix .. 'HealthGradientType', {Values = {'Pulsing Glow', 'Wave Bounce'}, Default = 1, Multi = false, Text = 'Mode', Callback = function(v) L[prefix .. "HGR_Type"] = v end})
        D_HealthGrad:AddSlider(prefix .. "HealthGradientRotationSpeed", {Text = "Speed", Default = 4, Min = 0.1, Max = 10, Rounding = 1, Compact = true, Callback = function(v) L[prefix .. "HGRS"] = v end})
    end
    local D_Dist = tab:AddDependencyBox(); D_Dist:SetupDependencies({{ME, true}})
    local CE2 = D_Dist:AddToggle(prefix .. 'DistanceESP', {Text = 'Distance', Default = false, Callback = function(v) L[prefix .. "DE"] = v end})
    CE2:AddColorPicker(prefix .. "DistanceESPCP", {Default = L[prefix .. "DTC"], Title = "Color", Callback = function(v) L[prefix .. "DTC"] = v end})
    local D_DistSub = tab:AddDependencyBox(); D_DistSub:SetupDependencies({{ME, true}, {CE2, true}})
    D_DistSub:AddDropdown(prefix .. 'DistanceMode', {Values = {'Studs', 'Meters'}, Default = 1, Multi = false, Text = 'Measuring', Callback = function(v) L[prefix .. "DistMode"] = v end})
    if not isAnimal then
        local D_Weapon = tab:AddDependencyBox(); D_Weapon:SetupDependencies({{ME, true}})
        local CE3 = D_Weapon:AddToggle(prefix .. 'WeaponESP', {Text = 'Weapon', Default = false, Callback = function(v) L[prefix .. "WE"] = v end})
        CE3:AddColorPicker(prefix .. "WeaponESPCP", {Default = L[prefix .. "WTC"], Title = "Color", Callback = function(v) L[prefix .. "WTC"] = v end})
    end
    if not hideSkeleton then
        local D_Skel = tab:AddDependencyBox(); D_Skel:SetupDependencies({{ME, true}})
        local SET = D_Skel:AddToggle(prefix .. 'SkeletonESP', {Text = 'Skeleton', Default = false, Callback = function(v) L[prefix .. "SKE"] = v end})
        SET:AddColorPicker(prefix .. "SkeletonESPCP", {Default = L[prefix .. "SKC"], Title = "Color", Transparency = 0, Callback = function(c, t) L[prefix .. "SKC"] = c L[prefix .. "SKTrans"] = t end})
    end
    local D_Misc = tab:AddDependencyBox(); D_Misc:SetupDependencies({{ME, true}})
    D_Misc:AddDivider()
    if isAnimal then
        D_Misc:AddToggle(prefix .. "LegendaryOnly", {Text = "Legendarys Only", Default = false, Tooltip = "Only shows legendary animals", Callback = function(v) L[prefix .. "LegendaryOnly"] = v end})
        D_Misc:AddToggle(prefix .. "LegendaryOverride", {Text = "Legendary Color Override", Default = true, Callback = function(v) L[prefix .. "LegendaryOverride"] = v end}):AddColorPicker(prefix .. "LegendaryColor", {Default = Color3.fromRGB(255, 255, 0), Title = "Legendary Color", Callback = function(c) L[prefix .. "LegendaryColor"] = c end})
        D_Misc:AddToggle(prefix .. "NotifyLegendary", {Text = "Notify On Legendary Spawn", Default = false, Tooltip = "Notifies user whenever a legendary animal is found.", Callback = function(v) L[prefix .. "NotifyLegendary"] = v end})
    end
    D_Misc:AddDropdown(prefix .. 'FontTypeDropdown', {Values = {'UI', 'System', 'Plex', 'Monospace'}, Default = 3, Multi = false, Text = 'Font Type', Callback = function(v) local f = FM[v] if f ~= nil then uAF(f) end end})
    D_Misc:AddDropdown(prefix .. 'FontCaseDropdown', {Values = {'Normal', 'Lowercase', 'Uppercase'}, Default = 1, Multi = false, Text = 'Font Case', Callback = function(v) L.FCase = v end})
    if isAnimal or prefix == "" then D_Misc:AddSlider(prefix .. "FontSize", {Text = "Font Size", Default = 13, Min = 8, Max = 24, Rounding = 0, Compact = true, Callback = function(v) L[prefix .. "FS"] = math.floor(v) end}) end
    D_Misc:AddSlider(prefix .. "MaxDistance", {Text = "Max Distance", Default = 2000, Min = 0, Max = 10000, Rounding = 0, Compact = true, Callback = function(v) L[prefix .. "DMax"] = v end})
end
local ESP_Tabbox = Tabs.Visuals:AddLeftTabbox()
setupESP(ESP_Tabbox:AddTab("Players"), "")
setupESP(ESP_Tabbox:AddTab("NPCs"), "NPC_", true)
setupESP(ESP_Tabbox:AddTab("Animals"), "Animal_", true, true)
local DroppedItems_Tabbox = Tabs.Visuals:AddRightTabbox("Dropped Items & Thunderstruck")
local DroppedItems_Group = DroppedItems_Tabbox:AddTab("Dropped Items")
local Thunderstruck_Group = DroppedItems_Tabbox:AddTab("Thunderstruck")
local Ores_Group = DroppedItems_Tabbox:AddTab("Ores")

local DI_Master = DroppedItems_Group:AddToggle("DI_Enabled", {Text = "Enable ESP", Default = false, Callback = function(v) L.DI_Enabled = v end})
local DI_Dep1 = DroppedItems_Group:AddDependencyBox(); DI_Dep1:SetupDependencies({{DI_Master, true}})
local DI_NameToggle = DI_Dep1:AddToggle("DI_Name", {Text = "Name", Default = false, Callback = function(v) L.DI_Name = v end})
DI_NameToggle:AddColorPicker("DI_NameColor", {Default = L.DI_NameColor, Title = "Name Color", Callback = function(c) L.DI_NameColor = c end})
local DI_DistToggle = DI_Dep1:AddToggle("DI_Distance", {Text = "Distance", Default = false, Callback = function(v) L.DI_Distance = v end})
DI_DistToggle:AddColorPicker("DI_DistanceColor", {Default = L.DI_DistanceColor, Title = "Distance Color", Callback = function(c) L.DI_DistanceColor = c end})
local DI_DistDep = DroppedItems_Group:AddDependencyBox(); DI_DistDep:SetupDependencies({{DI_Master, true}, {DI_DistToggle, true}})
DI_DistDep:AddDropdown("DI_Measuring", {Values = {"Meters", "Studs"}, Default = 2, Text = "Measuring", Callback = function(v) L.DI_Measuring = v end})
local DI_Dep2 = DroppedItems_Group:AddDependencyBox(); DI_Dep2:SetupDependencies({{DI_Master, true}})
DI_Dep2:AddDropdown("DI_Sort", {Values = {"Ore", "Gems", "Animal Drops", "Others"}, Default = {"Ore", "Gems", "Animal Drops", "Others"}, Multi = true, Text = "Item Sort", Callback = function(v) L.DI_Sort = v end})
DI_Dep2:AddDivider()
DI_Dep2:AddToggle("DI_LegendaryOverride", {Text = "Legendary Color Override", Default = true, Callback = function(v) L.DI_LegendaryOverride = v end}):AddColorPicker("DI_LegendaryColor", {Default = L.DI_LegendaryColor, Title = "Legendary Color", Callback = function(c) L.DI_LegendaryColor = c end})
DI_Dep2:AddDropdown('DI_FontType', {Values = {'UI', 'System', 'Plex', 'Monospace'}, Default = 3, Multi = false, Text = 'Font Type', Callback = function(v) L.DI_Font = FM[v] or 2 end})
DI_Dep2:AddDropdown('DI_FontCase', {Values = {'Normal', 'Lowercase', 'Uppercase'}, Default = 1, Multi = false, Text = 'Font Case', Callback = function(v) L.DI_FontCase = v end})
DI_Dep2:AddSlider("DI_FontSize", {Text = "Font Size", Default = 13, Min = 8, Max = 24, Rounding = 0, Compact = true, Callback = function(v) L.DI_FontSize = math.floor(v) end})
DI_Dep2:AddSlider("DI_MaxDistance", {Text = "Max Distance", Default = 10000, Min = 0, Max = 10000, Rounding = 0, Compact = true, Callback = function(v) L.DI_MaxDistance = v end})

local TS_Master = Thunderstruck_Group:AddToggle("TS_Enabled", {Text = "Enable ESP", Default = false, Callback = function(v) L.TS_Enabled = v end})
local TS_Dep1 = Thunderstruck_Group:AddDependencyBox(); TS_Dep1:SetupDependencies({{TS_Master, true}})
local TS_NameToggle = TS_Dep1:AddToggle("TS_Name", {Text = "Name", Default = false, Callback = function(v) L.TS_Name = v end})
TS_NameToggle:AddColorPicker("TS_NameColor", {Default = Color3.fromRGB(255, 0, 0), Title = "Name Color", Callback = function(c) L.TS_NameColor = c end})
local TS_DistToggle = TS_Dep1:AddToggle("TS_Distance", {Text = "Distance", Default = false, Callback = function(v) L.TS_Distance = v end})
TS_DistToggle:AddColorPicker("TS_DistanceColor", {Default = Color3.fromRGB(255, 255, 255), Title = "Distance Color", Callback = function(c) L.TS_DistanceColor = c end})
local TS_DistDep = Thunderstruck_Group:AddDependencyBox(); TS_DistDep:SetupDependencies({{TS_Master, true}, {TS_DistToggle, true}})
TS_DistDep:AddDropdown("TS_Measuring", {Values = {"Meters", "Studs"}, Default = 2, Text = "Measuring", Callback = function(v) L.TS_Measuring = v end})
local TS_Dep1_Bottom = Thunderstruck_Group:AddDependencyBox(); TS_Dep1_Bottom:SetupDependencies({{TS_Master, true}})
TS_Dep1_Bottom:AddDropdown("TS_Sort", {Values = {"Tree", "Cactus"}, Default = {"Tree", "Cactus"}, Multi = true, Text = "Thunderstruck Sort", Callback = function(v) L.TS_Sort = v end})
local TS_Dep2 = Thunderstruck_Group:AddDependencyBox(); TS_Dep2:SetupDependencies({{TS_Master, true}})
TS_Dep2:AddDivider()
TS_Dep2:AddToggle("TS_Notify", {Text = "Notify On Thunderstruck", Default = false, Tooltip = "Enables notifications for newly discovered Thunderstruck entities.", Callback = function(v) L.TS_Notify = v end})
TS_Dep2:AddDropdown('TS_FontType', {Values = {'UI', 'System', 'Plex', 'Monospace'}, Default = 3, Multi = false, Text = 'Font Type', Callback = function(v) L.TS_Font = FM[v] or 2 end})
TS_Dep2:AddDropdown('TS_FontCase', {Values = {'Normal', 'Lowercase', 'Uppercase'}, Default = 1, Multi = false, Text = 'Font Case', Callback = function(v) L.TS_FontCase = v end})
TS_Dep2:AddSlider("TS_FontSize", {Text = "Font Size", Default = 13, Min = 8, Max = 24, Rounding = 0, Compact = true, Callback = function(v) L.TS_FontSize = math.floor(v) end})
TS_Dep2:AddSlider("TS_MaxDistance", {Text = "Max Distance", Default = 10000, Min = 0, Max = 10000, Rounding = 0, Compact = true, Callback = function(v) L.TS_MaxDistance = v end})

L.Ore_Name = true
local Ore_Master = Ores_Group:AddToggle("Ore_Enabled", {Text = "Enable ESP", Default = false, Callback = function(v) L.Ore_Enabled = v end})
local Ore_Dep1 = Ores_Group:AddDependencyBox(); Ore_Dep1:SetupDependencies({{Ore_Master, true}})
Ore_Dep1:AddToggle("Ore_Name", {Text = "Name", Default = true, Callback = function(v) L.Ore_Name = v end})
local Ore_DistToggle = Ore_Dep1:AddToggle("Ore_Distance", {Text = "Distance", Default = false, Callback = function(v) L.Ore_Distance = v end})
Ore_DistToggle:AddColorPicker("Ore_DistanceColor", {Default = Color3.new(1, 1, 1), Title = "Distance Color", Callback = function(c) L.Ore_DistanceColor = c end})
local Ore_DistDep = Ores_Group:AddDependencyBox(); Ore_DistDep:SetupDependencies({{Ore_Master, true}, {Ore_DistToggle, true}})
Ore_DistDep:AddDropdown("Ore_Measuring", {Values = {"Meters", "Studs"}, Default = 2, Text = "Measuring", Callback = function(v) L.Ore_Measuring = v end})
local Ore_Dep2 = Ores_Group:AddDependencyBox(); Ore_Dep2:SetupDependencies({{Ore_Master, true}})
local OresList = {
    {Name = "Coal", Color = Color3.fromRGB(80, 80, 80)},
    {Name = "Copper", Color = Color3.fromRGB(184, 115, 51)},
    {Name = "Gold", Color = Color3.fromRGB(255, 215, 0)},
    {Name = "Iron", Color = Color3.fromRGB(161, 157, 148)},
    {Name = "Quartz", Color = Color3.fromRGB(255, 255, 255)},
    {Name = "Silver", Color = Color3.fromRGB(192, 192, 192)},
    {Name = "Zinc", Color = Color3.fromRGB(137, 207, 240)}
}
L.Ore_Settings = {}
for _, ore in ipairs(OresList) do
    L.Ore_Settings[ore.Name] = {Enabled = false, Color = ore.Color}
    local t = Ore_Dep2:AddToggle("Ore_" .. ore.Name, {Text = ore.Name, Default = false, Callback = function(v) L.Ore_Settings[ore.Name].Enabled = v end})
    t:AddColorPicker("Ore_Color_" .. ore.Name, {Default = ore.Color, Title = ore.Name .. " Color", Callback = function(c) L.Ore_Settings[ore.Name].Color = c end})
end
Ore_Dep2:AddDivider()
Ore_Dep2:AddToggle("Ore_OnlyVeins", {Text = "Only Show Veins", Default = false, Callback = function(v) L.Ore_OnlyVeins = v end})
Ore_Dep2:AddDropdown('Ore_FontType', {Values = {'UI', 'System', 'Plex', 'Monospace'}, Default = 3, Multi = false, Text = 'Font Type', Callback = function(v) L.Ore_Font = FM[v] or 2 end})
Ore_Dep2:AddDropdown('Ore_FontCase', {Values = {'Normal', 'Lowercase', 'Uppercase'}, Default = 1, Multi = false, Text = 'Font Case', Callback = function(v) L.Ore_FontCase = v end})
Ore_Dep2:AddSlider("Ore_FontSize", {Text = "Font Size", Default = 13, Min = 8, Max = 24, Rounding = 0, Compact = true, Callback = function(v) L.Ore_FontSize = math.floor(v) end})
Ore_Dep2:AddSlider("Ore_MaxDistance", {Text = "Max Distance", Default = 10000, Min = 0, Max = 10000, Rounding = 0, Compact = true, Callback = function(v) L.Ore_MaxDistance = v end})
local Local_Group = Tabs.Visuals:AddRightGroupbox("Local")
local LG_Toggle = Local_Group:AddToggle("LG_Enabled", {Text = "Local Gun Chams", Default = false, Callback = function(v) L.LG_Enabled = v end})
LG_Toggle:AddColorPicker("LG_Color", {Default = L.LG_Color, Transparency = 0, Title = "Color", Callback = function(c, t) 
    L.LG_Color = c
    L.LG_Trans = t
end})
local LG_Dep = Local_Group:AddDependencyBox(); LG_Dep:SetupDependencies({{LG_Toggle, true}})
LG_Dep:AddDropdown("LG_Mat", {Values = {"ForceField", "Neon", "Plastic", "Glass", "SmoothPlastic"}, Default = 1, Text = "Chams Material", Callback = function(v) L.LG_Mat = v end})
local LG_FF_Dep = Local_Group:AddDependencyBox(); LG_FF_Dep:SetupDependencies({{LG_Toggle, true}})
LG_FF_Dep:AddDropdown("LG_FFAnim", {Values = {"None", "Breathe", "Spectral", "Ethereal", "Vivid", "Glint", "Lustre"}, Default = 1, Text = "Forcefield Animation", Callback = function(v) L.LG_FFAnim = v end})

Local_Group:AddToggle("LG_HideHolsters", {Text = "Hide Local Holsters", Default = false, Callback = function(v) L.LG_HideHolsters = v end})
Local_Group:AddToggle("LG_HideGuns", {Text = "Hide Local Guns", Default = false, Callback = function(v) L.LG_HideGuns = v end})

Local_Group:AddDivider()

local LC_Toggle = Local_Group:AddToggle("LC_Enabled", {Text = "Local Character Chams", Default = false, Callback = function(v) L.LC_Enabled = v end})
LC_Toggle:AddColorPicker("LC_Color", {Default = L.LC_Color, Transparency = 0, Title = "Color", Callback = function(c, t) 
    L.LC_Color = c
    L.LC_Trans = t
end})

local LC_Dep = Local_Group:AddDependencyBox(); LC_Dep:SetupDependencies({{LC_Toggle, true}})
LC_Dep:AddDropdown("LC_Mat", {Values = {"ForceField", "Neon", "Plastic", "Glass", "SmoothPlastic"}, Default = 1, Text = "Chams Material", Callback = function(v) L.LC_Mat = v end})
LC_Dep:AddDropdown("LC_FFAnim", {Values = {"None", "Breathe", "Spectral", "Ethereal", "Vivid", "Glint", "Lustre"}, Default = 1, Text = "Forcefield Animation", Callback = function(v) L.LC_FFAnim = v end})

Local_Group:AddDivider()

local LH_Toggle = Local_Group:AddToggle("LH_Enabled", {Text = "Local Horse Chams", Default = false, Callback = function(v) L.LH_Enabled = v end})
LH_Toggle:AddColorPicker("LH_Color", {Default = L.LH_Color, Transparency = 0, Title = "Color", Callback = function(c, t) 
    L.LH_Color = c
    L.LH_Trans = t
end})

local LH_Dep = Local_Group:AddDependencyBox(); LH_Dep:SetupDependencies({{LH_Toggle, true}})
LH_Dep:AddDropdown("LH_Mat", {Values = {"ForceField", "Neon", "Plastic", "Glass", "SmoothPlastic"}, Default = 1, Text = "Chams Material", Callback = function(v) L.LH_Mat = v end})
LH_Dep:AddDropdown("LH_FFAnim", {Values = {"None", "Breathe", "Spectral", "Ethereal", "Vivid", "Glint", "Lustre"}, Default = 1, Text = "Forcefield Animation", Callback = function(v) L.LH_FFAnim = v end})
local Extra_Tab = ESP_Tabbox:AddTab("Extra")
Extra_Tab:AddToggle("HideProtected", {Text = "Hide Protected", Default = false, Tooltip = "Hides protected players esp.", Callback = function(v) L.HideProtected = v end})
Extra_Tab:AddToggle("VisOnly", {Text = "Only Show When Visible", Default = false, Tooltip = "Only shows ESP for visible players/npcs/animals.", Callback = function(v) L.VisOnly = v end})
Extra_Tab:AddDivider()
Extra_Tab:AddToggle("OverwriteDuelOpponent", {Text = "Overwrite Duel Opponent", Default = true, Tooltip = "Overwrites the ESP color for current duel opponent.", Callback = function(v) L.OverwriteDuelOpponent = v end}):AddColorPicker("OverwriteDuelColor", {Default = Color3.fromRGB(255, 240, 108), Title = "Color", Callback = function(c) L.OverwriteDuelColor = c end})
Extra_Tab:AddToggle("OverwritePriority", {Text = "Overwrite Priority Color", Default = true, Callback = function(v) L.PE = v; if Library.PlayerList and Library.PlayerList.RefreshColors then Library.PlayerList:RefreshColors() end end}):AddColorPicker("OverwritePriorityCP", {Default = Color3.fromRGB(255, 0, 0), Title = "Priority Color", Callback = function(c) L.PCOC = c; if Library.PlayerList and Library.PlayerList.RefreshColors then Library.PlayerList:RefreshColors() end end})
Extra_Tab:AddToggle("OverwriteFriendly", {Text = "Overwrite Friendly Color", Default = true, Callback = function(v) L.FE = v; if Library.PlayerList and Library.PlayerList.RefreshColors then Library.PlayerList:RefreshColors() end end}):AddColorPicker("OverwriteFriendlyCP", {Default = Color3.fromRGB(0, 255, 0), Title = "Friendly Color", Callback = function(c) L.FCOC = c; if Library.PlayerList and Library.PlayerList.RefreshColors then Library.PlayerList:RefreshColors() end end})
Extra_Tab:AddSlider("FadeInTime", {Text = "Fade In", Default = 0.15, Min = 0.05, Max = 2, Rounding = 2, Compact = true, Callback = function(v) L.FIn = v end})
Extra_Tab:AddSlider("FadeOutTime", {Text = "Fade Out", Default = 0.15, Min = 0.05, Max = 2, Rounding = 2, Compact = true, Callback = function(v) L.FOut = v end})
local VisualsTracers = Tabs.Visuals:AddLeftGroupbox("Bullet Tracers")
local LocalTracersToggle = VisualsTracers:AddToggle("BulletTracers", {Text = "Local Bullet Tracers", Default = false, Tooltip = "Shows local tracer's.", Callback = function(v) L.BulletTracers = v end})
LocalTracersToggle:AddColorPicker("BulletTracersColor", {Default = Color3.fromRGB(136, 159, 255), Title = "Start Color", Callback = function(v) L.BulletTracersColor = v end})
LocalTracersToggle:AddColorPicker("BulletTracersColor2", {Default = Color3.fromRGB(255, 255, 255), Title = "End Color", Callback = function(v) L.BulletTracersColor2 = v end})

local LocalTracersDep = VisualsTracers:AddDependencyBox()
LocalTracersDep:SetupDependencies({{LocalTracersToggle, true}})
LocalTracersDep:AddSlider("BulletTracersSize", {Text = "Size", Default = 0.2, Min = 0.05, Max = 2.5, Rounding = 2, Compact = true, Callback = function(v) L.BulletTracersSize = v end})
LocalTracersDep:AddSlider("BulletTracersDuration", {Text = "Duration", Default = 1, Min = 0.1, Max = 5, Rounding = 1, Suffix = "s", Compact = true, Callback = function(v) L.BulletTracersDuration = v end})
LocalTracersDep:AddDropdown("BulletTracersStyle", {Values = {"None", "1", "2", "3", "4", "5"}, Default = "None", Multi = false, Text = "Style", Callback = function(v) L.BulletTracersStyle = v end})

VisualsTracers:AddDivider()

local EnemyTracersToggle = VisualsTracers:AddToggle("EnemyBulletTracers", {Text = "Enemy Bullet Tracers", Default = false, Tooltip = "Shows other player's tracers.", Callback = function(v) L.EnemyBulletTracers = v end})
EnemyTracersToggle:AddColorPicker("EnemyBulletTracersColor", {Default = Color3.fromRGB(118, 52, 52), Title = "Start Color", Callback = function(v) L.EnemyBulletTracersColor = v end})
EnemyTracersToggle:AddColorPicker("EnemyBulletTracersColor2", {Default = Color3.fromRGB(255, 255, 255), Title = "End Color", Callback = function(v) L.EnemyBulletTracersColor2 = v end})

local EnemyTracersDep = VisualsTracers:AddDependencyBox()
EnemyTracersDep:SetupDependencies({{EnemyTracersToggle, true}})
EnemyTracersDep:AddSlider("EnemyBulletTracersSize", {Text = "Size", Default = 0.2, Min = 0.05, Max = 2.5, Rounding = 2, Compact = true, Callback = function(v) L.EnemyBulletTracersSize = v end})
EnemyTracersDep:AddSlider("EnemyBulletTracersDuration", {Text = "Duration", Default = 1, Min = 0.1, Max = 5, Rounding = 1, Suffix = "s", Compact = true, Callback = function(v) L.EnemyBulletTracersDuration = v end})
EnemyTracersDep:AddDropdown("EnemyBulletTracersStyle", {Values = {"None", "1", "2", "3", "4", "5"}, Default = "None", Multi = false, Text = "Style", Callback = function(v) L.EnemyBulletTracersStyle = v end})

local World_Group = Tabs.Visuals:AddRightGroupbox("World")

World_Group:AddToggle("NoFog", {Text = "No Fog", Default = false, Callback = function(v) L.NoFog = v; updateWorldVisuals() end})
World_Group:AddToggle("FullBright", {Text = "Fullbright", Default = false, Callback = function(v) L.FullBright = v; updateWorldVisuals() end})

World_Group:AddDivider()

local AtmToggle = World_Group:AddToggle("AtmosphereOverride", {Text = "Atmosphere Color", Default = false, Callback = function(v) 
    L.AtmosphereOverride = v
    if not v and worldOriginals.AtmosphereColor then
        local atm = S.Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then atm.Color = worldOriginals.AtmosphereColor end
        worldOriginals.AtmosphereColor = nil
    end
    updateWorldVisuals() 
end})
AtmToggle:AddColorPicker("AtmosphereColor", {Default = S.Lighting:FindFirstChildOfClass("Atmosphere") and S.Lighting:FindFirstChildOfClass("Atmosphere").Color or Color3.new(1, 1, 1), Title = "Atmosphere Color", Callback = function() updateWorldVisuals() end})

local CCToggle = World_Group:AddToggle("ColorCorrectionOverride", {Text = "Color Correction", Default = false, Callback = function(v) 
    L.ColorCorrectionOverride = v
    if not v and worldOriginals.ColorCorrectionTintColor then
        local cc = S.Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if cc then cc.TintColor = worldOriginals.ColorCorrectionTintColor end
        worldOriginals.ColorCorrectionTintColor = nil
    end
    updateWorldVisuals() 
end})
CCToggle:AddColorPicker("ColorCorrectionColor", {Default = S.Lighting:FindFirstChildOfClass("ColorCorrectionEffect") and S.Lighting:FindFirstChildOfClass("ColorCorrectionEffect").TintColor or Color3.new(1, 1, 1), Title = "Color Correction", Callback = function() updateWorldVisuals() end})

local BloomToggle = World_Group:AddToggle("BloomOverride", {Text = "Bloom", Default = false, Callback = function(v) 
    L.BloomOverride = v
    if not v and worldOriginals.Bloom then
        local bloom = S.Lighting:FindFirstChildOfClass("BloomEffect")
        if bloom then
            bloom.Intensity = worldOriginals.Bloom.Intensity; bloom.Threshold = worldOriginals.Bloom.Threshold; bloom.Size = worldOriginals.Bloom.Size
        end
        worldOriginals.Bloom = nil
    end
    updateWorldVisuals() 
end})
BloomToggle:AddColorPicker("BloomColor", {Default = Color3.new(1, 1, 1), Title = "Bloom Tint", Callback = function() updateWorldVisuals() end})

local BloomDep = World_Group:AddDependencyBox()
BloomDep:SetupDependencies({{BloomToggle, true}})
BloomDep:AddSlider("BloomIntensity", {Text = "Intensity", Default = S.Lighting:FindFirstChildOfClass("BloomEffect") and S.Lighting:FindFirstChildOfClass("BloomEffect").Intensity or 1, Min = 0, Max = 10, Rounding = 1, Compact = true, Callback = function() updateWorldVisuals() end})
BloomDep:AddSlider("BloomThreshold", {Text = "Threshold", Default = S.Lighting:FindFirstChildOfClass("BloomEffect") and S.Lighting:FindFirstChildOfClass("BloomEffect").Threshold or 1, Min = 0, Max = 10, Rounding = 1, Compact = true, Callback = function() updateWorldVisuals() end})
BloomDep:AddSlider("BloomSize", {Text = "Size", Default = S.Lighting:FindFirstChildOfClass("BloomEffect") and S.Lighting:FindFirstChildOfClass("BloomEffect").Size or 24, Min = 0, Max = 56, Rounding = 0, Compact = true, Callback = function() updateWorldVisuals() end})

World_Group:AddDivider()

local TimeToggle = World_Group:AddToggle("TimeOfDayEnabled", {Text = "Time Of Day", Default = false, Callback = function(v) 
    L.TimeOfDayEnabled = v
    if not v and worldOriginals.ClockTime then
        S.Lighting.ClockTime = worldOriginals.ClockTime
        worldOriginals.ClockTime = nil
    end
    updateWorldVisuals()
end})

local TimeDep = World_Group:AddDependencyBox()
TimeDep:SetupDependencies({{TimeToggle, true}})
TimeDep:AddSlider("WorldClockTime", {Text = "Time", Default = S.Lighting.ClockTime, Min = 0, Max = 24, Rounding = 1, Compact = true, Callback = function() updateWorldVisuals() end})

World_Group:AddToggle("AmbientOverride", {Text = "Ambient Override", Default = false, Callback = function(v) 
    L.AmbientOverride = v
    if not v and worldOriginals.Ambient then
        S.Lighting.Ambient = worldOriginals.Ambient; S.Lighting.OutdoorAmbient = worldOriginals.OutdoorAmbient
        worldOriginals.Ambient = nil; worldOriginals.OutdoorAmbient = nil
    end
    updateWorldVisuals()
end}):AddColorPicker("AmbientColor", {Default = S.Lighting.Ambient, Title = "Ambient", Callback = function() updateWorldVisuals() end}):AddColorPicker("OutdoorAmbientColor", {Default = S.Lighting.OutdoorAmbient, Title = "Outdoor Ambient", Callback = function() updateWorldVisuals() end})
local SA_Tabbox = Tabs.Combat:AddLeftTabbox("Silent & Aimbot")
local Combat_SA = SA_Tabbox:AddTab("Silent Aim")
local Combat_Aim = SA_Tabbox:AddTab("Aimbot")
local SA_Toggle = Combat_SA:AddToggle("SA_Enabled", {Text = "Silent Aim", Default = false, Callback = function(v) L.SA_Enabled = v end})
SA_Toggle:AddKeyPicker("SA_Key", {Default = "None", SyncToggleState = true, Mode = "Toggle", Text = "Silent Aim", NoUI = false})
Combat_SA:AddToggle("SA_Backtrack", {Text = "Backtrack Hitbox", Default = false, Callback = function(v) L.SA_Backtrack = v end})
Combat_SA:AddToggle("SA_WallCheck", {Text = "Wall Check", Default = false, Callback = function(v) L.SA_WallCheck = v end})
Combat_SA:AddToggle("SA_ClosestPart", {Text = "Closest Part", Default = false, Callback = function(v) L.SA_ClosestPart = v end})
Combat_SA:AddToggle("SA_DuelOnly", {Text = "Duel Focus", Default = false, Tooltip = "Focuses targeting onto your duel opponent when a duel is active.", Callback = function(v) L.SA_DuelOnly = v end})
Combat_SA:AddSlider("SA_HitChance", {Text = "Hit Chance", Default = 100, Min = 0, Max = 100, Suffix = "%", Rounding = 0, Compact = true, Callback = function(v) L.SA_HitChance = v end})
Combat_SA:AddSlider("SA_MaxDist", {Text = "Max Distance", Default = 1000, Min = 0, Max = 5000, Rounding = 0, Compact = true, Callback = function(v) L.SA_MaxDist = v end})
Combat_SA:AddDropdown("SA_TargetPart", {Values = {"Head", "UpperTorso", "Torso", "LowerTorso", "Random"}, Default = 1, Multi = false, Text = "Hit Part", Callback = function(v) L.SA_TargetPart = v end})
Combat_SA:AddDropdown("SA_Targets", {Values = {"Players", "NPCs", "Animals"}, Default = {"Players"}, Multi = true, Text = "Target Types", Callback = function(v) L.SA_Targets = v end})
Combat_SA:AddDivider()
Combat_SA:AddToggle("SA_Snapline", {Text = "Snapline", Default = false, Callback = function(v) L.SA_Snapline = v end}):AddColorPicker("SA_Snapline_Color", {Default = Color3.fromRGB(255, 255, 255), Title = "Color", Callback = function(c) if snaplineLine then snaplineLine.Color = c end; L.SA_Snapline_Color = c end})
local SA_FOV_Toggle = Combat_SA:AddToggle("SA_FOV_Vis", {Text = "Show FOV", Default = false, Callback = function(v) L.SA_FOV_Vis = v end})
SA_FOV_Toggle:AddColorPicker("SA_FOV_Color", {Default = Color3.fromRGB(255, 255, 255), Transparency = 0, Title = "Color", Callback = function(c, t) 
    L.SA_FOV_Color = c; L.SA_FOV_Transparency = t
    if fovCircle then fovCircle.Color = c; fovCircle.Transparency = 1 - t end
end})
local SA_FOV_Dep = Combat_SA:AddDependencyBox(); SA_FOV_Dep:SetupDependencies({{SA_FOV_Toggle, true}})
local SA_Grad_Toggle = SA_FOV_Dep:AddToggle("SA_FOV_Gradient", {Text = "Gradient Color", Default = false, Callback = function(v) L.SA_FOV_Gradient = v end})
SA_Grad_Toggle:AddColorPicker("SA_FOV_Grad1", {Default = Color3.new(1, 1, 1), Title = "Color 1", Callback = function(c) L.SA_FOV_Grad1 = c end})
SA_Grad_Toggle:AddColorPicker("SA_FOV_Grad2", {Default = Color3.fromRGB(125, 151, 255), Title = "Color 2", Callback = function(c) L.SA_FOV_Grad2 = c end})
local SA_Grad_Dep = Combat_SA:AddDependencyBox(); SA_Grad_Dep:SetupDependencies({{SA_Grad_Toggle, true}})
SA_Grad_Dep:AddSlider("SA_FOV_Speed", {Text = "Speed", Default = 1, Min = 0.1, Max = 10, Rounding = 1, Compact = true, Callback = function(v) L.SA_FOV_Speed = v end})
local SA_Highlight_Toggle = Combat_SA:AddToggle("SA_HighlightTarget", {Text = "Highlight Target", Default = false, Callback = function(v) L.SA_HighlightTarget = v end})
SA_Highlight_Toggle:AddColorPicker("SA_Highlight_Color", {Default = Color3.fromRGB(255, 0, 0), Title = "Highlight Color", Callback = function(c) L.SA_Highlight_Color = c end})
Combat_SA:AddToggle("SA_Dynamic_FOV", {Text = "Dynamic FOV", Default = false, Callback = function(v) L.SA_Dynamic_FOV = v end})
Combat_SA:AddSlider("SA_FOV_Radius", {Text = "FOV Radius", Default = 130, Min = 0, Max = 800, Rounding = 0, Compact = true, Callback = function(v) L.SA_FOV = v; UI.fov.Radius = v; UI.fovO.Radius = v end})
Combat_SA:AddSlider("SA_FOV_Thickness", {Text = "FOV Thickness", Default = 1.5, Min = 1, Max = 5, Rounding = 1, Compact = true, Callback = function(v) L.SA_FOV_Thickness = v end})

local AimToggle = Combat_Aim:AddToggle("Aim_Enabled", {Text = "Aimbot", Default = false, Callback = function(v) L.Aim_Enabled = v end})
AimToggle:AddKeyPicker("Aim_Key", {Default = "MB2", SyncToggleState = true, Mode = "Hold", Text = "Aimbot", NoUI = false})
Combat_Aim:AddToggle("Aim_WallCheck", {Text = "Wall Check", Default = false, Callback = function(v) L.Aim_WallCheck = v end})
Combat_Aim:AddToggle("Aim_StickyAim", {Text = "Sticky Aim", Default = false, Callback = function(v) L.Aim_StickyAim = v end})
Combat_Aim:AddToggle("Aim_BulletDrop", {Text = "Calculate Bullet Drop", Default = false, Callback = function(v) L.Aim_BulletDrop = v end})
Combat_Aim:AddToggle("Aim_BulletLead", {Text = "Calculate Bullet Lead", Default = false, Callback = function(v) L.Aim_BulletLead = v end})
Combat_Aim:AddToggle("Aim_DuelOnly", {Text = "Duel Focus", Default = false, Tooltip = "Focuses targeting onto your duel opponent when a duel is active.", Callback = function(v) L.Aim_DuelOnly = v end})
Combat_Aim:AddSlider("Aim_Smoothness", {Text = "Smoothness", Default = 1, Min = 1, Max = 10, Rounding = 1, Compact = true, Callback = function(v) L.Aim_Smoothness = v end})
Combat_Aim:AddSlider("Aim_MaxDist", {Text = "Max Distance", Default = 1000, Min = 0, Max = 5000, Rounding = 0, Compact = true, Callback = function(v) L.Aim_MaxDist = v end})
Combat_Aim:AddDropdown("Aim_TargetPart", {Values = {"Head", "UpperTorso", "Torso", "LowerTorso", "Random"}, Default = 1, Multi = false, Text = "Aimbot Bone", Callback = function(v) L.Aim_TargetPart = v end})
Combat_Aim:AddDropdown("Aim_Targets", {Values = {"Players", "NPCs", "Animals"}, Default = {"Players"}, Multi = true, Text = "Targets", Callback = function(v) L.Aim_Targets = v end})
Combat_Aim:AddDivider()
Combat_Aim:AddToggle("Aim_Snapline", {Text = "Snapline", Default = false, Callback = function(v) L.Aim_Snapline = v end}):AddColorPicker("Aim_Snapline_Color", {Default = Color3.fromRGB(255, 255, 255), Title = "Color", Callback = function(c) if aimSnaplineLine then aimSnaplineLine.Color = c end; L.Aim_Snapline_Color = c end})
local Aim_FOV_Toggle = Combat_Aim:AddToggle("Aim_FOV_Vis", {Text = "Show FOV", Default = false, Callback = function(v) L.Aim_FOV_Vis = v end})
Aim_FOV_Toggle:AddColorPicker("Aim_FOV_Color", {Default = Color3.fromRGB(255, 255, 255), Transparency = 0, Title = "Color", Callback = function(c, t) 
    L.Aim_FOV_Color = c; L.Aim_FOV_Transparency = t
    if aimFovCircle then aimFovCircle.Color = c; aimFovCircle.Transparency = 1 - t end
end})
local Aim_FOV_Dep = Combat_Aim:AddDependencyBox(); Aim_FOV_Dep:SetupDependencies({{Aim_FOV_Toggle, true}})
local Aim_Grad_Toggle = Aim_FOV_Dep:AddToggle("Aim_FOV_Gradient", {Text = "Gradient Color", Default = false, Callback = function(v) L.Aim_FOV_Gradient = v end})
Aim_Grad_Toggle:AddColorPicker("Aim_FOV_Grad1", {Default = Color3.new(1, 1, 1), Title = "Color 1", Callback = function(c) L.Aim_FOV_Grad1 = c end})
Aim_Grad_Toggle:AddColorPicker("Aim_FOV_Grad2", {Default = Color3.fromRGB(125, 151, 255), Title = "Color 2", Callback = function(c) L.Aim_FOV_Grad2 = c end})
local Aim_Grad_Dep = Combat_Aim:AddDependencyBox(); Aim_Grad_Dep:SetupDependencies({{Aim_Grad_Toggle, true}})
Aim_Grad_Dep:AddSlider("Aim_FOV_Speed", {Text = "Speed", Default = 1, Min = 0.1, Max = 10, Rounding = 1, Compact = true, Callback = function(v) L.Aim_FOV_Speed = v end})
local Aim_Highlight_Toggle = Combat_Aim:AddToggle("Aim_HighlightTarget", {Text = "Highlight Target", Default = false, Callback = function(v) L.Aim_HighlightTarget = v end})
Aim_Highlight_Toggle:AddColorPicker("Aim_Highlight_Color", {Default = Color3.fromRGB(255, 0, 0), Title = "Highlight Color", Callback = function(c) L.Aim_Highlight_Color = c end})
Combat_Aim:AddToggle("Aim_Dynamic_FOV", {Text = "Dynamic FOV", Default = false, Callback = function(v) L.Aim_Dynamic_FOV = v end})
Combat_Aim:AddSlider("Aim_FOV_Radius", {Text = "FOV Radius", Default = 130, Min = 0, Max = 800, Rounding = 0, Compact = true, Callback = function(v) L.Aim_FOV = v; UI.aimFov.Radius = v; UI.aimFovO.Radius = v end})
Combat_Aim:AddSlider("Aim_FOV_Thickness", {Text = "FOV Thickness", Default = 1.5, Min = 1, Max = 5, Rounding = 1, Compact = true, Callback = function(v) L.Aim_FOV_Thickness = v end})

local Combat_GM = Tabs.Combat:AddRightGroupbox("Gun Mods")
local GM_RecoilToggle = Combat_GM:AddToggle("GM_NoRecoil", {Text = "No Recoil", Default = false, Callback = function(v) L.GM_NoRecoil = v; updateGunMods() end})
local GM_RecoilDep = Combat_GM:AddDependencyBox(); GM_RecoilDep:SetupDependencies({{GM_RecoilToggle, true}})
GM_RecoilDep:AddSlider("GM_RecoilAmount", {Text = "Recoil Amount", Default = 0, Min = 0, Max = 100, Suffix = "%", Rounding = 0, Compact = true, Callback = function(v) L.GM_RecoilAmount = v; updateGunMods() end})
local GM_SpreadToggle = Combat_GM:AddToggle("GM_NoSpread", {Text = "No Spread", Default = false, Callback = function(v) L.GM_NoSpread = v; updateGunMods() end})
local GM_SpreadDep = Combat_GM:AddDependencyBox(); GM_SpreadDep:SetupDependencies({{GM_SpreadToggle, true}})
GM_SpreadDep:AddSlider("GM_SpreadAmount", {Text = "Spread Amount", Default = 0, Min = 0, Max = 100, Suffix = "%", Rounding = 0, Compact = true, Callback = function(v) L.GM_SpreadAmount = v; updateGunMods() end})
Combat_GM:AddToggle("GM_InstantReload", {Text = "Instant Reload", Default = false, Callback = function(v) L.GM_InstantReload = v; updateGunMods() end})
Combat_GM:AddToggle("GM_InfWallbang", {Text = "Infinite Wallbang", Default = false, Callback = function(v) L.GM_InfWallbang = v; updateGunMods() end})
Combat_GM:AddToggle("GM_RapidFire", {Text = "No Weapon Delay", Default = false, Callback = function(v) L.GM_RapidFire = v; updateGunMods() end})
Combat_GM:AddToggle("GM_NoScope", {Text = "No Scope Overlay", Default = false, Callback = function(v) 
    L.GM_NoScope = v; 
    updateGunMods()
    if not v then
        local mainUI = LP.PlayerGui:FindFirstChild("MainUI")
        if mainUI then mainUI.Enabled = true end
    end
end})
local ReloadModifierToggle = Combat_GM:AddToggle("GM_ReloadSpeedModifier", {Text = "Reload Speed Modifier", Default = false, Callback = function(v) L.GM_ReloadSpeedModifier = v; updateGunMods() end})
local ReloadModifierDep = Combat_GM:AddDependencyBox(); ReloadModifierDep:SetupDependencies({{ReloadModifierToggle, true}})
ReloadModifierDep:AddSlider("GM_ReloadSpeedAmount", {Text = "Modifier Amount", Default = 2, Min = 0.1, Max = 10, Rounding = 1, Compact = true, Suffix = "x", Callback = function(v) L.GM_ReloadSpeedAmount = v; updateGunMods() end})
local Misc_Camera = Tabs.Misc:AddLeftGroupbox("Camera")
Misc_Camera:AddToggle('CZ_E', {Text='Camera Zoom', Default=false, Callback=function(v) L.CZ_E=v end}):AddKeyPicker('CZ_K', {Default='None', SyncToggleState=true, Mode='Toggle', Text='Camera Zoom', NoUI=false})
Misc_Camera:AddSlider('CZ_V', {Text='Zoom Multiplier', Default=1, Min=1, Max=15, Rounding = 1, Compact=true, Suffix='x', Callback=function(v) L.CZ_V=v end})
local Misc_Emotes = Tabs.Misc:AddLeftGroupbox("Emotes")
local ClapToggle = Misc_Emotes:AddToggle("ClapSpeedMultiplier", {Text = "Clap Speed Multiplier", Default = false, Callback = function(v) 
    L.ClapSpeedMultiplier = v
    local params = S.ReplicatedStorage:FindFirstChild("Params")
    local emoteParams = params and params:FindFirstChild("Emotes")
    local clapSpeed = emoteParams and emoteParams:FindFirstChild("ClapSpeed")
    if clapSpeed and clapSpeed:IsA("NumberValue") then
        clapSpeed.Value = v and L.ClapSpeedAmount or 3
    end
end})
local ClapDep = Misc_Emotes:AddDependencyBox(); ClapDep:SetupDependencies({{ClapToggle, true}})
ClapDep:AddSlider("ClapSpeedAmount", {Text = "Speed Multiplier", Default = 3, Min = 0.1, Max = 10000, Rounding = 1, Compact = true, Callback = function(v) 
    L.ClapSpeedAmount = v
    if L.ClapSpeedMultiplier then
        local params = S.ReplicatedStorage:FindFirstChild("Params")
        local emoteParams = params and params:FindFirstChild("Emotes")
        local clapSpeed = emoteParams and emoteParams:FindFirstChild("ClapSpeed")
        if clapSpeed and clapSpeed:IsA("NumberValue") then clapSpeed.Value = v end
    end
end})
Misc_Emotes:AddDivider()
local emotePackFolder = S.ReplicatedStorage.Resources.Animations_New.Player.Emotes.EmotePack
local emoteList = {"Yakuza", "Bow", "Dab", "Dance3", "Dance4", "Kalinka", "Ponder", "The Shuffle", "The Twist"}
local EmoteToggle = Misc_Emotes:AddToggle("EmotePackEnabled", {Text = "Emote Pack", Default = false, Callback = function(v) L.EmotePackEnabled = v end})
local EmoteDep = Misc_Emotes:AddDependencyBox(); EmoteDep:SetupDependencies({{EmoteToggle, true}})
for _, name in ipairs(emoteList) do
    EmoteDep:AddButton(name, function()
        local animObj = emotePackFolder:FindFirstChild(name)
        if animObj then playEmote(animObj) end
    end)
end
EmoteDep:AddButton("Stop Emote", function()
    if currentEmoteTrack then currentEmoteTrack:Stop(); currentEmoteTrack:Destroy(); currentEmoteTrack = nil end
end)

local Misc_Troll = Tabs.Misc:AddLeftGroupbox("Troll")
local MBF_Toggle = Misc_Troll:AddToggle("MBF_Enabled", {Text = "Money Bag Fling", Default = false, Callback = function(v) 
    L.MBF_Enabled = v 
    if v and Toggles.MBF_ShowRadius then Toggles.MBF_ShowRadius:SetValue(true) end
end})
MBF_Toggle:AddKeyPicker("MBF_Key", {Default = "None", SyncToggleState = true, Mode = "Toggle", Text = "Money Bag Fling", NoUI = false})

local MBF_Dep = Misc_Troll:AddDependencyBox(); MBF_Dep:SetupDependencies({{MBF_Toggle, true}})
MBF_Dep:AddToggle("MBF_ShowRadius", {Text = "Show Radius", Default = false, Callback = function(v) L.MBF_ShowRadius = v end}):AddColorPicker("MBF_RadiusColor", {Default = Color3.fromRGB(255, 255, 255), Title = "Radius Color", Callback = function(c) L.MBF_RadiusColor = c end})
MBF_Dep:AddSlider("MBF_Radius", {Text = "Radius", Default = 25, Min = 5, Max = 100, Rounding = 1, Compact = true, Callback = function(v) L.MBF_Radius = v end})
local MBF_StatusLabel = MBF_Dep:AddLabel("Status: <font color=\"#FFFFFF\">Inactive</font>")
MBF_StatusLabel.RichText = true

local function updateMBFStatus(status, color)
    local hex = string.format("%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
    MBF_StatusLabel:SetText(string.format("Status: <font color=\"#%s\">%s</font>", hex, status))
end
local LocalMods = Tabs.Misc:AddRightGroupbox("Local Mods")
-- Fly
local FlyToggle = LocalMods:AddToggle("FlyEnabled", {Text = "Fly", Default = false, Callback = function(v) L.FlyEnabled = v end})
FlyToggle:AddKeyPicker("FlyKey", {Default = "None", SyncToggleState = true, Mode = "Toggle", Text = "Fly", NoUI = false})
local FlyDep = LocalMods:AddDependencyBox(); FlyDep:SetupDependencies({{FlyToggle, true}})
FlyDep:AddSlider("FlySpeed", {Text = "Fly Speed Amount", Default = 25, Min = 10, Max = 28, Rounding = 0, Compact = true, Callback = function(v) L.FlySpeed = v end})
-- Speed
local SpeedToggle = LocalMods:AddToggle("SpeedEnabled", {Text = "Speed", Default = false, Callback = function(v) L.SpeedEnabled = v end})
SpeedToggle:AddKeyPicker("SpeedKey", {Default = "None", SyncToggleState = true, Mode = "Toggle", Text = "Speed", NoUI = false})
local SpeedDep = LocalMods:AddDependencyBox(); SpeedDep:SetupDependencies({{SpeedToggle, true}})
SpeedDep:AddSlider("SpeedAmount", {Text = "Walkspeed Amount", Default = 25, Min = 16, Max = 28, Rounding = 0, Compact = true, Callback = function(v) L.SpeedAmount = v end})
-- No Ragdoll
LocalMods:AddToggle("NoRagdoll", {Text = "No Ragdoll", Default = false, Callback = function(v) 
    L.NoRagdoll = v 
    if v and Modules.plrCharacter then
        local _Ragdoll = Modules.plrCharacter.Ragdoll
        Modules.plrCharacter.Ragdoll = wwguard(_Ragdoll, function(...)
            if not L.NoRagdoll then return _Ragdoll(...) end
        end)
    end
end})
-- No Jump Delay
LocalMods:AddToggle("NoJumpDelay", {Text = "No Jump Delay", Default = false, Callback = function(v) L.NoJumpDelay = v end})
-- No Fall Damage
LocalMods:AddToggle("NoFallDamage", {Text = "No Fall Damage", Default = false, Callback = function(v) L.NoFallDamage = v end})
-- Auto Break Free
LocalMods:AddToggle("AutoBreakFree", {Text = "Auto Break Free", Default = false, Callback = function(v) 
    L.AutoBreakFree = v 
    if v and Modules.plrCharacter then
        local _BreakFreePerc = Modules.plrCharacter.BreakFreePerc
        setmetatable(Modules.plrCharacter, {
            __index = function(t, p)
                if p == "BreakFreePerc" then return _BreakFreePerc end
                return rawget(t, p)
            end,
            __newindex = function(t, p, v)
                if p == "BreakFreePerc" then
                    _BreakFreePerc = v
                    if L.AutoBreakFree and v > 0 then _BreakFreePerc = 1 end
                else
                    rawset(t, p, v)
                end
            end
        })
        Modules.plrCharacter.BreakFreePerc = nil
    end
end})
-- Auto Get Up
LocalMods:AddToggle("AutoGetUp", {Text = "Auto Get Up", Default = false, Callback = function(v) 
    L.AutoGetUp = v 
    if v then
        task.spawn(function()
            while L.AutoGetUp do
                if Modules.Network and Modules.plrCharacter and Modules.plrCharacter:CanGetUp() then
                    pcall(function()
                        if Modules.repState.State.Stamina <= 0 then
                            Modules.plrCharacter:ToggleSelfRagdoll(false)
                            Modules.Network:InvokeServer("AttemptGetUp")
                        end
                    end)
                end
                task.wait()
            end
        end)
    end
end})
-- Infinite Stamina
LocalMods:AddToggle("InfiniteStamina", {Text = "Infinite Stamina", Default = false, Callback = function(v) 
    L.InfStamina = v
    if v and Modules.repState then
        local _repState = Modules.repState
        local _Stamina = _repState.State.Stamina
        setmetatable(_repState.State, {
            __index = function(_, p)
                if p == "Stamina" then return L.InfStamina and 100 or _Stamina end
            end,
            __newindex = function(t, p, v)
                if p == "Stamina" then _Stamina = v else rawset(t, p, v) end
            end
        })
        _repState.State.Stamina = nil
    end
end})
-- Roll Speed Modifier
local RollSpeedToggle = LocalMods:AddToggle("RollSpeedModifier", {Text = "Roll Speed Modifier", Default = false, Callback = function(v)
    L.RollSpeedModifier = v
    local ok, p2To = pcall(function()
        return game:GetService("ReplicatedStorage").Params.Character.Roll.Phase2.To
    end)
    if ok and p2To and p2To:IsA("NumberValue") then
        if v then
            if not O.Roll[p2To] then O.Roll[p2To] = p2To.Value end
            p2To.Value = O.Roll[p2To] * L.RollSpeedAmount
        elseif O.Roll[p2To] then
            p2To.Value = O.Roll[p2To]
        end
    end
end})
local RollSpeedDep = LocalMods:AddDependencyBox(); RollSpeedDep:SetupDependencies({{RollSpeedToggle, true}})
RollSpeedDep:AddSlider("RollSpeedAmount", {Text = "Roll Speed", Default = 1.25, Min = 0.5, Max = 5, Rounding = 2, Suffix = "x", Compact = true, Callback = function(v)
    L.RollSpeedAmount = v
    if not L.RollSpeedModifier then return end
    local ok, p2To = pcall(function()
        return game:GetService("ReplicatedStorage").Params.Character.Roll.Phase2.To
    end)
    if ok and p2To and p2To:IsA("NumberValue") and O.Roll[p2To] then
        p2To.Value = O.Roll[p2To] * v
    end
end})
local function getActiveDuelOpponent()
    if not LP then return nil end
    local pGui = LP:FindFirstChild("PlayerGui")
    if not pGui then return nil end
    local pInfo = pGui:FindFirstChild("PlayerInfo")
    if not pInfo then return nil end
    local usl = pInfo:FindFirstChild("UserStatusList")
    if not usl then return nil end
    local duel = usl:FindFirstChild("Duel")
    if not duel or not duel.Visible then return nil end
    local statusName = duel:FindFirstChild("StatusName")
    if not statusName or not statusName:IsA("TextLabel") then return nil end
    local text = statusName.Text
    local name = string.match(text, "</b>\n?(.-)%s*-")
    if not name then name = string.match(text, "Dueling\n?(.-)%s*-") end
    return name
end
local function getHlColor(baseColor, hlTrans, actColor, duelTrans, duelColor, prioTrans, prioColor, friendTrans, friendColor)
    local c = baseColor
    if friendTrans and friendTrans > 0 and friendColor then c = c:Lerp(friendColor, friendTrans) end
    if prioTrans and prioTrans > 0 and prioColor then c = c:Lerp(prioColor, prioTrans) end
    if duelTrans and duelTrans > 0 and duelColor then c = c:Lerp(duelColor, duelTrans) end
    if hlTrans and hlTrans > 0 and actColor then c = c:Lerp(actColor, hlTrans) end
    return c
end
local function onRenderSteppedESP(dt, cP, n, mP, camCF)
    local duelOpponent = getActiveDuelOpponent()
    for m, data in pairs(espCache) do
        if not m or not m.Parent then hAll(m) continue end
        local prefix = data.type == "NPCs" and "NPC_" or (data.type == "Animals" and "Animal_" or "")
        local sS, d = data.sS, data.d or 0
        local fA = data.fA or 0
        if L[prefix .. "Master"] and sS then fA = math.min(fA + dt / (L.FIn or 0.15), 1) else fA = math.max(fA - dt / (L.FOut or 0.15), 0) end
        if data.type == "NPCs" then
            if not data.cachedName or data.lastCase ~= L.FCase then data.cachedName = aFC(gPN(m)); data.lastCase = L.FCase end
            if data.cachedName == "Model" then fA = 0 end
        end
        data.fA = fA

        local isDuelOpponent = (duelOpponent and data.type == "Players" and m.Name == duelOpponent)
        if L.OverwriteDuelOpponent and isDuelOpponent then
            data.duelTrans = math.min((data.duelTrans or 0) + dt / 0.15, 1)
        else
            data.duelTrans = math.max((data.duelTrans or 0) - dt / 0.15, 0)
        end

        local isPriority = (data.type == "Players" and L.Priorities and L.Priorities[m.Name])
        if L.PE and isPriority then
            data.prioTrans = math.min((data.prioTrans or 0) + dt / 0.15, 1)
        else
            data.prioTrans = math.max((data.prioTrans or 0) - dt / 0.15, 0)
        end

        local isFriendly = (data.type == "Players" and L.Friendlies and L.Friendlies[m.Name])
        if L.FE and isFriendly then
            data.friendTrans = math.min((data.friendTrans or 0) + dt / 0.15, 1)
        else
            data.friendTrans = math.max((data.friendTrans or 0) - dt / 0.15, 0)
        end

        local isSATarget = (L.SA_HighlightTarget and L.SA_Enabled and m == SA_State.CurrentTarget)
        local isAimTarget = (L.Aim_HighlightTarget and L.Aim_Enabled and m == Aim_State.CurrentTarget)
        if isSATarget or isAimTarget then
            data.hlTrans = math.min((data.hlTrans or 0) + dt / 0.15, 1)
            data.hlColor = isAimTarget and L.Aim_Highlight_Color or L.SA_Highlight_Color
        else
            data.hlTrans = math.max((data.hlTrans or 0) - dt / 0.15, 0)
        end
        local hlTrans = data.hlTrans or 0
        local actColor = data.hlColor or L.SA_Highlight_Color
        local duelTrans = data.duelTrans or 0
        if fA <= 0 then if data.removed then rHE(m, true) end hAll(m) continue end
        local to = data.to
        local pos = data.lastW
        if not data.removed and to and to.Parent then pos = gP(to); data.lastW = pos end
        if not pos then hAll(m) continue end
        local sP, onS = C:WorldToViewportPoint(pos)
        if not onS and not data.removed then hAll(m) continue end
        local tW, bW = pos + v3_T, pos - v3_B
        local tP, tV = C:WorldToViewportPoint(tW)
        local bP, bV = C:WorldToViewportPoint(bW)
        if not tV or not bV then hAll(m) continue end
        local h, w = math.floor(math.abs(tP.Y - bP.Y)), math.floor(math.abs(tP.Y - bP.Y) * 0.55)
        local x, y = math.floor(tP.X - w / 2), math.floor(tP.Y)
        local tN, tWp, tD, bx, ou, fl, hB, hO, hT, aCList, hSolid = L.ND[m], L.WD[m], L.DD[m], L.BD[m], L.BOD[m], L.BFD[m], L.HD[m], L.HOD[m], L.HTD[m], L.AC[m], L.HSD[m]
        local dE, wE, nE, bE, hE, cE, skE = L[prefix .. "DE"], L[prefix .. "WE"], L[prefix .. "NE"], L[prefix .. "BE"], L[prefix .. "HE"], L[prefix .. "CE"], L[prefix .. "SKE"]
        if data.type == "Animals" and not data.isLegendary then
            if not data.animalName then data.animalName = m.Name:lower() end
            local maxH = data.maxH or 100
            local name = data.animalName
            if (name:find("bear") and maxH > 301) or (name:find("bison") and maxH > 301) or (name:find("deer") and maxH > 51) or (name:find("gator") and maxH > 301) then
                data.isLegendary = true
                if L.Animal_NotifyLegendary and not data.notifiedLegendary then
                    data.notifiedLegendary = true
                    Library:Notify("Legendary Animal Spawned: " .. aFC(gPN(m)), 5)
                end
            end
        end
        if data.type == "Animals" and L.Animal_LegendaryOnly and not data.isLegendary then hAll(m) continue end
        local nameColor = L[prefix .. "NTC"]
        local distColor = L[prefix .. "DTC"]
        if data.isLegendary and L.Animal_LegendaryOverride then
            nameColor = L.Animal_LegendaryColor
            distColor = L.Animal_LegendaryColor
        end
        nameColor = getHlColor(nameColor, hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)
        distColor = getHlColor(distColor, hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)
        if tN then 
            if nE and L[prefix .. "Master"] then 
                if not data.cachedName or data.lastCase ~= L.FCase then 
                    local rawName = gPN(m)
                    data.cachedName = (data.isLegendary and "Legendary " or "") .. aFC(rawName)
                    data.lastCase = L.FCase 
                end 
                local text = data.cachedName
                local fs = math.floor(L[prefix .. "FS"] or 13)
                cPropV2(tN, "Position", x + w / 2, y - 15) cProp(tN, "Text", text) cProp(tN, "Color", nameColor) cProp(tN, "Transparency", fA) cProp(tN, "Visible", true) cProp(tN, "Size", fs) cProp(tN, "Center", true)
                if data.type == "Animals" and hT and hE then
                    local curH = (data.hs or 1) * (data.maxH or 100)
                    local hText = " [ " .. math.floor(curH) .. "/" .. math.floor(data.maxH or 100) .. " ]"
                    local nBounds = tN.TextBounds
                    cProp(hT, "Center", false)
                    local hlcAnim = getHlColor(L[prefix .. "HLC"], hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)
                    local hhcAnim = getHlColor(L[prefix .. "HHC"], hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)
                    cPropV2(hT, "Position", math.floor((x + w / 2) + (nBounds.X / 2) + 4), y - 15) cProp(hT, "Text", hText) cProp(hT, "Color", hlcAnim:Lerp(hhcAnim, data.hs or 1)) cProp(hT, "Transparency", fA) cProp(hT, "Visible", true) cProp(hT, "Size", fs)
                elseif hT and data.type == "Animals" then cProp(hT, "Visible", false) end
            else cProp(tN, "Visible", false) if hT and data.type == "Animals" then cProp(hT, "Visible", false) end end 
        end
        if tWp then if wE and L[prefix .. "Master"] then cPropV2(tWp, "Position", x + w / 2, y + h) cProp(tWp, "Text", aFC(data.wN or "None")) cProp(tWp, "Color", getHlColor(L[prefix .. "WTC"], hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)) cProp(tWp, "Transparency", fA) cProp(tWp, "Visible", true) else cProp(tWp, "Visible", false) end end
        if tD then 
            if dE and L[prefix .. "Master"] then 
                local dDisp = math.floor(L[prefix .. "DistMode"] == "Meters" and d * 0.28 or d) 
                local dSuffix = L[prefix .. "DistMode"] == "Meters" and "m" or "s" 
                local text = dDisp .. dSuffix
                local fs = math.floor(L[prefix .. "FS"] or 13)
                local posX, posY = x + w / 2, y + h + (wE and fs or 0)
                if data.type == "Animals" then
                    text = "[ " .. dDisp .. dSuffix .. " ]"
                    local nBounds, hBounds = tN.TextBounds, (hT and hT.TextBounds or {X = 0})
                    local totalW = nBounds.X + 4 + (hE and hBounds.X or 0)
                    posX = math.floor((x + w / 2) - (nBounds.X / 2) + (totalW / 2))
                    posY = math.floor(y - 3)
                end
                cPropV2(tD, "Position", posX, posY) cProp(tD, "Text", text) cProp(tD, "Color", distColor) cProp(tD, "Transparency", fA) cProp(tD, "Visible", true) cProp(tD, "Size", fs) cProp(tD, "Center", true)
            else cProp(tD, "Visible", false) end 
        end
        if hT and data.type ~= "Animals" then
            cProp(hT, "Visible", false)
        end
        if bx and ou then
            if bE and L[prefix .. "Master"] then
                cProp(bx, "Visible", true) cProp(ou, "Visible", true) cProp(bx, "Color", getHlColor(L[prefix .. "BC"], hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)) cProp(ou, "Color", Color3.new(0, 0, 0)) cProp(bx, "Transparency", fA) cProp(ou, "Transparency", fA)
                cPropV2(bx, "Size", w, h) cPropV2(bx, "Position", x, y) cPropV2(ou, "Size", w, h) cPropV2(ou, "Position", x, y)
                if fl then if L[prefix .. "BFE"] then cProp(fl, "Visible", true) cProp(fl, "Color", getHlColor(L[prefix .. "BFC"], hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)) cProp(fl, "Transparency", (1 - L[prefix .. "BFTrans"]) * fA) cPropV2(fl, "Size", w, h) cPropV2(fl, "Position", x, y) else cProp(fl, "Visible", false) end end
            else cProp(bx, "Visible", false) cProp(ou, "Visible", false) if fl then cProp(fl, "Visible", false) end end
        end
        if hB and hO and data.type ~= "Animals" then
            if hE and L[prefix .. "Master"] then
                local vs = L.VH[m] or 0
                if not data.removed then vs = vs + ((data.hs or 0) - vs) * (1 - math.exp(-15 * dt)) end
                L.VH[m] = vs; local bX, bY = math.floor(x - 5), math.floor(y)
                cPropV2(hO, "Size", 4, math.floor(h) + 2) cPropV2(hO, "Position", bX - 1, bY - 1) cProp(hO, "Transparency", fA) cProp(hO, "Visible", true)
                local bh = math.ceil(h * vs); local hC = L[prefix .. "HLC"]:Lerp(L[prefix .. "HHC"], vs)
                local hlc = getHlColor(L[prefix .. "HLC"], hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)
                local hhc = getHlColor(L[prefix .. "HHC"], hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)
                if L[prefix .. "HGR"] then 
                    cProp(hSolid, "Visible", false)
                    local t = M.clock() * (L[prefix .. "HGRS"] or 4); local mode = L[prefix .. "HGR_Type"]; local animated = L[prefix .. "HGR_Anim"]
                    for i = 1, 65 do local seg = hB[i] if i <= (vs * 65) then local p = i / 65 local factor = p
                        if animated then
                            if mode == "Pulsing Glow" then factor = M.clamp(p + math.sin(t) * 0.3, 0, 1) elseif mode == "Wave Bounce" then factor = M.abs(math.sin(t - p * 3)) end
                        end
                        local color = hlc:Lerp(hhc, factor)
                        local segBottom = M.floor(y + h - (i - 1) * (h / 65))
                        local segTop = M.floor(y + h - i * (h / 65))
                        cPropV2(seg, "Size", 2, segBottom - segTop) cPropV2(seg, "Position", bX, segTop) cProp(seg, "Color", color) cProp(seg, "Transparency", fA) cProp(seg, "Visible", true)
                    else cProp(seg, "Visible", false) end end
                else 
                    for i = 1, 65 do cProp(hB[i], "Visible", false) end 
                    cPropV2(hSolid, "Size", 2, bh) cPropV2(hSolid, "Position", bX, M.floor(y + h - bh))
                    cProp(hSolid, "Color", hC) cProp(hSolid, "Transparency", fA) cProp(hSolid, "Visible", true)
                end
                if hT and L[prefix .. "HTE"] then
                    local fP = L.HTFC[m] or 0 if vs < 0.99 and not data.removed then fP = math.min(fP + dt / 0.15, 1) else fP = math.max(fP - dt / 0.15, 0) end L.HTFC[m] = fP
                    if fP > 0.01 then cProp(hT, "Text", tostring(math.floor(vs * 100))) cPropV2(hT, "Position", x - 15, y + h - bh - 7) cProp(hT, "Color", getHlColor(L[prefix .. "HTC"], hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)) cProp(hT, "Transparency", fA * fP) cProp(hT, "Visible", true) else cProp(hT, "Visible", false) end
                elseif hT then cProp(hT, "Visible", false) end
            else cProp(hO, "Visible", false) for i = 1, 65 do if hB[i] then hB[i].Visible = false end end if hT then cProp(hT, "Visible", false) end end
        elseif hB and hO then cProp(hB, "Visible", false) cProp(hO, "Visible", false) end
        if aCList then
            if cE and L[prefix .. "Master"] and not data.removed then
                local fCol = getHlColor(L[prefix .. "CFC"], hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)
                local oCol = getHlColor(L[prefix .. "CC"], hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC)
                local fTrans = 1 - (fA * (1 - L[prefix .. "CFTrans"]))
                local oTrans = 1 - (fA * (1 - L[prefix .. "CTrans"]))
                local dMode = Enum.HighlightDepthMode[L[prefix .. "CB"]]
                
                if aCList.FillColor ~= fCol then aCList.FillColor = fCol end
                if aCList.OutlineColor ~= oCol then aCList.OutlineColor = oCol end
                if aCList.FillTransparency ~= fTrans then aCList.FillTransparency = fTrans end
                if aCList.OutlineTransparency ~= oTrans then aCList.OutlineTransparency = oTrans end
                if aCList.DepthMode ~= dMode then aCList.DepthMode = dMode end
                if not aCList.Enabled then aCList.Enabled = true end
            else 
                if aCList.Enabled then aCList.Enabled = false end 
            end
        end
        if skE and L[prefix .. "Master"] and fA > 0 then
            local isR15 = data.hu and data.hu.RigType == Enum.HumanoidRigType.R15; local lines = L.SKD[m]
            if not lines then lines = {} for i = 1, 40 do local l = Drawing.new("Line") l.Visible = false; l.Thickness = (i <= 20 and 2 or 1); l.ZIndex = (i <= 20 and 1 or 2); l.Color = (i <= 20 and Color3.new(0, 0, 0) or L[prefix .. "SKC"]) lines[i] = l end L.SKD[m] = lines end
            local pts = data.lastPts; local allV = false
            if not data.removed then
                local bCount = isR15 and 15 or 6
                if not data.bones or #data.bones < bCount or data.isR15 ~= isR15 then local bones = {} local list = isR15 and L.R15_N or L.SK_N for i = 1, bCount do bones[i] = m:FindFirstChild(list[i]) end data.bones, data.isR15 = bones, isR15 end
                local b, newPts = data.bones, {}; allV = true
                for i = 1, bCount do if b[i] and b[i].Parent then local p, o = C:WorldToViewportPoint(b[i].Position) if o then newPts[i] = Vector2.new(p.X, p.Y) else allV = false break end else allV = false break end end
                if allV then pts = newPts; data.lastPts = pts end
            end
            if pts and (data.removed or allV) then
                local sCl, conList = getHlColor(L[prefix .. "SKC"], hlTrans, actColor, duelTrans, L.OverwriteDuelColor, data.prioTrans, L.PCOC, data.friendTrans, L.FCOC), (isR15 and L.R15_C or L.SK_C); local reqLines = #conList
                local sT = fA * (1 - L[prefix .. "SKTrans"])
                for i = 1, reqLines do 
                    local ol, l = lines[i], lines[i + 20] 
                    local con = conList[i] 
                    local p1, p2 = pts[con[1]], pts[con[2]] 
                    if p1 and p2 then 
                        cPropV2(ol, "From", p1.X, p1.Y); cPropV2(l, "From", p1.X, p1.Y); 
                        cPropV2(ol, "To", p2.X, p2.Y); cPropV2(l, "To", p2.X, p2.Y); 
                        cProp(l, "Color", sCl); 
                        cProp(ol, "Transparency", sT); cProp(l, "Transparency", sT); 
                        cProp(ol, "Visible", true); cProp(l, "Visible", true) 
                    end 
                end
                for i = reqLines + 1, 20 do cProp(lines[i], "Visible", false); cProp(lines[i + 20], "Visible", false) end
            else for i = 1, 40 do cProp(lines[i], "Visible", false) end end
        elseif L.SKD[m] then for i = 1, 40 do cProp(L.SKD[m][i], "Visible", false) end end
    end
end
local lg_parts = {}
local known_weapons = {}
local local_classification = setmetatable({}, {__mode = "k"})
local function updateLocalVisuals(dt)
    local anyEnabled = L.LG_Enabled or L.LG_HideHolsters or L.LG_HideGuns or L.LC_Enabled or L.LH_Enabled
    
    local function restore(obj)
        local parts = lg_parts[obj]
        if parts then
            for _, dat in ipairs(parts) do
                local p = dat.p
                if p and p.Parent then
                    if p.Color ~= dat.c then p.Color = dat.c end
                    if p.Transparency ~= dat.t then p.Transparency = dat.t end
                    if p.Material ~= dat.m then p.Material = dat.m end
                    if dat.tex and p.TextureID ~= dat.tex then p.TextureID = dat.tex end
                    if dat.d and dat.d.Transparency ~= (dat.dt or 0) then dat.d.Transparency = dat.dt or 0 end
                end
            end
            lg_parts[obj] = nil
        end
    end

    if not L or not anyEnabled then 
        if next(lg_parts) then 
            for obj in pairs(lg_parts) do restore(obj) end
            lg_parts = {} 
        end
        return 
    end

    local t = M.clock()
    local charModels = {}
    if LP.Character then M.insert(charModels, LP.Character) end
    local customChar = getLocalCharacter()
    if customChar and customChar ~= LP.Character then M.insert(charModels, customChar) end
    
    local horseModel = L.State.LocalHorse
    if not horseModel or not horseModel.Parent then
        local now = M.clock()
        if now - (L.State.LastHorseCheck or 0) > 1 then
            L.State.LastHorseCheck = now
            local animals = WS:FindFirstChild("WORKSPACE_Entities")
            animals = animals and animals:FindFirstChild("Animals")
            if animals then
                local myName = LP.Name:lower()
                for _, child in ipairs(animals:GetChildren()) do
                    if child:IsA("Model") and child.Name:lower():find("horse") then
                        local owner = child:FindFirstChild("Owner")
                        if owner and owner.Value and tostring(owner.Value):lower() == myName then
                            horseModel = child; L.State.LocalHorse = horseModel; break
                        end
                    end
                end
            end
        end
    end

    local function getAnim(anim, baseColor, baseTrans)
        local color, trans = baseColor, baseTrans
        if anim == "Breathe" then
            trans = M.clamp(trans + (1 - trans) * ((math.sin(t * 2.5) + 1) / 2), 0, 1)
        elseif anim == "Spectral" then
            color = Color3.fromHSV((t * 0.4) % 1, 0.7, 1)
            trans = M.clamp(trans + (1 - trans) * (math.sin(t * 1.5) + 1) / 4, 0, 1)
        elseif anim == "Ethereal" then
            trans = M.clamp(trans + (1 - trans) * (0.85 + 0.15 * math.sin(t * 0.8)), 0, 1)
        elseif anim == "Vivid" then
            local p = (math.sin(t * 2) + 1) / 2
            color = baseColor:Lerp(Color3.fromHSV((t * 0.2) % 1, 0.8, 1), p)
            trans = M.clamp(trans + (1 - trans) * (p * 0.4), 0, 1)
        elseif anim == "Glint" then
            local p = M.abs(math.sin(t * 3.5))
            if p > 0.9 then trans = M.clamp(trans - (p - 0.9) * 4, 0, 1) end
        elseif anim == "Lustre" then
            local p = (math.sin(t * 4) + 1) / 2
            trans = M.clamp(trans + (1 - trans) * (p * 0.15), 0, 1)
        end
        return color, trans
    end

    local gC, gT = getAnim(L.LG_FFAnim, L.LG_Color, L.LG_Trans)
    local cC, cT = getAnim(L.LC_FFAnim, L.LC_Color, L.LC_Trans)
    local hC, hT = getAnim(L.LH_FFAnim, L.LH_Color, L.LH_Trans)

    local function apply(obj, color, trans, mat, hideDecals, exclusions)
        local parts = lg_parts[obj]
        if not parts then
            parts = {}
            local items = obj:GetDescendants()
            M.insert(items, obj)
            for _, d in ipairs(items) do
                if d:IsA("BasePart") then
                    local skip = false
                    if exclusions then
                        for _, exc in ipairs(exclusions) do
                            if d.Name == exc or (d.Parent and d.Parent.Name == exc) then
                                skip = true; break
                            end
                        end
                    end
                    if not skip then
                        local dat = {p = d, t = d.Transparency, c = d.Color, m = d.Material}
                        if d:IsA("MeshPart") then dat.tex = d.TextureID end
                        if hideDecals then
                            local dec = d:FindFirstChildOfClass("Decal") or d:FindFirstChildOfClass("Texture")
                            if dec then dat.d = dec; dat.dt = dec.Transparency end
                        end
                        M.insert(parts, dat)
                    end
                end
            end
            lg_parts[obj] = parts
        end
        for i = #parts, 1, -1 do
            local dat = parts[i]
            local p = dat.p
            if p and p.Parent then
                if p.Color ~= color then p.Color = color end
                if p.Transparency ~= trans then p.Transparency = trans end
                if p.Material ~= mat then p.Material = mat end
                if dat.tex and p.TextureID ~= "" then p.TextureID = "" end
                if dat.d and dat.d.Transparency ~= 1 then dat.d.Transparency = 1 end
            else M.remove(parts, i) end
        end
    end

    for _, char in ipairs(charModels) do
        for _, v in ipairs(char:GetChildren()) do
            local cls = local_classification[v]
            if not cls then
                cls = {}
                cls.isHolster = v.Name:find("Holster") ~= nil
                cls.isHolsteredGun = v.Name:find("LoadoutItem/") ~= nil
                cls.isWeapon = false
                if cls.isHolsteredGun then
                    cls.isWeapon = true
                    known_weapons[v.Name:gsub("LoadoutItem/", "")] = true
                elseif known_weapons[v.Name] then
                    cls.isWeapon = true
                else
                    local h = v:FindFirstChild("Handle")
                    if h and not h:FindFirstChild("HatAttachment") then cls.isWeapon = true end
                end
                cls.isBody = v:IsA("BasePart") or v:IsA("Accessory")
                local_classification[v] = cls
            end

            if cls.isHolster or cls.isWeapon then
                if (L.LG_HideHolsters and cls.isHolster) or (L.LG_HideGuns and cls.isHolsteredGun) then
                    apply(v, Color3.new(0,0,0), 1, Enum.Material.Plastic)
                elseif L.LG_Enabled and cls.isWeapon then
                    apply(v, gC, gT, Enum.Material[L.LG_Mat])
                else restore(v) end
            elseif L.LC_Enabled and cls.isBody then
                apply(v, cC, cT, Enum.Material[L.LC_Mat], true, {"HumanoidRootPart"})
            else restore(v) end
        end
    end

    if horseModel then
        if L.LH_Enabled then 
            apply(horseModel, hC, hT, Enum.Material[L.LH_Mat], true, {"Center", "CollisionModel", "RiderSeat", "LassoCircle", "Passenger", "HumanoidRootPart"})
        else restore(horseModel) end
    end
end

local activeProjectiles = {}
local fadingBeams = {}

local function addProjectile(child)
    local isProj, pos = false, nil
    if child:IsA("Attachment") and child:FindFirstChild("ProjectileTrailBeam") then
        isProj, pos = true, child.WorldPosition
    elseif child:FindFirstChild("ProjectileTrailBeam", true) then
        isProj, pos = true, child.Position
    end
    
    if isProj then
        local char = getLocalCharacter()
        local isLocal = false
        if char then
            local rifleMuzzle = false
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Model") then
                    if item.Name == "SharpsRifle" then
                        local p = item:FindFirstChild("Endcap")
                        if p and (pos - p.Position).Magnitude < 2 then isLocal = true; rifleMuzzle = true; break end
                    elseif item.Name == "YellowBoyRifle" then
                        local p = item:FindFirstChild("FrontCylinder")
                        if p and (pos - p.Position).Magnitude < 2 then isLocal = true; rifleMuzzle = true; break end
                    end
                end
            end
            if not rifleMuzzle and char.PrimaryPart then
                isLocal = (pos - char.PrimaryPart.Position).Magnitude < 5
            end
        end
        
        local isNPC = false
        if not isLocal and L.EnemyBulletTracers then
            for _, npc in ipairs(getEntities("NPCs")) do
                if npc.PrimaryPart and (pos - npc.PrimaryPart.Position).Magnitude < 10 then isNPC = true; break end
            end
        end
        
        local enabled = isLocal and L.BulletTracers or (not isLocal and not isNPC and L.EnemyBulletTracers)
        local color1 = isLocal and L.BulletTracersColor or L.EnemyBulletTracersColor
        local color2 = isLocal and L.BulletTracersColor2 or L.EnemyBulletTracersColor2
        local size = isLocal and L.BulletTracersSize or L.EnemyBulletTracersSize
        local duration = isLocal and L.BulletTracersDuration or L.EnemyBulletTracersDuration
        local style = isLocal and L.BulletTracersStyle or L.EnemyBulletTracersStyle
        
        local data = {startPos = pos, lastPos = pos, dur = duration, isLocal = isLocal, color = color1, color2 = color2, size = size, style = style}
        if enabled then
            local a0 = Instance.new("Attachment", workspace.Terrain)
            local a1 = Instance.new("Attachment", workspace.Terrain)
            a0.WorldPosition = pos
            a1.WorldPosition = pos
            local b = Instance.new("Beam", workspace.Terrain)
            b.Attachment0 = a0; b.Attachment1 = a1
            b.Color = ColorSequence.new(color1, color2)
            b.Width0 = size; b.Width1 = size
            b.LightEmission = 0; b.LightInfluence = 0; b.FaceCamera = true
            
            if style == "None" then
                b.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.26, 0.2),
                    NumberSequenceKeypoint.new(1, 0.2)
                })
            else
                local tid = "rbxthumb://type=Asset&id=7151778311&w=420&h=420"
                if style == "2" then tid = "rbxthumb://type=Asset&id=446111271&w=420&h=420"
                elseif style == "3" then tid = "rbxthumb://type=Asset&id=86406621856457&w=420&h=420"
                elseif style == "4" then tid = "rbxthumb://type=Asset&id=7151842833&w=420&h=420"
                elseif style == "5" then tid = "rbxthumb://type=Asset&id=73663492833517&w=420&h=420" end
                b.Texture = tid; b.TextureMode = Enum.TextureMode.Wrap; b.TextureSpeed = 2
                if style == "5" then b.Width0 = size * 2; b.Width1 = size * 2 end
            end
            
            data.a0 = a0; data.a1 = a1; data.b = b
        end
        activeProjectiles[child] = data
    end
end

workspace.Terrain.ChildAdded:Connect(function(child)
    task.delay(0, function()
        if not child.Parent then return end
        addProjectile(child)
    end)
end)
for _, child in ipairs(workspace.Terrain:GetChildren()) do
    addProjectile(child)
end

local handleDroppedItem
local handleThunderstruckTree
local handleOre

L.Ore_Cache = L.Ore_Cache or {}

local ActiveMBF_Bag = nil
local MBF_Target = nil
local MBF_Angle = 0

L.Connections.MBF = RS.Heartbeat:Connect(function(dt)
    if not L.MBF_Enabled then
        if ActiveMBF_Bag then ActiveMBF_Bag = nil end
        if MBF_Target then MBF_Target = nil end
        for i = 1, 73 do MBF_RingLines[i].Visible = false; MBF_RingOutlineLines[i].Visible = false end
        if updateMBFStatus then updateMBFStatus("Inactive", Color3.fromRGB(255, 255, 255)) end
        return
    end

    local char = getLocalCharacter()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        for i = 1, 73 do MBF_RingLines[i].Visible = false; MBF_RingOutlineLines[i].Visible = false end
        if updateMBFStatus then updateMBFStatus("Character Missing", Color3.fromRGB(255, 100, 100)) end
        return
    end

    -- Update 3D Radius Ring (Smooth Lerped Update)
    if L.MBF_ShowRadius then
        local rad = L.MBF_Radius
        local color = L.MBF_RadiusColor or Color3.new(1, 1, 1)
        
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {LP.Character, WS:FindFirstChild("WORKSPACE_Entities")}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        
        local ray = WS:Raycast(hrp.Position, Vector3.new(0, -100, 0), rayParams)
        local targetGroundPos = ray and ray.Position or (hrp.Position - Vector3.new(0, 3, 0))
        
        -- Smooth Lerp Position
        if MBF_CurrentPos == Vector3.new(0,0,0) then MBF_CurrentPos = targetGroundPos end
        MBF_CurrentPos = MBF_CurrentPos:Lerp(targetGroundPos, 0.15)
        
        local lastPoint = nil
        local firstPoint = nil
        
        for i = 1, 72 do
            local angle = math.rad((i - 1) * 5)
            local offset = Vector3.new(math.cos(angle) * rad, 0.05, math.sin(angle) * rad)
            local worldPos = MBF_CurrentPos + offset
            
            local screenPos, onScreen = C:WorldToViewportPoint(worldPos)
            local line = MBF_RingLines[i]
            local outline = MBF_RingOutlineLines[i]
            
            if onScreen and lastPoint then
                local currentV2 = M.v2(screenPos.X, screenPos.Y)
                
                line.From = lastPoint
                line.To = currentV2
                line.Color = color
                line.Visible = true
                
                outline.From = lastPoint
                outline.To = currentV2
                outline.Visible = true
            else
                line.Visible = false
                outline.Visible = false
            end
            
            lastPoint = M.v2(screenPos.X, screenPos.Y)
            if i == 1 then firstPoint = lastPoint end
        end

        -- Final Closure (Segment 73)
        if firstPoint and lastPoint then
            local closeLine = MBF_RingLines[73]
            local closeOutline = MBF_RingOutlineLines[73]
            closeLine.From = lastPoint
            closeLine.To = firstPoint
            closeLine.Color = color
            closeLine.Visible = true
            
            closeOutline.From = lastPoint
            closeOutline.To = firstPoint
            closeOutline.Visible = true
        else
            MBF_RingLines[73].Visible = false
            MBF_RingOutlineLines[73].Visible = false
        end
    else
        for i = 1, 73 do
            MBF_RingLines[i].Visible = false
            MBF_RingOutlineLines[i].Visible = false
        end
    end

    -- Bag Search Logic
    if not ActiveMBF_Bag or not ActiveMBF_Bag.Parent then
        ActiveMBF_Bag = nil
        local ignore = WS:FindFirstChild("Ignore")
        if ignore then
            local closestDist = 60
            for _, child in ipairs(ignore:GetChildren()) do
                if child.Name == "MoneyBag" then
                    local bag = child:FindFirstChild("Bag")
                    if bag and bag:IsA("BasePart") then
                        local dist = (bag.Position - hrp.Position).Magnitude
                        if dist < closestDist then
                            ActiveMBF_Bag = bag
                            closestDist = dist
                        end
                    end
                end
            end
        end
    end

    if not ActiveMBF_Bag then
        if updateMBFStatus then updateMBFStatus("Waiting for Money Bag", Color3.fromRGB(255, 255, 0)) end
        return
    end

    -- Target Acquisition (Persistent targeting)
    if MBF_Target then
        local targetHum = MBF_Target.Parent:FindFirstChild("Humanoid")
        if not MBF_Target.Parent or (targetHum and targetHum.Health <= 0) or (MBF_Target.Position - hrp.Position).Magnitude > L.MBF_Radius then
            MBF_Target = nil
        end
    end

    if not MBF_Target then
        local we = WS:FindFirstChild("WORKSPACE_Entities")
        local playersFolder = we and we:FindFirstChild("Players")
        
        if playersFolder then
            for _, charModel in ipairs(playersFolder:GetChildren()) do
                if charModel:IsA("Model") and charModel.Name ~= LP.Name then
                    if L.Friendlies and L.Friendlies[charModel.Name] then continue end
                    
                    local hum = charModel:FindFirstChild("Humanoid")
                    local targetHrp = charModel:FindFirstChild("HumanoidRootPart")
                    
                    if hum and hum.Health > 0 and targetHrp then
                        local dist = (targetHrp.Position - hrp.Position).Magnitude
                        if dist < L.MBF_Radius then
                            MBF_Target = targetHrp
                            break -- Lock onto the first valid target in range
                        end
                    end
                end
            end
        end
    end

    if MBF_Target then
        if updateMBFStatus then updateMBFStatus("Flinging: " .. MBF_Target.Parent.Name, Color3.fromRGB(255, 50, 50)) end
        
        local targetPos = MBF_Target.Position
        local dist = (targetPos - ActiveMBF_Bag.Position).Magnitude
        
        if dist > 4 then
            -- Hybrid Interception (CFrame for smoothness + Velocity for server replication)
            ActiveMBF_Bag.CFrame = ActiveMBF_Bag.CFrame:Lerp(CFrame.new(targetPos), 0.2)
            ActiveMBF_Bag.AssemblyLinearVelocity = (targetPos - ActiveMBF_Bag.Position) * 30
        else
            -- High-Intensity Torso Glitch (Fling Protocol)
            local glitch = Vector3.new(math.random(-10, 10)/20, math.random(-10, 10)/20, math.random(-10, 10)/20)
            ActiveMBF_Bag.CFrame = MBF_Target.CFrame * CFrame.new(glitch) * CFrame.Angles(math.rad(math.random(0, 360)), math.rad(math.random(0, 360)), math.rad(math.random(0, 360)))
            
            ActiveMBF_Bag.AssemblyAngularVelocity = Vector3.new(30000, 30000, 30000)
            ActiveMBF_Bag.AssemblyLinearVelocity = Vector3.new(0, 5000, 0)
        end
    else
        if updateMBFStatus then updateMBFStatus("Bag Hooked | Orbiting", Color3.fromRGB(50, 255, 50)) end
        -- Hybrid Orbiting (CFrame for perfect visual + Velocity for server replication)
        MBF_Angle = MBF_Angle + dt * 8
        local orbitPos = hrp.Position + Vector3.new(math.cos(MBF_Angle) * 6, 1.5, math.sin(MBF_Angle) * 6)
        
        ActiveMBF_Bag.CFrame = ActiveMBF_Bag.CFrame:Lerp(CFrame.new(orbitPos), 0.2)
        ActiveMBF_Bag.AssemblyLinearVelocity = (orbitPos - ActiveMBF_Bag.Position) * 30
        ActiveMBF_Bag.AssemblyAngularVelocity = Vector3.zero
    end
end)

L.Connections.RenderStepped = RS.RenderStepped:Connect(function(dt)
    local now = M.clock()
    for proj, data in pairs(activeProjectiles) do
        if not proj.Parent then
            activeProjectiles[proj] = nil
            if data.b then fadingBeams[data] = now end
            continue
        end
        local currentPos = proj:IsA("Attachment") and proj.WorldPosition or proj.Position
        if data.b then
            data.a1.WorldPosition = currentPos
        end
    end
    
    for data, st in pairs(fadingBeams) do
        local alpha = (now - st) / data.dur
        if alpha >= 1 then
            if data.b and data.b.Parent then data.b:Destroy() end
            if data.a0 and data.a0.Parent then data.a0:Destroy() end
            if data.a1 and data.a1.Parent then data.a1:Destroy() end
            fadingBeams[data] = nil
        else
            if data.b and data.b.Parent then
                data.b.Transparency = NumberSequence.new(alpha)
            end
        end
    end
    local cP, n, mP = C.CFrame.Position, M.clock(), UIS:GetMouseLocation()
    local camCF = C.CFrame
    local targetFOV = 70
    
    if not L._CachedGlobal then
        pcall(function()
            L._CachedGlobal = require(game:GetService("ReplicatedStorage").SharedModules.Global)
        end)
    end
    
    if L._CachedGlobal then
        targetFOV = L._CachedGlobal.Settings:Get("FOV") or 70
    end
    if L.CZ_E then
        targetFOV = targetFOV / (L.CZ_V or 1)
    end
    if L.GM_NoScope then
        local hasSniper = false
        local we = WS:FindFirstChild("WORKSPACE_Entities")
        local customChar = we and we:FindFirstChild("Players") and we.Players:FindFirstChild(LP.Name)
        if customChar then
            for _, v in ipairs(customChar:GetChildren()) do
                if v:IsA("Model") and (v.Name == "SharpsRifle" or v.Name == "SpitfireRevolvingSniper") then
                    hasSniper = true
                    break
                end
            end
        end
        if hasSniper then
            local scopeUI = LP.PlayerGui:FindFirstChild("ScopeUI")
            if scopeUI and scopeUI.Enabled then 
                scopeUI.Enabled = false
                pcall(function()
                    local Global = L._CachedGlobal
                    if not Global then return end
                    
                    if not L._CachedUIHandler then
                        L._CachedUIHandler = Global:LoadModule("UIHandler")
                    end
                    
                    local UIHandler = L._CachedUIHandler
                    if UIHandler and not UIHandler._RoxyHooked then
                        UIHandler._RoxyHooked = true
                        local old = UIHandler.SetMainUIEnabled
                        UIHandler.SetMainUIEnabled = function(self, state)
                            if L.GM_NoScope and state == false then return end
                            return old(self, state)
                        end
                    end
                    if Global.Camera then
                        Global.Camera.ScopeActivated = false
                        Global.Camera.SensitivityMultiplier = 1
                    end
                end)
                local mainUI = LP.PlayerGui:FindFirstChild("MainUI")
                if mainUI then mainUI.Enabled = true end
                if LP.Character then
                    for _, part in ipairs(LP.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency > 0.5 then
                            part.Transparency = 0
                        end
                    end
                end
            end
            local isAiming = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            if (L.CZ_E or isAiming) and C.FieldOfView < 69.5 then
                targetFOV = math.min(targetFOV, 68)
                local mouse = UIS:GetMouseLocation()
                local cX, cY = mouse.X, mouse.Y
                local gap, length = 8, 11
                local function setLine(i, x1, y1, x2, y2)
                    local o, l = crosshairLines[i], crosshairLines[i+4]
                    o.From = Vector2.new(x1, y1); o.To = Vector2.new(x2, y2)
                    l.From = Vector2.new(x1, y1); l.To = Vector2.new(x2, y2)
                    o.Visible = true; l.Visible = true
                end
                setLine(1, cX, cY - gap, cX, cY - (gap + length))
                setLine(2, cX, cY + gap, cX, cY + (gap + length))
                setLine(3, cX - gap, cY, cX - (gap + length), cY)
                setLine(4, cX + gap, cY, cX + (gap + length), cY)
            else
                for i = 1, 8 do crosshairLines[i].Visible = false end
            end
        else
            for i = 1, 8 do crosshairLines[i].Visible = false end
        end
    else
        for i = 1, 8 do crosshairLines[i].Visible = false end
    end
    local fovSpeed = (L.CZ_E or L.GM_NoScope) and 50 or 15
    C.FieldOfView = C.FieldOfView + (targetFOV - C.FieldOfView) * M.clamp(dt * fovSpeed, 0, 1)
    if L.GM_NoScope and not (L.CZ_E or isAiming) and C.FieldOfView < 69 then
        C.FieldOfView = 70
    end
    local targetRadius = L.SA_Dynamic_FOV and (L.SA_FOV * (70 / M.max(C.FieldOfView, 1))) or L.SA_FOV
    SA_State.SmoothedFOV = SA_State.SmoothedFOV + (targetRadius - SA_State.SmoothedFOV) * M.clamp(dt * 10, 0, 1)
    local aimTargetRadius = L.Aim_Dynamic_FOV and (L.Aim_FOV * (70 / M.max(C.FieldOfView, 1))) or L.Aim_FOV
    Aim_State.SmoothedFOV = Aim_State.SmoothedFOV + (aimTargetRadius - Aim_State.SmoothedFOV) * M.clamp(dt * 10, 0, 1)

    pcall(function()
        if Global and Global.Camera then
            Global.Camera.FieldOfView = C.FieldOfView
        end
    end)
    
    local mX, mY = math.floor(mP.X), math.floor(mP.Y)
    local mPosInt = M.v2(mX, mY)

    local function drawFov(prefix, fVisible, fGrad, fThick, fRad, state, fC_O, fC, lines, olines)
        if fVisible then
            if fGrad then
                if state.WasFovCircleVisible then cProp(fC_O, "Visible", false); cProp(fC, "Visible", false); state.WasFovCircleVisible = false end
                L[prefix .. "_FOV_Rot"] = ((L[prefix .. "_FOV_Rot"] or 0) + dt * (L[prefix .. "_FOV_Speed"] * 0.5)) % 1
                local rotation = L[prefix .. "_FOV_Rot"]
                local transparency = 1 - L[prefix .. "_FOV_Transparency"]
                local g1, g2 = L[prefix .. "_FOV_Grad1"], L[prefix .. "_FOV_Grad2"]
                for i = 1, 120 do
                    local line, outline = lines[i], olines[i]
                    local p1, p2 = circlePoints[i], circlePoints[i+1]
                    local p1V = M.v2(mX + p1.x * fRad, mY + p1.y * fRad)
                    local p2V = M.v2(mX + p2.x * fRad, mY + p2.y * fRad)
                    local dir = (p2V - p1V).Unit * 1.0
                    cPropV2(line, "From", p1V.X, p1V.Y); cPropV2(line, "To", p2V.X + dir.X, p2V.Y + dir.Y)
                    cPropV2(outline, "From", p1V.X, p1V.Y); cPropV2(outline, "To", p2V.X + dir.X, p2V.Y + dir.Y)
                    cProp(line, "Thickness", fThick); cProp(outline, "Thickness", fThick + 2)
                    local t = ((i / 120) + rotation) % 1
                    cProp(line, "Color", g1:Lerp(g2, (math.sin(t * math.pi * 2) + 1) / 2))
                    cProp(line, "Transparency", transparency); cProp(outline, "Transparency", transparency)
                    cProp(line, "Visible", true); cProp(outline, "Visible", true)
                end
                state.WasFovLinesVisible = true
            else
                if state.WasFovLinesVisible then
                    for i = 1, 120 do cProp(lines[i], "Visible", false); cProp(olines[i], "Visible", false) end
                    state.WasFovLinesVisible = false
                end
                cPropV2(fC_O, "Position", mX, mY); cProp(fC_O, "Radius", fRad); cProp(fC_O, "Thickness", fThick + 2)
                cProp(fC_O, "Transparency", 1 - L[prefix .. "_FOV_Transparency"]); cProp(fC_O, "Visible", true)
                cPropV2(fC, "Position", mX, mY); cProp(fC, "Radius", fRad); cProp(fC, "Thickness", fThick)
                cProp(fC, "Color", L[prefix .. "_FOV_Color"]); cProp(fC, "Transparency", 1 - L[prefix .. "_FOV_Transparency"]); cProp(fC, "Visible", true)
                state.WasFovCircleVisible = true
            end
        else
            if state.WasFovLinesVisible then
                for i = 1, 120 do cProp(lines[i], "Visible", false); cProp(olines[i], "Visible", false) end
                state.WasFovLinesVisible = false
            end
            if state.WasFovCircleVisible ~= false then
                cProp(fC_O, "Visible", false); cProp(fC, "Visible", false)
                state.WasFovCircleVisible = false
            end
        end
    end

    drawFov("SA", L.SA_FOV_Vis, L.SA_FOV_Gradient and L.SA_FOV_Vis, L.SA_FOV_Thickness or 1.5, SA_State.SmoothedFOV, SA_State, UI.fovO, UI.fov, UI.fovL, UI.fovOL)
    drawFov("Aim", L.Aim_FOV_Vis, L.Aim_FOV_Gradient and L.Aim_FOV_Vis, L.Aim_FOV_Thickness or 1.5, Aim_State.SmoothedFOV, Aim_State, UI.aimFovO, UI.aimFov, UI.aimFovL, UI.aimFovOL)

    local closestTarget, closestDist = nil, targetRadius
    local aimClosestTarget, aimClosestDist = nil, aimTargetRadius
    for m, data in pairs(espCache) do
        if not m or not m.Parent then continue end
        local currentPos = gP(m)
        if currentPos then
            if data.lastPos then
                local rawVelocity = (currentPos - data.lastPos) / dt
                data.velocity = data.velocity and (data.velocity * 0.8 + rawVelocity * 0.2) or rawVelocity
            else
                data.velocity = M.v3(0, 0, 0)
            end
            data.lastPos = currentPos
        end
        local prefix = data.type == "NPCs" and "NPC_" or (data.type == "Animals" and "Animal_" or "")
        local settings = data.settings or {
            Master = prefix .. "Master", DE = prefix .. "DE", WE = prefix .. "WE", 
            BE = prefix .. "BE", HE = prefix .. "HE", CE = prefix .. "CE", 
            SKE = prefix .. "SKE", NE = prefix .. "NE", DMax = prefix .. "DMax"
        }
        data.settings = settings
        local hu = data.hu if not hu or not hu.Parent then if n - (data.hT or 0) > 0.5 then hu = m:FindFirstChildOfClass("Humanoid"); data.hu = hu; data.hT = n end end
        local d = (cP - currentPos).Magnitude
        local isAlive = true
        if data.type == "Players" then
            isAlive = not (not hu or hu.Health <= 0 or (data.hs and data.hs <= 0) or isRagdolled(m))
        elseif data.type == "NPCs" then
            isAlive = not isRagdolled(m)
        end
        local v = data.vS or {v = false, t = 0} 
        local throttle = d > 500 and 0.5 or 0.2
        if n - v.t > throttle then 
            local to = data.to if not to or not to.Parent then if n - (data.tT or 0) > 0.5 then to = gT(m); data.to = to; data.tT = n end end
            v.v = iV(cP, m, to); v.t = n; data.vS = v 
        end 
        data.visible = v.v
        local allowSA = true
        if L.SA_DuelOnly and duelOpponent and data.type == "Players" then
            if m.Name ~= duelOpponent then allowSA = false end
        end
        if data.type == "Players" and L.Friendlies and L.Friendlies[m.Name] then allowSA = false end

        if L.SA_Enabled and allowSA and isAlive and L.SA_Targets[data.type] and not isProtected(m) then
            if d <= L.SA_MaxDist then
                local rootSP, onS = C:WorldToViewportPoint(currentPos)
                if onS or d < 100 then
                    local mouseDistToRoot = (M.v2(rootSP.X, rootSP.Y) - mP).Magnitude
                    if mouseDistToRoot < (SA_State.SmoothedFOV + 150) then
                        local part = getTargetPart(m, "SA")
                        if part then
                            local screenPos, onScreen = C:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local mouseDist = (M.v2(screenPos.X, screenPos.Y) - mP).Magnitude
                                if mouseDist < closestDist then
                                    if data.visible or not L.SA_WallCheck then
                                        closestTarget = m; closestDist = mouseDist
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        local allowAim = true
        if L.Aim_DuelOnly and duelOpponent and data.type == "Players" then
            if m.Name ~= duelOpponent then allowAim = false end
        end
        if data.type == "Players" and L.Friendlies and L.Friendlies[m.Name] then allowAim = false end

        if L.Aim_Enabled and allowAim and isAlive and L.Aim_Targets and L.Aim_Targets[data.type] and not isProtected(m) then
            local isSticky = L.Aim_StickyAim and Aim_State.CurrentTarget == m and Options.Aim_Key:GetState()
            if isSticky or d <= (L.Aim_MaxDist or 1000) then
                local rootSP, onS = C:WorldToViewportPoint(currentPos)
                if isSticky or onS or d < 100 then
                local mouseDistToRoot = (M.v2(rootSP.X, rootSP.Y) - mP).Magnitude
                if isSticky or mouseDistToRoot < (Aim_State.SmoothedFOV + 150) then
                    local part = getTargetPart(m, "Aim")
                    if part then
                        local screenPos, onScreen = C:WorldToViewportPoint(part.Position)
                        if isSticky or onScreen then
                            local mouseDist = (M.v2(screenPos.X, screenPos.Y) - mP).Magnitude
                            if isSticky or mouseDist < aimClosestDist then
                                if isSticky or data.visible or not L.Aim_WallCheck then
                                    aimClosestTarget = m
                                    aimClosestDist = isSticky and -1 or mouseDist
                                end
                            end
                        end
                    end
                end
                end
            end
        end
        local sS = true
        if L[settings.Master] then
            if not isAlive then sS = false end
            if sS and d > L[settings.DMax] then sS = false end
            if sS and camCF:PointToObjectSpace(currentPos).Z > 0 then sS = false end
            if sS and L.VisOnly and not data.visible then sS = false end
            if sS and data.type == "Animals" then
                local owner = m:FindFirstChild("Owner")
                if owner and owner.Value == LP.Name then sS = false end
            end
            if sS and L.HideProtected and data.type == "Players" and isProtected(m) then sS = false end
        else
            sS = false
        end
        data.sS, data.d = sS, d
        if sS then
            if L[settings.HE] or data.type == "Animals" then 
                if data.type == "Players" then
                    local hF = data.hF
                    if not hF or not hF.Parent then
                        if n - (data.hFT or 0) > 0.5 then
                            local head = m:FindFirstChild("Head")
                            local bar = head and head:FindFirstChild("PlayerStatus", true) and head.PlayerStatus:FindFirstChild("HealthBar", true)
                            hF = bar and bar:FindFirstChild("HealthProgressFrame"); data.hF = hF; data.hFT = n
                        end
                    end
                    if hF then data.hs = M.clamp(hF.Size.X.Scale, 0, 1) end
                else
                    local hV = data.hV or m:FindFirstChild("Health")
                    data.hV = hV
                    local curVal = hV and hV.Value or 100
                    if not data.maxH or (curVal > data.maxH) then data.maxH = curVal end
                    data.hs = M.clamp(curVal / (data.maxH or 100), 0, 1)
                end
            end
            if L[settings.WE] and n - (data.wt or 0) > 0.5 then
                local wName = "None"
                for _, v in ipairs(m:GetChildren()) do 
                    if v:IsA("Model") and not v.Name:find("LoadoutItem/") then
                        if v:FindFirstChild("Handle") then wName = v.Name; break end
                    end
                end
                data.wN, data.wt = wName, n
            end
        end
    end
    SA_State.CurrentTarget = closestTarget
    Aim_State.CurrentTarget = aimClosestTarget

    local function updateSnapline(enabled, target, state, lineO, line, mode)
        if enabled and target then
            local part = getTargetPart(target, mode)
            if part then
                local sP, oS = C:WorldToViewportPoint(part.Position)
                if oS then
                    local tPos = M.v2(sP.X, sP.Y)
                    state.Transparency = M.min(state.Transparency + dt / 0.1, 1)
                    local trans = state.Transparency
                    lineO.From = mP; lineO.To = tPos
                    line.From = mP; line.To = tPos
                    lineO.Transparency = trans; line.Transparency = trans
                    lineO.Visible = true; line.Visible = true
                    return
                end
            end
        end
        state.Transparency = M.max(state.Transparency - dt / 0.1, 0)
        local trans = state.Transparency
        lineO.Transparency = trans; line.Transparency = trans
        if trans <= 0.05 then lineO.Visible = false; line.Visible = false end
        state.LerpPos = nil
    end

    updateSnapline(L.SA_Snapline, closestTarget, SA_State, UI.snapO, UI.snap, "SA")
    updateSnapline(L.Aim_Snapline, aimClosestTarget, Aim_State, UI.aimSnapO, UI.aimSnap, "Aim")

    if Options.Aim_Key:GetState() and aimClosestTarget then
        local part = getTargetPart(aimClosestTarget, "Aim")
        if part then
            local pos = part.Position
            if L.Aim_BulletDrop or L.Aim_BulletLead then
                local stats, toolId = getWeaponStats()
                local speed = stats and (stats.ProjectileSpeed or stats.ProjectileVelocity or stats.BulletSpeed or stats.Speed) or 1000
                local gravity = stats and (stats.ProjectileDrop or stats.ProjectileGravity or stats.BulletDrop or stats.Gravity) or 34
                local profile = toolId and WeaponProfiles and WeaponProfiles[toolId]
                if profile then
                    if speed == 1000 and profile.Speed then speed = profile.Speed end
                    gravity = profile.Drop or 34
                end
                
                local function SolveTime(p1, s, p2, grav)
                    local diff = p2 - p1
                    local horiz = M.v3(diff.X, 0, diff.Z)
                    local t2 = horiz.Magnitude / math.max(s, 1)
                    if t2 == 0 then t2 = 0.001 end
                    local vY = (diff.Y + 0.5 * math.abs(grav) * t2 * t2) / t2
                    local vHoriz = horiz.Unit * s
                    return M.v3(vHoriz.X, vY, vHoriz.Z), t2
                end
                
                local targetVel = M.v3(0, 0, 0)
                if L.Aim_BulletLead and espCache[aimClosestTarget] then
                    local hrp = aimClosestTarget:FindFirstChild("HumanoidRootPart") or aimClosestTarget:FindFirstChild("Torso") or aimClosestTarget:FindFirstChild("Head")
                    if hrp and hrp:IsA("BasePart") then targetVel = hrp.AssemblyLinearVelocity or hrp.Velocity or M.v3(0, 0, 0) end
                    if targetVel.Magnitude < 0.1 and espCache[aimClosestTarget].velocity then targetVel = espCache[aimClosestTarget].velocity end
                end
                
                local aimPos = pos
                local reqVel = M.v3(0, 0, 0)
                local travelTime = 0
                local effectiveGrav = L.Aim_BulletDrop and gravity or 0
                
                for i = 1, 5 do
                    aimPos = pos + (targetVel * travelTime)
                    reqVel, travelTime = SolveTime(cP, speed, aimPos, effectiveGrav)
                end
                
                pos = cP + reqVel
            end
            
            if L.Aim_Type == "Mouse" then
                local targetPos, onScreen = C:WorldToViewportPoint(pos)
                if onScreen then
                    local moveX = (targetPos.X - mP.X) / L.Aim_Smoothness
                    local moveY = (targetPos.Y - mP.Y) / L.Aim_Smoothness
                    mousemoverel(moveX, moveY)
                end
            elseif L.Aim_Type == "Camera" then
                local currentCFrame = C.CFrame
                local targetCFrame = CFrame.new(cP, pos)
                C.CFrame = currentCFrame:Lerp(targetCFrame, 1 / L.Aim_Smoothness)
            end
        end
    end
    FrameCounter = FrameCounter + 1
    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter
        FrameTimer, FrameCounter = tick(), 0
    end
    if CanDoPing then
        Library:SetWatermark(('roxy.win / dev | %d fps | %d ms'):format(math.floor(FPS), GetPing()))
    else
        Library:SetWatermark(('roxy.win | %d fps'):format(math.floor(FPS)))
    end
    -- Local Mods Logic
    local char = getLocalCharacter()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hrp and hum then
        if L.FlyEnabled then
            hrp.Velocity = Vector3.new(0, 0, 0)
            local moveDir = hum.MoveDirection
            local flyUp = UIS:IsKeyDown(Enum.KeyCode.Space) and 1 or (UIS:IsKeyDown(Enum.KeyCode.LeftControl) and -1 or 0)
            local look = C.CFrame.LookVector
            local right = C.CFrame.RightVector
            local flyVec = (moveDir * L.FlySpeed) + (Vector3.new(0, flyUp, 0) * L.FlySpeed)
            hrp.CFrame = hrp.CFrame + (flyVec * dt)
        elseif L.SpeedEnabled then
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + (moveDir * (L.SpeedAmount - hum.WalkSpeed) * dt)
            end
        end
        if L.NoJumpDelay and UIS:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial ~= Enum.Material.Air and (os.clock() - (L.State.LastJump or 0) > 0.1) then
            L.State.LastJump = os.clock()
            hum.Jump = true
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end

    end

    onRenderSteppedESP(dt, cP, n, mP, camCF)
    local function updateDroppedItemsESP(dt, cP, camCF)
        local diFont = L.DI_Font or 3
        local diFontSize = L.DI_FontSize or 13
        local diMaxDist = L.DI_MaxDistance or 2000
        local diCase = L.DI_FontCase or "Normal"
        for m, data in pairs(L.DI_Cache) do
            if not m or not m.Parent then 
                if data.l then cProp(data.l, "Visible", false) end 
                if data.distL then cProp(data.distL, "Visible", false) end
                continue 
            end
            local show = L.DI_Enabled and L.DI_Sort[data.type]
            local fA = data.fA or 0
            if not show and fA <= 0 then
                if data.l and data.l.Visible then cProp(data.l, "Visible", false) end
                if data.distL and data.distL.Visible then cProp(data.distL, "Visible", false) end
                continue
            end
            local pos = m:GetPivot().Position
            local d = (cP - pos).Magnitude
            if show and camCF:PointToObjectSpace(pos).Z > 0 then show = false end
            if show and d > diMaxDist then show = false end
            if show then fA = math.min(fA + dt / (L.FIn or 0.15), 1) else fA = math.max(fA - dt / (L.FOut or 0.15), 0) end
            data.fA = fA
            if fA <= 0 then
                if data.l then cProp(data.l, "Visible", false) end
                if data.distL then cProp(data.distL, "Visible", false) end
                continue
            end
            local sP, onS = C:WorldToViewportPoint(pos)
            if not onS then
                if data.l then cProp(data.l, "Visible", false) end
                if data.distL then cProp(data.distL, "Visible", false) end
                continue
            end
            local l, dl = data.l, data.distL
            local useColor = L.DI_NameColor
            if data.isLegendary and L.DI_LegendaryOverride then useColor = L.DI_LegendaryColor end
            if l then
                if L.DI_Name then
                    local text = data.dispName
                    if not text or data.lastCase ~= diCase then
                        text = m.Name
                        if diCase == "Lowercase" then text = text:lower() elseif diCase == "Uppercase" then text = text:upper() end
                        data.dispName = text; data.lastCase = diCase
                    end
                    cPropV2(l, "Position", sP.X, sP.Y - 15)
                    cProp(l, "Text", text)
                    cProp(l, "Color", useColor)
                    cProp(l, "Transparency", fA)
                    cProp(l, "Font", diFont)
                    cProp(l, "Size", diFontSize)
                    cProp(l, "Visible", true)
                else
                    cProp(l, "Visible", false)
                end
            end
            if dl then
                if L.DI_Distance then
                    local dDisp = math.floor(L.DI_Measuring == "Meters" and d * 0.28 or d)
                    local text = "[ " .. dDisp .. (L.DI_Measuring == "Meters" and "m" or "s") .. " ]"
                    cPropV2(dl, "Position", sP.X, sP.Y + (L.DI_Name and 0 or -15))
                    cProp(dl, "Text", text)
                    cProp(dl, "Color", (data.isLegendary and L.DI_LegendaryOverride) and L.DI_LegendaryColor or L.DI_DistanceColor)
                    cProp(dl, "Transparency", fA)
                    cProp(dl, "Font", diFont)
                    cProp(dl, "Size", diFontSize)
                    cProp(dl, "Visible", true)
                else
                    cProp(dl, "Visible", false)
                end
            end
        end
    end
    local function updateThunderstruckESP(dt, cP, camCF)
        local tsFont = L.TS_Font or 2
        local tsFontSize = L.TS_FontSize or 13
        local tsMaxDist = L.TS_MaxDistance or 2000
        local tsCase = L.TS_FontCase or "Normal"
        for m, data in pairs(L.TS_Cache) do
            if not m or not m.Parent or not m:FindFirstChild("Strike2", true) then 
                handleThunderstruckTree(m, true)
                continue 
            end
            local show = L.TS_Enabled and L.TS_Sort[data.itemType or "Tree"]
            local fA = data.fA or 0
            if not show and fA <= 0 then
                if data.l and data.l.Visible then cProp(data.l, "Visible", false) end
                if data.distL and data.distL.Visible then cProp(data.distL, "Visible", false) end
                continue
            end
            local pos = data.pos
            local d = (cP - pos).Magnitude
            if show and camCF:PointToObjectSpace(pos).Z > 0 then show = false end
            if show and d > tsMaxDist then show = false end
            if show then fA = math.min(fA + dt / (L.FIn or 0.15), 1) else fA = math.max(fA - dt / (L.FOut or 0.15), 0) end
            data.fA = fA
            if fA <= 0 then
                if data.l then cProp(data.l, "Visible", false) end
                if data.distL then cProp(data.distL, "Visible", false) end
                continue
            end
            local sP, onS = C:WorldToViewportPoint(pos)
            if not onS then
                if data.l then cProp(data.l, "Visible", false) end
                if data.distL then cProp(data.distL, "Visible", false) end
                continue
            end
            local l, dl = data.l, data.distL
            local useColor = L.TS_NameColor or Color3.fromRGB(255, 0, 0)
            if l then
                if L.TS_Name then
                    local text = data.dispName
                    if not text or data.lastCase ~= tsCase then
                        text = "Thunderstruck " .. (data.itemType or "Tree")
                        if tsCase == "Lowercase" then text = text:lower() elseif tsCase == "Uppercase" then text = text:upper() end
                        data.dispName = text; data.lastCase = tsCase
                    end
                    cPropV2(l, "Position", sP.X, sP.Y - 15)
                    cProp(l, "Text", text)
                    cProp(l, "Color", useColor)
                    cProp(l, "Transparency", fA)
                    cProp(l, "Font", tsFont)
                    cProp(l, "Size", tsFontSize)
                    cProp(l, "Visible", true)
                else
                    cProp(l, "Visible", false)
                end
            end
            if dl then
                if L.TS_Distance then
                    local dDisp = math.floor(L.TS_Measuring == "Meters" and d * 0.28 or d)
                    local text = "[ " .. dDisp .. (L.TS_Measuring == "Meters" and "m" or "s") .. " ]"
                    cPropV2(dl, "Position", sP.X, sP.Y + (L.TS_Name and 0 or -15))
                    cProp(dl, "Text", text)
                    cProp(dl, "Color", L.TS_DistanceColor or Color3.fromRGB(255, 255, 255))
                    cProp(dl, "Transparency", fA)
                    cProp(dl, "Font", tsFont)
                    cProp(dl, "Size", tsFontSize)
                    cProp(dl, "Visible", true)
                else
                    cProp(dl, "Visible", false)
                end
            end
        end
    end
    local function updateOresESP(dt, cP, camCF)
        local oFont = L.Ore_Font or 2
        local oFontSize = L.Ore_FontSize or 13
        local oMaxDist = L.Ore_MaxDistance or 10000
        local oCase = L.Ore_FontCase or "Normal"
        for m, data in pairs(L.Ore_Cache) do
            if not m or not m.Parent then 
                handleOre(m, true)
                continue 
            end
            local oreSet = L.Ore_Settings[data.oreType]
            local show = L.Ore_Enabled and oreSet and oreSet.Enabled
            if show and L.Ore_OnlyVeins and not data.isVein then show = false end
            local fA = data.fA or 0
            if not show and fA <= 0 then
                if data.l and data.l.Visible then cProp(data.l, "Visible", false) end
                if data.distL and data.distL.Visible then cProp(data.distL, "Visible", false) end
                continue
            end
            local pos = data.pos
            local d = (cP - pos).Magnitude
            if show and camCF:PointToObjectSpace(pos).Z > 0 then show = false end
            if show and d > oMaxDist then show = false end
            if show then fA = math.min(fA + dt / (L.FIn or 0.15), 1) else fA = math.max(fA - dt / (L.FOut or 0.15), 0) end
            data.fA = fA
            if fA <= 0 then
                if data.l then cProp(data.l, "Visible", false) end
                if data.distL then cProp(data.distL, "Visible", false) end
                continue
            end
            local sP, onS = C:WorldToViewportPoint(pos)
            if not onS then
                if data.l then cProp(data.l, "Visible", false) end
                if data.distL then cProp(data.distL, "Visible", false) end
                continue
            end
            local l, dl = data.l, data.distL
            local useColor = oreSet and oreSet.Color or Color3.new(1, 1, 1)
            if l then
                if L.Ore_Name then
                    local text = data.cachedName
                    if not text or data.lastCase ~= oCase then
                        text = data.dispName
                        if oCase == "Lowercase" then text = text:lower() elseif oCase == "Uppercase" then text = text:upper() end
                        data.cachedName = text; data.lastCase = oCase
                    end
                    cPropV2(l, "Position", sP.X, sP.Y - 15)
                    cProp(l, "Text", text)
                    cProp(l, "Color", useColor)
                    cProp(l, "Transparency", fA)
                    cProp(l, "Font", oFont)
                    cProp(l, "Size", oFontSize)
                    cProp(l, "Visible", true)
                else
                    cProp(l, "Visible", false)
                end
            end
            if dl then
                if L.Ore_Distance then
                    local dDisp = math.floor(L.Ore_Measuring == "Meters" and d * 0.28 or d)
                    local text = "[ " .. dDisp .. (L.Ore_Measuring == "Meters" and "m" or "s") .. " ]"
                    cPropV2(dl, "Position", sP.X, sP.Y + (L.Ore_Name and 0 or -15))
                    cProp(dl, "Text", text)
                    cProp(dl, "Color", L.Ore_DistanceColor or Color3.new(1, 1, 1))
                    cProp(dl, "Transparency", fA)
                    cProp(dl, "Font", oFont)
                    cProp(dl, "Size", oFontSize)
                    cProp(dl, "Visible", true)
                else
                    cProp(dl, "Visible", false)
                end
            end
        end
    end
    updateDroppedItemsESP(dt, cP, camCF)
    updateThunderstruckESP(dt, cP, camCF)
    updateOresESP(dt, cP, camCF)
    updateLocalVisuals(dt)
end)
local function setupListeners(path, type)
    if not path then return end
    if type == "Players" or type == "Animals" then
        L.Connections[type .. "Added"] = path.ChildAdded:Connect(function(c) task.wait(0.1) if c:IsA("Model") then rHE(c, false, type) end end)
        L.Connections[type .. "Removed"] = path.ChildRemoved:Connect(function(c) if c:IsA("Model") then rHE(c, true) end end)
    else
        L.Connections[type .. "Added"] = path.DescendantAdded:Connect(function(c) 
            if c.Name == "Model" and c:IsA("Model") and c.Parent and c.Parent.Parent == path then task.wait(0.1) rHE(c, false, type) end 
        end)
        L.Connections[type .. "Removed"] = path.DescendantRemoving:Connect(function(c) 
            if c.Name == "Model" and c:IsA("Model") and c.Parent and c.Parent.Parent == path then rHE(c, true) end 
        end)
    end
    for _, c in ipairs(getEntities(type)) do rHE(c, false, type) end
end
setupListeners(WS:FindFirstChild("WORKSPACE_Entities") and WS.WORKSPACE_Entities:FindFirstChild("Players"), "Players")
setupListeners(WS:FindFirstChild("WORKSPACE_Entities") and WS.WORKSPACE_Entities:FindFirstChild("NPCs"), "NPCs")
setupListeners(WS:FindFirstChild("WORKSPACE_Entities") and WS.WORKSPACE_Entities:FindFirstChild("Animals"), "Animals")
local function getDroppedItemType(m)
    local name = m.Name
    local ln = name:lower()
    if ln:find("ore") then return "Ore" end
    local gem = m:FindFirstChild("Gem")
    if gem and gem:IsA("MeshPart") then return "Gems" end
    if ln:find("pelt") or ln:find("tooth") or ln:find("claw") or name == "AnimalMeat" then return "Animal Drops" end
    if name == "MoneyBag" then return "Others" end
    return "Others"
end
handleDroppedItem = function(m, rm)
    if rm then
        local d = L.DI_Cache[m]
        if d then
            if d.l then d.l.Visible = false d.l:Remove() end
            if d.distL then d.distL.Visible = false d.distL:Remove() end
            L.DI_Cache[m] = nil
        end
        return
    end
    if L.DI_Cache[m] then return end
    local type = getDroppedItemType(m)
    local l = Drawing.new("Text")
    l.Center = true; l.Outline = true; l.Size = 13; l.Font = L.Font; l.Visible = false
    local dl = Drawing.new("Text")
    dl.Center = true; dl.Outline = true; dl.Size = 13; dl.Font = L.Font; dl.Visible = false
    local isLegendary = m.Name:lower():find("legendary") ~= nil
    L.DI_Cache[m] = {m = m, type = type, l = l, distL = dl, fA = 0, isLegendary = isLegendary}
end
local DI_Folder = WS:WaitForChild("WORKSPACE_Interactables", 5)
if DI_Folder then DI_Folder = DI_Folder:WaitForChild("DroppedItems", 5) end
if DI_Folder then
    DI_Folder.ChildAdded:Connect(function(c) task.wait(0.1) if c:IsA("Model") then handleDroppedItem(c, false) end end)
    DI_Folder.ChildRemoved:Connect(function(c) handleDroppedItem(c, true) end)
    for _, c in ipairs(DI_Folder:GetChildren()) do if c:IsA("Model") then handleDroppedItem(c, false) end end
end

task.spawn(function()
    local DI_Ignore = WS:FindFirstChild("Ignore")
    if DI_Ignore then
        DI_Ignore.ChildAdded:Connect(function(c) task.wait(0.1) if c.Name == "MoneyBag" and c:IsA("Model") then handleDroppedItem(c, false) end end)
        DI_Ignore.ChildRemoved:Connect(function(c) if c.Name == "MoneyBag" then handleDroppedItem(c, true) end end)
        for _, c in ipairs(DI_Ignore:GetChildren()) do 
            if c.Name == "MoneyBag" and c:IsA("Model") then handleDroppedItem(c, false) end 
            if _ % 50 == 0 then task.wait() end -- Prevent frame drops during initial scan
        end
    end
end)
print("roxy.win | ESP Listeners initialized.")

handleThunderstruckTree = function(obj, rm)
    if rm then
        local d = L.TS_Cache[obj]
        if d then
            if d.l then pcall(function() d.l.Visible = false d.l:Remove() end) end
            if d.distL then pcall(function() d.distL.Visible = false d.distL:Remove() end) end
            L.TS_Cache[obj] = nil
        end
        return
    end
    if L.TS_Cache[obj] then return end
    local treeModel = obj
    if obj.Name == "Strike2" then
        treeModel = obj:FindFirstAncestorOfClass("Model")
    elseif obj:IsA("Model") then
        local strike = obj:FindFirstChild("Strike2", true)
        if not strike then return end
    else
        return
    end
    if not treeModel then return end
    if L.TS_Cache[treeModel] then return end
    local modelName = treeModel.Name
    local itemType = "Tree"
    if modelName:find("Cactus") then
        itemType = "Cactus"
    elseif modelName:find("Tree") then
        itemType = "Tree"
    end
    local l = Drawing.new("Text")
    l.Center = true; l.Outline = true; l.Size = 13; l.Font = L.Font; l.Visible = false
    local dl = Drawing.new("Text")
    dl.Center = true; dl.Outline = true; dl.Size = 13; dl.Font = L.Font; dl.Visible = false
    local success, pos = pcall(function() return treeModel:GetPivot().Position end)
    L.TS_Cache[treeModel] = {m = treeModel, l = l, distL = dl, fA = 0, itemType = itemType, pos = success and pos or Vector3.new(0, 0, 0)}
    if L.TS_Notify then
        local region = "Unknown"
        local p = treeModel.Parent
        while p and p ~= game do
            if p.Name:find("REGION_") then
                region = p.Name:gsub("REGION_", "")
                break
            end
            p = p.Parent
        end
        Library:Notify("Thunderstruck " .. itemType .. " Detected: " .. region, 5)
    end
end

local geom = WS:FindFirstChild("WORKSPACE_Geometry")
if geom then
    geom.DescendantAdded:Connect(function(c)
        if c.Name == "Strike2" then
            task.wait(0.1)
            handleThunderstruckTree(c, false)
        end
    end)
    
    task.spawn(function()
        for _, v in ipairs(geom:GetDescendants()) do
            if v.Name == "Strike2" then
                handleThunderstruckTree(v, false)
            end
        end
    end)
end

local function getOreType(name)
    if name:find("Coal") then return "Coal" end
    if name:find("Copper") then return "Copper" end
    if name:find("Gold") then return "Gold" end
    if name:find("Iron") then return "Iron" end
    if name:find("Quartz") then return "Quartz" end
    if name:find("Silver") then return "Silver" end
    if name:find("Zinc") then return "Zinc" end
    if name:find("Limestone") then return "Limestone" end
    return "Unknown"
end

handleOre = function(m, rm)
    if rm then
        local d = L.Ore_Cache[m]
        if d then
            if d.l then d.l.Visible = false d.l:Remove() end
            if d.distL then d.distL.Visible = false d.distL:Remove() end
            L.Ore_Cache[m] = nil
        end
        return
    end
    if L.Ore_Cache[m] then return end
    local name = m.Name
    local parentName = m.Parent and m.Parent.Name or ""
    local oreType = getOreType(parentName)
    if oreType == "Unknown" then oreType = getOreType(name) end
    local isVein = parentName:find("Vein") ~= nil or name:find("Vein") ~= nil
    local isBig = name:find("Big") ~= nil
    local isLarge = name:find("L") ~= nil and isVein
    local dispName = ""
    if isVein then
        dispName = (isLarge and "Large " or "") .. oreType .. " Vein"
    else
        dispName = (isBig and "Big " or "") .. oreType
    end
    local l = Drawing.new("Text")
    l.Center = true; l.Outline = true; l.Size = 13; l.Font = L.Font; l.Visible = false
    local dl = Drawing.new("Text")
    dl.Center = true; dl.Outline = true; dl.Size = 13; dl.Font = L.Font; dl.Visible = false
    local success, pos = pcall(function() return m:GetPivot().Position end)
    L.Ore_Cache[m] = {m = m, oreType = oreType, isVein = isVein, dispName = dispName, l = l, distL = dl, fA = 0, pos = success and pos or Vector3.new(0, 0, 0)}
end

task.spawn(function()
    local OreDepositsFolder = WS:WaitForChild("WORKSPACE_Interactables", 5)
    if OreDepositsFolder then OreDepositsFolder = OreDepositsFolder:WaitForChild("Mining", 5) end
    if OreDepositsFolder then OreDepositsFolder = OreDepositsFolder:WaitForChild("OreDeposits", 5) end
    
    if OreDepositsFolder then
        local function setupFolder(folder)
            for _, ore in ipairs(folder:GetChildren()) do
                if ore:IsA("Model") then handleOre(ore, false) end
            end
            L.Connections["OreDeposit_" .. folder.Name] = folder.ChildAdded:Connect(function(c)
                task.wait(0.1)
                if c:IsA("Model") then handleOre(c, false) end
            end)
            L.Connections["OreDepositRemoved_" .. folder.Name] = folder.ChildRemoved:Connect(function(c)
                handleOre(c, true)
            end)
        end
        for _, folder in ipairs(OreDepositsFolder:GetChildren()) do
            setupFolder(folder)
        end
        L.Connections["OreDepositAdded"] = OreDepositsFolder.ChildAdded:Connect(function(folder)
            task.wait(0.1)
            setupFolder(folder)
        end)
        L.Connections["OreDepositRemoved"] = OreDepositsFolder.ChildRemoved:Connect(function(folder)
            for _, ore in ipairs(folder:GetChildren()) do
                handleOre(ore, true)
            end
            if L.Connections["OreDeposit_" .. folder.Name] then
                L.Connections["OreDeposit_" .. folder.Name]:Disconnect()
                L.Connections["OreDeposit_" .. folder.Name] = nil
            end
            if L.Connections["OreDepositRemoved_" .. folder.Name] then
                L.Connections["OreDepositRemoved_" .. folder.Name]:Disconnect()
                L.Connections["OreDepositRemoved_" .. folder.Name] = nil
            end
        end)
    end
end)

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
MenuGroup:AddToggle("KeybindMenuOpen", {Default = Library.KeybindFrame.Visible, Text = "Open Keybind Menu", Callback = function(v) Library.KeybindFrame.Visible = v end})
MenuGroup:AddToggle("ShowCustomCursor", {Text = "Custom Cursor", Default = false, Callback = function(v) Library.ShowCustomCursor = v end})
MenuGroup:AddToggle("HideLogo", {Text = "Hide Logo", Default = false, Callback = function(v)
    Library.HideImages = v
    if Library.BackgroundImage then Library.BackgroundImage.Visible = not v end
end})

local BlurTgl = MenuGroup:AddToggle("UIBlur", {Text = "Blur", Default = false, Callback = function(v)
    Library.UIBlur = v
    if Library.UpdateBlur then Library:UpdateBlur() end
end})

local BlurDep = MenuGroup:AddDependencyBox()
BlurDep:SetupDependencies({{BlurTgl, true}})
BlurDep:AddSlider("UIBlurIntensity", {Text = "Blur Intensity", Default = 15, Min = 0, Max = 50, Rounding = 0, Callback = function(v)
    Library.UIBlurIntensity = v
    if Library.UpdateBlur then Library:UpdateBlur() end
end})
MenuGroup:AddDropdown("NotificationPosition", {Values = {"Left", "Right", "Bottom"}, Default = "Bottom", Multi = false, Text = "Notification Position", Callback = function(v) 
    Library.NotifySide = v 
    Library:Notify("notification test", 3)
end})
MenuGroup:AddSlider("UIGlowAmount", {
    Text = "UI Glow Intensity",
    Default = 1,
    Min = 0,
    Max = 4,
    Rounding = 2,
    Callback = function(v)
        if Library.SetGlowAmount then
            Library:SetGlowAmount(v)
        end
    end
})
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddButton("Unload", function() Library:Unload() end)

--// Initialize Player List Addon \\--
L.Friendlies = Library.Friendlies
L.Priorities = Library.Priorities
Library.PlayerList:Build(Tabs.Players)

local SG = Tabs['UI Settings']:AddRightGroupbox("Server")
SG:AddButton("Rejoin Server", function()
    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
end)
SG:AddButton("Server Hop", function()
    local success, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
        local data = game:GetService("HttpService"):JSONDecode(game:HttpGet(url))
        if data and data.data then
            for _, s in ipairs(data.data) do
                if s.id ~= game.JobId and s.playing >= 12 and s.playing < s.maxPlayers then return s.id end
            end
        end
    end)
    if success and result then
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, result, LP)
    else
        game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
    end
end)
task.spawn(function()
    local visible = true
    while true do
        if Library.Unloaded then break end
        local accent = Library.AccentColor
        local color = visible and "FFFFFF" or string.format("%02X%02X%02X", M.floor(accent.R * 255), M.floor(accent.G * 255), M.floor(accent.B * 255))
        local tag = '<font color="#' .. color .. '">$$</font>'
        Window:SetWindowTitle("                     " .. tag .. " roxy.win " .. tag .. "                  ")
        visible = not visible
        task.wait(0.5)
    end
end)
Library.ToggleKeybind = Options.MenuKeybind
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
ThemeManager:SetFolder('Roxy.win')
SaveManager:SetFolder('Roxy.win/TheWildWest')
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()
Library:OnUnload(function()
    for _, v in pairs(L.Connections) do if v then v:Disconnect() end end
    for m in pairs(espCache) do rHE(m, true) end
    for m in pairs(L.AC) do cC(m) end
    if oldRaycast then hookfunction(workspace.Raycast, oldRaycast) end
    if oldFireServer and Network then hookfunction(Network.FireServer, oldFireServer) end
    fovCircle:Remove(); fovCircleO:Remove(); snaplineLine:Remove(); snaplineLineO:Remove()
    for _, l in ipairs(fovLines) do l:Remove() end
    for _, l in ipairs(fovOutlineLines) do l:Remove() end
    if aimFovCircle then aimFovCircle:Remove() end
    if aimFovCircleO then aimFovCircleO:Remove() end
    if aimSnaplineLine then aimSnaplineLine:Remove() end
    if aimSnaplineLineO then aimSnaplineLineO:Remove() end
    for _, l in ipairs(MBF_RingLines) do l:Remove() end
    for _, l in ipairs(MBF_RingOutlineLines) do l:Remove() end
    for _, l in ipairs(aimFovLines) do l:Remove() end
    for _, l in ipairs(aimFovOutlineLines) do l:Remove() end
    for m in pairs(L.DI_Cache) do handleDroppedItem(m, true) end
    for m in pairs(L.TS_Cache) do handleThunderstruckTree(m, true) end
    if L.Ore_Cache then for m in pairs(L.Ore_Cache) do handleOre(m, true) end end
    Library.Unloaded = true
end)
local function renderTargetInfo(target)
    if not target or not L.SA_Enabled then return end
    local screenPos, onScreen = C:WorldToViewportPoint(target:GetPivot().Position)
    if onScreen then
    end
end
return { Library = Library, ThemeManager = ThemeManager, SaveManager = SaveManager, Options = Options, Toggles = Toggles, Window = Window, Tabs = Tabs }
