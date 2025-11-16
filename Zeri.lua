if _G.__L9_ENGINE_ZERI_LOADED then return end
_G.__L9_ENGINE_ZERI_LOADED = true

local Version = "1.0"
local Name = "L9Zeri"

local Heroes = {"Zeri"}
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

if not FileExist(COMMON_PATH .. "MapPositionGOS.lua") then
    print("MapPositionGOS.lua not found! Some W features may not work.")
end

local function CheckPredictionSystem()
    if not _G.GGPrediction then
        return false
    end
    return true
end

local function HaveBuff(unit, buffName)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffName and buff.count > 0 then 
            return true
        end
    end
    return false
end

local function GetBuffData(unit, buffName)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffName and buff.count > 0 then 
            return true, buff
        end
    end
    return false, nil
end

local function FindFirstWallCollisionInRectangle(startPos, endPos, width)
    local direction = (endPos - startPos):Normalized()
    for distance = 50, startPos:DistanceTo(endPos), 50 do
        local testPosition = startPos + direction * distance
        if MapPosition and MapPosition:inWall(testPosition) then
            return testPosition
        end
    end
    return nil
end

local function IsFacingMe(unit)
    local direction = (myHero.pos - unit.pos):Normalized()
    local unitDirection = Vector(unit.dir)
    local dotProduct = direction.x * unitDirection.x + direction.z * unitDirection.z
    return dotProduct > 0.5
end

local function HasInvalidDashBuff(unit)
    return false
end

local function GetEnemyCount(range, position)
    local pos = position or myHero.pos
    local count = 0
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and _G.L9Engine:IsValidTarget(hero) then
            if pos:DistanceTo(hero.pos) <= range then
                count = count + 1
            end
        end
    end
    return count
end

local function IsBlastPlant(plantName)
    local name = plantName:lower()
    return name:find("blast") or name:find("satchel")
end

local function IsValidPlant(plantName, ignoreBlast)
    local name = plantName:lower()
    
    if name == "sennasoul" or name == "gangplankbarrel" then
        return false
    end
    
    if not name:find("plant") then
        return false
    end
    
    if ignoreBlast and IsBlastPlant(name) then
        return false
    end
    
    return true
end

class "L9Zeri"

function L9Zeri:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    if _G.SDK and _G.SDK.Orbwalker then
        _G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
    end
    
    self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.237, Radius = 40, Range = 750, Speed = 2600, Collision = false}
    self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.55, Radius = 40, Range = 1150, Speed = 2500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.W2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.55, Radius = 100, Range = 2500, Speed = 2500, Collision = false}
    self.ESpell = { Range = 300 }
    self.RSpell = { Delay = 0.25, Range = 825 }
    
    self.lastPlantCheck = 0
    
    print("L9Zeri Loaded - Version " .. Version)
    print("Optimized for GGOrbwalker")
end

function L9Zeri:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Zeri", name = "L9Zeri"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. tostring(Version)}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "Q", name = "[Q] Use Q", value = true})
    self.Menu.Combo:MenuElement({id = "W", name = "[W] Use W (No QRange or Through Wall)", value = true})
    self.Menu.Combo:MenuElement({id = "Wwall", name = "[W] Only Through Wall", value = false})
    self.Menu.Combo:MenuElement({id = "E", name = "[E] Use E", value = false})
    self.Menu.Combo:MenuElement({id = "R", name = "[R] Use R", value = true})
    self.Menu.Combo:MenuElement({id = "RCount", name = "[R] Min Enemies to Hit", value = 3, min = 1, max = 5, step = 1})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "Q", name = "[Q] Use Q", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    self.Menu.Clear:MenuElement({id = "QHarass", name = "Use Q Harass in LaneClear", value = true})
    self.Menu.Clear:MenuElement({id = "QBuildings", name = "Use Q on Buildings", value = true})
    self.Menu.Clear:MenuElement({id = "QWards", name = "Use Q on Wards", value = true})
    self.Menu.Clear:MenuElement({id = "QPlants", name = "Use Q on Plants", value = false})
    self.Menu.Clear:MenuElement({id = "QTraps", name = "Use Q on Traps (Shaco/Teemo/Zyra/Yorick)", value = true})
    self.Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
    self.Menu.Clear.LaneClear:MenuElement({id = "Q", name = "[Q] Use Q", value = true})
    self.Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
    self.Menu.Clear.JungleClear:MenuElement({id = "Q", name = "[Q] Use Q", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
    self.Menu.LastHit:MenuElement({id = "Q", name = "[Q] Use Q", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
    self.Menu.Misc:MenuElement({id = "QhitChance", name = "Q HitChance", value = 1, drop = {"Normal", "High"}})
    self.Menu.Misc:MenuElement({id = "WhitChance", name = "W HitChance", value = 1, drop = {"Normal", "High"}})
    self.Menu.Misc:MenuElement({id = "QRange", name = "Q Range Offset", value = 0, min = -50, max = 50, step = 5})
    self.Menu.Misc:MenuElement({id = "QBarrel", name = "Q Attack GP's Barrel", value = true})
    self.Menu.Misc:MenuElement({id = "QPlants", name = "Q Auto on Plants", value = true})
    self.Menu.Misc:MenuElement({id = "IgnoreBlast", name = "Ignore Blast Cone Plants", value = true})
    self.Menu.Misc:MenuElement({id = "EPlants", name = "E Auto through Plants to hit enemies", value = true})
    self.Menu.Misc:MenuElement({id = "Egap", name = "Auto E Anti Gapcloser", value = true})
    self.Menu.Misc:MenuElement({id = "ClearAA", name = "Disable AA in Clear (Mouse Scroll)", value = true, key = 4})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawing"})
    self.Menu.Drawing:MenuElement({id = "ClearAA", name = "Draw Clear AA Status", value = true})
    self.Menu.Drawing:MenuElement({id = "Q", name = "Draw Q Range", value = true})
    self.Menu.Drawing:MenuElement({id = "W", name = "Draw W Range", value = false})
    self.Menu.Drawing:MenuElement({id = "E", name = "Draw E Range", value = false})
    self.Menu.Drawing:MenuElement({id = "R", name = "Draw R Range", value = false})
end

function L9Zeri:OnPreAttack(args)
    local Mode = _G.L9Engine:GetMode()
    local target = args.Target
    
    if Mode == "Combo" and target then
        if target.charName and target.charName:lower():find("plant") and target.maxHealth == 3 then
            args.Process = true
            return
        end
        
        local hasQPassive = HaveBuff(myHero, "ZeriQPassiveReady")
        
        if hasQPassive then
            args.Process = true
        elseif target.type == Obj_AI_Hero then
            local executeDmg = self:GetExecuteDamage()
            if target.health <= executeDmg then
                args.Process = true
            else
                args.Process = false
            end
        else
            args.Process = false
        end
    end
    
    if Mode == "Clear" and target then
        if target.charName and target.charName:lower():find("plant") and target.maxHealth == 3 then
            args.Process = true
            return
        end
        
        if target.type == Obj_AI_Minion then
            local AADamage = self:GetAADamage(target)
            if self.Menu.Misc.ClearAA:Value() then
                args.Process = false
                if target.maxHealth <= 8 then
                    args.Process = true
                end
                if _G.L9Engine:IsValidTarget(target) and target.health < AADamage then
                    local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
                    if collisionCount > 0 or not _G.L9Engine:Ready(_Q) then
                        args.Process = true
                    end
                end
            else
                args.Process = true
            end
        end
    end
end

function L9Zeri:GetAADamage(target)
    if not target then return 0 end
    return myHero.totalDamage
end

function L9Zeri:GetExecuteDamage()
    local level = myHero.levelData.lvl
    return 60 + 90 / 17 * (level - 1)
end

function L9Zeri:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    if myHero.range == 650 then
        self.QSpell.Range = 900 + self.Menu.Misc.QRange:Value()
    else
        self.QSpell.Range = 750 + self.Menu.Misc.QRange:Value()
    end
    
    if HaveBuff(myHero, "ZeriR") then
        self.QSpell.Speed = 3400
    else
        self.QSpell.Speed = 2600
    end
    
    self.WSpell.Delay = math.max(math.floor((0.55 - 0.09 * (myHero.attackSpeed - 1)) * 100) / 100, 0.3)
    self.W2Spell.Delay = self.WSpell.Delay
    
    self:AntiGapcloser()
    
    local Mode = _G.L9Engine:GetMode()
    
    if Mode == "Combo" then
        self:QPlants()
        self:QBarrel()
        self:Combo()
    elseif Mode == "Harass" then
        self:LastHit()
        self:Harass()
    elseif Mode == "Clear" then
        self:QTraps()
        self:QPlants()
        self:QBarrel()
        if self.Menu.Clear.QHarass:Value() then
            self:Harass()
        end
        self:LastHit()
        self:QObject()
        self:LaneClear()
        self:JungleClear()
    elseif Mode == "LastHit" then
        self:LastHit()
    end
end

function L9Zeri:AntiGapcloser()
    if self.Menu.Misc.Egap:Value() and _G.L9Engine:Ready(_E) then
        for i = 1, Game.HeroCount() do
            local target = Game.Hero(i)
            if target and target.isEnemy and _G.L9Engine:IsValidTarget(target, 1500) then
                if target.pathing.isDashing and not HasInvalidDashBuff(target) then
                    if myHero.pos:DistanceTo(target.pathing.endPos) < 300 and IsFacingMe(target) then
                        local castPos = myHero.pos + (myHero.pos - target.pos):Normalized() * self.ESpell.Range
                        if castPos:To2D().onScreen then
                            Control.CastSpell(HK_E, castPos)
                        end
                    end
                end
            end
        end
    end
end

function L9Zeri:QPlants()
    if not self.Menu.Misc.QPlants:Value() or not _G.L9Engine:Ready(_Q) then
        return
    end
    
    local currentTime = Game.Timer()
    if currentTime - self.lastPlantCheck < 0.25 then
        return
    end
    
    self.lastPlantCheck = currentTime
    local QRange = 750
    local objectCount = Game.ObjectCount()
    local ignoreBlast = self.Menu.Misc.IgnoreBlast:Value()
    
    for i = 1, objectCount, 1 do
        local plant = Game.Object(i)
        if plant and plant.charName and plant.isTargetable and plant.visible then
            local objName = plant.charName
            
            if IsValidPlant(objName, ignoreBlast) then
                local distance = myHero.pos:DistanceTo(plant.pos)
                if distance <= QRange then
                    local objNameLower = objName:lower()
                    if plant.team ~= myHero.team or objNameLower == "sru_plant_demon" then
                        if plant.maxHealth == 3 then
                            Control.CastSpell(HK_Q, plant)
                            DelayAction(function()
                                if plant and plant.valid and not plant.dead and _G.L9Engine:IsValidTarget(plant) then
                                    Control.Attack(plant)
                                    DelayAction(function()
                                        if plant and plant.valid and not plant.dead and _G.L9Engine:IsValidTarget(plant) and _G.L9Engine:Ready(_Q) then
                                            Control.CastSpell(HK_Q, plant)
                                        end
                                    end, 0.05)
                                end
                            end, 0.05)
                            return
                        else
                            Control.CastSpell(HK_Q, plant)
                            return
                        end
                    end
                end
            end
        end
    end
end

function L9Zeri:FindPlantToShootThrough()
    local enemies = {}
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and _G.L9Engine:IsValidTarget(hero, 1200) then
            table.insert(enemies, hero)
        end
    end
    
    if #enemies == 0 then return nil end
    
    local objectCount = Game.ObjectCount()
    local ignoreBlast = self.Menu.Misc.IgnoreBlast:Value()
    
    for i = 1, objectCount do
        local plant = Game.Object(i)
        if plant and plant.charName and plant.isTargetable and plant.visible then
            local objName = plant.charName
            
            if IsValidPlant(objName, ignoreBlast) then
                local distToPlant = myHero.pos:DistanceTo(plant.pos)
                if distToPlant <= self.ESpell.Range and distToPlant <= 750 then
                    for _, enemy in ipairs(enemies) do
                        local plantToEnemy = plant.pos:DistanceTo(enemy.pos)
                        if plantToEnemy <= 400 then
                            return plant
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

function L9Zeri:QBarrel()
    if not self.Menu.Misc.QBarrel:Value() or not _G.L9Engine:Ready(_Q) then
        return
    end
    
    local gangplank = nil
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if enemy and enemy.isEnemy and enemy.charName == "Gangplank" then
            gangplank = enemy
            break
        end
    end
    
    if not gangplank then
        return
    end
    
    local level = gangplank.levelData.lvl
    local healthDecayRate = level >= 13 and 0.5 or (level >= 7 and 1 or 2)
    local currentTime = Game.Timer()
    
    for i = 1, Game.ObjectCount() do
        local obj = Game.Object(i)
        if obj and obj.charName and obj.charName:lower() == "gangplankbarrel" then
            local distance = myHero.pos:DistanceTo(obj.pos)
            if distance <= 750 then
                local barrelHealth = obj.health
                local barrelBuff, barrelBuffData = GetBuffData(obj, "gangplankebarrelactive")
                local barrelBuffStartTime = barrelBuff and barrelBuffData.startTime or 0
                local time = distance / self.QSpell.Speed
                
                if barrelHealth <= 1 then
                    Control.CastSpell(HK_Q, obj)
                    return
                elseif barrelHealth <= 2 then
                    if distance <= myHero.range + myHero.boundingRadius then
                        Control.CastSpell(HK_Q, obj)
                        return
                    else
                        local nextHealthDecayTime = currentTime < barrelBuffStartTime + healthDecayRate and barrelBuffStartTime + healthDecayRate or barrelBuffStartTime + healthDecayRate * 2
                        if nextHealthDecayTime <= currentTime + time then
                            Control.CastSpell(HK_Q, obj)
                            return
                        end
                    end
                end
            end
        end
    end
end

function L9Zeri:Combo()
    local Qtarget = _G.L9Engine:GetTarget(self.QSpell.Range)
    
    if _G.L9Engine:Ready(_E) and self.Menu.Misc.EPlants:Value() then
        local bestPlant = self:FindPlantToShootThrough()
        if bestPlant then
            Control.CastSpell(HK_E, bestPlant.pos)
            return
        end
    end
    
    if _G.L9Engine:Ready(_E) and self.Menu.Combo.E:Value() then
        local Etarget = _G.L9Engine:GetTarget(self.ESpell.Range + self.QSpell.Range - 50)
        if Etarget and _G.L9Engine:IsValidTarget(Etarget) and Etarget.pos2D.onScreen then
            local dashPos = myHero.pos + (Etarget.pos - myHero.pos):Normalized() * self.ESpell.Range
            Control.CastSpell(HK_E, dashPos)
            return
        end
    end
    
    if Qtarget and _G.L9Engine:IsValidTarget(Qtarget) and Qtarget.pos2D.onScreen then
        if self.Menu.Combo.Q:Value() and _G.L9Engine:Ready(_Q) then
            local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
            QPrediction:GetPrediction(Qtarget, myHero)
            if QPrediction:CanHit(self.Menu.Misc.QhitChance:Value() + 1) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
            end
        end
    end
    
    local Wtarget = _G.L9Engine:GetTarget(self.W2Spell.Range)
    if Wtarget and _G.L9Engine:IsValidTarget(Wtarget) and Wtarget.pos2D.onScreen then
        if self.Menu.Combo.W:Value() and _G.L9Engine:Ready(_W) then
            if myHero.pos:DistanceTo(Wtarget.pos) > self.QSpell.Range and GetEnemyCount(self.QSpell.Range, myHero.pos) == 0 then
                self:CastW(Wtarget)
            end
        end
    end
    
    if self.Menu.Combo.R:Value() and _G.L9Engine:Ready(_R) then
        local Count = 0
        for i = 1, Game.HeroCount() do
            local enemy = Game.Hero(i)
            if enemy and enemy.isEnemy and _G.L9Engine:IsValidTarget(enemy) then
                local enemyPred = enemy:GetPrediction(math.huge, self.RSpell.Delay)
                if myHero.pos:DistanceTo(enemyPred) < self.RSpell.Range - 50 then
                    Count = Count + 1
                end
            end
        end
        
        if Count >= self.Menu.Combo.RCount:Value() then
            Control.CastSpell(HK_R)
        end
    end
end

function L9Zeri:CastW(target)
    local pred = GGPrediction:SpellPrediction(self.W2Spell)
    pred:GetPrediction(target, myHero)
    if not pred:CanHit(self.Menu.Misc.WhitChance:Value() + 1) then return end
    
    local predPos = Vector(pred.UnitPosition)
    local castPos = Vector(pred.CastPosition)
    local wallColPos = FindFirstWallCollisionInRectangle(myHero.pos, predPos, self.WSpell.Radius)
    
    if wallColPos and myHero.pos:DistanceTo(wallColPos) < self.WSpell.Range and wallColPos:DistanceTo(castPos) < 1400 then
        local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, wallColPos, self.WSpell.Speed, self.WSpell.Delay, self.WSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
        if collisionCount == 0 then
            Control.CastSpell(HK_W, castPos)
        end
    elseif not self.Menu.Combo.Wwall:Value() then
        local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
        WPrediction:GetPrediction(target, myHero)
        if WPrediction:CanHit(self.Menu.Misc.WhitChance:Value() + 1) then
            Control.CastSpell(HK_W, WPrediction.CastPosition)
        end
    end
end

function L9Zeri:Harass()
    local Qtarget = _G.L9Engine:GetTarget(self.QSpell.Range)
    if Qtarget and _G.L9Engine:IsValidTarget(Qtarget) and Qtarget.pos2D.onScreen then
        if self.Menu.Harass.Q:Value() and _G.L9Engine:Ready(_Q) then
            local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
            QPrediction:GetPrediction(Qtarget, myHero)
            if QPrediction:CanHit(self.Menu.Misc.QhitChance:Value() + 1) then
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
            end
        end
    end
end

function L9Zeri:GetQDmg(target)
    if not target then return 0 end
    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end
    local baseDmg = {15, 17, 19, 21, 23}
    local bonusDmg = {1.04, 1.08, 1.12, 1.16, 1.2}
    local QDmg = baseDmg[level] + bonusDmg[level] * myHero.totalDamage
    local targetArmor = target.armor
    local damageMultiplier = 100 / (100 + targetArmor)
    return QDmg * damageMultiplier
end

function L9Zeri:LastHit()
    if self.Menu.LastHit.Q:Value() and _G.L9Engine:Ready(_Q) then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.isEnemy and _G.L9Engine:IsValidTarget(minion, 750) and minion.pos2D.onScreen then
                local QDmg = self:GetQDmg(minion)
                local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
                if QDmg > minion.health and collisionCount == 0 then
                    Control.CastSpell(HK_Q, minion)
                    return
                end
            end
        end
    end
end

function L9Zeri:LaneClear()
    if self.Menu.Clear.LaneClear.Q:Value() and _G.L9Engine:Ready(_Q) then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.isEnemy and _G.L9Engine:IsValidTarget(minion, 750) and minion.team ~= 300 and minion.pos2D.onScreen then
                Control.CastSpell(HK_Q, minion)
                return
            end
        end
    end
end

function L9Zeri:JungleClear()
    if self.Menu.Clear.JungleClear.Q:Value() and _G.L9Engine:Ready(_Q) then
        local minions = {}
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and _G.L9Engine:IsValidTarget(minion, 750) and minion.team == 300 and minion.pos2D.onScreen then
                table.insert(minions, minion)
            end
        end
        
        table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
        
        if #minions > 0 then
            Control.CastSpell(HK_Q, minions[1])
        end
    end
end

function L9Zeri:QTraps()
    if not self.Menu.Clear.QTraps:Value() or not _G.L9Engine:Ready(_Q) then
        return
    end
    
    local QRange = 750
    local trapNames = {
        "shacobox",
        "teemomushroom",
        "zyraseed",
        "zyrathornsplant",
        "zyragraspingplant",
        "yorickghoulmelee",
        "yorickbigghoul",
        "nidaleespear",
        "caitlyntrap",
        "caitlynyordletrap",
        "jinxmine",
        "jhinetrap",
        "illaoitentacle",
        "illaoivessel",
        "heimerdingerturret",
        "malzaharvoidling",
        "elisespiderling",
        "annietibbers",
    }
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and _G.L9Engine:IsValidTarget(minion, QRange) then
            if minion.charName then
                local name = minion.charName:lower()
                for _, trapName in ipairs(trapNames) do
                    if name:find(trapName) then
                        Control.CastSpell(HK_Q, minion)
                        return
                    end
                end
            end
        end
    end
    
    for i = 1, Game.ObjectCount() do
        local obj = Game.Object(i)
        if obj and obj.isEnemy and obj.charName and obj.isTargetable then
            local distance = myHero.pos:DistanceTo(obj.pos)
            if distance <= QRange then
                local name = obj.charName:lower()
                for _, trapName in ipairs(trapNames) do
                    if name:find(trapName) then
                        Control.CastSpell(HK_Q, obj)
                        return
                    end
                end
            end
        end
    end
end

function L9Zeri:QObject()
    if not _G.L9Engine:Ready(_Q) then return end
    
    local QRange = 750
    local targets = {}
    
    if self.Menu.Clear.QBuildings:Value() then
        for i = 1, Game.TurretCount() do
            local turret = Game.Turret(i)
            if turret and turret.isEnemy and turret.isTargetable then
                local distance = myHero.pos:DistanceTo(turret.pos)
                if distance <= QRange then
                    table.insert(targets, turret)
                end
            end
        end
        
        for i = 1, Game.ObjectCount() do
            local obj = Game.Object(i)
            if obj and obj.isEnemy then
                local distance = myHero.pos:DistanceTo(obj.pos)
                if obj.type == Obj_AI_Nexus and distance < QRange + 350 then
                    table.insert(targets, obj)
                elseif obj.type == Obj_AI_Barracks and distance < QRange + 250 then
                    table.insert(targets, obj)
                end
            end
        end
    end
    
    if self.Menu.Clear.QWards:Value() then
        for i = 1, Game.MinionCount() do
            local ward = Game.Minion(i)
            if ward and ward.isEnemy then
                local distance = myHero.pos:DistanceTo(ward.pos)
                if distance <= QRange and ward.maxHealth <= 5 then
                    table.insert(targets, ward)
                end
            end
        end
    end
    
    local ignoreBlast = self.Menu.Misc.IgnoreBlast:Value()
    for i = 1, Game.ObjectCount() do
        local plant = Game.Object(i)
        if plant and plant.charName then
            local objName = plant.charName
            local distance = myHero.pos:DistanceTo(plant.pos)
            
            if distance <= QRange and IsValidPlant(objName, ignoreBlast) then
                local objNameLower = objName:lower()
                if self.Menu.Clear.QPlants:Value() or plant.team ~= 300 or objNameLower == "sru_plant_demon" then
                    table.insert(targets, plant)
                end
            end
        end
    end
    
    if #targets > 0 then
        Control.CastSpell(HK_Q, targets[1])
    end
end

function L9Zeri:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    if self.Menu.Drawing.ClearAA:Value() then
        Draw.Text("ClearAA", 16, myHero.pos2D.x - 25, myHero.pos2D.y + 58, Draw.Color(255, 138, 43, 226))
    end
    
    if self.Menu.Drawing.Q:Value() then
        Draw.Circle(myHero.pos, self.QSpell.Range, 0.5, Draw.Color(255, 66, 244, 113))
    end
    
    if self.Menu.Drawing.W:Value() and _G.L9Engine:Ready(_W) then
        Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
    end
    
    if self.Menu.Drawing.E:Value() and _G.L9Engine:Ready(_E) then
        Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
    end
    
    if self.Menu.Drawing.R:Value() and _G.L9Engine:Ready(_R) then
        Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
    end
end

L9Zeri()

