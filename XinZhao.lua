if _G.__L9_ENGINE_XINZHAO_LOADED then return end
_G.__L9_ENGINE_XINZHAO_LOADED = true

local Version = "1.0.0"
local Name = "L9Xin"
local GitHubURL = "https://github.com/Gos-Lua/gos/blob/main/XinZhao.lua"

local Heroes = {"XinZhao"}
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

local WLastCastTime = 0
local WTarget = nil
local WDuration = 3.0

local function IsWActiveOnTarget(target)
    if not target or not WTarget then return false end
    
    if target.networkID == WTarget.networkID then
        local timeSinceW = Game.Timer() - WLastCastTime
        return timeSinceW < WDuration
    end
    
    return false
end

local function GetERange(target)
    if target and IsWActiveOnTarget(target) then
        return 900
    end
    return 650
end

local function IsTargetBumped(target)
    local buffNames = {"XinZhaoQKnockup", "XinZhaoQ", "ThreeTalonStrike", "threetalonstrike", "knockup", "airborne"}
    for _, buffName in ipairs(buffNames) do
        local buff = _G.L9Engine:GetUnitBuff(target, buffName)
        if buff then
            return true
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

local function GetQHits()
    local buffNames = {"XinZhaoQ", "ThreeTalonStrike", "threetalonstrike"}
    for _, buffName in ipairs(buffNames) do
        local buff = _G.L9Engine:GetUnitBuff(myHero, buffName)
        if buff then
            return buff.count or 0
        end
    end
    return 0
end

-- Spell Predictions
local WPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = 0.25,
    Radius = 100,
    Range = 900,
    Speed = 2000,
    Collision = true,
    MaxCollision = 0,
    CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL },
})

local EPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = 0.25,
    Radius = 50,
    Range = 650,
    Speed = 2000,
    Collision = false,
})

local RPrediction = GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_CIRCULAR,
    Delay = 0.25,
    Radius = 500,
    Range = 500,
    Speed = 2000,
    Collision = false,
})

local HITCHANCE_NORMAL = 2
local HITCHANCE_HIGH = 3
local HITCHANCE_IMMOBILE = 4

class "L9Xin"

function L9Xin:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Xin:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Xin", name = "L9Xin"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Battle Cry", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Audacious Charge", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Crescent Guard", value = true})
    self.Menu.Combo:MenuElement({id = "ComboLogic", name = "Combo Logic: W->E->Q->W", value = true})
    self.Menu.Combo:MenuElement({id = "WHitChance", name = "W Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RHitChance", name = "R Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.Harass:MenuElement({id = "UseW", name = "[W] Battle Cry", value = false})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Audacious Charge", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    self.Menu.Harass:MenuElement({id = "WHitChance", name = "W Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    self.Menu.Harass:MenuElement({id = "EHitChance", name = "E Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Battle Cry", value = true})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Audacious Charge", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.JClear:MenuElement({id = "UseW", name = "[W] Battle Cry", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Audacious Charge", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
    self.Menu.LastHit:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.LastHit:MenuElement({id = "Mana", name = "Min Mana to LastHit", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.ks:MenuElement({id = "UseW", name = "[W] Battle Cry", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Audacious Charge", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] Crescent Guard", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawWActive", name = "Draw Extended E Range when W active", value = true})
end

function L9Xin:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    self:AutoAttackReset()
    
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

function L9Xin:AutoAttackReset()
    if _G.SDK and _G.SDK.Orbwalker:CanAttack() then
        local target = _G.L9Engine:GetTarget(175)
        if target and _G.L9Engine:IsValidTarget(target, 175) then
            if self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                Control.CastSpell(HK_Q)
            end
        end
    end
end

function L9Xin:Combo()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) then
        local eRange = GetERange(target)
        local distance = myHero.pos:DistanceTo(target.pos)
        
        if self.Menu.Combo.ComboLogic:Value() then
            if distance > 650 and not IsWActiveOnTarget(target) and self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
                WPrediction:GetPrediction(target, myHero)
                if WPrediction:CanHit(self.Menu.Combo.WHitChance:Value()) then
                    Control.CastSpell(HK_W, WPrediction.CastPosition)
                    WLastCastTime = Game.Timer()
                    WTarget = target
                end
                return
            end
            
            if distance <= eRange and self.Menu.Combo.UseE:Value() and _G.L9Engine:Ready(_E) then
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(self.Menu.Combo.EHitChance:Value()) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                end
                return
            end
            
            if distance <= 175 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                Control.CastSpell(HK_Q)
                return
            end
            
            if distance <= 175 and IsTargetBumped(target) and self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
                WPrediction:GetPrediction(target, myHero)
                if WPrediction:CanHit(self.Menu.Combo.WHitChance:Value()) then
                    Control.CastSpell(HK_W, WPrediction.CastPosition)
                end
                return
            end
            
            if distance <= 500 and self.Menu.Combo.UseR:Value() and _G.L9Engine:Ready(_R) then
                RPrediction:GetPrediction(target, myHero)
                if RPrediction:CanHit(self.Menu.Combo.RHitChance:Value()) then
                    Control.CastSpell(HK_R, RPrediction.CastPosition)
                end
            end
            
            if distance <= 175 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
                Control.Attack(target)
            end
        else
            if distance <= eRange and self.Menu.Combo.UseE:Value() and _G.L9Engine:Ready(_E) then
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(self.Menu.Combo.EHitChance:Value()) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                end
            end
            
            if distance <= 900 and self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
                WPrediction:GetPrediction(target, myHero)
                if WPrediction:CanHit(self.Menu.Combo.WHitChance:Value()) then
                    Control.CastSpell(HK_W, WPrediction.CastPosition)
                end
            end
            
            if distance <= 500 and self.Menu.Combo.UseR:Value() and _G.L9Engine:Ready(_R) then
                RPrediction:GetPrediction(target, myHero)
                if RPrediction:CanHit(self.Menu.Combo.RHitChance:Value()) then
                    Control.CastSpell(HK_R, RPrediction.CastPosition)
                end
            end
            
            if distance <= 175 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                Control.CastSpell(HK_Q)
            end
            
            if distance <= 175 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
                Control.Attack(target)
            end
        end
    end
end

function L9Xin:Harass()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        local eRange = GetERange(target)
        
        if myHero.pos:DistanceTo(target.pos) <= eRange and self.Menu.Harass.UseE:Value() and _G.L9Engine:Ready(_E) then
            EPrediction:GetPrediction(target, myHero)
            if EPrediction:CanHit(self.Menu.Harass.EHitChance:Value()) then
                Control.CastSpell(HK_E, EPrediction.CastPosition)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 900 and self.Menu.Harass.UseW:Value() and _G.L9Engine:Ready(_W) then
            WPrediction:GetPrediction(target, myHero)
            if WPrediction:CanHit(self.Menu.Harass.WHitChance:Value()) then
                Control.CastSpell(HK_W, WPrediction.CastPosition)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 175 and self.Menu.Harass.UseQ:Value() and _G.L9Engine:Ready(_Q) then
            Control.CastSpell(HK_Q)
        end
    end
end

function L9Xin:LaneClear()
    if myHero.mana/myHero.maxMana < self.Menu.Clear.Mana:Value() / 100 then
        return
    end
    
    if not (_G.SDK and _G.SDK.Orbwalker:CanAttack()) then
        return
    end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team == TEAM_ENEMY and _G.L9Engine:IsValidTarget(minion) and not IsJungleMob(minion) then
            local eRange = GetERange(minion)
            local distance = myHero.pos:DistanceTo(minion.pos)
            
            if distance <= eRange and self.Menu.Clear.UseE:Value() and _G.L9Engine:Ready(_E) then
                Control.CastSpell(HK_E, Vector(minion.pos.x, myHero.pos.y, minion.pos.z))
                return
            end
            
            if distance <= 900 and self.Menu.Clear.UseW:Value() and _G.L9Engine:Ready(_W) then
                Control.CastSpell(HK_W, Vector(minion.pos.x, myHero.pos.y, minion.pos.z))
                return
            end
            
            if distance <= 175 and self.Menu.Clear.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                Control.CastSpell(HK_Q)
                return
            end
        end
    end
end

function L9Xin:JungleClear()
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
            local eRange = GetERange(minion)
            local distance = myHero.pos:DistanceTo(minion.pos)
            
            if distance <= eRange and self.Menu.JClear.UseE:Value() and _G.L9Engine:Ready(_E) then
                Control.CastSpell(HK_E, Vector(minion.pos.x, myHero.pos.y, minion.pos.z))
                return
            end
            
            if distance <= 900 and self.Menu.JClear.UseW:Value() and _G.L9Engine:Ready(_W) then
                Control.CastSpell(HK_W, Vector(minion.pos.x, myHero.pos.y, minion.pos.z))
                return
            end
            
            if distance <= 175 and self.Menu.JClear.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                Control.CastSpell(HK_Q)
                return
            end
        end
    end
end

function L9Xin:LastHit()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 175 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.LastHit.Mana:Value() / 100 then
            
            if myHero.pos:DistanceTo(minion.pos) <= 175 and _G.L9Engine:Ready(_Q) and self.Menu.LastHit.UseQ:Value() then
                local QDmg = getdmg("Q", minion, myHero) or 0
                if minion.health <= QDmg then
                    Control.CastSpell(HK_Q)
                    break
                end
            end
        end
    end
end

function L9Xin:KillSteal()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) then
        local eRange = GetERange(target)
        
        if self.Menu.ks.UseR:Value() and _G.L9Engine:Ready(_R) and myHero.pos:DistanceTo(target.pos) <= 500 then
            local RDmg = getdmg("R", target, myHero) or 0
            if target.health <= RDmg then
                RPrediction:GetPrediction(target, myHero)
                if RPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_R, RPrediction.CastPosition)
                end
            end
        end
        
        if self.Menu.ks.UseE:Value() and _G.L9Engine:Ready(_E) and myHero.pos:DistanceTo(target.pos) <= eRange then
            local EDmg = getdmg("E", target, myHero) or 0
            if target.health <= EDmg then
                EPrediction:GetPrediction(target, myHero)
                if EPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_E, EPrediction.CastPosition)
                end
            end
        end
        
        if self.Menu.ks.UseW:Value() and _G.L9Engine:Ready(_W) and myHero.pos:DistanceTo(target.pos) <= 900 then
            local WDmg = getdmg("W", target, myHero) or 0
            if target.health <= WDmg then
                WPrediction:GetPrediction(target, myHero)
                if WPrediction:CanHit(HITCHANCE_NORMAL) then
                    Control.CastSpell(HK_W, WPrediction.CastPosition)
                end
            end
        end
        
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:Ready(_Q) and myHero.pos:DistanceTo(target.pos) <= 175 then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                Control.CastSpell(HK_Q)
            end
        end
    end
end

function L9Xin:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:Ready(_Q) then
        Draw.Circle(myHero.pos, 175, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:Ready(_W) then
        Draw.Circle(myHero.pos, 900, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:Ready(_E) then
        local target = _G.L9Engine:GetTarget(1000)
        local eRange = target and GetERange(target) or 650
        local color = (target and IsWActiveOnTarget(target)) and Draw.Color(255, 255, 165, 0) or Draw.Color(255, 0, 0, 255)
        Draw.Circle(myHero.pos, eRange, 1, color)
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:Ready(_R) then
        Draw.Circle(myHero.pos, 500, 1, Draw.Color(255, 255, 255, 0))
    end
    
    if self.Menu.Drawing.DrawWActive:Value() then
        local target = _G.L9Engine:GetTarget(1000)
        if target and IsWActiveOnTarget(target) and _G.L9Engine:Ready(_E) then
            Draw.Circle(myHero.pos, 900, 1, Draw.Color(255, 255, 165, 0))
        end
    end
end

L9Xin()
