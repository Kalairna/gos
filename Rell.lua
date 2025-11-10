if _G.__L9_ENGINE_RELL_LOADED then return end
_G.__L9_ENGINE_RELL_LOADED = true

local Version = "1.0.0"
local Name = "L9Rell"

local Heroes = {"Rell"}
if not table.contains(Heroes, myHero.charName) then return end

-- Download and load GGPrediction
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

local function CheckPredictionSystem()
    if not _G.GGPrediction then
        return false
    end
    return true
end

-- Rell spell ranges and properties
local SPELL_RANGE = {
    Q = 600,   -- Shattering Strike
    W = 600,   -- Ferromancy: Mount Up / Crash Down
    E = 400,   -- Attract and Repel
    R = 500    -- Magnet Storm
}

local SPELL_SPEED = {
    Q = 2000,
    W = 2000,
    E = 2000,
    R = 2000
}

local SPELL_DELAY = {
    Q = 0.25,
    W = 0.25,
    E = 0.25,
    R = 0.25
}

local SPELL_RADIUS = {
    Q = 100,
    W = 300,
    E = 100,
    R = 500
}

-- Spell Predictions
local QPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = SPELL_DELAY.Q,
    Radius = SPELL_RADIUS.Q,
    Range = SPELL_RANGE.Q,
    Speed = SPELL_SPEED.Q,
    Collision = false,
})

local WPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_CIRCULAR,
    Delay = SPELL_DELAY.W,
    Radius = SPELL_RADIUS.W,
    Range = SPELL_RANGE.W,
    Speed = SPELL_SPEED.W,
    Collision = false,
})

local EPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = SPELL_DELAY.E,
    Radius = SPELL_RADIUS.E,
    Range = SPELL_RANGE.E,
    Speed = SPELL_SPEED.E,
    Collision = false,
})

local RPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_CIRCULAR,
    Delay = SPELL_DELAY.R,
    Radius = SPELL_RADIUS.R,
    Range = SPELL_RANGE.R,
    Speed = SPELL_SPEED.R,
    Collision = false,
})

local HITCHANCE_NORMAL = 2
local HITCHANCE_HIGH = 3
local HITCHANCE_IMMOBILE = 4

-- Rell form detection
local function IsMounted()
    -- Check if Rell is in mounted form
    local buff = _G.L9Engine:GetUnitBuff(myHero, "rellmounted")
    return buff ~= nil
end

local function IsWActive()
    -- Check if W is currently active (mounted form)
    local buff = _G.L9Engine:GetUnitBuff(myHero, "rellw")
    return buff ~= nil
end

-- Helper function to detect jungle monsters
local function IsJungleMob(minion)
    if not minion or not minion.charName then return false end
    local name = minion.charName:lower()
    return name:find("baron") or name:find("dragon") or name:find("sru_") or 
           name:find("gromp") or name:find("krug") or name:find("murkwolf") or 
           name:find("razorbeak") or name:find("red") or name:find("blue") or
           name:find("crab") or name:find("rift")
end

class "L9Rell"

function L9Rell:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Rell:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Rell", name = "L9Rell"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Shattering Strike", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Ferromancy", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Attract and Repel", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Magnet Storm", value = true})
    self.Menu.Combo:MenuElement({id = "UseRInW", name = "[R] During W (Mounted)", value = true})
    self.Menu.Combo:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "WHitChance", name = "W Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RHitChance", name = "R Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RMinEnemies", name = "R Min Enemies", value = 2, min = 1, max = 5, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Shattering Strike", value = true})
    self.Menu.Harass:MenuElement({id = "UseW", name = "[W] Ferromancy", value = false})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Attract and Repel", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    self.Menu.Harass:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    self.Menu.Harass:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Shattering Strike", value = true})
    self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Ferromancy", value = true})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Attract and Repel", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Shattering Strike", value = true})
    self.Menu.JClear:MenuElement({id = "UseW", name = "[W] Ferromancy", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Attract and Repel", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Shattering Strike", value = true})
    self.Menu.ks:MenuElement({id = "UseW", name = "[W] Ferromancy", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Attract and Repel", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawForm", name = "Draw Current Form", value = true})
end

function L9Rell:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
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

function L9Rell:Combo()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        local distance = myHero.pos:DistanceTo(target.pos)
        local isMounted = IsMounted()
        local isWActive = IsWActive()
        
        -- R for multiple enemies (can be cast during W)
        if self.Menu.Combo.UseR:Value() and _G.L9Engine:IsSpellReady(_R) and distance <= SPELL_RANGE.R then
            local enemiesInRange = 0
            for i = 1, Game.HeroCount() do
                local enemy = Game.Hero(i)
                if enemy and enemy.isEnemy and _G.L9Engine:IsValidEnemy(enemy) then
                    if myHero.pos:DistanceTo(enemy.pos) <= SPELL_RANGE.R then
                        enemiesInRange = enemiesInRange + 1
                    end
                end
            end
            
            if enemiesInRange >= self.Menu.Combo.RMinEnemies:Value() then
                -- Can cast R during W if enabled
                if isWActive and self.Menu.Combo.UseRInW:Value() then
                    RPrediction:GetPrediction(target, myHero)
                    if RPrediction:CanHit(self.Menu.Combo.RHitChance:Value()) then
                        Control.CastSpell(HK_R, RPrediction.CastPosition)
                        return
                    end
                elseif not isWActive then
                    RPrediction:GetPrediction(target, myHero)
                    if RPrediction:CanHit(self.Menu.Combo.RHitChance:Value()) then
                        Control.CastSpell(HK_R, RPrediction.CastPosition)
                        return
                    end
                end
            end
        end
        
        -- W for engage/disengage
        if self.Menu.Combo.UseW:Value() and _G.L9Engine:IsSpellReady(_W) and distance <= SPELL_RANGE.W then
            if isMounted then
                -- Crash Down (dismount)
                WPrediction:GetPrediction(target, myHero)
                if WPrediction:CanHit(self.Menu.Combo.WHitChance:Value()) then
                    Control.CastSpell(HK_W, WPrediction.CastPosition)
                    return
                end
            else
                -- Mount Up (engage)
                WPrediction:GetPrediction(target, myHero)
                if WPrediction:CanHit(self.Menu.Combo.WHitChance:Value()) then
                    Control.CastSpell(HK_W, WPrediction.CastPosition)
                    return
                end
            end
        end
        
        -- E for stun/knockback
        if self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and distance <= SPELL_RANGE.E then
            EPrediction:GetPrediction(target, myHero)
            if EPrediction:CanHit(self.Menu.Combo.EHitChance:Value()) then
                Control.CastSpell(HK_E, EPrediction.CastPosition)
                return
            end
        end
        
        -- Q for damage and shield break
        if self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and distance <= SPELL_RANGE.Q then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Combo.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
                return
            end
        end
    end
end

function L9Rell:Harass()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        if distance <= SPELL_RANGE.Q and self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Harass.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
                return
            end
        end
        
        if distance <= SPELL_RANGE.W and self.Menu.Harass.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            local isMounted = IsMounted()
            if not isMounted then -- Only mount up for harass, not dismount
                WPrediction:GetPrediction(target, myHero)
                if WPrediction:CanHit(HITCHANCE_HIGH) then
                    Control.CastSpell(HK_W, WPrediction.CastPosition)
                    return
                end
            end
        end
        
        if distance <= SPELL_RANGE.E and self.Menu.Harass.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            EPrediction:GetPrediction(target, myHero)
            if EPrediction:CanHit(self.Menu.Harass.EHitChance:Value()) then
                Control.CastSpell(HK_E, EPrediction.CastPosition)
                return
            end
        end
    end
end

function L9Rell:LaneClear()
    if myHero.mana/myHero.maxMana < self.Menu.Clear.Mana:Value() / 100 then
        return
    end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and not IsJungleMob(minion) then
            local distance = myHero.pos:DistanceTo(minion.pos)
            
            if distance <= SPELL_RANGE.Q and self.Menu.Clear.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
                local minionsInRange = 0
                for j = 1, Game.MinionCount() do
                    local otherMinion = Game.Minion(j)
                    if otherMinion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(otherMinion) and not IsJungleMob(otherMinion) then
                        if myHero.pos:DistanceTo(otherMinion.pos) <= SPELL_RANGE.Q then
                            minionsInRange = minionsInRange + 1
                        end
                    end
                end
                
                if minionsInRange >= 3 then
                    Control.CastSpell(HK_Q, minion.pos)
                    return
                end
            end
            
            if distance <= SPELL_RANGE.W and self.Menu.Clear.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
                local isMounted = IsMounted()
                if not isMounted then -- Only mount up for clear
                    local minionsInRange = 0
                    for j = 1, Game.MinionCount() do
                        local otherMinion = Game.Minion(j)
                        if otherMinion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(otherMinion) and not IsJungleMob(otherMinion) then
                            if myHero.pos:DistanceTo(otherMinion.pos) <= SPELL_RANGE.W then
                                minionsInRange = minionsInRange + 1
                            end
                        end
                    end
                    
                    if minionsInRange >= 3 then
                        Control.CastSpell(HK_W, minion.pos)
                        return
                    end
                end
            end
            
            if distance <= SPELL_RANGE.E and self.Menu.Clear.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
                local minionsInRange = 0
                for j = 1, Game.MinionCount() do
                    local otherMinion = Game.Minion(j)
                    if otherMinion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(otherMinion) and not IsJungleMob(otherMinion) then
                        if myHero.pos:DistanceTo(otherMinion.pos) <= SPELL_RANGE.E then
                            minionsInRange = minionsInRange + 1
                        end
                    end
                end
                
                if minionsInRange >= 3 then
                    Control.CastSpell(HK_E, minion.pos)
                    return
                end
            end
        end
    end
end

function L9Rell:JungleClear()
    if myHero.mana/myHero.maxMana < self.Menu.JClear.Mana:Value() / 100 then
        return
    end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if _G.L9Engine:IsValidEnemy(minion) and IsJungleMob(minion) then
            local distance = myHero.pos:DistanceTo(minion.pos)
            
            if distance <= SPELL_RANGE.Q and self.Menu.JClear.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
                Control.CastSpell(HK_Q, minion.pos)
                return
            end
            
            if distance <= SPELL_RANGE.W and self.Menu.JClear.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
                local isMounted = IsMounted()
                if not isMounted then -- Only mount up for jungle clear
                    Control.CastSpell(HK_W, minion.pos)
                    return
                end
            end
            
            if distance <= SPELL_RANGE.E and self.Menu.JClear.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
                Control.CastSpell(HK_E, minion.pos)
                return
            end
        end
    end
end

function L9Rell:KillSteal()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and distance <= SPELL_RANGE.Q then
            if target.health <= 200 then -- Basic threshold
                QPrediction:GetPrediction(target, myHero)
                if QPrediction:CanHit(HITCHANCE_HIGH) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                    return
                end
            end
        end
        
        if self.Menu.ks.UseW:Value() and _G.L9Engine:IsSpellReady(_W) and distance <= SPELL_RANGE.W then
            if target.health <= 300 then -- Basic threshold
                local isMounted = IsMounted()
                if isMounted then -- Only dismount for kill steal
                    WPrediction:GetPrediction(target, myHero)
                    if WPrediction:CanHit(HITCHANCE_HIGH) then
                        Control.CastSpell(HK_W, WPrediction.CastPosition)
                        return
                    end
                end
            end
        end
        
        if self.Menu.ks.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and distance <= SPELL_RANGE.E then
            if target.health <= 250 then -- Basic threshold
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(HITCHANCE_HIGH) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                    return
                end
            end
        end
    end
end

function L9Rell:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    local textPos = myHero.pos:To2D()
    local isMounted = IsMounted()
    local isWActive = IsWActive()
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        Draw.Circle(myHero.pos, SPELL_RANGE.Q, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:IsSpellReady(_W) then
        Draw.Circle(myHero.pos, SPELL_RANGE.W, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:IsSpellReady(_E) then
        Draw.Circle(myHero.pos, SPELL_RANGE.E, 1, Draw.Color(255, 0, 0, 255))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:IsSpellReady(_R) then
        Draw.Circle(myHero.pos, SPELL_RANGE.R, 1, Draw.Color(255, 255, 255, 0))
    end
    
    -- Draw current form
    if self.Menu.Drawing.DrawForm:Value() then
        local formText = "Form: "
        local formColor = Draw.Color(255, 255, 255, 255)
        
        if isWActive then
            formText = formText .. "W Active"
            formColor = Draw.Color(255, 255, 0, 0)
        elseif isMounted then
            formText = formText .. "Mounted"
            formColor = Draw.Color(255, 0, 255, 0)
        else
            formText = formText .. "Dismounted"
            formColor = Draw.Color(255, 0, 0, 255)
        end
        
        Draw.Text(formText, 15, textPos.x - 60, textPos.y + 60, formColor)
    end
    
    Draw.Text("Rell - L9 Script", 15, textPos.x - 60, textPos.y + 40, Draw.Color(255, 255, 255, 255))
end

L9Rell()


