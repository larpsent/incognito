-- knife duels | linoria ui
-- hitbox expander + triggerbot + esp + skinchanger

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

-- ── linoria ──────────────────────────────────────────────────────────────────
local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "knife duels",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Combat  = Window:AddTab("Combat"),
    Visual  = Window:AddTab("Visual"),
    Misc    = Window:AddTab("Misc"),
}

local Groups = {
    Hitbox   = Tabs.Combat:AddLeftGroupbox("Hitbox Expander"),
    Trigger  = Tabs.Combat:AddRightGroupbox("Triggerbot"),
    ESP      = Tabs.Visual:AddLeftGroupbox("ESP"),
    Skin     = Tabs.Misc:AddLeftGroupbox("Skinchanger"),
}

-- ── cfg ──────────────────────────────────────────────────────────────────────
local CFG = {
    hitbox_enabled  = false,
    hitbox_x        = 4.0,
    hitbox_y        = 3.5,
    hitbox_z        = 3.5,
    trigger_enabled = false,
    trigger_range   = 12,
    trigger_delay   = 0.06,
    esp_enabled     = false,
    esp_color       = Color3.fromRGB(255, 60, 60),
    skin_id         = "Default",
}

-- ── knife ids (add more as you find them) ────────────────────────────────────
local KNIFE_IDS = {
    "Default",
    "Shark",
    "Butterfly",
    "Bowie",
    "Bayonet",
    "Gut",
    "Falchion",
    "Huntsman",
    "Flip",
    "Karambit",
    "M9Bayonet",
    "Navaja",
    "Shadow",
    "Stiletto",
    "Talon",
    "Ursus",
    "Nomad",
    "Skeleton",
    "Survival",
    "Paracord",
}

-- ── get modules ──────────────────────────────────────────────────────────────
local Controllers = lp.PlayerScripts:WaitForChild("Controllers")
local Combat      = Controllers:WaitForChild("Combat")
local Utils       = Controllers:WaitForChild("Utils")
local HitDetectionUtils   = require(Utils:WaitForChild("HitDetectionUtils"))
local HitboxController    = require(Combat:WaitForChild("HitboxController"))
local EquippedKnifeRC     = require(Utils:WaitForChild("EquippedKnifeReplicationController"))
local KnifeController     = require(Combat:WaitForChild("KnifeController"))

-- ── hitbox expander ──────────────────────────────────────────────────────────
local old_EnsureCombatHitboxes = HitboxController._EnsureCombatHitboxes
HitboxController._EnsureCombatHitboxes = function(self, character, _size)
    if not CFG.hitbox_enabled then
        old_EnsureCombatHitboxes(self, character, _size)
        return
    end
    old_EnsureCombatHitboxes(self, character,
        Vector3.new(CFG.hitbox_x, CFG.hitbox_y, CFG.hitbox_z))
end

local oldGetTargets = HitDetectionUtils.GetTargets
HitDetectionUtils.GetTargets = function(character)
    if not CFG.hitbox_enabled then
        return oldGetTargets(character)
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    local results = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end
        local char = player.Character
        if not char then continue end
        local enemyHRP = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not enemyHRP or not humanoid or humanoid.Health <= 0 then continue end
        local dist = (enemyHRP.Position - hrp.Position).Magnitude
        if dist > 60 then continue end
        table.insert(results, {
            isHeadshot = false,
            model = char,
            distance = dist,
            hitPosition = enemyHRP.Position
        })
    end
    table.sort(results, function(a, b) return a.distance < b.distance end)
    return results
end

-- ── skinchanger ──────────────────────────────────────────────────────────────
-- patch the u5 cache inside EquippedKnifeReplicationController
-- Get() reads u5[userId] so overwriting it spoofs the knife client-side
local function apply_skin(knifeId)
    CFG.skin_id = knifeId
    -- force the cache entry for local player
    pcall(function()
        local prop = EquippedKnifeRC:GetProperty(lp)
        -- directly overwrite via Get hook
        local old_get = EquippedKnifeRC.Get
        EquippedKnifeRC.Get = function(self, target)
            local uid
            if typeof(target) == "Instance" and target:IsA("Player") then
                uid = target.UserId
            else
                uid = tonumber(target)
            end
            if uid == lp.UserId then
                return { KnifeId = CFG.skin_id }
            end
            return old_get(self, target)
        end
    end)
end

-- ── triggerbot ───────────────────────────────────────────────────────────────
local InputBindingController = require(Utils:WaitForChild("InputBindingController"))
local InputBindingConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("InputBindingConfig"))

local lastTrigger = 0
RunService.Heartbeat:Connect(function()
    if not CFG.trigger_enabled then return end
    if not lp.Character then return end
    local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = lp.Character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return end

    local now = os.clock()
    if now - lastTrigger < CFG.trigger_delay then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end
        local char = player.Character
        if not char then continue end
        local enemyHRP = char:FindFirstChild("HumanoidRootPart")
        local enemyHuman = char:FindFirstChildOfClass("Humanoid")
        if not enemyHRP or not enemyHuman or enemyHuman.Health <= 0 then continue end

        if (enemyHRP.Position - hrp.Position).Magnitude <= CFG.trigger_range then
            -- fire through the game's own action system, no simulated input
            pcall(function()
                InputBindingController:ConnectAction(
                    InputBindingConfig.ActionIds.ThrowKnife,
                    function() end
                )
                -- begin throw
                InputBindingController:_HandleActionInput(
                    InputBindingConfig.ActionIds.ThrowKnife,
                    Enum.UserInputState.Begin,
                    { KeyCode = Enum.KeyCode.Unknown,
                      UserInputType = Enum.UserInputType.MouseButton2 }
                )
                task.wait(0.05)
                -- end throw
                InputBindingController:_HandleActionInput(
                    InputBindingConfig.ActionIds.ThrowKnife,
                    Enum.UserInputState.End,
                    { KeyCode = Enum.KeyCode.Unknown,
                      UserInputType = Enum.UserInputType.MouseButton2 }
                )
            end)
            lastTrigger = now
            break
        end
    end
end)
-- ── esp ──────────────────────────────────────────────────────────────────────
local esp_folder = Instance.new("Folder")
esp_folder.Name = "KnifeESP"
esp_folder.Parent = game.CoreGui

local highlights = {}

RunService.Heartbeat:Connect(function()
    if not CFG.esp_enabled then
        for _, h in pairs(highlights) do h.Enabled = false end
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end
        if not highlights[player] then
            local h = Instance.new("Highlight")
            h.FillColor = CFG.esp_color
            h.OutlineColor = Color3.fromRGB(255,255,255)
            h.FillTransparency = 0.5
            h.OutlineTransparency = 0
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = esp_folder
            highlights[player] = h
        end
        local h = highlights[player]
        h.Adornee = player.Character or nil
        h.Enabled = player.Character ~= nil
        h.FillColor = CFG.esp_color
    end
    for player, h in pairs(highlights) do
        if not player.Parent then
            h:Destroy()
            highlights[player] = nil
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if highlights[p] then highlights[p]:Destroy() highlights[p] = nil end
end)

-- ── ui wiring ────────────────────────────────────────────────────────────────

-- combat — hitbox
Groups.Hitbox:AddToggle("HitboxEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(v) CFG.hitbox_enabled = v end
})
Groups.Hitbox:AddSlider("HitboxX", {
    Text = "Size X",
    Default = 4.0, Min = 1.5, Max = 12, Rounding = 1,
    Callback = function(v) CFG.hitbox_x = v end
})
Groups.Hitbox:AddSlider("HitboxY", {
    Text = "Size Y",
    Default = 3.5, Min = 1.5, Max = 12, Rounding = 1,
    Callback = function(v) CFG.hitbox_y = v end
})
Groups.Hitbox:AddSlider("HitboxZ", {
    Text = "Size Z",
    Default = 3.5, Min = 1.5, Max = 12, Rounding = 1,
    Callback = function(v) CFG.hitbox_z = v end
})

-- combat — triggerbot
Groups.Trigger:AddToggle("TriggerEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(v) CFG.trigger_enabled = v end
})
Groups.Trigger:AddSlider("TriggerRange", {
    Text = "Range (studs)",
    Default = 12, Min = 4, Max = 40, Rounding = 1,
    Callback = function(v) CFG.trigger_range = v end
})
Groups.Trigger:AddSlider("TriggerDelay", {
    Text = "Delay (s)",
    Default = 0.06, Min = 0.01, Max = 0.5, Rounding = 2,
    Callback = function(v) CFG.trigger_delay = v end
})

-- visual — esp
Groups.ESP:AddToggle("ESPEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(v) CFG.esp_enabled = v end
})
Groups.ESP:AddLabel("ESP Color"):AddColorPicker("ESPColor", {
    Default = Color3.fromRGB(255, 60, 60),
    Callback = function(v) CFG.esp_color = v end
})

-- misc — skinchanger
Groups.Skin:AddDropdown("SkinDropdown", {
    Text = "Knife Skin",
    Default = "Default",
    Values = KNIFE_IDS,
    Callback = function(v) apply_skin(v) end
})
Groups.Skin:AddButton("Apply Skin", function()
    apply_skin(CFG.skin_id)
end)

-- ── theme + save ─────────────────────────────────────────────────────────────
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("KnifeDuels")
SaveManager:BuildConfigSection(Tabs.Misc)
ThemeManager:ApplyToTab(Tabs.Misc)

Library:SetWatermark("knife duels | closet")
Library.ToggleKeybind = Enum.KeyCode.RightShift
game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        task.wait(1) -- wait for new place to load
        loadstring(game:HttpGet("https://raw.githubusercontent.com/larpsent/incognito/refs/heads/main/incognito.lua"))()
    end
end)

print("[knife duels] ui loaded")
