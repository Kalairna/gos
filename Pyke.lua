if _G.__L9_ENGINE_PYKE_LOADED then return end
_G.__L9_ENGINE_PYKE_LOADED = true

local Version = 1.0
local Name = "L9Pyke"

local Heroes = {"Pyke"}
if not table.contains(Heroes, myHero.charName) then return end

if not FileExist(COMMON_PATH .. "GGPrediction.lua") then
    DownloadFileAsync(
        "https://raw.githubusercontent.com/gamsteron/GG/master/GGPrediction.lua",
        COMMON_PATH .. "GGPrediction.lua",
        function() end
    )
    print("GGPrediction - downloaded! Please 2xf6!")
    return
end
require("GGPrediction")
require("DamageLib")

local function CheckPredictionSystem()
    if not _G.GGPrediction then
        return false
    end
    return true
end

local QPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = 0.25,
    Radius = 100,
    Range = 1100,
    Speed = 1900,
    Collision = true,
    MaxCollision = 0,
    CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL },
})

local EPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = 0.25,
    Radius = 50,
    Range = 550,
    Speed = 2000,
    Collision = false,
})

local RPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = 0.25,
    Radius = 100,
    Range = 750,
    Speed = 2000,
    Collision = false,
})

local HITCHANCE_NORMAL = 2
local HITCHANCE_HIGH = 3
local HITCHANCE_IMMOBILE = 4

local function IsJungleMob(minion)
    if not minion or not minion.charName then return false end
    local name = minion.charName:lower()
    return name:find("baron") or name:find("dragon") or name:find("sru_") or 
           name:find("gromp") or name:find("krug") or name:find("murkwolf") or 
           name:find("razorbeak") or name:find("red") or name:find("blue") or
           name:find("crab") or name:find("rift")
end

local QCharging = false
local QStartTime = 0
local QKeyHeld = false -- tracking KeyDown state for Q
local QMaxCharge = 1.25 -- seconds (max hold time for Q)
local LastQPressTime = 0 -- Track when Q was last pressed
local QPredictionPos = nil -- Store prediction position for release

-- Vector casting system for Q (based on Taliyah W system)
local vectorCast = {}
local mouseReturnPos = Game.cursorPos()
local mouseCurrentPos = Game.cursorPos()
local nextVectorCast = 0

-- Helper function to get prediction with dynamic range for Q (Taliyah style)
local function GetQPredictionWithRange(target, range)
    if not target or not target.valid then return nil, 0 end
    
    -- Create a temporary prediction with the current range
    local tempPrediction = GGPrediction:SpellPrediction({
        Type = GGPrediction.SPELLTYPE_LINE,
        Delay = 0.25,
        Radius = 100,
        Range = range,
        Speed = 1900,
        Collision = true,
        MaxCollision = 0,
        CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL },
    })
    
    tempPrediction:GetPrediction(target, myHero)
    if tempPrediction:CanHit(HITCHANCE_NORMAL) then
        -- Return in old format for compatibility
        return {x = tempPrediction.CastPosition.x, z = tempPrediction.CastPosition.z}, HITCHANCE_NORMAL
    end
    
    return nil, 0
end

-- Hybrid system: Taliyah prediction + Vladimir charge logic
local function StartChargeQWithPrediction(target)
    if not target or not target.valid then return false end
    
    -- Get prediction position
    local prediction, hitChance = GetQPredictionWithRange(target, 1100)
    if prediction and hitChance >= HITCHANCE_NORMAL then
        -- Store prediction position for later use (don't set cursor yet)
        QPredictionPos = Vector(prediction.x, myHero.pos.y, prediction.z)
        
        -- Start charging Q (Vladimir style) - NO movement blocking
        if Control.KeyDown then Control.KeyDown(HK_Q) end
        QKeyHeld = true
        QStartTime = Game.Timer()
        LastQPressTime = Game.Timer()
        return true
    end
    
    return false
end

-- Vladimir-style charge management with Taliyah prediction
local function ManageQCharge(target, menu)
    if not target or not target.valid then return end
    
    local act = myHero.activeSpell
    if act and act.name == "PykeQ" then
        local chargeTime = Game.Timer() - QStartTime
        local range = math.max(math.min(chargeTime, 1.25) * 1100, 400)
        
        -- Update cursor position to prediction during charge (but don't block movement yet)
        local prediction, hitChance = GetQPredictionWithRange(target, range)
        if prediction and hitChance > 0 then
            -- Store prediction for later use, don't set cursor yet
            QPredictionPos = Vector(prediction.x, myHero.pos.y, prediction.z)
        end
        
        -- Release conditions (Vladimir style) - IMPROVED with GGPrediction
        local shouldRelease = false
        local distance = myHero.pos:DistanceTo(target.pos)
        local manualReleaseOnly = menu and menu.Combo and menu.Combo.ManualRelease and menu.Combo.ManualRelease:Value()
        
        -- Max charge reached (respect menu setting) - always release at max
        local maxChargeTime = menu and menu.Combo and menu.Combo.QMaxCharge and menu.Combo.QMaxCharge:Value() or 1.25
        if chargeTime >= maxChargeTime then
            shouldRelease = true
        end
        
        -- Emergency release if target moved very far (always release)
        if distance > 1200 then
            shouldRelease = true
        end
        
        -- Auto-release conditions (only if not manual release only)
        if not manualReleaseOnly then
            local minChargeTime = menu and menu.Combo and menu.Combo.QMinCharge and menu.Combo.QMinCharge:Value() or 0.8
            
            -- Good prediction with higher threshold
            if prediction and hitChance >= HITCHANCE_HIGH then
                local castPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                if myHero.pos:DistanceTo(castPos) <= range and chargeTime >= minChargeTime then
                    shouldRelease = true
                end
            end
            
            -- Close range auto-release (only if very close and charged enough)
            if distance <= 600 and chargeTime >= minChargeTime then
                shouldRelease = true
            end
        end
        
        if shouldRelease then
            -- NOW block movement and set cursor to prediction before releasing
            if QPredictionPos then
                -- Only block movement if FreeMovement is enabled (default behavior)
                if menu and menu.Combo and menu.Combo.FreeMovement and menu.Combo.FreeMovement:Value() then
                    -- Disable orbwalker during release
                    if _G.SDK and _G.SDK.Orbwalker then
                        _G.SDK.Orbwalker:SetMovement(false)
                        _G.SDK.Orbwalker:SetAttack(false)
                    elseif _G.DepressiveOrbwalker then
                        _G.DepressiveOrbwalker:SetMode(_G.DepressiveOrbwalker.MODES.NONE)
                    elseif _G.GOS then
                        _G.GOS:BlockOrbwalker(true)
                    end
                end
                
                -- Set cursor to prediction position
                Control.SetCursorPos(QPredictionPos)
                
                -- Release Q
                if Control.KeyUp and QKeyHeld then Control.KeyUp(HK_Q) end
                QKeyHeld = false
                
                -- Re-enable orbwalker after a short delay (only if we blocked it)
                if menu and menu.Combo and menu.Combo.FreeMovement and menu.Combo.FreeMovement:Value() then
                    DelayAction(function()
                        if _G.SDK and _G.SDK.Orbwalker then
                            _G.SDK.Orbwalker:SetMovement(true)
                            _G.SDK.Orbwalker:SetAttack(true)
                        elseif _G.DepressiveOrbwalker then
                            _G.DepressiveOrbwalker:SetMode(_G.DepressiveOrbwalker.MODES.COMBO)
                        elseif _G.GOS then
                            _G.GOS:BlockOrbwalker(false)
                        end
                    end, 0.1)
                end
            else
                -- Fallback: release without prediction
                if Control.KeyUp and QKeyHeld then Control.KeyUp(HK_Q) end
                QKeyHeld = false
            end
        end
    end
end

-- Get best Q cast position (Taliyah style)
local function GetBestQCastPos(target, range)
    if not target or not target.pos then return nil, nil end
    
    -- Get prediction position
    local predPos = target.pos
    local prediction, hitChance = GetQPredictionWithRange(target, range)
    if prediction and hitChance > 0 then
        predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
    end
    
    local d = myHero.pos:DistanceTo(predPos)
    if d <= range then
        -- For Pyke Q, we want to cast towards the prediction position
        local endPos = predPos  -- Q goes towards the target
        
        return predPos, endPos
    end
    
    return nil, nil
end

local function GetUltDamage()
    local level = myHero:GetSpellData(_R).level
    local baseDamage = 250 + (level - 1) * 200
    local bonusAD = myHero.bonusDamage
    return baseDamage + (bonusAD * 0.8)
end

-- Utility function to check if prediction position is valid within range
local function PredictionInRange(prediction, range)
    if not prediction or not prediction[1] then return false end
    local castPos = Vector(prediction[1].x, myHero.pos.y, prediction[1].z)
    return myHero.pos:DistanceTo(castPos) <= range
end

-- Vector casting function for Q (based on Taliyah system + Vladimir charging)
local function CastVectorQ(pos1, pos2)
    if nextVectorCast > Game.Timer() then 
        return 
    end
    nextVectorCast = Game.Timer() + 0.5
    
    -- Disable orbwalker during cast
    if _G.SDK and _G.SDK.Orbwalker then
        _G.SDK.Orbwalker:SetMovement(false)
        _G.SDK.Orbwalker:SetAttack(false)
    elseif _G.DepressiveOrbwalker then
        _G.DepressiveOrbwalker:SetMode(_G.DepressiveOrbwalker.MODES.NONE)
    elseif _G.GOS then
        _G.GOS:BlockOrbwalker(true)
    end
    
    -- Create vector cast sequence
    vectorCast[#vectorCast + 1] = function() 
        mouseReturnPos = Game.cursorPos()  -- Save original position
        mouseCurrentPos = pos1
        Control.SetCursorPos(pos1)  -- Move to target position
    end
    
    vectorCast[#vectorCast + 1] = function() 
        Control.KeyDown(HK_Q)  -- Start charging Q (Vladimir style)
        QKeyHeld = true
        QStartTime = Game.Timer()
    end
    
    vectorCast[#vectorCast + 1] = function() 
        local deltaMousePos = Game.cursorPos() - mouseCurrentPos
        mouseReturnPos = mouseReturnPos + deltaMousePos
        Control.SetCursorPos(pos2)  -- Move to cast direction
        mouseCurrentPos = pos2
    end
    
    vectorCast[#vectorCast + 1] = function()
        Control.KeyUp(HK_Q)  -- Release Q
        QKeyHeld = false
    end
    
    vectorCast[#vectorCast + 1] = function()	
        local deltaMousePos = Game.cursorPos() - mouseCurrentPos
        mouseReturnPos = mouseReturnPos + deltaMousePos
        Control.SetCursorPos(mouseReturnPos)  -- Return to original position
    end
    
    vectorCast[#vectorCast + 1] = function() 
        -- Re-enable orbwalker
        if _G.SDK and _G.SDK.Orbwalker then
            _G.SDK.Orbwalker:SetMovement(true)
            _G.SDK.Orbwalker:SetAttack(true)
        elseif _G.DepressiveOrbwalker then
            _G.DepressiveOrbwalker:SetMode(_G.DepressiveOrbwalker.MODES.COMBO)
        elseif _G.GOS then
            _G.GOS:BlockOrbwalker(false)
        end
    end		
end

-- Progressive charging system (Vladimir style)
local function HandleProgressiveCharging(target)
    local act = myHero.activeSpell
    if not myHero.isChanneling then
        -- Start charging Q if target in range and not already charging
        local inQRange = target and myHero.pos:DistanceTo(target.pos) <= 1100
        if _G.L9Engine:IsSpellReady(_Q) and not QKeyHeld and inQRange then
            if Control.KeyDown then Control.KeyDown(HK_Q) end
            QKeyHeld = true
            QStartTime = Game.Timer()
        elseif QKeyHeld and not inQRange then
            -- Release early if target moved out of range and we're not channeling yet (safety)
            if Control.KeyUp then Control.KeyUp(HK_Q) end
            QKeyHeld = false
        end
    else
        if act and act.name == "PykeQ" then
            local tnow = Game.Timer()
            local elapsedSinceEnd = (tnow - (act.castEndTime or tnow))
            local chargeTime = tnow - QStartTime
            local range = math.max(math.min(chargeTime, 1.25) * 1100, 400)
            
            -- Get prediction for current range
            local prediction = GetPrediction(target, "Q", range)
            
            -- Release if prediction says we can hit OR max charge reached
            local shouldRelease = false
            
            -- Good prediction (use predicted cast position instead of target distance)
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 3 then
                local castPos = Vector(prediction[1].x, myHero.pos.y, prediction[1].z)
                if myHero.pos:DistanceTo(castPos) <= range then
                    shouldRelease = true
                end
            end
            
            -- Max charge reached
            if elapsedSinceEnd >= 1.25 then
                shouldRelease = true
            end
            
            if shouldRelease then
                if Control.KeyUp and QKeyHeld then Control.KeyUp(HK_Q) end
                QKeyHeld = false
            end
        end
    end
    
    -- Safety: if we somehow hold longer than 3s (failsafe) release anyway
    if QKeyHeld and (Game.Timer() - QStartTime) > 3.0 then
        if Control.KeyUp then Control.KeyUp(HK_Q) end
        QKeyHeld = false
    end
end

class "L9Pyke"

function L9Pyke:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Pyke:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Pyke", name = "L9Pyke"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Bone Skewer", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Phantom Undertow", value = true})
    self.Menu.Combo:MenuElement({id = "EWhileQCharging", name = "Use E while Q is charging", value = false, tooltip = "Allow E to be used while Q is charging (may interrupt Q)"})
    self.Menu.Combo:MenuElement({id = "QMaxCharge", name = "Q Max Charge Time (s)", value = 1.25, min = 0.5, max = 2.0, step = 0.1})
    self.Menu.Combo:MenuElement({id = "QMinCharge", name = "Q Min Charge Time (s)", value = 0.8, min = 0.3, max = 1.5, step = 0.1, tooltip = "Minimum time before auto-release"})
    self.Menu.Combo:MenuElement({id = "QPredictionThreshold", name = "Q Prediction Threshold", value = 3, min = 1, max = 5, tooltip = "Lower = more aggressive, Higher = more conservative"})
    self.Menu.Combo:MenuElement({id = "QChargeMode", name = "Q Charge Mode", drop = {"Vector Cast", "Progressive Charge", "Auto"}, value = 1, tooltip = "Vector = Taliyah style, Progressive = Vladimir style, Auto = Smart choice"})
    self.Menu.Combo:MenuElement({id = "UseVectorSystem", name = "Use Vector System (Taliyah Style)", value = true, tooltip = "Use advanced vector casting like Taliyah W"})
    self.Menu.Combo:MenuElement({id = "FreeMovement", name = "Free Movement During Charge", value = true, tooltip = "Allow free movement during Q charge, only block at release"})
    self.Menu.Combo:MenuElement({id = "ManualRelease", name = "Manual Release Only", value = false, tooltip = "Only release Q manually, no auto-release"})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Death From Below", value = true})
    self.Menu.Combo:MenuElement({id = "RCount", name = "Min enemies for R", value = 1, min = 1, max = 5})
    self.Menu.Combo:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RHitChance", name = "R Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Bone Skewer", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Phantom Undertow", value = false})
    self.Menu.Harass:MenuElement({id = "EWhileQCharging", name = "Use E while Q is charging", value = false, tooltip = "Allow E to be used while Q is charging (may interrupt Q)"})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    self.Menu.Harass:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    self.Menu.Harass:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Bone Skewer", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Bone Skewer", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Bone Skewer", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Phantom Undertow", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] Death From Below", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawQCharge", name = "Draw Q Charge Status", value = true})
    self.Menu.Drawing:MenuElement({id = "Kill", name = "Draw Killable Targets", value = true})
end

function L9Pyke:Tick()
    if myHero.dead or Game.IsChatOpen() then 
        -- Clean up Q key state if hero is dead or chat is open
        if QKeyHeld and Control.KeyUp then Control.KeyUp(HK_Q) end
        QKeyHeld = false
        return 
    end
    
    -- Vector casting system for Q
    if #vectorCast > 0 then
        vectorCast[1]()
        table.remove(vectorCast, 1)
        return
    end
    
    -- Detect manual Q press and fix charging time
    local act = myHero.activeSpell
    if act and act.name == "PykeQ" and not QKeyHeld then
        -- Q is being cast but we didn't start it - fix the time
        QStartTime = Game.Timer() - 0.1 -- Assume it started 0.1s ago
        QKeyHeld = true
        LastQPressTime = Game.Timer()
    elseif not act or act.name ~= "PykeQ" then
        QKeyHeld = false
    end
    
    local Mode = _G.L9Engine:GetCurrentMode()
    
    if Mode == "Combo" then
        self:Combo()
    elseif Mode == "Harass" then
        self:Harass()
    elseif Mode == "Clear" then
        self:LaneClear()
        self:JungleClear()
    end
    
    self:KillSteal()
end

function L9Pyke:Combo()
    local target = _G.L9Engine:GetBestTarget(1200)
    if not target then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        -- Q charge logic - Hybrid System (Taliyah prediction + Vladimir charge)
        if self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            local act = myHero.activeSpell
            
            if not myHero.isChanneling then
                -- Start charging Q if target in range and not already charging
                local inQRange = target and myHero.pos:DistanceTo(target.pos) <= 1100
                if not QKeyHeld and inQRange then
                    -- Use hybrid system: Taliyah prediction + Vladimir charge
                    if self.Menu.Combo.UseVectorSystem:Value() then
                        StartChargeQWithPrediction(target)
                    else
                        -- Fallback to simple charge
                    if Control.KeyDown then Control.KeyDown(HK_Q) end
                    QKeyHeld = true
                    QStartTime = Game.Timer()
                    LastQPressTime = Game.Timer()
                    end
                elseif QKeyHeld and not inQRange then
                    -- Release early if target moved out of range
                    if Control.KeyUp then Control.KeyUp(HK_Q) end
                    QKeyHeld = false
                end
            else
                -- Manage charge with prediction (Vladimir style + Taliyah prediction)
                ManageQCharge(target, self.Menu)
            end
            
            -- Safety: if we somehow hold longer than 3s (failsafe) release anyway
            if QKeyHeld and (Game.Timer() - QStartTime) > 3.0 then
                if Control.KeyUp then Control.KeyUp(HK_Q) end
                QKeyHeld = false
            end
        else
            -- Release Q if menu disabled or spell not ready
            if QKeyHeld and Control.KeyUp then Control.KeyUp(HK_Q) end
            QKeyHeld = false
        end
        
        -- E logic (don't use E if Q is charging, unless option enabled)
        local canUseE = not QKeyHeld or (self.Menu.Combo.EWhileQCharging and self.Menu.Combo.EWhileQCharging:Value())
        if self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and canUseE then
            local distance = myHero.pos:DistanceTo(target.pos)
            if distance <= 550 then
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(self.Menu.Combo.EHitChance:Value()) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                end
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 750 and self.Menu.Combo.UseR:Value() and _G.L9Engine:IsSpellReady(_R) then
            local enemies = {}
            for i = 1, Game.HeroCount() do
                local hero = Game.Hero(i)
                if _G.L9Engine:IsValidEnemy(hero, 750) then
                    table.insert(enemies, hero)
                end
            end
            
            local killableCount = 0
            for _, enemy in pairs(enemies) do
                local ultDamage = GetUltDamage()
                if ultDamage >= enemy.health then
                    killableCount = killableCount + 1
                end
            end
            
            if killableCount >= self.Menu.Combo.RCount:Value() then
                RPrediction:GetPrediction(target, myHero)
                if RPrediction:CanHit(self.Menu.Combo.RHitChance:Value()) then
                    Control.CastSpell(HK_R, RPrediction.CastPosition)
                else
                    Control.CastSpell(HK_R, target.pos)
                end
            end
        end
    end
end

function L9Pyke:Harass()
    if myHero.mana/myHero.maxMana * 100 < self.Menu.Harass.Mana:Value() then return end
    
    local target = _G.L9Engine:GetBestTarget(1200)
    if not target then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        -- Q charge logic - Hybrid System (Taliyah prediction + Vladimir charge)
        if self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            local act = myHero.activeSpell
            
            if not myHero.isChanneling then
                -- Start charging Q if target in range and not already charging
                local inQRange = target and myHero.pos:DistanceTo(target.pos) <= 1100
                if not QKeyHeld and inQRange then
                    -- Use hybrid system: Taliyah prediction + Vladimir charge
                    if self.Menu.Combo.UseVectorSystem:Value() then
                        StartChargeQWithPrediction(target)
                    else
                        -- Fallback to simple charge
                    if Control.KeyDown then Control.KeyDown(HK_Q) end
                    QKeyHeld = true
                    QStartTime = Game.Timer()
                    LastQPressTime = Game.Timer()
                    end
                elseif QKeyHeld and not inQRange then
                    -- Release early if target moved out of range
                    if Control.KeyUp then Control.KeyUp(HK_Q) end
                    QKeyHeld = false
                end
            else
                -- Manage charge with prediction (Vladimir style + Taliyah prediction)
                ManageQCharge(target, self.Menu)
            end
            
            -- Safety: if we somehow hold longer than 3s (failsafe) release anyway
            if QKeyHeld and (Game.Timer() - QStartTime) > 3.0 then
                if Control.KeyUp then Control.KeyUp(HK_Q) end
                QKeyHeld = false
            end
        else
            -- Release Q if menu disabled or spell not ready
            if QKeyHeld and Control.KeyUp then Control.KeyUp(HK_Q) end
            QKeyHeld = false
        end
        
        -- E logic for harass (don't use E if Q is charging, unless option enabled)
        local canUseE = not QKeyHeld or (self.Menu.Harass.EWhileQCharging and self.Menu.Harass.EWhileQCharging:Value())
        if self.Menu.Harass.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and canUseE then
            local distance = myHero.pos:DistanceTo(target.pos)
            if distance <= 550 then
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(self.Menu.Harass.EHitChance:Value()) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                end
            end
        end

    end
end

function L9Pyke:LaneClear()
    if myHero.mana/myHero.maxMana * 100 < self.Menu.Clear.Mana:Value() then return end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and not IsJungleMob(minion) and myHero.pos:DistanceTo(minion.pos) <= 1100 then
            
            if self.Menu.Clear.UseQ:Value() then
                local act = myHero.activeSpell
                if not myHero.isChanneling then
                    -- Start holding Q only if minion in Q range (1100)
                    local inQRange = minion and myHero.pos:DistanceTo(minion.pos) <= 1100
                    if _G.L9Engine:IsSpellReady(_Q) and not QKeyHeld and inQRange then
                        if Control.KeyDown then Control.KeyDown(HK_Q) end
                        QKeyHeld = true
                        QStartTime = Game.Timer()
                    elseif QKeyHeld and not inQRange then
                        -- Release early if minion moved out of range and we're not channeling yet (safety)
                        if Control.KeyUp then Control.KeyUp(HK_Q) end
                        QKeyHeld = false
                    end
                else
                    if act and act.name == "PykeQ" then
                        local tnow = Game.Timer()
                        local elapsedSinceEnd = (tnow - (act.castEndTime or tnow))
                        -- Release if max charge reached OR minion is in range to hit
                        local chargeTime = tnow - QStartTime
                        local range = math.max(math.min(chargeTime, 1.25) * 1100, 400)
                        local shouldRelease = false
                        
                        if range > 400 and myHero.pos:DistanceTo(minion.pos) <= range then
                            shouldRelease = true
                        end
                        
                        if elapsedSinceEnd >= self.Menu.Combo.QMaxCharge:Value() or shouldRelease then
                            if Control.KeyUp and QKeyHeld then Control.KeyUp(HK_Q) end
                            QKeyHeld = false
                        end
                    end
                end
                -- Safety: if we somehow hold longer than 3s (failsafe) release anyway
                if QKeyHeld and (Game.Timer() - QStartTime) > 3.0 then
                    if Control.KeyUp then Control.KeyUp(HK_Q) end
                    QKeyHeld = false
                end
            end
            

        end
    end
end

function L9Pyke:JungleClear()
    if myHero.mana/myHero.maxMana * 100 < self.Menu.JClear.Mana:Value() then return end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if _G.L9Engine:IsValidEnemy(minion) and IsJungleMob(minion) and myHero.pos:DistanceTo(minion.pos) <= 1100 then
            
            if self.Menu.JClear.UseQ:Value() then
                local act = myHero.activeSpell
                if not myHero.isChanneling then
                    -- Start holding Q only if minion in Q range (1100)
                    local inQRange = minion and myHero.pos:DistanceTo(minion.pos) <= 1100
                    if _G.L9Engine:IsSpellReady(_Q) and not QKeyHeld and inQRange then
                        if Control.KeyDown then Control.KeyDown(HK_Q) end
                        QKeyHeld = true
                        QStartTime = Game.Timer()
                    elseif QKeyHeld and not inQRange then
                        -- Release early if minion moved out of range and we're not channeling yet (safety)
                        if Control.KeyUp then Control.KeyUp(HK_Q) end
                        QKeyHeld = false
                    end
                else
                    if act and act.name == "PykeQ" then
                        local tnow = Game.Timer()
                        local elapsedSinceEnd = (tnow - (act.castEndTime or tnow))
                        -- Release if max charge reached OR minion is in range to hit
                        local chargeTime = tnow - QStartTime
                        local range = math.max(math.min(chargeTime, 1.25) * 1100, 400)
                        local shouldRelease = false
                        
                        if range > 400 and myHero.pos:DistanceTo(minion.pos) <= range then
                            shouldRelease = true
                        end
                        
                        if elapsedSinceEnd >= self.Menu.Combo.QMaxCharge:Value() or shouldRelease then
                            if Control.KeyUp and QKeyHeld then Control.KeyUp(HK_Q) end
                            QKeyHeld = false
                        end
                    end
                end
                -- Safety: if we somehow hold longer than 3s (failsafe) release anyway
                if QKeyHeld and (Game.Timer() - QStartTime) > 3.0 then
                    if Control.KeyUp then Control.KeyUp(HK_Q) end
                    QKeyHeld = false
                end
            end
            

        end
    end
end

function L9Pyke:KillSteal()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if self.Menu.ks.UseR:Value() and _G.L9Engine:IsSpellReady(_R) and myHero.pos:DistanceTo(target.pos) <= 750 then
            local ultDamage = GetUltDamage()
            if target.health <= ultDamage then
                RPrediction:GetPrediction(target, myHero)
                if RPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_R, RPrediction.CastPosition)
                end
            end
        end
        
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= 1100 then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                local act = myHero.activeSpell
                if not myHero.isChanneling then
                    -- Start holding Q only if target in Q range (1100)
                    local inQRange = target and myHero.pos:DistanceTo(target.pos) <= 1100
                    if _G.L9Engine:IsSpellReady(_Q) and not QKeyHeld and inQRange then
                        if Control.KeyDown then Control.KeyDown(HK_Q) end
                        QKeyHeld = true
                        QStartTime = Game.Timer()
                    elseif QKeyHeld and not inQRange then
                        -- Release early if target moved out of range and we're not channeling yet (safety)
                        if Control.KeyUp then Control.KeyUp(HK_Q) end
                        QKeyHeld = false
                    end
                else
                    if act and act.name == "PykeQ" then
                        local tnow = Game.Timer()
                        local elapsedSinceEnd = (tnow - (act.castEndTime or tnow))
                        -- Release if max charge reached OR target is in range to hit
                        local chargeTime = tnow - QStartTime
                        local range = math.max(math.min(chargeTime, 1.25) * 1100, 400)
                        local prediction, hitChance = GetQPredictionWithRange(target, range)
                        local shouldRelease = false
                        
                        if prediction and hitChance >= HITCHANCE_NORMAL then
                            if range > 400 then
                                local castPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                                if myHero.pos:DistanceTo(castPos) <= range then
                                    shouldRelease = true
                                end
                            end
                        end
                        
                        if elapsedSinceEnd >= self.Menu.Combo.QMaxCharge:Value() or shouldRelease then
                            if Control.KeyUp and QKeyHeld then Control.KeyUp(HK_Q) end
                            QKeyHeld = false
                        end
                    end
                end
                -- Safety: if we somehow hold longer than 3s (failsafe) release anyway
                if QKeyHeld and (Game.Timer() - QStartTime) > 3.0 then
                    if Control.KeyUp then Control.KeyUp(HK_Q) end
                    QKeyHeld = false
                end
            end
        end
        
        -- E KillSteal logic
        if self.Menu.ks.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= 550 then
            local EDmg = getdmg("E", target, myHero) or 0
            if target.health <= EDmg then
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                end
            end
        end

    end
end

function L9Pyke:Draw()
    if myHero.dead then return end
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        Draw.Circle(myHero.pos, 1100, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:IsSpellReady(_E) then
        Draw.Circle(myHero.pos, 550, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:IsSpellReady(_R) then
        Draw.Circle(myHero.pos, 750, 1, Draw.Color(255, 0, 0, 255))
    end
    
    -- Draw Q charge status
    if self.Menu.Drawing.DrawQCharge:Value() then
        local act = myHero.activeSpell
        if act and act.valid and act.name == "PykeQ" then
            local chargeTime = Game.Timer() - QStartTime
            local maxCharge = self.Menu.Combo.QMaxCharge:Value()
            local progress = math.min(1, chargeTime / maxCharge)
            local chargeText = string.format("Q Charging: %.1fs/%.1fs", chargeTime, maxCharge)
            local color = Draw.Color(255, 255, 255, 0)
            if progress >= 1 then
                color = Draw.Color(255, 255, 0, 0) -- Yellow when fully charged
            end
            Draw.Text(chargeText, 14, myHero.pos:To2D().x - 60, myHero.pos:To2D().y - 80, color)
        elseif QKeyHeld then
            Draw.Text("Q Key Held", 14, myHero.pos:To2D().x - 40, myHero.pos:To2D().y - 80, Draw.Color(255, 0, 255, 0))
        end
    end
    
    if self.Menu.Drawing.Kill:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero.isEnemy and _G.L9Engine:IsValidEnemy(hero) and _G.L9Engine:CalculateDistance(myHero.pos, hero.pos) <= 2000 then
                local ultDamage = GetUltDamage()
                if hero.health <= ultDamage and _G.L9Engine:IsSpellReady(_R) then
                    local pos = hero.pos:To2D()
                    Draw.Text("TUABLE", 20, pos.x - 30, pos.y - 50, Draw.Color(255, 255, 0, 0))
                end
            end
        end
    end
end

L9Pyke()
