local AIO_FOLDER = "L9Engine"
local BASE_URL = "https://raw.githubusercontent.com/Gos-Lua/gos/main/"
local LOCAL_PATH = COMMON_PATH .. AIO_FOLDER .. "/"
local CORE_FILE = LOCAL_PATH .. "Core.lua"
local CHAMPIONS_LIST_FILE = LOCAL_PATH .. "Champions.lua"

-- Option pour désactiver les mises à jour automatiques
local AUTO_UPDATE = false -- Mettre à false pour désactiver

-- Liste des champions chargée dynamiquement depuis Champions.lua
local CHAMPION_LIST = nil

local needed = {
    [CORE_FILE] = "Core.lua",
    [CHAMPIONS_LIST_FILE] = "Champions.lua"
}

local function FileExists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local pendingDownloads = 0
local function Download(url, path, cb)
    pendingDownloads = pendingDownloads + 1
    DownloadFileAsync(url, path, function()
        pendingDownloads = pendingDownloads - 1
        if cb then cb(path) end
    end)
end

local function LoadChampionsList()
    if not FileExists(CHAMPIONS_LIST_FILE) then
        return false
    end
    
    local success, championsList = pcall(dofile, CHAMPIONS_LIST_FILE)
    if success and type(championsList) == "table" then
        CHAMPION_LIST = championsList
        -- Ajouter les champions à la liste des fichiers nécessaires
        for _, championName in ipairs(CHAMPION_LIST) do
            local scriptName = championName .. ".lua"
            local scriptPath = LOCAL_PATH .. "Champions/" .. scriptName
            needed[scriptPath] = "Champions/" .. scriptName
        end
        return true
    else
        print("[L9Engine] Erreur lors du chargement de la liste des champions")
        return false
    end
end

local function EnsureDir()
    local championsPath = LOCAL_PATH .. "Champions/"
    if not FileExists(championsPath) then
        print("[L9Engine] Création du dossier Champions...")
    end
end

local function CheckAndDownload()
    EnsureDir()
    for fullPath, shortName in pairs(needed) do
        if AUTO_UPDATE then
            print(string.format("[L9Engine] Mise à jour de %s depuis GitHub...", shortName))
            Download(BASE_URL .. shortName, fullPath, function()
                print(string.format("[L9Engine] %s mis à jour", shortName))
            end)
        else
            -- Mode local uniquement
            if not FileExists(fullPath) then
                print(string.format("[L9Engine] Téléchargement de %s depuis GitHub...", shortName))
                Download(BASE_URL .. shortName, fullPath, function()
                    print(string.format("[L9Engine] %s prêt", shortName))
                end)
            end
        end
    end
end

local function SafeDofile(path)
    local ok, err = pcall(dofile, path)
    if not ok then
        print("[L9Engine] Erreur lors du chargement de " .. path .. ": " .. tostring(err))
        return false
    end
    return true
end

local function TryLoadCore()
    if _G.L9EngineLoaded then
        Callback.Del("Tick", TryLoadCore)
        return
    end
    if pendingDownloads > 0 then return end
    
    -- Charger d'abord la liste des champions
    if not CHAMPION_LIST and FileExists(CHAMPIONS_LIST_FILE) then
        if LoadChampionsList() then
            print("[L9Engine] Liste des champions chargée: " .. #CHAMPION_LIST .. " champions disponibles")
        end
    end
    
    if not FileExists(CORE_FILE) then return end
    if SafeDofile(CORE_FILE) then
        if _G.L9EngineLoaded then
            print("[L9Engine] Engine original chargé avec succès")
            if CHAMPION_LIST then
                local champStr = table.concat(CHAMPION_LIST, ", ")
                print("[L9Engine] Champions supportés: " .. champStr)
            end
        end
        Callback.Del("Tick", TryLoadCore)
    end
end

print("[L9Engine] Démarrage de l'engine original...")
if AUTO_UPDATE then
    print("[L9Engine] Mode: Mises à jour automatiques activées")
else
    print("[L9Engine] Mode: Mises à jour automatiques désactivées")
end
print("[L9Engine] Téléchargement depuis: https://github.com/Gos-Lua/gos")

-- Charger la liste des champions en local si elle existe avant de télécharger
if FileExists(CHAMPIONS_LIST_FILE) then
    LoadChampionsList()
end

CheckAndDownload()

Callback.Add("Tick", TryLoadCore)

DelayAction(function()
    TryLoadCore()
    if pendingDownloads == 0 and not FileExists(CORE_FILE) then
        print("[L9Engine] Impossible d'obtenir Core.lua depuis GitHub")
    end
end, 3)
