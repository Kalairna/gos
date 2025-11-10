-- L9Engine compatibility guard
if _G.__L9_ENGINE_TALON_LOADED then return end
_G.__L9_ENGINE_TALON_LOADED = true

local Version = "1.0.0"
local Name = "L9Talon"

local Heroes = {"Talon"}
if not table.contains(Heroes, myHero.charName) then return end

require("DepressivePrediction")
local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
        print("[L9Talon] DepressivePrediction chargé!")
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

-- Talon spell ranges and properties
local SPELL_RANGE = {
    Q = 575,  -- Q dash range (melee reset AA range ~200)
    W = 650,  -- Rake
    R = 550   -- Shadow Assault
}

local SPELL_SPEED = {
    W = 2300, -- Rake projectile speed
    R = 20    -- R instantané
}

local SPELL_DELAY = {
    W = 0.25,
    R = 0.25
}

local SPELL_RADIUS = {
    W = 80,
    R = 550
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
        local baseDmg = 50 + (level - 1) * 15
        local adRatio = 1.0
        return baseDmg + (source.totalDamage * adRatio)
    elseif spell == "W" then
        local level = source:GetSpellData(_W).level
        if level == 0 then return 0 end
        local baseDmg = 50 + (level - 1) * 25
        local adRatio = 0.6
        return (baseDmg + (source.totalDamage * adRatio)) * 2  -- W hits twice (going and returning)
    elseif spell == "R" then
        local level = source:GetSpellData(_R).level
        if level == 0 then return 0 end
        local baseDmg = 90 + (level - 1) * 45
        local adRatio = 0.9
        return (baseDmg + (source.totalDamage * adRatio)) * 2  -- R hits twice
    end
    
    return 0
end

-- Fonction pour vérifier si la cible est à portée de mélée
local function IsInMeleeRange(target)
    if not target then return false end
    local distance = myHero.pos:DistanceTo(target.pos)
    return distance <= 200
end

class "L9Talon"

function L9Talon:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Talon:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Talon", name = "L9Talon"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Noxian Diplomacy", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Rake", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Shadow Assault", value = true})
    self.Menu.Combo:MenuElement({id = "BurstLogic", name = "Logique Burst: W->AA->Q->AA (melee) / W->Q (range)", value = true})
    self.Menu.Combo:MenuElement({id = "RHealth", name = "Utiliser R si vie cible < %", value = 50, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Noxian Diplomacy", value = true})
    self.Menu.Harass:MenuElement({id = "UseW", name = "[W] Rake", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Noxian Diplomacy", value = true})
    self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Rake", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Noxian Diplomacy", value = true})
    self.Menu.JClear:MenuElement({id = "UseW", name = "[W] Rake", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
    self.Menu.LastHit:MenuElement({id = "UseQ", name = "[Q] Noxian Diplomacy", value = true})
    self.Menu.LastHit:MenuElement({id = "Mana", name = "Min Mana to LastHit", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Noxian Diplomacy", value = true})
    self.Menu.ks:MenuElement({id = "UseW", name = "[W] Rake", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] Shadow Assault", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = true})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = true})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "Kill", name = "Draw Killable Targets", value = true})
end

function L9Talon:Tick()
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

function L9Talon:Combo()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) then
        local distance = myHero.pos:DistanceTo(target.pos)
        local isMelee = IsInMeleeRange(target)
        
        -- Logique de burst
        if self.Menu.Combo.BurstLogic:Value() then
            
            -- PRIORITÉ 1: W en premier (pour faire tomber le passif rapidement)
            if distance <= SPELL_RANGE.W and self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
                local prediction = GetPrediction(target, "W")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    Control.CastSpell(HK_W, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                else
                    Control.CastSpell(HK_W, target.pos)
                end
                return
            end
            
            -- PRIORITÉ 2: Logique corps à corps vs distance
            if isMelee then
                -- Corps à corps : W -> AA -> Q -> AA
                if self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                    Control.CastSpell(HK_Q)
                    return
                end
                
                if _G.SDK and _G.SDK.Orbwalker:CanAttack() then
                    Control.Attack(target)
                end
                
            else
                -- À distance : W -> Q (dash pour closer)
                if distance <= SPELL_RANGE.Q and self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                    Control.CastSpell(HK_Q, target)
                    return
                end
            end
            
            -- PRIORITÉ 3: R pour finir ou si vie basse
            if distance <= SPELL_RANGE.R and self.Menu.Combo.UseR:Value() and _G.L9Engine:Ready(_R) then
                local healthPct = (target.health / target.maxHealth) * 100
                if healthPct <= self.Menu.Combo.RHealth:Value() then
                    Control.CastSpell(HK_R)
                    return
                end
            end
            
        else
            -- Mode standard (pas de logique burst)
            if distance <= SPELL_RANGE.W and self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
                local prediction = GetPrediction(target, "W")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    Control.CastSpell(HK_W, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                else
                    Control.CastSpell(HK_W, target.pos)
                end
            end
            
            if distance <= SPELL_RANGE.Q and self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                if isMelee then
                    Control.CastSpell(HK_Q)
                else
                    Control.CastSpell(HK_Q, target)
                end
            end
            
            if distance <= SPELL_RANGE.R and self.Menu.Combo.UseR:Value() and _G.L9Engine:Ready(_R) then
                local healthPct = (target.health / target.maxHealth) * 100
                if healthPct <= self.Menu.Combo.RHealth:Value() then
                    Control.CastSpell(HK_R)
                end
            end
            
            if isMelee and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
                Control.Attack(target)
            end
        end
    end
end

function L9Talon:Harass()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        local distance = myHero.pos:DistanceTo(target.pos)
        local isMelee = IsInMeleeRange(target)
        
        -- W pour harass
        if distance <= SPELL_RANGE.W and self.Menu.Harass.UseW:Value() and _G.L9Engine:Ready(_W) then
            local prediction = GetPrediction(target, "W")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_W, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_W, target.pos)
            end
        end
        
        -- Q seulement en mélée pour harass
        if isMelee and self.Menu.Harass.UseQ:Value() and _G.L9Engine:Ready(_Q) then
            Control.CastSpell(HK_Q)
        end
    end
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

-- Helper function to get jungle monster priority (higher = more important)
local function GetJunglePriority(minion)
    if not minion or not minion.charName then return 0 end
    local name = minion.charName:lower()
    
    -- Baron et Dragon = priorité max
    if name:find("baron") or name:find("dragon") or name:find("herald") or name:find("rift") then
        return 10
    end
    
    -- Gros monstres des camps (détecté par le nom)
    if name:find("sru_murkwolf") and not name:find("mini") then return 5 end  -- Gros loup
    if name:find("sru_razorbeak") and not name:find("mini") then return 5 end  -- Gros raptor
    if name:find("sru_krug") and not name:find("mini") then return 5 end       -- Gros golem
    if name:find("sru_gromp") then return 5 end                                -- Gromp
    if name:find("sru_blue") then return 5 end                                 -- Buff bleu
    if name:find("sru_red") then return 5 end                                  -- Buff rouge
    if name:find("sru_crab") then return 4 end                                 -- Crab
    
    -- Petits monstres
    return 1
end

function L9Talon:LaneClear()
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
            local isMelee = IsInMeleeRange(minion)
            
            -- W pour clear (hit multiple minions)
            if distance <= SPELL_RANGE.W and self.Menu.Clear.UseW:Value() and _G.L9Engine:Ready(_W) then
                Control.CastSpell(HK_W, Vector(minion.pos.x, myHero.pos.y, minion.pos.z))
                return
            end
            
            -- Q pour last hit
            if isMelee and self.Menu.Clear.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                Control.CastSpell(HK_Q)
                return
            end
        end
    end
end

function L9Talon:JungleClear()
    if myHero.mana/myHero.maxMana < self.Menu.JClear.Mana:Value() / 100 then
        return
    end
    
    -- Trouver le meilleur monstre à cibler (priorité + distance)
    local bestMonster = nil
    local bestPriority = -1
    local bestDistance = 9999
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if _G.L9Engine:IsValidTarget(minion) and IsJungleMob(minion) then
            local distance = myHero.pos:DistanceTo(minion.pos)
            local priority = GetJunglePriority(minion)
            
            -- Sélectionner le monstre avec la meilleure priorité, ou le plus proche si même priorité
            if distance <= SPELL_RANGE.Q then
                if priority > bestPriority or (priority == bestPriority and distance < bestDistance) then
                    bestMonster = minion
                    bestPriority = priority
                    bestDistance = distance
                end
            end
        end
    end
    
    -- Lancer les sorts sur le meilleur monstre trouvé
    if bestMonster then
        local distance = myHero.pos:DistanceTo(bestMonster.pos)
        local isMelee = IsInMeleeRange(bestMonster)
        
        -- Q pour jungle clear (priorise les gros monstres)
        if distance <= SPELL_RANGE.Q and self.Menu.JClear.UseQ:Value() and _G.L9Engine:Ready(_Q) then
            Control.CastSpell(HK_Q, bestMonster)
            return
        end
        
        -- W pour jungle clear
        if distance <= SPELL_RANGE.W and self.Menu.JClear.UseW:Value() and _G.L9Engine:Ready(_W) then
            Control.CastSpell(HK_W, Vector(bestMonster.pos.x, myHero.pos.y, bestMonster.pos.z))
            return
        end
    end
end

function L9Talon:LastHit()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if minion.team == TEAM_ENEMY and _G.L9Engine:IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.LastHit.Mana:Value() / 100 then
            local distance = myHero.pos:DistanceTo(minion.pos)
            
            if IsInMeleeRange(minion) and _G.L9Engine:Ready(_Q) and self.Menu.LastHit.UseQ:Value() then
                local QDmg = getdmg("Q", minion, myHero) or 0
                if minion.health <= QDmg then
                    Control.CastSpell(HK_Q)
                    break
                end
            end
        end
    end
end

function L9Talon:KillSteal()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) then
        local distance = myHero.pos:DistanceTo(target.pos)
        
        -- R KillSteal
        if self.Menu.ks.UseR:Value() and _G.L9Engine:Ready(_R) and distance <= SPELL_RANGE.R then
            local RDmg = getdmg("R", target, myHero) or 0
            if target.health <= RDmg then
                Control.CastSpell(HK_R)
            end
        end
        
        -- W KillSteal
        if self.Menu.ks.UseW:Value() and _G.L9Engine:Ready(_W) and distance <= SPELL_RANGE.W then
            local WDmg = getdmg("W", target, myHero) or 0
            if target.health <= WDmg then
                local prediction = GetPrediction(target, "W")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_W, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                else
                    Control.CastSpell(HK_W, target.pos)
                end
            end
        end
        
        -- Q KillSteal
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:Ready(_Q) and distance <= SPELL_RANGE.Q then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                if IsInMeleeRange(target) then
                    Control.CastSpell(HK_Q)
                else
                    Control.CastSpell(HK_Q, target)
                end
            end
        end
    end
end

function L9Talon:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:Ready(_Q) then
        Draw.Circle(myHero.pos, SPELL_RANGE.Q, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:Ready(_W) then
        Draw.Circle(myHero.pos, SPELL_RANGE.W, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:Ready(_R) then
        Draw.Circle(myHero.pos, SPELL_RANGE.R, 1, Draw.Color(255, 255, 255, 0))
    end
    
    if self.Menu.Drawing.Kill:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero.isEnemy and _G.L9Engine:IsValidTarget(hero) and myHero.pos:DistanceTo(hero.pos) <= 2000 then
                local QDmg = getdmg("Q", hero, myHero) or 0
                local WDmg = getdmg("W", hero, myHero) or 0
                local RDmg = getdmg("R", hero, myHero) or 0
                local totalDmg = QDmg + WDmg + RDmg
                
                if hero.health <= totalDmg then
                    local pos = hero.pos:To2D()
                    Draw.Text("KILLABLE", 20, pos.x - 35, pos.y - 50, Draw.Color(255, 255, 0, 0))
                end
            end
        end
    end
end

L9Talon()

