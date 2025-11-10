if _G.__L9_ENGINE_KENNEN_LOADED then return end
_G.__L9_ENGINE_KENNEN_LOADED = true

local Version = 1.0
local Name = "L9Kennen"

local Heroes = {"Kennen"}
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
    Delay = 0.18,
    Radius = 50,
    Range = 1050,
    Speed = 1700,
    Collision = true,
    MaxCollision = 0,
    CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL },
})

local WPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_CIRCULAR,
    Delay = 0.25,
    Radius = 900,
    Range = 900,
    Speed = math.huge,
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

class "L9Kennen"

function L9Kennen:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Kennen:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Kennen", name = "L9Kennen"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Thundering Shuriken", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Electrical Surge", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Slicing Maelstrom", value = true})
    self.Menu.Combo:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RTargets", name = "R if X enemies (550)", value = 2, min = 1, max = 5})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Thundering Shuriken", value = true})
    self.Menu.Harass:MenuElement({id = "UseW", name = "[W] Electrical Surge", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    self.Menu.Harass:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Thundering Shuriken", value = true})
    self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Electrical Surge", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Thundering Shuriken", value = true})
    self.Menu.JClear:MenuElement({id = "UseW", name = "[W] Electrical Surge", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Thundering Shuriken", value = true})
    self.Menu.ks:MenuElement({id = "UseW", name = "[W] Electrical Surge", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] Slicing Maelstrom", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
end

function L9Kennen:Tick()
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

function L9Kennen:Combo()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        -- R multi-target logic
        if myHero.pos:DistanceTo(target.pos) <= 550 and self.Menu.Combo.UseR:Value() and _G.L9Engine:IsSpellReady(_R) then
            local count = 0
            for i = 1, Game.HeroCount() do
                local enemy = Game.Hero(i)
                if enemy and enemy.team ~= myHero.team and _G.L9Engine:IsValidEnemy(enemy) and myHero.pos:DistanceTo(enemy.pos) <= 550 then
                    count = count + 1
                end
            end
            if count >= self.Menu.Combo.RTargets:Value() then
                Control.CastSpell(HK_R)
            end
        end
        
        -- W usage (Electrical Surge) - reset AA
        if myHero.pos:DistanceTo(target.pos) <= 900 and self.Menu.Combo.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            WPrediction:GetPrediction(target, myHero)
            if WPrediction:CanHit(HITCHANCE_NORMAL) then
                Control.CastSpell(HK_W)
            end
        end
        
        -- Q usage (Thundering Shuriken) - reset AA
        if myHero.pos:DistanceTo(target.pos) <= 1050 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Combo.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
            end
        end
    end
end

function L9Kennen:Harass()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        
        if myHero.pos:DistanceTo(target.pos) <= 1050 and self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Harass.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 900 and self.Menu.Harass.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            WPrediction:GetPrediction(target, myHero)
            if WPrediction:CanHit(HITCHANCE_NORMAL) then
                Control.CastSpell(HK_W)
            end
        end
    end
end

function L9Kennen:LaneClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 1050 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and not IsJungleMob(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            
            if myHero.pos:DistanceTo(minion.pos) <= 900 and _G.L9Engine:IsSpellReady(_W) and self.Menu.Clear.UseW:Value() then
                WPrediction:GetPrediction(minion, myHero)
                if WPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_W)
                    break
                end
            end
            
            if myHero.pos:DistanceTo(minion.pos) <= 1050 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.Clear.UseQ:Value() then
                QPrediction:GetPrediction(minion, myHero)
                if QPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                    break
                end
            end
        end
    end
end

function L9Kennen:JungleClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 1050 and _G.L9Engine:IsValidEnemy(minion) and IsJungleMob(minion) and myHero.mana/myHero.maxMana >= self.Menu.JClear.Mana:Value() / 100 then
            
            if myHero.pos:DistanceTo(minion.pos) <= 900 and _G.L9Engine:IsSpellReady(_W) and self.Menu.JClear.UseW:Value() then
                WPrediction:GetPrediction(minion, myHero)
                if WPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_W)
                    break
                end
            end
            
            if myHero.pos:DistanceTo(minion.pos) <= 1050 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.JClear.UseQ:Value() then
                QPrediction:GetPrediction(minion, myHero)
                if QPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                    break
                end
            end
        end
    end
end

function L9Kennen:KillSteal()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if self.Menu.ks.UseR:Value() and _G.L9Engine:IsSpellReady(_R) and myHero.pos:DistanceTo(target.pos) <= 550 then
            local RDmg = getdmg("R", target, myHero) or 0
            if target.health <= RDmg then
                Control.CastSpell(HK_R)
            end
        end
        
        if self.Menu.ks.UseW:Value() and _G.L9Engine:IsSpellReady(_W) and myHero.pos:DistanceTo(target.pos) <= 900 then
            local WDmg = getdmg("W", target, myHero) or 0
            if target.health <= WDmg then
                WPrediction:GetPrediction(target, myHero)
                if WPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_W)
                end
            end
        end
        
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= 1050 then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                QPrediction:GetPrediction(target, myHero)
                if QPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                end
            end
        end
    end
end

function L9Kennen:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        Draw.Circle(myHero.pos, 1050, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:IsSpellReady(_W) then
        Draw.Circle(myHero.pos, 900, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:IsSpellReady(_R) then
        Draw.Circle(myHero.pos, 550, 1, Draw.Color(255, 255, 255, 0))
    end
end

L9Kennen()






