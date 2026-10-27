--[[
  Living Chrome v0.3.0 - Cyberpunk 2077 mod (Cyber Engine Tweaks)

  Your cyberware levels up as you use it, and every implant rolls a hidden
  quirk the first time you install it:
    Clean   - normal chrome
    Tuned   - learns 50% faster
    Glitchy - learns 2x faster and gives 25% bigger bonuses, but malfunctions
              in combat until it reaches max level (Stabilized)

  Implants learn from combat time, kills, and from doing their own job
  (RAM spent, damage soaked, healing, stamina used, Sandevistan/Berserk/
  Kerenzikov activations). At Lv 5 they are MASTERED and add a second bonus.
  Each body area malfunctions in its own way. Ripperdocs can stabilize a
  Glitchy implant or re-roll a quirk for eddies.

  Open the CET overlay to see the Living Chrome window (with Settings).
  Console helpers: GetMod("LivingChrome").status()  /  .addXp(500)
                   .forceMalfunction(kind)  /  .reset()  /  .importOld()
                   kind = "optics" | "cortex" | "neural" | "body" | "limbs"

  Progress is kept per playthrough: each save gets a hidden ID stored as a
  quest fact (saved inside the game save), and the mod keeps one data file
  per ID in this folder.
]]

local LC = {
  version = "0.3.0",

  -- Tweak these to taste
  config = {
    xpPerCombatSecond = 0.5,      -- XP every equipped implant earns per second of combat
    xpPerKill = 15,               -- XP per nearby kill/takedown while fighting
    killRadius = 40,              -- metres; deaths farther away than this don't count
    killGraceSeconds = 10,        -- kills still count this long after combat ends

    -- Usage XP: implants also learn from doing their own job while fighting
    usageXpMult = 1.0,            -- scales all usage XP below
    usageXp = {
      ram = 0.6,                  -- per % of RAM spent (quickhacks)       -> Frontal Cortex, OS
      damage = 0.5,               -- per % of Health lost                  -> Skeleton, Immune, Integumentary
      heal = 0.5,                 -- per % of Health regained              -> Circulatory
      stamina = 0.15,             -- per % of Stamina spent (dash, melee)  -> Legs, Arms
      activation = 30,            -- per Sandevistan/Berserk/Kerenzikov use -> OS, Nervous System
      kill = 10,                  -- extra per kill                        -> Eyes, Hands, Arms
    },
    levelThresholds = { 400, 1100, 2200, 3800, 6000 }, -- total XP for Lv 1..5

    tunedChance = 0.25,
    glitchyChance = 0.15,         -- the rest is Clean
    tunedXpMult = 1.5,
    glitchyXpMult = 2.0,
    glitchyBonusMult = 1.25,

    malfunctionCheckEvery = 15,   -- seconds of combat between malfunction rolls
    malfunctionChance = 0.035,    -- chance per roll (~13% per minute of combat)
    malfunctionDuration = 6,      -- seconds
    malfunctionCritPenalty = -15, -- crit chance during an optics fault
    screenGlitch = true,          -- screen glitch on optics/cortex faults
    malfunctionEffect = "BaseStatusEffect.JohnnySicknessLow", -- the glitch effect used

    stabilizeCost = 6000,         -- eddies to stabilize a Glitchy implant at a ripperdoc
    rerollCost = 3000,            -- eddies to re-roll an implant's quirk at a ripperdoc
    servicesAnywhere = false,     -- allow ripperdoc services outside the ripperdoc screen

    onScreenMessages = true,
    messageGap = 2.5,             -- seconds between queued on-screen messages
    reapplyEvery = 15,
    saveEvery = 30,
  },

  data = { implants = {} },
  saveId = nil,          -- ID of the playthrough currently loaded (nil = none)
  equipped = {},
  applied = {},
  malfunction = nil,
  needsReapply = true,
  dirty = false,
  clock = 0,
  lastCombat = -1000,
  combatAccum = 0,
  recentKills = {},
  overlayOpen = false,
  pending = {},          -- IDs given to saves that haven't been saved with them yet
  checkSave = true,      -- re-read the save ID on the next update
  disabled = false,      -- set by uninstall(); mod does nothing until restart
  atRipperdoc = false,   -- ripperdoc screen is open
  pools = {},            -- last RAM/Health/Stamina % seen, for usage XP
  ignorePoolsUntil = 0,  -- skip usage XP while our own malfunction drains a pool
  recentActivations = {},
  msgQueue = {},
  msgTimer = 0,
  levelUps = {},         -- level-ups this frame, shown as one message
  timers = { scan = 0, combat = 0, reapply = 0, save = 0, saveCheck = 0, usage = 0 },
}

-- Per cyberware area: the stat it improves per level, what it learns from
-- (usage XP signals), its Lv 5 mastery bonus, and how it malfunctions.
local AREAS = {
  { key = "FrontalCortexCW", label = "Frontal Cortex", stat = "CritChance", perLevel = 1,
    uses = { "ram" }, mastery = { stat = "Memory", value = 1 }, fault = "cortex" },
  { key = "SystemReplacementCW", label = "Operating System", stat = "CritChance", perLevel = 1.5,
    uses = { "ram", "os" }, mastery = { stat = "Memory", value = 2 }, fault = "cortex" },
  { key = "EyesCW", label = "Ocular System", stat = "CritChance", perLevel = 1,
    uses = { "kill" }, mastery = { stat = "CritDamage", value = 5 }, fault = "optics" },
  { key = "MusculoskeletalSystemCW", label = "Skeleton", stat = "Health", perLevel = 8,
    uses = { "damage" }, mastery = { stat = "Armor", value = 10 }, fault = "body" },
  { key = "NervousSystemCW", label = "Nervous System", stat = "CritDamage", perLevel = 3,
    uses = { "reflex" }, mastery = { stat = "CritChance", value = 2 }, fault = "neural" },
  { key = "CardiovascularSystemCW", label = "Circulatory System", stat = "Health", perLevel = 6,
    uses = { "heal" }, mastery = { stat = "Stamina", value = 10 }, fault = "body" },
  { key = "ImmuneSystemCW", label = "Immune System", stat = "Armor", perLevel = 6,
    uses = { "damage" }, mastery = { stat = "Health", value = 20 }, fault = "body" },
  { key = "IntegumentarySystemCW", label = "Integumentary System", stat = "Armor", perLevel = 6,
    uses = { "damage" }, mastery = { stat = "Health", value = 20 }, fault = "body" },
  { key = "HandsCW", label = "Hands", stat = "CritDamage", perLevel = 2,
    uses = { "kill" }, mastery = { stat = "CritChance", value = 2 }, fault = "limbs" },
  { key = "ArmsCW", label = "Arms", stat = "CritDamage", perLevel = 4,
    uses = { "kill", "stamina" }, mastery = { stat = "Health", value = 15 }, fault = "limbs" },
  { key = "LegsCW", label = "Legs", stat = "Stamina", perLevel = 5,
    uses = { "stamina" }, mastery = { stat = "Armor", value = 10 }, fault = "neural" },
}

local AREA_BY_KEY = {}
for _, a in ipairs(AREAS) do
  AREA_BY_KEY[a.key] = a
  a.useSet = {}
  for _, u in ipairs(a.uses) do a.useSet[u] = true end
end

-- Player buffs that mean an implant was just activated -> usage signal
local ACTIVATIONS = {
  { pattern = "SandevistanPlayerBuff", signal = "os" },
  { pattern = "BerserkPlayerBuff", signal = "os" },
  { pattern = "KerenzikovPlayerBuff", signal = "reflex" },
}

-- How each kind of chrome fails. mods are temporary stat penalties
-- ("critPenalty" = config.malfunctionCritPenalty); drain empties a stat pool.
local FAULTS = {
  optics = { label = "OPTICS FAULT", glitch = true, mods = { { "CritChance", "critPenalty" } } },
  cortex = { label = "RAM LEAK", glitch = true, drain = "Memory", mods = {} },
  neural = { label = "MOTOR STUTTER", drain = "Stamina", mods = { { "CritChance", -10 } } },
  body = { label = "PLATING FAULT", mods = { { "Armor", -100 } } },
  limbs = { label = "SERVO JAM", mods = { { "CritDamage", -40 }, { "CritChance", -10 } } },
}

-- Shown in the Living Chrome window and in the game's Settings menu (if the
-- Native Settings UI mod is installed). Saved to SETTINGS_FILE.
local SETTINGS = {
  { key = "xpPerCombatSecond", label = "XP per second of combat", kind = "float", min = 0, max = 5, fmt = "%.1f" },
  { key = "xpPerKill", label = "XP per kill", kind = "int", min = 0, max = 100 },
  { key = "usageXpMult", label = "Usage XP multiplier", kind = "float", min = 0, max = 5, fmt = "%.1f" },
  { key = "malfunctionChance", label = "Malfunction chance per roll", kind = "float", min = 0, max = 0.2, fmt = "%.3f" },
  { key = "malfunctionDuration", label = "Malfunction length (seconds)", kind = "int", min = 1, max = 20 },
  { key = "screenGlitch", label = "Screen glitch on malfunctions", kind = "bool" },
  { key = "onScreenMessages", label = "On-screen messages", kind = "bool" },
  { key = "stabilizeCost", label = "Stabilize cost (eddies)", kind = "int", min = 0, max = 50000, step = 500 },
  { key = "rerollCost", label = "Re-roll cost (eddies)", kind = "int", min = 0, max = 50000, step = 500 },
  { key = "servicesAnywhere", label = "Ripperdoc services anywhere (cheat)", kind = "bool" },
}
local SETTINGS_FILE = "living_chrome_settings.txt"
local DEFAULTS = {}
for _, st in ipairs(SETTINGS) do DEFAULTS[st.key] = LC.config[st.key] end

-- Overlay/status list groups implants by quirk in this order
local QUIRK_ORDER = { glitchy = 1, tuned = 2, clean = 3 }
local QUIRK_COLOR = {
  glitchy = { 1, 0.35, 0.35 },
  tuned = { 0.4, 1, 0.5 },
  clean = { 0.7, 0.7, 0.7 },
}

-- Equipped implant records, grouped by quirk, then by name
local function equippedSorted()
  local list = {}
  for key in pairs(LC.equipped) do
    local r = LC.data.implants[key]
    if r then table.insert(list, r) end
  end
  table.sort(list, function(a, b)
    local oa, ob = QUIRK_ORDER[a.quirk] or 9, QUIRK_ORDER[b.quirk] or 9
    if oa ~= ob then return oa < ob end
    return (a.name or "") < (b.name or "")
  end)
  return list
end

local STAT_LABEL = {
  CritChance = "% Crit Chance",
  CritDamage = "% Crit Damage",
  Health = " Max Health",
  Armor = " Armor",
  Stamina = " Max Stamina",
  Memory = " Max RAM",
}

local QUIRK_LABEL = { clean = "Clean", tuned = "Tuned", glitchy = "Glitchy" }

-- Endings the game puts on cyberware IDs for each upgrade tier, e.g.
-- ...BonesLegendary2PlusPlus, ...BerserkC4MK5PlusPlus, ...MaskCWPlusPlus.
-- They are stripped (repeatedly) so an upgraded implant keeps its progress.
-- Uncommon must come before Common.
local TIER_PATTERNS = {
  "_?Plus$",
  "_?Uncommon%d*$", "_?Common%d*$", "_?Rare%d*$", "_?Epic%d*$", "_?Legendary%d*$",
  "_?C%d+MK%d+$", "_?MK%d+$",
}

local LEGACY_FILE = "living_chrome_data.txt"          -- v0.1.0 shared file
local LEGACY_DONE_FILE = "living_chrome_data_old.txt" -- after it was imported
local SAVE_ID_FACT = "living_chrome_save_id"
-- 1 while our screen-glitch effect is on the player. Facts are stored in the
-- game save, so if a save is made mid-malfunction we can clean it up on load.
local GLITCH_FACT = "living_chrome_glitch_active"

local function saveFile(id)
  return "living_chrome_save_" .. tostring(id) .. ".txt"
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function safe(fn)
  local ok, res = pcall(fn)
  if ok then return res end
  return nil
end

local function enumValue(typeName, valueName)
  local v = safe(function() return Enum.new(typeName, valueName) end)
  if v ~= nil then return v end
  return safe(function() return _G[typeName][valueName] end)
end

local function entityHash(ent)
  return safe(function() return tostring(ent:GetEntityID().hash) end)
end

local function getPlayer()
  local preGame = safe(function() return Game.GetSystemRequestsHandler():IsPreGame() end)
  if preGame == true then return nil end
  local p = safe(function() return Game.GetPlayer() end)
  if p == nil then return nil end
  if entityHash(p) == nil then return nil end
  return p
end

local function showOnScreen(msg)
  local p = getPlayer()
  if p then safe(function() p:SetWarningMessage(msg) end) end
end

-- Urgent messages (malfunctions, purchases) show at once; the rest wait in a
-- queue so they don't overwrite each other.
local function notify(msg, urgent)
  print("[Living Chrome] " .. msg)
  if not LC.config.onScreenMessages then return end
  if urgent then
    showOnScreen(msg)
    LC.msgTimer = LC.config.messageGap
  else
    table.insert(LC.msgQueue, msg)
    while #LC.msgQueue > 6 do table.remove(LC.msgQueue, 1) end
  end
end

-- Called every frame: turns this frame's level-ups into one message and shows
-- the next queued message when the previous one has had time to be read.
local function pumpMessages(dt)
  if #LC.levelUps > 0 then
    local ups = LC.levelUps
    LC.levelUps = {}
    if LC.config.onScreenMessages then
      if #ups == 1 then
        table.insert(LC.msgQueue, ups[1].full)
      else
        local parts = {}
        for i = 1, math.min(3, #ups) do parts[i] = ups[i].short end
        local msg = "Chrome upgraded: " .. table.concat(parts, ", ")
        if #ups > 3 then msg = msg .. string.format(" (+%d more)", #ups - 3) end
        table.insert(LC.msgQueue, msg)
      end
    end
  end
  LC.msgTimer = LC.msgTimer - dt
  if LC.msgTimer <= 0 and #LC.msgQueue > 0 then
    showOnScreen(table.remove(LC.msgQueue, 1))
    LC.msgTimer = LC.config.messageGap
  end
end

local function saveSettings()
  local f = io.open(SETTINGS_FILE, "w")
  if not f then return end
  for _, st in ipairs(SETTINGS) do f:write(st.key, "=", tostring(LC.config[st.key]), "\n") end
  f:close()
end

local function loadSettings()
  local f = io.open(SETTINGS_FILE, "r")
  if not f then return end
  local byKey = {}
  for _, st in ipairs(SETTINGS) do byKey[st.key] = st end
  for line in f:lines() do
    local k, v = line:match("^([%w_]+)=(.*)$")
    local st = k and byKey[k]
    if st then
      if st.kind == "bool" then
        LC.config[k] = (v == "true")
      else
        local n = tonumber(v)
        if n then LC.config[k] = math.max(st.min, math.min(st.max, n)) end
      end
    end
  end
  f:close()
end

local function setSetting(key, value)
  LC.config[key] = value
  saveSettings()
end

local function maxLevel()
  return #LC.config.levelThresholds
end

local function levelForXp(xp)
  local lvl = 0
  for i, t in ipairs(LC.config.levelThresholds) do
    if xp >= t then lvl = i else break end
  end
  return lvl
end

local function fmtNum(v)
  if math.floor(v) == v then return tostring(v) end
  return string.format("%.1f", v)
end

---------------------------------------------------------------------------
-- Save / load (simple tab-separated file inside the mod folder)
---------------------------------------------------------------------------

local function saveData(force)
  if LC.saveId == nil then return end
  if not LC.dirty and not force then return end
  local f = io.open(saveFile(LC.saveId), "w")
  if not f then return end
  f:write("LIVINGCHROME\t1\n")
  for key, r in pairs(LC.data.implants) do
    local name = (tostring(r.name or key):gsub("[\t\r\n]", " "))
    f:write(table.concat({
      key,
      r.area or "",
      r.quirk or "clean",
      string.format("%.1f", r.xp or 0),
      tostring(r.level or 0),
      tostring(r.kills or 0),
      name,
      r.stable and "1" or "0",
    }, "\t"), "\n")
  end
  f:close()
  LC.dirty = false
end

local function readFile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local implants = {}
  local first = true
  for line in f:lines() do
    if first then
      first = false
    else
      local parts = {}
      for field in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(parts, field) end
      if #parts >= 7 and parts[1] ~= "" then
        local quirk = parts[3]
        if QUIRK_LABEL[quirk] == nil then quirk = "clean" end
        implants[parts[1]] = {
          area = parts[2],
          quirk = quirk,
          xp = tonumber(parts[4]) or 0,
          level = tonumber(parts[5]) or 0,
          kills = tonumber(parts[6]) or 0,
          name = parts[7],
          stable = parts[8] == "1",
        }
      end
    end
  end
  f:close()
  return implants
end

local function fileExists(path)
  local f = io.open(path, "r")
  if not f then return false end
  f:close()
  return true
end

local function copyFile(from, to)
  local src = io.open(from, "r")
  if not src then return false end
  local text = src:read("*a")
  src:close()
  local dst = io.open(to, "w")
  if not dst then return false end
  dst:write(text)
  dst:close()
  return true
end

---------------------------------------------------------------------------
-- Per-save ID (stored as a quest fact, so it lives inside the game save)
---------------------------------------------------------------------------

local function readSaveIdFact()
  return safe(function() return Game.GetQuestsSystem():GetFactStr(SAVE_ID_FACT) end)
end

-- A save only keeps its ID once the player saves the game. Until then, every
-- reload of that save would get a brand-new ID (and re-rolled quirks). So we
-- remember untagged saves by a fingerprint of the character as loaded, and
-- hand the same ID back if the exact same save is loaded again.
local PENDING_FILE = "living_chrome_pending_ids.txt"
local MAX_PENDING = 50

local function loadPending()
  local list = {}
  local f = io.open(PENDING_FILE, "r")
  if not f then return list end
  for line in f:lines() do
    local id, sig = line:match("^(%d+)\t(.+)$")
    if id then table.insert(list, { id = tonumber(id), sig = sig }) end
  end
  f:close()
  return list
end

local function savePending()
  local f = io.open(PENDING_FILE, "w")
  if not f then return end
  for _, e in ipairs(LC.pending) do f:write(e.id, "\t", e.sig, "\n") end
  f:close()
end

-- The ID made it into a save that was loaded again, so it no longer needs remembering
local function confirmPending(id)
  for i, e in ipairs(LC.pending) do
    if e.id == id then
      table.remove(LC.pending, i)
      savePending()
      return
    end
  end
end

-- Same save loaded twice => same lifepath, gender, level, street cred, money
-- and spot. Returns nil if the character can't be read yet.
local function characterSignature(player)
  local lifePath = safe(function()
    return tostring(PlayerDevelopmentSystem.GetInstance(player):GetLifePath(player))
  end)
  local gender = safe(function()
    local n = player:GetResolvedGenderName()
    return n.value or Game.NameToString(n)
  end)
  local stats = Game.GetStatsSystem()
  local eid = safe(function() return player:GetEntityID() end)
  local function stat(name)
    local v = safe(function()
      return stats:GetStatValue(eid, enumValue("gamedataStatType", name))
    end)
    return v and tostring(math.floor(v)) or "?"
  end
  local money = safe(function()
    return Game.GetTransactionSystem():GetItemQuantity(player,
      ItemID.FromTDBID(TweakDBID.new("Items.money")))
  end)
  local pos = safe(function()
    local p = player:GetWorldPosition()
    return string.format("%d,%d,%d", math.floor(p.x / 10), math.floor(p.y / 10), math.floor(p.z / 10))
  end)
  if lifePath == nil and gender == nil and money == nil then return nil end
  return table.concat({ tostring(lifePath), tostring(gender), stat("Level"),
    stat("StreetCred"), tostring(money), tostring(pos) }, "|")
end

-- Returns this playthrough's ID, creating one if it has none yet.
local function resolveSaveId(player)
  local id = readSaveIdFact()
  if id == nil then return nil end -- quest system not ready
  if id ~= 0 then
    confirmPending(id)
    return id
  end
  local sig = characterSignature(player)
  local reused = false
  if sig then
    for _, e in ipairs(LC.pending) do
      if e.sig == sig then
        id = e.id
        reused = true
        break
      end
    end
  end
  if not reused then id = math.random(1, 2147483646) end
  local ok = pcall(function() Game.GetQuestsSystem():SetFactStr(SAVE_ID_FACT, id) end)
  if not ok or readSaveIdFact() ~= id then return nil end
  if reused then
    print("[Living Chrome] Same save loaded again; keeping playthrough " .. id .. ".")
    return id
  end
  if sig then
    table.insert(LC.pending, { id = id, sig = sig })
    while #LC.pending > MAX_PENDING do table.remove(LC.pending, 1) end
    savePending()
  end
  -- First playthrough to get an ID after updating from v0.1.0 inherits the old
  -- shared progress; the old file is then retired so no other save copies it.
  if fileExists(LEGACY_FILE) and not fileExists(saveFile(id)) then
    if copyFile(LEGACY_FILE, saveFile(id)) and copyFile(LEGACY_FILE, LEGACY_DONE_FILE) then
      pcall(function() os.remove(LEGACY_FILE) end)
      print("[Living Chrome] Imported v0.1.0 progress into this playthrough.")
    end
  end
  return id
end

---------------------------------------------------------------------------
-- Implant records, XP and levels
---------------------------------------------------------------------------

local function rollQuirk()
  local r = math.random()
  if r < LC.config.glitchyChance then return "glitchy" end
  if r < LC.config.glitchyChance + LC.config.tunedChance then return "tuned" end
  return "clean"
end

local function onNewImplant(rec)
  if rec.quirk == "tuned" then
    notify(rec.name .. ": TUNED chrome. It learns fast.")
  elseif rec.quirk == "glitchy" then
    notify(rec.name .. ": GLITCHY chrome. Malfunctions until Lv " .. maxLevel() .. " or a ripperdoc stabilizes it.")
  else
    print("[Living Chrome] " .. rec.name .. ": clean chrome.")
  end
end

-- Glitchy chrome malfunctions until it hits max level or a ripperdoc stabilizes it
local function isUnstable(rec)
  return rec.quirk == "glitchy" and not rec.stable and (rec.level or 0) < maxLevel()
end

-- Extra bonus an implant gives once it reaches max level
local function masteryFor(rec)
  local area = AREA_BY_KEY[rec.area]
  if area == nil or area.mastery == nil or (rec.level or 0) < maxLevel() then return nil, 0 end
  return area.mastery.stat, area.mastery.value
end

local function masteryText(rec)
  local stat, v = masteryFor(rec)
  if stat == nil then return "" end
  return "+" .. fmtNum(v) .. (STAT_LABEL[stat] or (" " .. stat))
end

local function onLevelUp(rec)
  local full, short
  if rec.level >= maxLevel() then
    if rec.quirk == "glitchy" and not rec.stable then
      full = rec.name .. " MASTERED and STABILIZED: " .. masteryText(rec)
    else
      full = rec.name .. " MASTERED: " .. masteryText(rec)
    end
    short = rec.name .. " MASTERED"
  else
    full = rec.name .. " reached Lv " .. rec.level .. "!"
    short = rec.name .. " Lv " .. rec.level
  end
  print("[Living Chrome] " .. full)
  table.insert(LC.levelUps, { full = full, short = short })
end

local function getRecord(info)
  local rec = LC.data.implants[info.key]
  if rec == nil then
    rec = { name = info.name, area = info.area.key, xp = 0, level = 0, kills = 0, quirk = rollQuirk() }
    LC.data.implants[info.key] = rec
    LC.dirty = true
    onNewImplant(rec)
  end
  rec.name = info.name
  rec.area = info.area.key
  rec.key = info.key
  return rec
end

local function addXp(rec, amount)
  local mult = 1
  if rec.quirk == "tuned" then
    mult = LC.config.tunedXpMult
  elseif rec.quirk == "glitchy" then
    mult = LC.config.glitchyXpMult
  end
  rec.xp = (rec.xp or 0) + amount * mult
  local newLevel = levelForXp(rec.xp)
  if newLevel > (rec.level or 0) then
    rec.level = newLevel
    onLevelUp(rec)
    LC.needsReapply = true
  end
  LC.dirty = true
end

local function bonusFor(rec)
  local area = AREA_BY_KEY[rec.area]
  if area == nil or (rec.level or 0) <= 0 then return nil, 0 end
  local v = area.perLevel * rec.level
  if rec.quirk == "glitchy" then v = v * LC.config.glitchyBonusMult end
  return area.stat, v
end

---------------------------------------------------------------------------
-- Reading equipped cyberware
---------------------------------------------------------------------------

local function getEquipmentData(player)
  return safe(function()
    local es = Game.GetScriptableSystemsContainer():Get(CName.new("EquipmentSystem"))
    return es:GetPlayerData(player)
  end)
end

local function isValidItem(itemID)
  if itemID == nil then return false end
  local valid = safe(function() return ItemID.IsValid(itemID) end)
  if valid ~= nil then return valid end
  local hash = safe(function() return itemID.id.hash end)
  return hash ~= nil and hash ~= 0
end

local function baseId(idStr)
  local changed = true
  while changed do
    changed = false
    for _, pat in ipairs(TIER_PATTERNS) do
      local s, n = idStr:gsub(pat, "")
      if n > 0 and #s > #"Items." + 2 then
        idStr = s
        changed = true
        break
      end
    end
  end
  return idStr
end

-- Older versions stored some implants under tier-specific IDs. Merge them onto
-- the tier-free ID, keeping whichever record has more XP.
local function normalizeKeys(implants)
  local out, changed = {}, false
  for key, rec in pairs(implants) do
    local k = baseId(key)
    if k ~= key then changed = true end
    local existing = out[k]
    if existing == nil or (rec.xp or 0) > (existing.xp or 0) then out[k] = rec end
  end
  return out, changed
end

local function itemName(itemID, idStr)
  local name = safe(function()
    return Game.GetLocalizedTextByKey(TweakDB:GetRecord(itemID.id):DisplayName())
  end)
  if name == nil or name == "" then
    name = safe(function()
      return Game.GetLocalizedText(TweakDB:GetRecord(itemID.id):DisplayName())
    end)
  end
  if name == nil or name == "" then
    name = ((idStr or "Implant"):gsub("^Items%.", ""))
  end
  return name
end

local function scanEquipped(player)
  local found = {}
  local espd = getEquipmentData(player)
  if espd == nil then return found end

  for _, area in ipairs(AREAS) do
    local enum = enumValue("gamedataEquipmentArea", area.key)
    if enum ~= nil then
      local slots = safe(function() return espd:GetNumberOfSlots(enum, true) end)
        or safe(function() return espd:GetNumberOfSlots(enum) end)
        or 3
      if slots > 8 then slots = 8 end -- also covers extra slots from Cyberware-EX
      for i = 0, slots - 1 do
        local itemID = safe(function() return espd:GetItemInEquipSlot(enum, i) end)
        if isValidItem(itemID) then
          local idStr = safe(function() return TDBID.ToStringDEBUG(itemID.id) end)
          if idStr == nil or idStr == "" then idStr = "unknown_" .. area.key .. "_" .. i end
          local key = baseId(idStr)
          found[key] = { key = key, area = area, name = itemName(itemID, idStr) }
        end
      end
    end
  end
  return found
end

local function refreshEquipped(player)
  local found = scanEquipped(player)
  local changed = false
  for key in pairs(found) do
    if not LC.equipped[key] then changed = true end
  end
  for key in pairs(LC.equipped) do
    if not found[key] then changed = true end
  end
  for _, info in pairs(found) do getRecord(info) end
  LC.equipped = found
  if changed then LC.needsReapply = true end
end

---------------------------------------------------------------------------
-- Stat bonuses
---------------------------------------------------------------------------

local function clearModifiers(player)
  local eid = player and safe(function() return player:GetEntityID() end)
  if eid then
    local ss = Game.GetStatsSystem()
    for _, mod in ipairs(LC.applied) do
      pcall(function() ss:RemoveModifier(eid, mod) end)
    end
  end
  LC.applied = {}
end

local function applyModifiers(player)
  clearModifiers(player)
  local eid = safe(function() return player:GetEntityID() end)
  if not eid then return end
  local ss = Game.GetStatsSystem()
  local additive = enumValue("gameStatModifierType", "Additive")

  local function add(stat, v)
    local statEnum = enumValue("gamedataStatType", stat)
    local mod = safe(function() return Game.CreateStatModifier(statEnum, additive, v) end)
    if mod and pcall(function() ss:AddModifier(eid, mod) end) then
      table.insert(LC.applied, mod)
    end
  end

  for key in pairs(LC.equipped) do
    local rec = LC.data.implants[key]
    if rec then
      local stat, v = bonusFor(rec)
      if stat then add(stat, v) end
      local mstat, mv = masteryFor(rec)
      if mstat then add(mstat, mv) end
    end
  end
end

---------------------------------------------------------------------------
-- Malfunctions (Glitchy chrome)
---------------------------------------------------------------------------

local function unstableGlitchyEquipped()
  local list = {}
  for key in pairs(LC.equipped) do
    local r = LC.data.implants[key]
    if r and isUnstable(r) then
      table.insert(list, r)
    end
  end
  return list
end

local function setFact(name, value)
  pcall(function() Game.GetQuestsSystem():SetFactStr(name, value) end)
end

local function getFact(name)
  return safe(function() return Game.GetQuestsSystem():GetFactStr(name) end)
end

-- true / false, or nil if it can't be checked
local function playerHasEffect(player, effect)
  local id = safe(function() return TweakDBID.new(effect) end)
  if id == nil then return nil end
  local v = safe(function() return StatusEffectSystem.ObjectHasStatusEffect(player, id) end)
  if v == nil then
    v = safe(function() return Game.GetStatusEffectSystem():HasStatusEffect(player:GetEntityID(), id) end)
  end
  return v
end

-- Status effects are added/removed with a short delay, so we can't check the
-- result in the same frame. Apply exactly once (first method that works) and
-- verify removal on later frames (see tickGlitchRemoval).
local function applyGlitchEffect(player)
  local id = safe(function() return TweakDBID.new(LC.config.malfunctionEffect) end)
  if id == nil then return false, "bad effect id" end
  local ok, err = pcall(function() StatusEffectHelper.ApplyStatusEffect(player, id) end)
  if ok then return true end
  local ok2, err2 = pcall(function()
    Game.GetStatusEffectSystem():ApplyStatusEffect(player:GetEntityID(), id,
      player:GetRecordID(), player:GetEntityID())
  end)
  if ok2 then return true end
  return false, tostring(err) .. " | " .. tostring(err2)
end

local function removeGlitchNow(player)
  local id = safe(function() return TweakDBID.new(LC.config.malfunctionEffect) end)
  if id == nil or player == nil then return end
  local ok = pcall(function() StatusEffectHelper.RemoveStatusEffect(player, id) end)
  if not ok then
    pcall(function() Game.GetStatusEffectSystem():RemoveStatusEffect(player:GetEntityID(), id) end)
  end
end

-- Remove our glitch and keep checking until it's really gone. GLITCH_FACT
-- stays 1 until then, so if the game is saved meanwhile the next load cleans up.
local function requestGlitchRemoval(player)
  if player == nil then return end -- cleaned up on next load instead
  removeGlitchNow(player)
  LC.glitchRemoval = { wait = 1, tries = 1 }
end

local function tickGlitchRemoval(player, dt)
  local r = LC.glitchRemoval
  if r == nil then return end
  r.wait = r.wait - dt
  if r.wait > 0 then return end
  local has = playerHasEffect(player, LC.config.malfunctionEffect)
  if has == true and r.tries < 5 then
    removeGlitchNow(player)
    r.tries = r.tries + 1
    r.wait = 1
  elseif has == true then
    LC.glitchRemoval = nil
    print("[Living Chrome] Could not remove the malfunction screen effect. Run GetMod(\"LivingChrome\").clearGlitch()")
  else
    LC.glitchRemoval = nil
    setFact(GLITCH_FACT, 0)
  end
end

-- A save made during a malfunction still has our glitch effect on it.
-- The fact is only 1 if we added the effect, so this never touches the story's.
local function cleanupStaleGlitch(player)
  if getFact(GLITCH_FACT) == 1 and not LC.malfunction and not LC.glitchRemoval then
    print("[Living Chrome] Removing a leftover malfunction effect from this save.")
    requestGlitchRemoval(player)
  end
end

-- Temporary stat penalty; never saved (StatsSystem modifiers aren't persisted)
local function addTempModifier(player, stat, value)
  local eid = safe(function() return player:GetEntityID() end)
  if not eid then return nil end
  local mod = safe(function()
    return Game.CreateStatModifier(enumValue("gamedataStatType", stat),
      enumValue("gameStatModifierType", "Additive"), value)
  end)
  if mod and pcall(function() Game.GetStatsSystem():AddModifier(eid, mod) end) then return mod end
  return nil
end

-- Empty RAM or Stamina
local function drainPool(player, pool)
  LC.ignorePoolsUntil = LC.clock + 1.5 -- don't count our own drain as usage
  pcall(function()
    Game.GetStatPoolsSystem():RequestSettingStatPoolValue(player:GetEntityID(),
      enumValue("gamedataStatPoolType", pool), 0, player)
  end)
end

local function startMalfunction(player, rec)
  if LC.malfunction then return end
  local area = AREA_BY_KEY[rec.area or ""]
  local fault = FAULTS[area and area.fault or "optics"] or FAULTS.optics

  local mods = {}
  for _, m in ipairs(fault.mods) do
    local value = m[2]
    if value == "critPenalty" then value = LC.config.malfunctionCritPenalty end
    local mod = addTempModifier(player, m[1], value)
    if mod then table.insert(mods, mod) end
  end
  if fault.drain then drainPool(player, fault.drain) end

  -- Only add the screen glitch if we can confirm the player doesn't already
  -- have it from the story, so we never remove a quest's own effect.
  local effectOk = false
  local hasEffect = nil
  if fault.glitch and LC.config.screenGlitch and LC.config.malfunctionEffect ~= "" then
    hasEffect = playerHasEffect(player, LC.config.malfunctionEffect)
  end
  if hasEffect == false then
    setFact(GLITCH_FACT, 1)
    local err
    effectOk, err = applyGlitchEffect(player)
    if not effectOk then
      setFact(GLITCH_FACT, 0)
      print("[Living Chrome] Screen glitch failed: " .. tostring(err))
    end
  end
  print(string.format("[Living Chrome] Malfunction %s (glitch check=%s, applied=%s)",
    fault.label, tostring(hasEffect), tostring(effectOk)))
  LC.malfunction = {
    t = LC.config.malfunctionDuration,
    mods = mods,
    effect = effectOk and LC.config.malfunctionEffect or nil,
    name = rec.name,
    label = fault.label,
  }
  notify(rec.name .. ": " .. fault.label .. "!", true)
end

local function endMalfunction(player)
  local m = LC.malfunction
  if not m then return end
  LC.malfunction = nil
  if player then
    local eid = safe(function() return player:GetEntityID() end)
    if eid then
      for _, mod in ipairs(m.mods or {}) do
        pcall(function() Game.GetStatsSystem():RemoveModifier(eid, mod) end)
      end
    end
  end
  if m.effect then requestGlitchRemoval(player) end
end

local function maybeMalfunction(player)
  local list = unstableGlitchyEquipped()
  if #list == 0 or LC.malfunction then return end
  if math.random() < LC.config.malfunctionChance * #list then
    startMalfunction(player, list[math.random(#list)])
  end
end

---------------------------------------------------------------------------
-- Combat and kills
---------------------------------------------------------------------------

local function isInCombat(player)
  local v = safe(function() return player:IsInCombat() end)
  if v ~= nil then return v == true end
  v = safe(function()
    local bb = Game.GetBlackboardSystem():GetLocalInstanced(
      player:GetEntityID(), GetAllBlackboardDefs().PlayerStateMachine)
    return bb:GetInt(GetAllBlackboardDefs().PlayerStateMachine.Combat) == 1
  end)
  return v == true
end

local function isFighting(player)
  return isInCombat(player) or (LC.clock - LC.lastCombat) <= LC.config.killGraceSeconds
end

---------------------------------------------------------------------------
-- Usage XP: implants learn from doing their own job
---------------------------------------------------------------------------

local function awardUse(signal, amount)
  if amount <= 0 then return end
  amount = amount * LC.config.usageXpMult
  for key in pairs(LC.equipped) do
    local rec = LC.data.implants[key]
    local area = rec and AREA_BY_KEY[rec.area]
    if area and area.useSet[signal] then addXp(rec, amount) end
  end
end

local function poolPercent(player, pool)
  return safe(function()
    return Game.GetStatPoolsSystem():GetStatPoolValue(player:GetEntityID(),
      enumValue("gamedataStatPoolType", pool), true)
  end)
end

-- Compare RAM / Health / Stamina with the previous check; changes while
-- fighting become usage XP for the matching body areas.
local function tickUsage(player, fighting)
  local U = LC.config.usageXp
  local now = {
    Memory = poolPercent(player, "Memory"),
    Health = poolPercent(player, "Health"),
    Stamina = poolPercent(player, "Stamina"),
  }
  local prev = LC.pools
  LC.pools = now
  if not fighting or LC.clock < LC.ignorePoolsUntil then return end
  local function delta(pool)
    if now[pool] == nil or prev[pool] == nil then return 0 end
    return now[pool] - prev[pool]
  end
  local ram, hp, st = delta("Memory"), delta("Health"), delta("Stamina")
  if ram < 0 then awardUse("ram", -ram * U.ram) end
  if hp < 0 then awardUse("damage", -hp * U.damage) end
  if hp > 0 then awardUse("heal", hp * U.heal) end
  if st < 0 then awardUse("stamina", -st * U.stamina) end
end

-- Sandevistan / Berserk / Kerenzikov activations (status effects on V)
local function onPlayerEffect(evt)
  if LC.disabled or LC.saveId == nil then return end
  local player = getPlayer()
  if not player or not isFighting(player) then return end
  local id = safe(function() return TDBID.ToStringDEBUG(evt.staticData:GetID()) end)
  if id == nil then return end
  for _, a in ipairs(ACTIVATIONS) do
    if id:find(a.pattern, 1, true) then
      local last = LC.recentActivations[a.signal]
      if last == nil or LC.clock - last > 3 then
        LC.recentActivations[a.signal] = LC.clock
        awardUse(a.signal, LC.config.usageXp.activation)
        print("[Living Chrome] Implant activation: " .. id)
      end
      return
    end
  end
end

local function onNpcDeath(npc)
  if LC.disabled or LC.saveId == nil then return end
  local player = getPlayer()
  if not player then return end
  local h = entityHash(npc)
  if h == nil or h == entityHash(player) then return end

  local last = LC.recentKills[h]
  if last and LC.clock - last < 60 then return end -- already counted
  LC.recentKills[h] = LC.clock

  if not isFighting(player) then return end

  local dist = safe(function()
    return Vector4.Distance(player:GetWorldPosition(), npc:GetWorldPosition())
  end)
  if dist == nil or dist > LC.config.killRadius then return end

  for key in pairs(LC.equipped) do
    local rec = LC.data.implants[key]
    if rec then
      rec.kills = (rec.kills or 0) + 1
      addXp(rec, LC.config.xpPerKill)
    end
  end
  awardUse("kill", LC.config.usageXp.kill)
end

---------------------------------------------------------------------------
-- Ripperdoc services (paid in eddies while the ripperdoc screen is open)
---------------------------------------------------------------------------

local function moneyItem()
  return safe(function() return ItemID.FromTDBID(TweakDBID.new("Items.money")) end)
end

local function getMoney(player)
  local id = moneyItem()
  if id == nil then return nil end
  return safe(function() return Game.GetTransactionSystem():GetItemQuantity(player, id) end)
end

-- Takes the eddies; true only if the balance really went down
local function pay(player, amount)
  if amount <= 0 then return true end
  local before = getMoney(player)
  if before == nil or before < amount then return false end
  local id = moneyItem()
  pcall(function() Game.GetTransactionSystem():RemoveItem(player, id, amount) end)
  local after = getMoney(player)
  return after ~= nil and after <= before - amount
end

local function servicesOpen()
  return LC.atRipperdoc or LC.config.servicesAnywhere
end

local function stabilizeImplant(rec)
  local player = getPlayer()
  if not player or not servicesOpen() or not isUnstable(rec) then return end
  if not pay(player, LC.config.stabilizeCost) then
    notify("Not enough eddies to stabilize " .. rec.name .. ".", true)
    return
  end
  rec.stable = true
  LC.dirty = true
  saveData(true)
  notify(rec.name .. " STABILIZED by the ripperdoc. No more malfunctions.", true)
end

local function rerollImplant(rec)
  local player = getPlayer()
  if not player or not servicesOpen() then return end
  if not pay(player, LC.config.rerollCost) then
    notify("Not enough eddies to re-roll " .. rec.name .. ".", true)
    return
  end
  local old, new = rec.quirk, rec.quirk
  for _ = 1, 20 do
    new = rollQuirk()
    if new ~= old then break end
  end
  rec.quirk = new
  rec.stable = false
  LC.dirty = true
  LC.needsReapply = true
  saveData(true)
  notify(string.format("%s re-rolled: %s -> %s", rec.name,
    QUIRK_LABEL[old] or "?", QUIRK_LABEL[new] or "?"), true)
end

-- Tags shown after an implant's name
local function implantTags(r)
  local tags = ""
  if r.quirk == "glitchy" and not isUnstable(r) then tags = tags .. "  STABLE" end
  if (r.level or 0) >= maxLevel() then tags = tags .. "  MASTERED" end
  return tags
end

---------------------------------------------------------------------------
-- Console helpers: GetMod("LivingChrome").status() etc.
---------------------------------------------------------------------------

function LC.status()
  local list = equippedSorted()
  local lastQuirk = nil
  for _, r in ipairs(list) do
    if r.quirk ~= lastQuirk then
      lastQuirk = r.quirk
      print("[Living Chrome] -- " .. (QUIRK_LABEL[r.quirk] or "?") .. " --")
    end
    local stat, v = bonusFor(r)
    print(string.format("[Living Chrome] %s | %s | Lv %d | %d XP | %d kills | %s%s%s",
      r.name, QUIRK_LABEL[r.quirk] or "?", r.level or 0, math.floor(r.xp or 0), r.kills or 0,
      stat and ("+" .. fmtNum(v) .. STAT_LABEL[stat]) or "no bonus yet",
      masteryFor(r) and (" | mastery " .. masteryText(r)) or "", implantTags(r)))
  end
  if #list == 0 then print("[Living Chrome] No implants detected.") end
end

function LC.addXp(amount)
  amount = tonumber(amount) or 100
  for key in pairs(LC.equipped) do
    local rec = LC.data.implants[key]
    if rec then addXp(rec, amount) end
  end
  print("[Living Chrome] Added XP to equipped implants.")
end

-- Test a malfunction; kind = "optics", "cortex", "neural", "body" or "limbs"
function LC.forceMalfunction(kind)
  local player = getPlayer()
  if not player then return end
  if LC.malfunction then endMalfunction(player) end
  local rec
  if kind and FAULTS[kind] then
    for _, a in ipairs(AREAS) do
      if a.fault == kind then
        rec = { name = "Test " .. a.label, area = a.key }
        break
      end
    end
  else
    rec = unstableGlitchyEquipped()[1] or { name = "Test implant", area = "EyesCW" }
  end
  startMalfunction(player, rec)
end

-- Manual fix if the screen glitch ever gets stuck
function LC.clearGlitch()
  local player = getPlayer()
  if not player then return end
  for _ = 1, 5 do
    removeGlitchNow(player)
    pcall(function()
      Game.GetStatusEffectSystem():RemoveStatusEffect(player:GetEntityID(),
        TweakDBID.new(LC.config.malfunctionEffect))
    end)
  end
  LC.glitchRemoval = { wait = 1, tries = 3 } -- confirm it's gone, then clear the fact
  print("[Living Chrome] Screen glitch cleared.")
end

function LC.reset()
  LC.data.implants = {}
  LC.dirty = true
  LC.needsReapply = true
  saveData(true)
  print("[Living Chrome] Implant progress and quirks reset for this playthrough.")
end

-- Copy the old v0.1.0 shared progress into the current playthrough
function LC.importOld()
  if LC.saveId == nil then
    print("[Living Chrome] Load a save first.")
    return
  end
  local implants = readFile(LEGACY_DONE_FILE) or readFile(LEGACY_FILE)
  if implants == nil then
    print("[Living Chrome] No old v0.1.0 progress file found.")
    return
  end
  LC.data.implants = (normalizeKeys(implants))
  LC.dirty = true
  LC.needsReapply = true
  saveData(true)
  print("[Living Chrome] Imported old progress into this playthrough.")
end

---------------------------------------------------------------------------
-- Switching between playthroughs
---------------------------------------------------------------------------

-- Leaving a playthrough (main menu, loading screen, or another save loaded)
local function unloadSave(player)
  if LC.saveId == nil then return end
  endMalfunction(player)
  clearModifiers(player)
  saveData(true)
  LC.saveId = nil
  LC.data.implants = {}
  LC.equipped = {}
  LC.malfunction = nil
  LC.glitchRemoval = nil
  LC.combatAccum = 0
  LC.recentKills = {}
  LC.pools = {}
  LC.msgQueue = {}
  LC.levelUps = {}
end

-- Makes sure the loaded data belongs to the save the player is in.
-- Returns false while the save ID can't be read yet.
local function syncSave(player)
  local id = resolveSaveId(player)
  if id == nil then return false end
  if LC.checkSave then cleanupStaleGlitch(player) end
  if id == LC.saveId then return true end
  unloadSave(player)
  LC.saveId = id
  local implants, migrated = normalizeKeys(readFile(saveFile(id)) or {})
  LC.data.implants = implants
  LC.dirty = migrated
  LC.needsReapply = true
  LC.timers.scan = 2 -- scan equipped chrome right away
  print("[Living Chrome] Playthrough " .. id .. " loaded.")
  return true
end

-- Strip everything this mod put on the player so the current save is clean.
-- Afterwards: save the game, quit, delete the LivingChrome folder.
function LC.uninstall()
  local player = getPlayer()
  unloadSave(player)
  if player and getFact(GLITCH_FACT) == 1 then
    for _ = 1, 3 do removeGlitchNow(player) end
    setFact(GLITCH_FACT, 0)
  end
  LC.glitchRemoval = nil
  LC.disabled = true
  print("[Living Chrome] Disabled. Bonuses and effects removed from V.")
  print("[Living Chrome] Now save your game, quit, and delete the LivingChrome mod folder.")
  notify("Living Chrome removed. Save, quit, delete the mod folder.", true)
end

---------------------------------------------------------------------------
-- Settings menus
---------------------------------------------------------------------------

-- Adds a Living Chrome tab to the game's Settings menu if the optional
-- Native Settings UI mod is installed. Returns true if it was added.
local function registerNativeSettings()
  local ns = safe(function() return GetMod("nativeSettings") end)
  if ns == nil then return false end
  return pcall(function()
    ns.addTab("/livingchrome", "Living Chrome")
    ns.addSubcategory("/livingchrome/main", "Living Chrome " .. LC.version)
    for _, st in ipairs(SETTINGS) do
      local cb = function(v) setSetting(st.key, v) end
      if st.kind == "bool" then
        ns.addSwitch("/livingchrome/main", st.label, st.label, LC.config[st.key], DEFAULTS[st.key], cb)
      elseif st.kind == "int" then
        ns.addRangeInt("/livingchrome/main", st.label, st.label, st.min, st.max, st.step or 1,
          math.floor(LC.config[st.key]), DEFAULTS[st.key], cb)
      else
        ns.addRangeFloat("/livingchrome/main", st.label, st.label, st.min, st.max,
          (st.max - st.min) / 100, st.fmt, LC.config[st.key], DEFAULTS[st.key], cb)
      end
    end
  end)
end

-- Same settings inside the Living Chrome overlay window
local function drawSettings()
  if not ImGui.CollapsingHeader("Settings") then return end
  for _, st in ipairs(SETTINGS) do
    local v, changed = LC.config[st.key], false
    if st.kind == "bool" then
      v, changed = ImGui.Checkbox(st.label, v)
    elseif st.kind == "int" then
      v, changed = ImGui.SliderInt(st.label, math.floor(v), st.min, st.max)
    else
      v, changed = ImGui.SliderFloat(st.label, v, st.min, st.max, st.fmt)
    end
    if changed then setSetting(st.key, v) end
  end
  if ImGui.Button("Reset settings to defaults") then
    for _, st in ipairs(SETTINGS) do LC.config[st.key] = DEFAULTS[st.key] end
    saveSettings()
  end
end

---------------------------------------------------------------------------
-- CET events
---------------------------------------------------------------------------

registerForEvent("onInit", function()
  math.randomseed(os.time())
  LC.pending = loadPending()
  loadSettings()

  -- A save was loaded / player respawned: old modifiers are gone, re-add ours
  pcall(function()
    Observe("PlayerPuppet", "OnGameAttached", function()
      LC.applied = {}
      LC.malfunction = nil
      LC.glitchRemoval = nil
      LC.pools = {}
      LC.needsReapply = true
      LC.checkSave = true
    end)
  end)

  -- Kill / takedown detection (duplicates are filtered in onNpcDeath)
  pcall(function()
    ObserveAfter("NPCPuppet", "SendAfterDeathOrDefeatEvent", function(self) onNpcDeath(self) end)
  end)
  pcall(function()
    Observe("NPCPuppet", "OnDeath", function(self) onNpcDeath(self) end)
  end)

  -- Sandevistan / Berserk / Kerenzikov activations, for usage XP
  pcall(function()
    Observe("PlayerPuppet", "OnStatusEffectApplied", function(_, evt) onPlayerEffect(evt) end)
  end)

  -- Ripperdoc screen open / closed, for ripperdoc services
  pcall(function()
    Observe("RipperDocGameController", "OnInitialize", function() LC.atRipperdoc = true end)
  end)
  pcall(function()
    Observe("RipperDocGameController", "OnUninitialize", function() LC.atRipperdoc = false end)
  end)

  if registerNativeSettings() then
    print("[Living Chrome] Settings added to the game's Settings menu.")
  end

  print("[Living Chrome] v" .. LC.version .. " loaded.")
end)

registerForEvent("onUpdate", function(dt)
  if LC.disabled then return end
  LC.clock = LC.clock + dt
  local player = getPlayer()
  if player == nil then
    unloadSave(nil) -- main menu / loading screen
    LC.checkSave = true
    return
  end

  local T = LC.timers
  T.saveCheck = (T.saveCheck or 0) + dt
  if LC.checkSave or LC.saveId == nil or T.saveCheck >= 5 then
    T.saveCheck = 0
    if not syncSave(player) then return end
    LC.checkSave = false
  end

  pumpMessages(dt)

  T.usage = T.usage + dt
  if T.usage >= 0.5 then
    T.usage = 0
    tickUsage(player, isFighting(player))
  end

  T.scan = T.scan + dt
  T.combat = T.combat + dt
  T.reapply = T.reapply + dt
  T.save = T.save + dt

  if LC.malfunction then
    LC.malfunction.t = LC.malfunction.t - dt
    if LC.malfunction.t <= 0 then endMalfunction(player) end
  end
  tickGlitchRemoval(player, dt)

  if T.scan >= 2 then
    T.scan = 0
    refreshEquipped(player)
  end

  if T.combat >= 1 then
    local secs = T.combat
    T.combat = 0
    if isInCombat(player) then
      LC.lastCombat = LC.clock
      for key in pairs(LC.equipped) do
        local rec = LC.data.implants[key]
        if rec then addXp(rec, secs * LC.config.xpPerCombatSecond) end
      end
      LC.combatAccum = LC.combatAccum + secs
      if LC.combatAccum >= LC.config.malfunctionCheckEvery then
        LC.combatAccum = 0
        maybeMalfunction(player)
      end
    end
  end

  if LC.needsReapply or T.reapply >= LC.config.reapplyEvery then
    T.reapply = 0
    LC.needsReapply = false
    applyModifiers(player)
  end

  if T.save >= LC.config.saveEvery then
    T.save = 0
    saveData(false)
    -- keep the kill-dedupe table small
    for h, t in pairs(LC.recentKills) do
      if LC.clock - t > 120 then LC.recentKills[h] = nil end
    end
  end
end)

registerForEvent("onShutdown", function()
  if LC.disabled then return end
  unloadSave(getPlayer())
end)

registerForEvent("onOverlayOpen", function() LC.overlayOpen = true end)
registerForEvent("onOverlayClose", function() LC.overlayOpen = false end)

registerForEvent("onDraw", function()
  if not LC.overlayOpen then return end
  if ImGui.Begin("Living Chrome") then
    local list = equippedSorted()
    local services = servicesOpen() and LC.saveId ~= nil
    if services then
      local player = getPlayer()
      local money = player and getMoney(player)
      ImGui.TextColored(1, 0.8, 0.2, 1, "RIPPERDOC SERVICES" ..
        (money and string.format("   (you have %d eddies)", money) or ""))
      ImGui.Text(string.format("Stabilize a Glitchy implant: %d   Re-roll a quirk: %d",
        LC.config.stabilizeCost, LC.config.rerollCost))
      ImGui.Separator()
    end
    ImGui.Text("Equipped implants")
    ImGui.Separator()
    local lastQuirk = nil
    for _, r in ipairs(list) do
      if r.quirk ~= lastQuirk then
        lastQuirk = r.quirk
        local c = QUIRK_COLOR[r.quirk] or { 1, 1, 1 }
        ImGui.Spacing()
        ImGui.TextColored(c[1], c[2], c[3], 1, string.upper(QUIRK_LABEL[r.quirk] or "?"))
      end
      local area = AREA_BY_KEY[r.area]
      ImGui.Text(string.format("%s  (%s)  Lv %d", r.name, area and area.label or "?", r.level or 0))
      local tags = implantTags(r)
      if tags ~= "" then
        ImGui.SameLine()
        ImGui.TextColored(0.9, 0.75, 0.3, 1, tags)
      end
      local lvl = r.level or 0
      local frac, label = 1, "MAX"
      if lvl < maxLevel() then
        local prev = (lvl == 0) and 0 or LC.config.levelThresholds[lvl]
        local nxt = LC.config.levelThresholds[lvl + 1]
        frac = math.max(0, math.min(1, ((r.xp or 0) - prev) / (nxt - prev)))
        label = string.format("%d / %d XP", math.floor(r.xp or 0), nxt)
      end
      ImGui.ProgressBar(frac, -1, 0, label)
      local stat, v = bonusFor(r)
      if stat then
        ImGui.Text("  +" .. fmtNum(v) .. STAT_LABEL[stat] .. "   Kills: " .. (r.kills or 0))
      else
        ImGui.Text("  No bonus yet   Kills: " .. (r.kills or 0))
      end
      if masteryFor(r) then
        ImGui.TextColored(0.9, 0.75, 0.3, 1, "  Mastery: " .. masteryText(r))
      end
      if services and r.key then
        if isUnstable(r) then
          if ImGui.Button("Stabilize##s" .. r.key) then stabilizeImplant(r) end
          ImGui.SameLine()
        end
        if ImGui.Button("Re-roll quirk##r" .. r.key) then rerollImplant(r) end
      end
      ImGui.Spacing()
    end
    if #list == 0 then
      ImGui.Text(LC.saveId and "No implants detected yet." or "Load a save to see your chrome.")
    end
    if LC.malfunction then
      ImGui.Separator()
      ImGui.TextColored(1, 0.3, 0.3, 1, "MALFUNCTION: " .. (LC.malfunction.name or "?") ..
        " - " .. (LC.malfunction.label or ""))
    end
    ImGui.Separator()
    drawSettings()
  end
  ImGui.End()
end)

registerHotkey("LivingChromeStatus", "Show implant status", function()
  local n, total = 0, 0
  for key in pairs(LC.equipped) do
    local r = LC.data.implants[key]
    if r then
      n = n + 1
      total = total + (r.level or 0)
    end
  end
  if n == 0 then
    notify("No implants detected")
  else
    notify(string.format("Chrome: %d implants, average Lv %.1f", n, total / n))
  end
  LC.status()
end)

return LC
