if _G.__L9_ENGINE_THRESH_LOADED then return end
_G.__L9_ENGINE_THRESH_LOADED = true

local Version = 1.0
local Name = "L9Thresh"

local Heroes = {"Thresh"}
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
    Delay = 0.5,
    Radius = 70,
    Range = 1075,
    Speed = 1900,
    Collision = true,
    MaxCollision = 0,
    CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL },
})

local EPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = 0.25,
    Radius = 100,
    Range = 400,
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

class "L9Thresh"

function L9Thresh:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Thresh:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Thresh", name = "L9Thresh"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Death Sentence", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Dark Passage", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Flay", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] The Box", value = true})
    self.Menu.Combo:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Death Sentence", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Flay", value = false})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    self.Menu.Harass:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Death Sentence", value = false})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Flay", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Death Sentence", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Flay", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Death Sentence", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Flay", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] The Box", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
end

function L9Thresh:Tick()
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

function L9Thresh:Combo()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if myHero.pos:DistanceTo(target.pos) <= 420 and self.Menu.Combo.UseR:Value() and _G.L9Engine:IsSpellReady(_R) then
            Control.CastSpell(HK_R, target.pos)
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            EPrediction:GetPrediction(target, myHero)
            if EPrediction:CanHit(HITCHANCE_NORMAL) then
                local direction = (myHero.pos - target.pos):Normalized()
                local castPos = myHero.pos + direction * 200
                Control.CastSpell(HK_E, castPos)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 1075 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Combo.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
            end
        end
        
        if self.Menu.Combo.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
        end
    end
end

function L9Thresh:Harass()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        
        if myHero.pos:DistanceTo(target.pos) <= 1075 and self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            QPrediction:GetPrediction(target, myHero)
            if QPrediction:CanHit(self.Menu.Harass.QHitChance:Value()) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.Harass.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            EPrediction:GetPrediction(target, myHero)
            if EPrediction:CanHit(HITCHANCE_NORMAL) then
                local direction = (myHero.pos - target.pos):Normalized()
                local castPos = myHero.pos + direction * 200
                Control.CastSpell(HK_E, castPos)
            end
        end
    end
end

function L9Thresh:LaneClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 400 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and not IsJungleMob(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            
            if myHero.pos:DistanceTo(minion.pos) <= 400 and _G.L9Engine:IsSpellReady(_E) and self.Menu.Clear.UseE:Value() then
                EPrediction:GetPrediction(minion, myHero)
                if EPrediction:CanHit(HITCHANCE_NORMAL) then
                    local direction = (myHero.pos - minion.pos):Normalized()
                    local castPos = myHero.pos + direction * 200
                    Control.CastSpell(HK_E, castPos)
                    break
                end
            end
            
            if myHero.pos:DistanceTo(minion.pos) <= 1075 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.Clear.UseQ:Value() then
                QPrediction:GetPrediction(minion, myHero)
                if QPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                    break
                end
            end
        end
    end
end

function L9Thresh:JungleClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 400 and _G.L9Engine:IsValidEnemy(minion) and IsJungleMob(minion) and myHero.mana/myHero.maxMana >= self.Menu.JClear.Mana:Value() / 100 then
            
            if myHero.pos:DistanceTo(minion.pos) <= 400 and _G.L9Engine:IsSpellReady(_E) and self.Menu.JClear.UseE:Value() then
                EPrediction:GetPrediction(minion, myHero)
                if EPrediction:CanHit(HITCHANCE_NORMAL) then
                    local direction = (myHero.pos - minion.pos):Normalized()
                    local castPos = myHero.pos + direction * 200
                    Control.CastSpell(HK_E, castPos)
                    break
                end
            end
            
            if myHero.pos:DistanceTo(minion.pos) <= 1075 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.JClear.UseQ:Value() then
                QPrediction:GetPrediction(minion, myHero)
                if QPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_Q, QPrediction.CastPosition)
                    break
                end
            end
        end
    end
end

function L9Thresh:KillSteal()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if self.Menu.ks.UseR:Value() and _G.L9Engine:IsSpellReady(_R) and myHero.pos:DistanceTo(target.pos) <= 420 then
            local RDmg = getdmg("R", target, myHero) or 0
            if target.health <= RDmg then
                Control.CastSpell(HK_R, target.pos)
            end
        end
        
        if self.Menu.ks.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= 400 then
            local EDmg = getdmg("E", target, myHero) or 0
            if target.health <= EDmg then
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(HITCHANCE_NORMAL) then
                    local direction = (myHero.pos - target.pos):Normalized()
                    local castPos = myHero.pos + direction * 200
                    Control.CastSpell(HK_E, castPos)
                end
            end
        end
        
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= 1075 then
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

function L9Thresh:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        Draw.Circle(myHero.pos, 1075, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:IsSpellReady(_W) then
        Draw.Circle(myHero.pos, 950, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:IsSpellReady(_E) then
        Draw.Circle(myHero.pos, 400, 1, Draw.Color(255, 0, 0, 255))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:IsSpellReady(_R) then
        Draw.Circle(myHero.pos, 420, 1, Draw.Color(255, 255, 255, 0))
    end
end

L9Thresh()

