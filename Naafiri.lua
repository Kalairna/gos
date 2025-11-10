if _G.__L9_ENGINE_NAAFIRI_LOADED then return end
_G.__L9_ENGINE_NAAFIRI_LOADED = true

local Version = 1.0
local Name = "L9Naafiri"

local Heroes = {"Naafiri"}
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
    Radius = 60,
    Range = 1000,
    Speed = 2000,
    Collision = false,
})

local WPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = 0.25,
    Radius = 80,
    Range = 1200,
    Speed = 2000,
    Collision = false,
})

local EPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_CIRCULAR,
    Delay = 0.25,
    Radius = 300,
    Range = 600,
    Speed = 2000,
    Collision = false,
})

local RPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = 0.25,
    Radius = 100,
    Range = 1500,
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

local function GetPackmatesCount()
    local count = 0
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team == myHero.team and minion.charName == "NaafiriHound" then
            count = count + 1
        end
    end
    return count
end

local function IsTargetMarked(target)
    if not target then return false end
    local buff = _G.L9Engine:GetUnitBuff(target, "NaafiriPassive")
    return buff ~= nil
end

local function GetMarkedTargets()
    local targets = {}
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and _G.L9Engine:IsValidEnemy(hero) and IsTargetMarked(hero) then
            table.insert(targets, hero)
        end
    end
    return targets
end

class "L9Naafiri"

function L9Naafiri:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Naafiri:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Naafiri", name = "L9Naafiri"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Darkin Daggers", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Hounds' Pursuit", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Eviscerate", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] The Call of the Pack", value = true})
    self.Menu.Combo:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "WHitChance", name = "W Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RHitChance", name = "R Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Darkin Daggers", value = true})
    self.Menu.Harass:MenuElement({id = "UseW", name = "[W] Hounds' Pursuit", value = false})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Eviscerate", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    self.Menu.Harass:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    self.Menu.Harass:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Darkin Daggers", value = true})
    self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Hounds' Pursuit", value = true})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Eviscerate", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Darkin Daggers", value = true})
    self.Menu.JClear:MenuElement({id = "UseW", name = "[W] Hounds' Pursuit", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Eviscerate", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Darkin Daggers", value = true})
    self.Menu.ks:MenuElement({id = "UseW", name = "[W] Hounds' Pursuit", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Eviscerate", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] The Call of the Pack", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "Kill", name = "Draw Killable Targets", value = true})
    self.Menu.Drawing:MenuElement({id = "Packmates", name = "Draw Packmates Count", value = true})
end

function L9Naafiri:Tick()
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

function L9Naafiri:Combo()
    local target = _G.L9Engine:GetBestTarget(1500)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        -- R - Ultimate (priorité haute)
        if distance <= 1500 and self.Menu.Combo.UseR:Value() and _G.L9Engine:IsSpellReady(_R) then
            RPrediction:GetPrediction(target, myHero)
            if RPrediction:CanHit(self.Menu.Combo.RHitChance:Value()) then
                Control.CastSpell(HK_R, RPrediction.CastPosition)
                return
            end
        end
        
        -- W - Dash (si pas de packmates ou cible marquée)
        if distance <= 1200 and self.Menu.Combo.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            local packmatesCount = GetPackmatesCount()
            if packmatesCount == 0 or IsTargetMarked(target) then
                WPrediction:GetPrediction(target, myHero)
                if WPrediction:CanHit(self.Menu.Combo.WHitChance:Value()) then
                    Control.CastSpell(HK_W, WPrediction.CastPosition)
                    return
                end
            end
        end
        
        -- Q + E combo simultané (technique avancée)
        if distance <= 600 and self.Menu.Combo.UseQ:Value() and self.Menu.Combo.UseE:Value() and 
           _G.L9Engine:IsSpellReady(_Q) and _G.L9Engine:IsSpellReady(_E) then
            QPrediction:GetPrediction(target, myHero)
            EPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Combo.QHitChance:Value()) and EPrediction:CanHit(self.Menu.Combo.EHitChance:Value()) then
                -- Cast Q puis E simultanément
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
                Control.CastSpell(HK_E, EPrediction.CastPosition)
                return
            end
        end
        
        -- E seul (si Q pas prêt ou pas activé)
        if distance <= 600 and self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            EPrediction:GetPrediction(target, myHero)
            if EPrediction:CanHit(self.Menu.Combo.EHitChance:Value()) then
                Control.CastSpell(HK_E, EPrediction.CastPosition)
                return
            end
        end
        
        -- Q seul (si E pas prêt ou pas activé)
        if distance <= 1000 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Combo.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
                return
            end
        end
        
        -- Auto attack
        if distance <= 175 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
            Control.Attack(target)
        end
    end
end

function L9Naafiri:Harass()
    local target = _G.L9Engine:GetBestTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        -- E - AoE damage
        if distance <= 600 and self.Menu.Harass.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            EPrediction:GetPrediction(target, myHero)
            if EPrediction:CanHit(self.Menu.Harass.EHitChance:Value()) then
                Control.CastSpell(HK_E, EPrediction.CastPosition)
                return
            end
        end
        
        -- Q - Main damage
        if distance <= 1000 and self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Harass.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
                return
            end
        end
        
        -- W - Dash (seulement si activé et pas de packmates)
        if distance <= 1200 and self.Menu.Harass.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            local packmatesCount = GetPackmatesCount()
            if packmatesCount == 0 then
                WPrediction:GetPrediction(target, myHero)
                if WPrediction:CanHit(HITCHANCE_HIGH) then
                    Control.CastSpell(HK_W, WPrediction.CastPosition)
                    return
                end
            end
        end
    end
end

function L9Naafiri:LaneClear()
    if myHero.mana/myHero.maxMana < self.Menu.Clear.Mana:Value() / 100 then
        return
    end
    
    local minions = {}
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and not IsJungleMob(minion) and myHero.pos:DistanceTo(minion.pos) <= 1000 then
            table.insert(minions, minion)
        end
    end
    
    if #minions == 0 then return end
    
    -- E - AoE clear
    if self.Menu.Clear.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
        local bestMinion = nil
        local maxMinions = 0
        
        for _, minion in ipairs(minions) do
            local count = 0
            for _, otherMinion in ipairs(minions) do
                if minion.pos:DistanceTo(otherMinion.pos) <= 300 then
                    count = count + 1
                end
            end
            
            if count > maxMinions then
                maxMinions = count
                bestMinion = minion
            end
        end
        
        if bestMinion and maxMinions >= 2 then
            EPrediction:GetPrediction(bestMinion, myHero)
            if EPrediction:CanHit(HITCHANCE_NORMAL) then
                Control.CastSpell(HK_E, EPrediction.CastPosition)
                return
            end
        end
    end
    
    -- Q - Single target clear
    if self.Menu.Clear.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        for _, minion in ipairs(minions) do
            QPrediction:GetPrediction(minion, myHero)
            if QPrediction:CanHit(HITCHANCE_NORMAL) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
                return
            end
        end
    end
    
    -- W - Dash to minions (si pas de packmates)
    if self.Menu.Clear.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
        local packmatesCount = GetPackmatesCount()
        if packmatesCount == 0 then
            for _, minion in ipairs(minions) do
                WPrediction:GetPrediction(minion, myHero)
                if WPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_W, WPrediction.CastPosition)
                    return
                end
            end
        end
    end
end

function L9Naafiri:JungleClear()
    if myHero.mana/myHero.maxMana < self.Menu.JClear.Mana:Value() / 100 then
        return
    end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and _G.L9Engine:IsValidEnemy(minion) and IsJungleMob(minion) and myHero.pos:DistanceTo(minion.pos) <= 1000 then
            
            -- E - AoE damage
            if self.Menu.JClear.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
                EPrediction:GetPrediction(minion, myHero)
                if EPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                    return
                end
            end
            
            -- Q - Single target damage
            if self.Menu.JClear.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
                QPrediction:GetPrediction(minion, myHero)
                if QPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                    return
                end
            end
            
            -- W - Dash to jungle monsters
            if self.Menu.JClear.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
                local packmatesCount = GetPackmatesCount()
                if packmatesCount == 0 then
                    WPrediction:GetPrediction(minion, myHero)
                    if WPrediction:CanHit(HITCHANCE_NORMAL) then
                        Control.CastSpell(HK_W, WPrediction.CastPosition)
                        return
                    end
                end
            end
        end
    end
end

function L9Naafiri:KillSteal()
    local target = _G.L9Engine:GetBestTarget(1500)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        -- R - Ultimate killsteal
        if self.Menu.ks.UseR:Value() and _G.L9Engine:IsSpellReady(_R) and distance <= 1500 then
            local RDmg = getdmg("R", target, myHero) or 0
            if target.health <= RDmg then
                RPrediction:GetPrediction(target, myHero)
                if RPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_R, RPrediction.CastPosition)
                    return
                end
            end
        end
        
        -- W - Dash killsteal
        if self.Menu.ks.UseW:Value() and _G.L9Engine:IsSpellReady(_W) and distance <= 1200 then
            local WDmg = getdmg("W", target, myHero) or 0
            if target.health <= WDmg then
                WPrediction:GetPrediction(target, myHero)
                if WPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_W, WPrediction.CastPosition)
                    return
                end
            end
        end
        
        -- E - AoE killsteal
        if self.Menu.ks.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and distance <= 600 then
            local EDmg = getdmg("E", target, myHero) or 0
            if target.health <= EDmg then
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                    return
                end
            end
        end
        
        -- Q - Main damage killsteal
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and distance <= 1000 then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                QPrediction:GetPrediction(target, myHero)
                if QPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                    return
                end
            end
        end
    end
end

function L9Naafiri:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    local textPos = myHero.pos:To2D()
    
    -- Draw spell ranges
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        Draw.Circle(myHero.pos, 1000, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:IsSpellReady(_W) then
        Draw.Circle(myHero.pos, 1200, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:IsSpellReady(_E) then
        Draw.Circle(myHero.pos, 600, 1, Draw.Color(255, 0, 0, 255))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:IsSpellReady(_R) then
        Draw.Circle(myHero.pos, 1500, 1, Draw.Color(255, 255, 255, 0))
    end
    
    -- Draw killable targets
    if self.Menu.Drawing.Kill:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and hero.isEnemy and _G.L9Engine:IsValidEnemy(hero) and myHero.pos:DistanceTo(hero.pos) <= 2000 then
                local QDmg = getdmg("Q", hero, myHero) or 0
                local WDmg = getdmg("W", hero, myHero) or 0
                local EDmg = getdmg("E", hero, myHero) or 0
                local RDmg = getdmg("R", hero, myHero) or 0
                local totalDmg = QDmg + WDmg + EDmg + RDmg
                
                if hero.health <= totalDmg then
                    local pos = hero.pos:To2D()
                    Draw.Text("KILLABLE", 20, pos.x - 30, pos.y - 50, Draw.Color(255, 255, 0, 0))
                end
            end
        end
    end
    
    -- Draw packmates count
    if self.Menu.Drawing.Packmates:Value() then
        local packmatesCount = GetPackmatesCount()
        Draw.Text("Packmates: " .. packmatesCount, 15, textPos.x - 80, textPos.y + 60, Draw.Color(255, 255, 255, 255))
    end
end

L9Naafiri()
