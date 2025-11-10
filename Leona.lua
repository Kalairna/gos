if _G.__L9_ENGINE_LEONA_LOADED then return end
_G.__L9_ENGINE_LEONA_LOADED = true

local Version = "1.0.0"
local Name = "L9Leona"

local Heroes = {"Leona"}
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

-- Leona spell ranges and properties
local SPELL_RANGE = {
    Q = 200,   -- Shield of Daybreak (auto attack reset)
    W = 300,   -- Eclipse (self-buff)
    E = 700,   -- Zenith Blade
    R = 1200   -- Solar Flare
}

local SPELL_SPEED = {
    E = 2000,
    R = 2000
}

local SPELL_DELAY = {
    E = 0.25,
    R = 0.625
}

local SPELL_RADIUS = {
    E = 100,
    R = 300
}

-- Spell Predictions
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

-- Helper function to detect jungle monsters
local function IsJungleMob(minion)
    if not minion or not minion.charName then return false end
    local name = minion.charName:lower()
    return name:find("baron") or name:find("dragon") or name:find("sru_") or 
           name:find("gromp") or name:find("krug") or name:find("murkwolf") or 
           name:find("razorbeak") or name:find("red") or name:find("blue") or
           name:find("crab") or name:find("rift")
end

class "L9Leona"

function L9Leona:__init()
    self:LoadMenu()
    
    -- Variables for combo tracking
    self.lastRTime = 0
    self.lastETime = 0
    self.comboActive = false
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Leona:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Leona", name = "L9Leona"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Shield of Daybreak", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Eclipse", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Zenith Blade", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Solar Flare", value = true})
    self.Menu.Combo:MenuElement({id = "TripleStun", name = "Triple Stun Combo (R+E+Q)", value = true})
    self.Menu.Combo:MenuElement({id = "DoubleStun", name = "Double Stun Combo (R+E)", value = true})
    self.Menu.Combo:MenuElement({id = "AutoQ", name = "Auto Q After E", value = true})
    self.Menu.Combo:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RHitChance", name = "R Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RMinEnemies", name = "R Min Enemies", value = 1, min = 1, max = 5, identifier = ""})
    self.Menu.Combo:MenuElement({id = "ComboDelay", name = "Combo Delay (ms)", value = 100, min = 0, max = 500, step = 50})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Shield of Daybreak", value = true})
    self.Menu.Harass:MenuElement({id = "UseW", name = "[W] Eclipse", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Zenith Blade", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    self.Menu.Harass:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Shield of Daybreak", value = true})
    self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Eclipse", value = true})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Zenith Blade", value = false})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Shield of Daybreak", value = true})
    self.Menu.JClear:MenuElement({id = "UseW", name = "[W] Eclipse", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Zenith Blade", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Zenith Blade", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] Solar Flare", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = true})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = true})
    self.Menu.Drawing:MenuElement({id = "DrawCombo", name = "Draw Combo Status", value = true})
end

function L9Leona:Tick()
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

function L9Leona:Combo()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        -- Triple Stun Combo (R + E + Q)
        if self.Menu.Combo.TripleStun:Value() then
            -- R for engage
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
                    RPrediction:GetPrediction(target, myHero)
                    if RPrediction:CanHit(self.Menu.Combo.RHitChance:Value()) then
                        Control.CastSpell(HK_R, RPrediction.CastPosition)
                        self.lastRTime = Game.Timer()
                        self.comboActive = true
                        return
                    end
                end
            end
            
            -- E after R (with delay)
            if self.comboActive and Game.Timer() - self.lastRTime <= 1.0 and Game.Timer() - self.lastRTime >= (self.Menu.Combo.ComboDelay:Value() / 1000) then
                if self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and distance <= SPELL_RANGE.E then
                    EPrediction:GetPrediction(target, myHero)
                    if EPrediction:CanHit(self.Menu.Combo.EHitChance:Value()) then
                        Control.CastSpell(HK_E, EPrediction.CastPosition)
                        self.lastETime = Game.Timer()
                        return
                    end
                end
            end
            
            -- Q after E (when in range)
            if Game.Timer() - self.lastETime <= 0.5 and distance <= SPELL_RANGE.Q then
                if self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
                    Control.CastSpell(HK_Q)
                    self.comboActive = false
                    return
                end
            end
        end
        
        -- Double Stun Combo (R + E)
        if self.Menu.Combo.DoubleStun:Value() and not self.Menu.Combo.TripleStun:Value() then
            -- R for engage
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
                    RPrediction:GetPrediction(target, myHero)
                    if RPrediction:CanHit(self.Menu.Combo.RHitChance:Value()) then
                        Control.CastSpell(HK_R, RPrediction.CastPosition)
                        self.lastRTime = Game.Timer()
                        self.comboActive = true
                        return
                    end
                end
            end
            
            -- E after R (with delay)
            if self.comboActive and Game.Timer() - self.lastRTime <= 1.0 and Game.Timer() - self.lastRTime >= (self.Menu.Combo.ComboDelay:Value() / 1000) then
                if self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and distance <= SPELL_RANGE.E then
                    EPrediction:GetPrediction(target, myHero)
                    if EPrediction:CanHit(self.Menu.Combo.EHitChance:Value()) then
                        Control.CastSpell(HK_E, EPrediction.CastPosition)
                        self.comboActive = false
                        return
                    end
                end
            end
        end
        
        -- Standard combo (no special combo active)
        if not self.comboActive then
            -- W for shield (activate when close to enemy)
            if self.Menu.Combo.UseW:Value() and _G.L9Engine:IsSpellReady(_W) and distance <= SPELL_RANGE.E then
                Control.CastSpell(HK_W)
            end
            
            -- Q first if in melee range (stun before dash)
            if self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and distance <= SPELL_RANGE.Q then
                Control.CastSpell(HK_Q)
                return
            end
            
            -- E for engage (only if not in melee or Q not ready)
            if self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and distance <= SPELL_RANGE.E and distance > SPELL_RANGE.Q then
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(self.Menu.Combo.EHitChance:Value()) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                    self.lastETime = Game.Timer()
                    return
                end
            end
            
            -- E if Q not ready but we need to engage
            if self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and distance <= SPELL_RANGE.E and not _G.L9Engine:IsSpellReady(_Q) then
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(self.Menu.Combo.EHitChance:Value()) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                    self.lastETime = Game.Timer()
                    return
                end
            end
            
            -- R for multiple enemies or finisher
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
                    RPrediction:GetPrediction(target, myHero)
                    if RPrediction:CanHit(self.Menu.Combo.RHitChance:Value()) then
                        Control.CastSpell(HK_R, RPrediction.CastPosition)
                        return
                    end
                end
            end
        end
    end
end

function L9Leona:Harass()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        -- W when close for shield
        if distance <= SPELL_RANGE.E and self.Menu.Harass.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            Control.CastSpell(HK_W)
        end
        
        -- E for harass
        if distance <= SPELL_RANGE.E and self.Menu.Harass.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            EPrediction:GetPrediction(target, myHero)
            if EPrediction:CanHit(self.Menu.Harass.EHitChance:Value()) then
                Control.CastSpell(HK_E, EPrediction.CastPosition)
                self.lastETime = Game.Timer()
                return
            end
        end
        
        -- Q in melee range
        if distance <= SPELL_RANGE.Q and self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            Control.CastSpell(HK_Q)
        end
    end
end

function L9Leona:LaneClear()
    if myHero.mana/myHero.maxMana < self.Menu.Clear.Mana:Value() / 100 then
        return
    end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and not IsJungleMob(minion) then
            local distance = myHero.pos:DistanceTo(minion.pos)
            
            if distance <= SPELL_RANGE.W and self.Menu.Clear.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
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
                    Control.CastSpell(HK_W)
                    return
                end
            end
            
            if distance <= SPELL_RANGE.Q and self.Menu.Clear.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
                Control.CastSpell(HK_Q)
                return
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

function L9Leona:JungleClear()
    if myHero.mana/myHero.maxMana < self.Menu.JClear.Mana:Value() / 100 then
        return
    end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if _G.L9Engine:IsValidEnemy(minion) and IsJungleMob(minion) then
            local distance = myHero.pos:DistanceTo(minion.pos)
            
            if distance <= SPELL_RANGE.Q and self.Menu.JClear.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
                Control.CastSpell(HK_Q)
                return
            end
            
            if distance <= SPELL_RANGE.W and self.Menu.JClear.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
                Control.CastSpell(HK_W)
                return
            end
            
            if distance <= SPELL_RANGE.E and self.Menu.JClear.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
                Control.CastSpell(HK_E, minion.pos)
                return
            end
        end
    end
end

function L9Leona:KillSteal()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        if self.Menu.ks.UseR:Value() and _G.L9Engine:IsSpellReady(_R) and distance <= SPELL_RANGE.R then
            if target.health <= 300 then -- Basic threshold
                RPrediction:GetPrediction(target, myHero)
                if RPrediction:CanHit(HITCHANCE_HIGH) then
                    Control.CastSpell(HK_R, RPrediction.CastPosition)
                    return
                end
            end
        end
        
        if self.Menu.ks.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and distance <= SPELL_RANGE.E then
            if target.health <= 200 then -- Basic threshold
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(HITCHANCE_HIGH) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                    return
                end
            end
        end
    end
end

function L9Leona:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    local textPos = myHero.pos:To2D()
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        Draw.Circle(myHero.pos, SPELL_RANGE.Q, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:IsSpellReady(_W) then
        Draw.Circle(myHero.pos, SPELL_RANGE.W, 1, Draw.Color(255, 255, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:IsSpellReady(_E) then
        Draw.Circle(myHero.pos, SPELL_RANGE.E, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:IsSpellReady(_R) then
        Draw.Circle(myHero.pos, SPELL_RANGE.R, 1, Draw.Color(255, 0, 0, 255))
    end
    
    -- Draw combo status
    if self.Menu.Drawing.DrawCombo:Value() then
        local comboText = "Combo: "
        local comboColor = Draw.Color(255, 255, 255, 255)
        
        if self.comboActive then
            comboText = comboText .. "ACTIVE"
            comboColor = Draw.Color(255, 255, 0, 0)
        else
            comboText = comboText .. "Ready"
            comboColor = Draw.Color(255, 0, 255, 0)
        end
        
        Draw.Text(comboText, 15, textPos.x - 60, textPos.y + 60, comboColor)
    end
    
    Draw.Text("Leona - L9 Script", 15, textPos.x - 60, textPos.y + 40, Draw.Color(255, 255, 255, 255))
end

L9Leona()
