if _G.__L9_ENGINE_AURORA_LOADED then return end
_G.__L9_ENGINE_AURORA_LOADED = true

local Version = 1.0
local Name = "L9Aurora"

local Heroes = {"Aurora"}
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
    Radius = 80,
    Range = 900,
    Speed = 1800,
    Collision = true,
    MaxCollision = 0,
    CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL },
})

local WPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_CIRCULAR,
    Delay = 0.25,
    Radius = 70,
    Range = 450,
    Speed = math.huge,
    Collision = false,
})

local EPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = 0.25,
    Radius = 100,
    Range = 825,
    Speed = 1600,
    Collision = true,
    MaxCollision = 0,
    CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL },
})

local RPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_CIRCULAR,
    Delay = 0.5,
    Radius = 200,
    Range = 700,
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

class "L9Aurora"

function L9Aurora:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Aurora:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Aurora", name = "L9Aurora"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "AutoW", name = "AutoW"})
    self.Menu.AutoW:MenuElement({id = "UseW", name = "Safe Life", value = true})
    self.Menu.AutoW:MenuElement({id = "hp", name = "Self Hp", value = 40, min = 1, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Aurora Beam", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Aurora Shield", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Aurora Burst", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Aurora Storm", value = true})
    self.Menu.Combo:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RHitChance", name = "R Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Aurora Beam", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Aurora Burst", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    self.Menu.Harass:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    self.Menu.Harass:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Aurora Beam", value = true})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Aurora Burst", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Aurora Beam", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Aurora Burst", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Aurora Beam", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Aurora Burst", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] Aurora Storm", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "Kill", name = "Draw Killable Targets", value = true})
end

function L9Aurora:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    local Mode = _G.L9Engine:GetCurrentMode()
    
    if Mode == "Combo" then
        self:Combo()
    elseif Mode == "Harass" then
        self:Harass()
    elseif Mode == "Clear" then
        self:Clear()
        self:JungleClear()
    elseif Mode == "LastHit" then
    end
    
    self:KillSteal()
    self:AutoW()
end

function L9Aurora:Combo()
    local target = _G.L9Engine:GetBestTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if myHero.pos:DistanceTo(target.pos) <= 700 and self.Menu.Combo.UseR:Value() and _G.L9Engine:IsSpellReady(_R) then
            RPrediction:GetPrediction(target, myHero)
            if RPrediction:CanHit(self.Menu.Combo.RHitChance:Value()) then
                Control.CastSpell(HK_R, RPrediction.CastPosition)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 900 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Combo.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 825 and self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            EPrediction:GetPrediction(target, myHero)
            if EPrediction:CanHit(self.Menu.Combo.EHitChance:Value()) then
                Control.CastSpell(HK_E, EPrediction.CastPosition)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 450 and self.Menu.Combo.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            WPrediction:GetPrediction(target, myHero)
            if WPrediction:CanHit(HITCHANCE_NORMAL) then
                Control.CastSpell(HK_W, WPrediction.CastPosition)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 175 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
            Control.Attack(target)
        end
    end
end

function L9Aurora:Harass()
    local target = _G.L9Engine:GetBestTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        if myHero.pos:DistanceTo(target.pos) <= 900 and self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Harass.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 825 and self.Menu.Harass.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            EPrediction:GetPrediction(target, myHero)
            if EPrediction:CanHit(self.Menu.Harass.EHitChance:Value()) then
                Control.CastSpell(HK_E, EPrediction.CastPosition)
            end
        end
    end
end

function L9Aurora:Clear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 900 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and not IsJungleMob(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            if myHero.pos:DistanceTo(minion.pos) <= 900 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.Clear.UseQ:Value() then
                QPrediction:GetPrediction(minion, myHero)
                if QPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                    break
                end
            end
            
            if myHero.pos:DistanceTo(minion.pos) <= 825 and _G.L9Engine:IsSpellReady(_E) and self.Menu.Clear.UseE:Value() then
                EPrediction:GetPrediction(minion, myHero)
                if EPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                    break
                end
            end
        end
    end
end

function L9Aurora:JungleClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 900 and _G.L9Engine:IsValidEnemy(minion) and IsJungleMob(minion) and myHero.mana/myHero.maxMana >= self.Menu.JClear.Mana:Value() / 100 then
            if myHero.pos:DistanceTo(minion.pos) <= 900 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.JClear.UseQ:Value() then
                QPrediction:GetPrediction(minion, myHero)
                if QPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                    break
                end
            end
            
            if myHero.pos:DistanceTo(minion.pos) <= 825 and _G.L9Engine:IsSpellReady(_E) and self.Menu.JClear.UseE:Value() then
                EPrediction:GetPrediction(minion, myHero)
                if EPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                    break
                end
            end
        end
    end
end

function L9Aurora:KillSteal()
    local target = _G.L9Engine:GetBestTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if self.Menu.ks.UseR:Value() and _G.L9Engine:IsSpellReady(_R) and myHero.pos:DistanceTo(target.pos) <= 700 then
            local RDmg = getdmg("R", target, myHero) or 0
            if target.health <= RDmg then
                RPrediction:GetPrediction(target, myHero)
                if RPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_R, RPrediction.CastPosition)
                end
            end
        end
        
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= 900 then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                QPrediction:GetPrediction(target, myHero)
                if QPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                end
            end
        end
        
        if self.Menu.ks.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= 825 then
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

function L9Aurora:AutoW()
    local target = _G.L9Engine:GetBestTarget(450)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.pos:DistanceTo(target.pos) <= 450 and self.Menu.AutoW.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
        if myHero.health/myHero.maxHealth <= self.Menu.AutoW.hp:Value()/100 then
            WPrediction:GetPrediction(target, myHero)
            if WPrediction:CanHit(HITCHANCE_NORMAL) then
                Control.CastSpell(HK_W, WPrediction.CastPosition)
            end
        end
    end
end

function L9Aurora:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    local textPos = myHero.pos:To2D()
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        Draw.Circle(myHero.pos, 900, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:IsSpellReady(_W) then
        Draw.Circle(myHero.pos, 450, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:IsSpellReady(_E) then
        Draw.Circle(myHero.pos, 825, 1, Draw.Color(255, 0, 0, 255))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:IsSpellReady(_R) then
        Draw.Circle(myHero.pos, 700, 1, Draw.Color(255, 255, 255, 0))
    end
    
    if self.Menu.Drawing.Kill:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero.isEnemy and _G.L9Engine:IsValidEnemy(hero) and myHero.pos:DistanceTo(hero.pos) <= 2000 then
                local QDmg = getdmg("Q", hero, myHero) or 0
                local EDmg = getdmg("E", hero, myHero) or 0
                local RDmg = getdmg("R", hero, myHero) or 0
                local totalDmg = QDmg + EDmg + RDmg
                
                if hero.health <= totalDmg then
                    local pos = hero.pos:To2D()
                    Draw.Text("TUABLE", 20, pos.x - 30, pos.y - 50, Draw.Color(255, 255, 0, 0))
                end
            end
        end
    end
    
    Draw.Text("Aurora - L9 Script", 15, textPos.x - 80, textPos.y + 40, Draw.Color(255, 255, 255, 255))
end

L9Aurora()

