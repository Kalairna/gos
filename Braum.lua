if _G.__L9_ENGINE_BRAUM_LOADED then return end
_G.__L9_ENGINE_BRAUM_LOADED = true

local Version = "1.0.0"
local Name = "L9Braum"

local Heroes = {"Braum"}
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

-- Braum spell ranges and properties
local SPELL_RANGE = {
    Q = 1000,  -- Winter's Bite
    W = 650,   -- Stand Behind Me
    E = 0,     -- Unbreakable (self)
    R = 1200   -- Glacial Fissure
}

local SPELL_SPEED = {
    Q = 1700,
    R = 1400
}

local SPELL_DELAY = {
    Q = 0.25,
    R = 0.5
}

local SPELL_RADIUS = {
    Q = 100,
    R = 200
}

-- Spell Predictions
local QPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = SPELL_DELAY.Q,
    Radius = SPELL_RADIUS.Q,
    Range = SPELL_RANGE.Q,
    Speed = SPELL_SPEED.Q,
    Collision = true,
    MaxCollision = 0,
    CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL },
})

local RPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = SPELL_DELAY.R,
    Radius = SPELL_RADIUS.R,
    Range = SPELL_RANGE.R,
    Speed = SPELL_SPEED.R,
    Collision = false,
})

local HITCHANCE_NORMAL = 2
local HITCHANCE_HIGH = 3
local HITCHANCE_IMMOBILE = 4

-- Helper function to check if ally is in combat
local function IsAllyInCombat(ally)
    if not ally then return false end
    
    -- Check if ally is attacking or being attacked
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if enemy and enemy.isEnemy and not enemy.dead then
            local distance = ally.pos:DistanceTo(enemy.pos)
            -- Ally is in combat if enemy is close (within 1000 units)
            if distance <= 1000 then
                return true
            end
        end
    end
    
    return false
end

-- Helper function to check if target is stunned/immobilized (hard CC only)
local function IsTargetStunned(target)
    if not target then return false end
    
    -- List of slow/non-hard CC buff names to exclude
    local excludedBuffs = {
        "braumqslow",          -- Braum Q slow
        "slow",                -- Generic slow
        "itemfrostcannonSlow", -- Items slow
        "summonerexhaust",     -- Exhaust
        "chilled",             -- Various slows
        "cripple",             -- Attack speed slow
        "wither",              -- Nasus W
    }
    
    -- VERY STRICT - Only specific hard CC types AND check buff name
    for i = 0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff and buff.count > 0 then
            local buffType = buff.type
            local buffName = (buff.name or ""):lower()
            
            -- First check if it's in excluded list
            local isExcluded = false
            for _, excludedName in ipairs(excludedBuffs) do
                if buffName:find(excludedName:lower()) then
                    isExcluded = true
                    print("EXCLUDED BUFF: " .. buffName .. " on " .. target.charName)
                    break
                end
            end
            
            -- Only accept hard CC types AND not excluded
            if not isExcluded then
                -- ONLY these specific types - NO SLOW (10)
                -- 5=stun, 8=taunt, 11=snare/root, 21=knockup, 24=charm, 29=suppression
                if buffType == 5 or buffType == 8 or buffType == 11 or 
                   buffType == 21 or buffType == 24 or buffType == 29 then
                    -- Debug print with buff name
                    print("VALID Hard CC on " .. target.charName .. " - Type: " .. buffType .. " Name: " .. buffName)
                    return true
                end
            end
        end
    end
    return false
end

-- Helper function to check if target is slowed
local function IsTargetSlowed(target)
    if not target then return false end
    
    -- Check if target has slow buff (type 10 ONLY)
    for i = 0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff and buff.count > 0 then
            local buffType = buff.type
            if buffType == 10 then -- 10 = slow
                print("Slow detected on " .. target.charName .. " - Type: " .. buffType)
                return true
            end
        end
    end
    return false
end

-- Helper function to check if being attacked by ranged enemies
local function IsBeingAttackedByRanged()
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if enemy and enemy.isEnemy and _G.L9Engine:IsValidEnemy(enemy) then
            local distance = myHero.pos:DistanceTo(enemy.pos)
            -- Check if enemy is ranged (attack range > 300) and close enough to be threatening
            local attackRange = enemy.attackRange or 125
            if attackRange > 300 and distance <= attackRange + 200 then
                -- Check if enemy is facing us (simple check)
                if distance <= 1000 then
                    return true
                end
            end
        end
    end
    return false
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

class "L9Braum"

function L9Braum:__init()
    self:LoadMenu()
    
    self.lastRTime = 0
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Braum:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Braum", name = "L9Braum"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Winter's Bite", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Stand Behind Me", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Unbreakable", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Glacial Fissure", value = true})
    self.Menu.Combo:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RHitChance", name = "R Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RMinEnemies", name = "R Min Enemies", value = 2, min = 1, max = 5, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "AutoPlay", name = "Auto Play"})
    self.Menu.AutoPlay:MenuElement({id = "AutoE", name = "Auto E vs Ranged Attacks", value = false})
    self.Menu.AutoPlay:MenuElement({id = "AutoR", name = "Auto R on Hard CC ONLY", value = true})
    self.Menu.AutoPlay:MenuElement({id = "AutoW", name = "Auto W to Allies in Combat", value = false})
    self.Menu.AutoPlay:MenuElement({id = "AutoWHP", name = "Auto W Ally HP %", value = 50, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Winter's Bite", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    self.Menu.Harass:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Winter's Bite", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Winter's Bite", value = true})
    self.Menu.JClear:MenuElement({id = "UseW", name = "[W] Stand Behind Me", value = false})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Winter's Bite", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] Glacial Fissure", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = true})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = true})
    self.Menu.Drawing:MenuElement({id = "DrawAutoStatus", name = "Draw Auto Status", value = true})
end

function L9Braum:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    -- Only run auto play if enabled (optimization)
    if self.Menu.AutoPlay.AutoE:Value() then
        self:AutoE()
    end
    
    if self.Menu.AutoPlay.AutoR:Value() then
        self:AutoR()
    end
    
    if self.Menu.AutoPlay.AutoW:Value() then
        self:AutoW()
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

function L9Braum:AutoE()
    if not _G.L9Engine:IsSpellReady(_E) then
        return
    end
    
    -- Simplified check - only check closest enemies for performance
    local target = _G.L9Engine:GetBestTarget(800)
    if target and _G.L9Engine:IsValidEnemy(target) then
        local attackRange = target.attackRange or 125
        local distance = myHero.pos:DistanceTo(target.pos)
        if attackRange > 300 and distance <= attackRange + 100 then
            Control.CastSpell(HK_E)
        end
    end
end

function L9Braum:AutoR()
    if not _G.L9Engine:IsSpellReady(_R) then
        return
    end
    
    -- Cooldown between R casts
    if Game.Timer() - self.lastRTime < 1.0 then
        return
    end
    
    -- Check all enemies for HARD CC'd targets ONLY
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if enemy and enemy.isEnemy and _G.L9Engine:IsValidEnemy(enemy) then
            local distance = myHero.pos:DistanceTo(enemy.pos)
            if distance <= SPELL_RANGE.R then
                -- ONLY check hard CC - NO SLOW CHECK AT ALL
                if IsTargetStunned(enemy) then
                    RPrediction:GetPrediction(enemy, myHero)
                    if RPrediction:CanHit(HITCHANCE_NORMAL) then
                        Control.CastSpell(HK_R, RPrediction.CastPosition)
                        self.lastRTime = Game.Timer()
                        print("=== BRAUM AUTO R CAST === Hard CC: " .. enemy.charName)
                        return
                    end
                end
            end
        end
    end
end

function L9Braum:AutoW()
    if not _G.L9Engine:IsSpellReady(_W) then
        return
    end
    
    -- Check nearby allies for combat
    for i = 1, Game.HeroCount() do
        local ally = Game.Hero(i)
        if ally and ally.isAlly and not ally.isMe and not ally.dead then
            local distance = myHero.pos:DistanceTo(ally.pos)
            if distance <= SPELL_RANGE.W then
                local allyHealthPercent = (ally.health / ally.maxHealth) * 100
                if allyHealthPercent <= self.Menu.AutoPlay.AutoWHP:Value() and IsAllyInCombat(ally) then
                    Control.CastSpell(HK_W, ally)
                    return
                end
            end
        end
    end
end

function L9Braum:Combo()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        -- R for engage or multiple enemies
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
        
        -- Q for poke and slow
        if self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and distance <= SPELL_RANGE.Q then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Combo.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
                return
            end
        end
        
        -- E for defense when in combat
        if self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and distance <= 600 then
            if IsBeingAttackedByRanged() then
                Control.CastSpell(HK_E)
            end
        end
        
        -- W to allies in combat
        if self.Menu.Combo.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            for i = 1, Game.HeroCount() do
                local ally = Game.Hero(i)
                if ally and ally.isAlly and not ally.isMe and not ally.dead then
                    local distanceToAlly = myHero.pos:DistanceTo(ally.pos)
                    if distanceToAlly <= SPELL_RANGE.W and IsAllyInCombat(ally) then
                        Control.CastSpell(HK_W, ally)
                        return
                    end
                end
            end
        end
    end
end

function L9Braum:Harass()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        if distance <= SPELL_RANGE.Q and self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Harass.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
            end
        end
    end
end

function L9Braum:LaneClear()
    if myHero.mana/myHero.maxMana < self.Menu.Clear.Mana:Value() / 100 then
        return
    end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and not IsJungleMob(minion) then
            local distance = myHero.pos:DistanceTo(minion.pos)
            
            if distance <= SPELL_RANGE.Q and self.Menu.Clear.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
                local minionsInLine = 0
                for j = 1, Game.MinionCount() do
                    local otherMinion = Game.Minion(j)
                    if otherMinion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(otherMinion) and not IsJungleMob(otherMinion) then
                        if myHero.pos:DistanceTo(otherMinion.pos) <= SPELL_RANGE.Q then
                            minionsInLine = minionsInLine + 1
                        end
                    end
                end
                
                if minionsInLine >= 3 then
                    Control.CastSpell(HK_Q, minion.pos)
                    return
                end
            end
        end
    end
end

function L9Braum:JungleClear()
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
        end
    end
end

function L9Braum:KillSteal()
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
        
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and distance <= SPELL_RANGE.Q then
            if target.health <= 200 then -- Basic threshold
                QPrediction:GetPrediction(target, myHero)
                if QPrediction:CanHit(HITCHANCE_HIGH) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                    return
                end
            end
        end
    end
end

function L9Braum:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    local textPos = myHero.pos:To2D()
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        Draw.Circle(myHero.pos, SPELL_RANGE.Q, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:IsSpellReady(_W) then
        Draw.Circle(myHero.pos, SPELL_RANGE.W, 1, Draw.Color(255, 255, 255, 0))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:IsSpellReady(_R) then
        Draw.Circle(myHero.pos, SPELL_RANGE.R, 1, Draw.Color(255, 0, 0, 255))
    end
    
    -- Draw auto play status (simplified for performance)
    if self.Menu.Drawing.DrawAutoStatus:Value() then
        local yOffset = 40
        local statusText = ""
        
        if self.Menu.AutoPlay.AutoE:Value() then
            statusText = statusText .. "E "
        end
        if self.Menu.AutoPlay.AutoR:Value() then
            statusText = statusText .. "R "
        end
        if self.Menu.AutoPlay.AutoW:Value() then
            statusText = statusText .. "W "
        end
        
        if statusText ~= "" then
            Draw.Text("Auto: " .. statusText, 15, textPos.x - 60, textPos.y + yOffset, Draw.Color(255, 0, 255, 0))
        end
    end
    
    Draw.Text("Braum - L9 Script", 15, textPos.x - 60, textPos.y + 20, Draw.Color(255, 255, 255, 255))
end

L9Braum()
