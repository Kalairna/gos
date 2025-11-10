-- L9Engine compatibility guard
if _G.__L9_ENGINE_PANTHEON_LOADED then return end
_G.__L9_ENGINE_PANTHEON_LOADED = true

local Version = "1.0.0"
local Name = "L9Pantheon"
local GitHubURL = "https://github.com/Gos-Lua/gos/blob/main/Pantheon.lua"

local Heroes = {"Pantheon"}
if not table.contains(Heroes, myHero.charName) then return end

require("DepressivePrediction")
local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
        print("[L9Pantheon] DepressivePrediction chargé!")
    end
end, 1.0)

local function CheckPredictionSystem()
    if not PredictionLoaded or not _G.DepressivePrediction then
        return false
    end
    
    if not _G.DepressivePrediction.GetPrediction then
        return false
    end
    
    return true
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

-- Pantheon spell ranges and properties
local SPELL_RANGE = {
    Q = 600,  -- Q mélée uniquement (pas de version chargée)
    W = 600,  -- Shield Vault
    E = 400   -- Aegis Assault
}

local SPELL_SPEED = {
    Q = 20,   -- Q mélée instantané
    W = 20,   -- W instantané
    E = 20    -- E instantané
}

local SPELL_DELAY = {
    Q = 0.25,
    W = 0.25,
    E = 0.25
}

local SPELL_RADIUS = {
    Q = 70,
    W = 70,
    E = 100
}

local function GetPrediction(target, spell)
    if not target or not target.valid then return nil, 0 end
    
    if CheckPredictionSystem() then
        local spellData = {
            range = SPELL_RANGE[spell],
            speed = SPELL_SPEED[spell],
            delay = SPELL_DELAY[spell],
            radius = SPELL_RADIUS[spell]
        }
        
        local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
        
        local unitPos, castPos, timeToHit = _G.DepressivePrediction.GetPrediction(
            target,
            sourcePos2D,
            spellData.speed,
            spellData.delay,
            spellData.radius
        )
        
        if castPos and castPos.x and castPos.z then
            local hitChance = 4
            return {x = castPos.x, z = castPos.z}, hitChance
        end
    end
    
    return {x = target.pos.x, z = target.pos.z}, 2
end

-- Fonction pour calculer les dégâts des sorts
local function getdmg(spell, target, source)
    if not target or not source then return 0 end
    
    if spell == "Q" then
        local level = source:GetSpellData(_Q).level
        if level == 0 then return 0 end
        local baseDmg = 65 + (level - 1) * 40
        local adRatio = 1.0
        return baseDmg + (source.totalDamage * adRatio)
    elseif spell == "W" then
        local level = source:GetSpellData(_W).level
        if level == 0 then return 0 end
        local baseDmg = 60 + (level - 1) * 30
        local apRatio = 1.0
        return baseDmg + (source.ap * apRatio)
    elseif spell == "E" then
        local level = source:GetSpellData(_E).level
        if level == 0 then return 0 end
        local baseDmg = 55 + (level - 1) * 25
        local adRatio = 1.5
        return baseDmg + (source.totalDamage * adRatio)
    end
    
    return 0
end

class "L9Pantheon"

function L9Pantheon:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Pantheon:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Pantheon", name = "L9Pantheon"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Comet Spear (Mélée)", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Shield Vault", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Aegis Assault", value = true})
    self.Menu.Combo:MenuElement({id = "WPriority", name = "Priorité W - Engager toujours avec W", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Comet Spear (Mélée)", value = true})
    self.Menu.Harass:MenuElement({id = "UseW", name = "[W] Shield Vault", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Aegis Assault", value = false})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Comet Spear (Mélée)", value = true})
    self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Shield Vault", value = true})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Aegis Assault", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Comet Spear (Mélée)", value = true})
    self.Menu.JClear:MenuElement({id = "UseW", name = "[W] Shield Vault", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Aegis Assault", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
    self.Menu.LastHit:MenuElement({id = "UseQ", name = "[Q] Comet Spear (Mélée)", value = true})
    self.Menu.LastHit:MenuElement({id = "Mana", name = "Min Mana to LastHit", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Comet Spear (Mélée)", value = true})
    self.Menu.ks:MenuElement({id = "UseW", name = "[W] Shield Vault", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Aegis Assault", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "Kill", name = "Draw Killable Targets", value = true})
end

function L9Pantheon:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    local Mode = _G.L9Engine:GetMode()
    
    if Mode == "Combo" then
        self:Combo()
    elseif Mode == "Harass" then
        self:Harass()
    elseif Mode == "Clear" then
        self:LaneClear()
        self:JungleClear()
    elseif Mode == "LastHit" then
        self:LastHit()
    end
    
    self:KillSteal()
end

function L9Pantheon:Combo()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        -- PRIORITÉ W - Engager toujours avec W si disponible
        if self.Menu.Combo.WPriority:Value() and distance <= SPELL_RANGE.W and self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
            Control.CastSpell(HK_W, target)
            return
        end
        
        -- W normal (si priorité désactivée)
        if distance <= SPELL_RANGE.W and self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
            Control.CastSpell(HK_W, target)
        end
        
        -- E après W ou si W pas disponible
        if distance <= SPELL_RANGE.E and self.Menu.Combo.UseE:Value() and _G.L9Engine:Ready(_E) then
            Control.CastSpell(HK_E, target)
        end
        
        -- Q mélée uniquement
        if distance <= SPELL_RANGE.Q and self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
            Control.CastSpell(HK_Q, target)
        end
        
        -- Auto Attack
        if distance <= 175 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
            Control.Attack(target)
        end
    end
end

function L9Pantheon:Harass()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        -- PRIORITÉ W - Engager toujours avec W si disponible
        if self.Menu.Combo.WPriority:Value() and distance <= SPELL_RANGE.W and self.Menu.Harass.UseW:Value() and _G.L9Engine:Ready(_W) then
            Control.CastSpell(HK_W, target)
            return
        end
        
        -- W normal
        if distance <= SPELL_RANGE.W and self.Menu.Harass.UseW:Value() and _G.L9Engine:Ready(_W) then
            Control.CastSpell(HK_W, target)
        end
        
        -- E
        if distance <= SPELL_RANGE.E and self.Menu.Harass.UseE:Value() and _G.L9Engine:Ready(_E) then
            Control.CastSpell(HK_E, target)
        end
        
        -- Q mélée uniquement
        if distance <= SPELL_RANGE.Q and self.Menu.Harass.UseQ:Value() and _G.L9Engine:Ready(_Q) then
            Control.CastSpell(HK_Q, target)
        end
    end
end

function L9Pantheon:LaneClear()
    if myHero.mana/myHero.maxMana < self.Menu.Clear.Mana:Value() / 100 then
        return
    end
    
    if not (_G.SDK and _G.SDK.Orbwalker:CanAttack()) then
        return
    end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team == TEAM_ENEMY and _G.L9Engine:IsValidTarget(minion) and not IsJungleMob(minion) then
            local distance = myHero.pos:DistanceTo(minion.pos)
            
            -- PRIORITÉ W - Engager toujours avec W si disponible
            if self.Menu.Combo.WPriority:Value() and distance <= SPELL_RANGE.W and self.Menu.Clear.UseW:Value() and _G.L9Engine:Ready(_W) then
                Control.CastSpell(HK_W, minion)
                return
            end
            
            -- W normal
            if distance <= SPELL_RANGE.W and self.Menu.Clear.UseW:Value() and _G.L9Engine:Ready(_W) then
                Control.CastSpell(HK_W, minion)
                return
            end
            
            -- E
            if distance <= SPELL_RANGE.E and self.Menu.Clear.UseE:Value() and _G.L9Engine:Ready(_E) then
                Control.CastSpell(HK_E, minion)
                return
            end
            
            -- Q mélée uniquement
            if distance <= SPELL_RANGE.Q and self.Menu.Clear.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                Control.CastSpell(HK_Q, minion)
                return
            end
        end
    end
end

function L9Pantheon:JungleClear()
    if myHero.mana/myHero.maxMana < self.Menu.JClear.Mana:Value() / 100 then
        return
    end
    
    if not (_G.SDK and _G.SDK.Orbwalker:CanAttack()) then
        return
    end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        -- Détecter les monstres de jungle par leur nom
        if _G.L9Engine:IsValidTarget(minion) and IsJungleMob(minion) then
            local distance = myHero.pos:DistanceTo(minion.pos)
            
            -- PRIORITÉ W - Engager toujours avec W si disponible
            if self.Menu.Combo.WPriority:Value() and distance <= SPELL_RANGE.W and self.Menu.JClear.UseW:Value() and _G.L9Engine:Ready(_W) then
                Control.CastSpell(HK_W, minion)
                return
            end
            
            -- W normal
            if distance <= SPELL_RANGE.W and self.Menu.JClear.UseW:Value() and _G.L9Engine:Ready(_W) then
                Control.CastSpell(HK_W, minion)
                return
            end
            
            -- E
            if distance <= SPELL_RANGE.E and self.Menu.JClear.UseE:Value() and _G.L9Engine:Ready(_E) then
                Control.CastSpell(HK_E, minion)
                return
            end
            
            -- Q mélée uniquement
            if distance <= SPELL_RANGE.Q and self.Menu.JClear.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                Control.CastSpell(HK_Q, minion)
                return
            end
        end
    end
end

function L9Pantheon:LastHit()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= SPELL_RANGE.Q and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.LastHit.Mana:Value() / 100 then
            
            if myHero.pos:DistanceTo(minion.pos) <= SPELL_RANGE.Q and _G.L9Engine:Ready(_Q) and self.Menu.LastHit.UseQ:Value() then
                local QDmg = getdmg("Q", minion, myHero) or 0
                if minion.health <= QDmg then
                    Control.CastSpell(HK_Q, minion)
                    break
                end
            end
        end
    end
end

function L9Pantheon:KillSteal()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) then
        
        -- W KillSteal
        if self.Menu.ks.UseW:Value() and _G.L9Engine:Ready(_W) and myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.W then
            local WDmg = getdmg("W", target, myHero) or 0
            if target.health <= WDmg then
                Control.CastSpell(HK_W, target)
            end
        end
        
        -- E KillSteal
        if self.Menu.ks.UseE:Value() and _G.L9Engine:Ready(_E) and myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.E then
            local EDmg = getdmg("E", target, myHero) or 0
            if target.health <= EDmg then
                Control.CastSpell(HK_E, target)
            end
        end
        
        -- Q KillSteal
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:Ready(_Q) and myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.Q then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                Control.CastSpell(HK_Q, target)
            end
        end
    end
end

function L9Pantheon:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    local textPos = myHero.pos:To2D()
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:Ready(_Q) then
        Draw.Circle(myHero.pos, SPELL_RANGE.Q, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:Ready(_W) then
        Draw.Circle(myHero.pos, SPELL_RANGE.W, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:Ready(_E) then
        Draw.Circle(myHero.pos, SPELL_RANGE.E, 1, Draw.Color(255, 0, 0, 255))
    end
    
    if self.Menu.Drawing.Kill:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero.isEnemy and _G.L9Engine:IsValidTarget(hero) and myHero.pos:DistanceTo(hero.pos) <= 2000 then
                local QDmg = getdmg("Q", hero, myHero) or 0
                local WDmg = getdmg("W", hero, myHero) or 0
                local EDmg = getdmg("E", hero, myHero) or 0
                local totalDmg = QDmg + WDmg + EDmg
                
                if hero.health <= totalDmg then
                    local pos = hero.pos:To2D()
                    Draw.Text("TUABLE", 20, pos.x - 30, pos.y - 50, Draw.Color(255, 255, 0, 0))
                end
            end
        end
    end
    
    Draw.Text("Pantheon - L9 Script", 15, textPos.x - 80, textPos.y + 40, Draw.Color(255, 255, 255, 255))
end

L9Pantheon()



