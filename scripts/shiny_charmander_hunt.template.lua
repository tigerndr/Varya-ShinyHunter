-- Varya-ShinyHunter: FireRed US shiny Charmander soft-reset lane
-- Full soft reset (A+B+Start+Select) → Continue → rightmost ball → Gen3 shiny check.
-- Isolation: bake HUNT_DIR / INST / FARM_STOP via tools/generate_lanes.sh before load.
-- US FireRed party slot 0 @ 0x02024284 (PID +0, OTID +4, encrypted data +32).
-- Shiny iff (TID ^ SID ^ PID_hi ^ PID_lo) < 8.
-- Do NOT load this .template.lua in mGBA — placeholders are syntax errors until baked.

local INST = __INST__
local HUNT_DIR = "__HUNT_DIR__"
local FARM_STOP = "__FARM_STOP__"
local STOP_PATH = HUNT_DIR .. "/STOP"
local FOUND_PATH = HUNT_DIR .. "/SHINY_FOUND"
local STATUS_PATH = HUNT_DIR .. "/hunt_status.txt"
local PID_LOG = HUNT_DIR .. "/pid_log.txt"
local PARTY0 = 0x02024284
local SPECIES_CHARMANDER = 4
local recent = {}
local cycle = 0
local running = true
local empty_streak = 0
local wrong_species_streak = 0

-- Portable 32-bit XOR (mGBA Lua may be 5.2 — no bitwise ~ / &)
local function bxor(a, b)
  local r, bit = 0, 1
  a = math.floor(a) % 4294967296
  b = math.floor(b) % 4294967296
  while a > 0 or b > 0 do
    local abit, bbit = a % 2, b % 2
    if abit ~= bbit then r = r + bit end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return r
end

local function band(a, b)
  local r, bit = 0, 1
  a = math.floor(a) % 4294967296
  b = math.floor(b) % 4294967296
  while a > 0 and b > 0 do
    if (a % 2 == 1) and (b % 2 == 1) then r = r + bit end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return r
end

-- Growth-block order for personality % 24 (G=Growth)
local ORDERS = {
  "GAEM","GAME","GEAM","GEMA","GMAE","GMEA",
  "AGEM","AGME","AEGM","AEMG","AMGE","AMEG",
  "EGAM","EGMA","EAGM","EAMG","EMGA","EMAG",
  "MGAE","MGEA","MAGE","MAEG","MEGA","MEAG",
}

local function readSpeciesParty0(pid, otid)
  -- Encrypted 48-byte region at +32; key = pid xor otid; word-wise XOR
  local key = bxor(pid, otid)
  local words = {}
  for i = 0, 11 do
    words[i + 1] = bxor(emu:read32(PARTY0 + 32 + i * 4), key)
  end
  local order = ORDERS[(pid % 24) + 1]
  local gpos = order:find("G") -- 1..4
  local base = (gpos - 1) * 3 -- 0-based index into words (3 words per block)
  local w0 = words[base + 1]
  -- species is little-endian u16 at start of growth
  return band(w0, 0xFFFF)
end

local function log(msg)
  console:log(string.format("[inst%d] %s", INST, msg))
  local f = io.open(STATUS_PATH, "w")
  if f then
    f:write(string.format("inst=%d\n%s\ncycle=%d\n", INST, msg, cycle))
    if #recent > 0 then
      f:write("recent_pids=")
      for j, p in ipairs(recent) do
        if j > 1 then f:write(",") end
        f:write(p)
      end
      f:write("\n")
    end
    f:close()
  end
end

local function pushRecent(pid)
  table.insert(recent, string.format("%08X", pid))
  while #recent > 5 do table.remove(recent, 1) end
end

local function appendPid(pid, otid, xor_value, shiny, species)
  local f = io.open(PID_LOG, "a")
  if f then
    f:write(string.format("cycle=%d pid=%08X otid=%08X xor=%s shiny=%s species=%s\n",
      cycle, pid or 0, otid or 0, tostring(xor_value), tostring(shiny), tostring(species or -1)))
    f:close()
  end
end

local function shouldStop()
  local f = io.open(STOP_PATH, "r")
  if f then f:close(); return true end
  f = io.open(FARM_STOP, "r")
  if f then f:close(); return true end
  return false
end

local function press(keys, frames)
  frames = frames or 2
  emu:setKeys(0)
  for _, k in ipairs(keys) do emu:addKey(k) end
  for _ = 1, frames do
    if shouldStop() then return end
    emu:runFrame()
  end
  emu:setKeys(0)
  for _ = 1, 3 do emu:runFrame() end
end

local function waitFrames(n)
  for _ = 1, n do
    if shouldStop() then return end
    emu:runFrame()
  end
end

local function tap(key, hold, gap)
  hold = hold or 3
  gap = gap or 12
  press({key}, hold)
  waitFrames(gap)
end

local function mashA(n)
  for _ = 1, n do tap(C.GBA_KEY.A, 2, 6) end
end

local function softReset()
  log("Soft resetting...")
  emu:setKeys(0)
  emu:addKey(C.GBA_KEY.A)
  emu:addKey(C.GBA_KEY.B)
  emu:addKey(C.GBA_KEY.START)
  emu:addKey(C.GBA_KEY.SELECT)
  for _ = 1, 70 do
    if shouldStop() then
      emu:setKeys(0)
      return
    end
    emu:runFrame()
  end
  emu:setKeys(0)
  waitFrames(120)
end

local function isShinyParty0()
  local pid = emu:read32(PARTY0)
  local otid = emu:read32(PARTY0 + 4)
  if pid == 0 and otid == 0 then return false, pid, otid, nil, true, 0 end
  local tid = otid % 65536
  local sid = math.floor(otid / 65536) % 65536
  local p_low = pid % 65536
  local p_high = math.floor(pid / 65536) % 65536
  local xor_value = bxor(bxor(tid, sid), bxor(p_low, p_high))
  local species = readSpeciesParty0(pid, otid)
  return xor_value < 8, pid, otid, xor_value, false, species
end

local function bootToLab()
  log("Booting to lab via Continue...")
  waitFrames(160)
  for _ = 1, 12 do tap(C.GBA_KEY.START, 4, 40) end
  waitFrames(50)
  tap(C.GBA_KEY.A, 3, 20)
  tap(C.GBA_KEY.A, 3, 40)
  waitFrames(60)
  mashA(160)
  waitFrames(80)
  for _ = 1, 8 do tap(C.GBA_KEY.B, 3, 10) end
  waitFrames(40)
end

local function walkToRightBall()
  log("Walk to rightmost Charmander ball...")
  for _ = 1, 5 do tap(C.GBA_KEY.UP, 4, 8) end
  waitFrames(15)
  tap(C.GBA_KEY.RIGHT, 6, 20)
  waitFrames(15)
  tap(C.GBA_KEY.UP, 4, 15)
  waitFrames(20)
end

local function takeCharmander()
  walkToRightBall()
  tap(C.GBA_KEY.A, 3, 40)
  waitFrames(30)
  tap(C.GBA_KEY.A, 3, 40)
  waitFrames(30)
  tap(C.GBA_KEY.A, 3, 50)
  waitFrames(40)
  mashA(40)
  waitFrames(30)
  tap(C.GBA_KEY.B, 4, 30)
  waitFrames(20)
  mashA(20)
  waitFrames(120)
end

local function saveGame()
  log("Saving after shiny...")
  for _ = 1, 6 do tap(C.GBA_KEY.B, 3, 10) end
  waitFrames(20)
  tap(C.GBA_KEY.START, 4, 40)
  for _ = 1, 6 do tap(C.GBA_KEY.DOWN, 3, 12) end
  tap(C.GBA_KEY.UP, 3, 12)
  tap(C.GBA_KEY.UP, 3, 12)
  tap(C.GBA_KEY.A, 4, 50)
  tap(C.GBA_KEY.UP, 2, 10)
  tap(C.GBA_KEY.A, 4, 80)
  mashA(25)
  waitFrames(40)
  for _ = 1, 5 do tap(C.GBA_KEY.B, 3, 10) end
  log("Battery save attempted (menu walk; confirm in-game if unsure)")
end

local function onShiny(pid, otid, xor_value, species)
  local f = io.open(FOUND_PATH, "w")
  if f then
    f:write("shiny=Charmander\nnotify=1\n")
    f:write(string.format("inst=%d\ncycle=%d\npid=%08X\notid=%08X\nxor=%d\nspecies=%d\nsaved=pending\n",
      INST, cycle, pid, otid, xor_value, species))
    f:close()
  end
  emu:screenshot(HUNT_DIR .. string.format("/shiny_Charmander_%d.png", cycle))
  saveGame()
  local f2 = io.open(FOUND_PATH, "w")
  if f2 then
    f2:write("shiny=Charmander\nnotify=1\n")
    -- saved=1 means we ran the save menu walk; verify battery.sav mtime yourself if paranoid
    f2:write(string.format("inst=%d\ncycle=%d\npid=%08X\notid=%08X\nxor=%d\nspecies=%d\nsaved=1\n",
      INST, cycle, pid, otid, xor_value, species))
    f2:close()
  end
  emu:screenshot(HUNT_DIR .. string.format("/shiny_Charmander_%d_saved.png", cycle))
  local fa = io.open(FARM_STOP, "w")
  if fa then fa:write(string.format("hit=inst%d\n", INST)); fa:close() end
  log("SHINY CHARMANDER FOUND + SAVE ATTEMPTED; wrote STOP_ALL")
end

local function oneCycle()
  softReset()
  if shouldStop() then return false end
  bootToLab()
  if shouldStop() then return false end
  log(string.format("cycle %d: take right-ball Charmander", cycle))
  takeCharmander()
  local shiny, pid, otid, xor_value, empty, species = isShinyParty0()
  if empty then
    empty_streak = empty_streak + 1
    log(string.format("EMPTY PARTY streak=%d", empty_streak))
    appendPid(0, 0, -1, "empty", 0)
    if empty_streak >= 8 then
      log("ERROR: 8 empty parties — stopping this lane")
      running = false
    end
    return false
  end
  empty_streak = 0
  if species ~= SPECIES_CHARMANDER then
    wrong_species_streak = wrong_species_streak + 1
    pushRecent(pid)
    appendPid(pid, otid, xor_value, shiny, species)
    log(string.format("WRONG SPECIES id=%d (want Charmander=4) streak=%d pid=%08X",
      species, wrong_species_streak, pid))
    if wrong_species_streak >= 8 then
      log("ERROR: 8 wrong-species takes — stopping this lane (pathing)")
      running = false
    end
    return false
  end
  wrong_species_streak = 0
  pushRecent(pid)
  appendPid(pid, otid, xor_value, shiny, species)
  log(string.format("Charmander pid=%08X xor=%d species=%d shiny=%s", pid, xor_value, species, tostring(shiny)))
  if shiny then
    onShiny(pid, otid, xor_value, species)
    return true
  end
  return false
end

log("Farm inst " .. INST .. " start — HUNT_DIR=" .. HUNT_DIR)
do
  local f = io.open(PID_LOG, "a")
  if f then f:write("--- inst " .. INST .. " start ---\n"); f:close() end
end

while running do
  if shouldStop() then log("STOP/STOP_ALL"); break end
  cycle = cycle + 1
  log(string.format("=== soft-reset cycle %d ===", cycle))
  if oneCycle() then break end
end
log("Hunt finished")
