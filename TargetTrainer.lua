<<<<<<< HEAD
-- Respect the user's real keybinds:
--   Target Party Member 1..4  -> Tank/DPS1/DPS2/DPS3
--   Target Self               -> Self
-- We bind clicks ONLY to those keys while the trainer is visible.

local f = CreateFrame("Frame", "TargetTrainerFrame", UIParent, "BackdropTemplate")
f:SetSize(360, 200)
f:SetPoint("CENTER")
f:EnableMouse(true)
f:EnableMouseWheel(true)

-- Title (also acts as drag handle with SHIFT)
local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 10, -10)
title:SetText("Target Trainer")

-- Make frame movable by dragging the title with Shift
f:SetMovable(true)
title:EnableMouse(true)
title:SetScript("OnMouseDown", function(_, button)
  if button == "LeftButton" and IsShiftKeyDown() then
    f:StartMoving()
  end
end)
title:SetScript("OnMouseUp", function(_, button)
  if button == "LeftButton" then
    f:StopMovingOrSizing()
    -- Save position (optional)
    TargetTrainerDB = TargetTrainerDB or {}
    local point, _, _, x, y = f:GetPoint()
    TargetTrainerDB.point, TargetTrainerDB.x, TargetTrainerDB.y = point, x, y
  end
end)

-- Restore saved position + settings
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
  TargetTrainerDB = TargetTrainerDB or {}

  -- restore frame position
  if TargetTrainerDB.point then
    f:ClearAllPoints()
    f:SetPoint(TargetTrainerDB.point, UIParent, TargetTrainerDB.point, TargetTrainerDB.x or 0, TargetTrainerDB.y or 0)
  end

  -- restore layout
  if TargetTrainerDB.layout then
    layoutMode = TargetTrainerDB.layout
    LayoutFrames()
  end

  -- restore hardcore toggle
  if TargetTrainerDB.hardcore ~= nil then
    hardcore = TargetTrainerDB.hardcore
  end
  
  -- in PLAYER_LOGIN restore:
  TargetTrainerDB = TargetTrainerDB or {}
  TargetTrainerDB.leaderboard = TargetTrainerDB.leaderboard or {}
end)

-- =========================
-- Party-style stacked frames
-- =========================
local partyFrames = {}
local labels = {"Tank", "Self", "DPS1", "DPS2", "DPS3"}

-- colors (approx role vibes)
local slotColors = {
  {r=0.25, g=0.78, b=0.92}, -- tank-ish
  {r=0.92, g=0.52, b=0.52}, -- self/red
  {r=0.95, g=0.77, b=0.36}, -- dps gold
  {r=0.60, g=0.95, b=0.60}, -- dps green
  {r=0.60, g=0.77, b=1.00}, -- dps blue
}

local ROW_W, ROW_H, ROW_GAP = 180, 80, 6

-- Layout mode + padding around the bars (room for the title at the top)
local layoutMode = "vertical"  -- or "horizontal"

local PAD_L, PAD_R = 10, 10
local PAD_T, PAD_B = 40, 10    -- ~40 leaves room for the "Target Trainer" title

-- Group container that holds the player frames
local content = CreateFrame("Frame", "TargetTrainerContent", f)
content:SetPoint("TOPLEFT", f, "TOPLEFT", PAD_L, -PAD_T)
content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD_R, PAD_B)

-- Recompute container size based on layout & number of frames.
local function ResizeContainer()
  local n = #partyFrames
  if n == 0 then return end

  local width, height
  if layoutMode == "vertical" then
    width  = PAD_L + ROW_W + PAD_R
    height = PAD_T + (n * ROW_H) + ((n - 1) * ROW_GAP) + PAD_B
  else
    width  = PAD_L + (n * ROW_W) + ((n - 1) * ROW_GAP) + PAD_R
    height = PAD_T + ROW_H + PAD_B
  end

  f:SetSize(width, height)
  -- content auto-fills via its TOPLEFT/BOTTOMRIGHT anchors set above
end

-- ===== HUD TEXTS (define early) =====
local scoreText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
local levelText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
local progressText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

-- Re-anchor the HUD texts after the container resizes / layout changes
local function LayoutHUD()
  scoreText:ClearAllPoints()
  levelText:ClearAllPoints()
  progressText:ClearAllPoints()

  -- anchor to the content group so it follows the bars
  scoreText:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 50)
  levelText:SetPoint("TOPRIGHT", scoreText, "BOTTOMRIGHT", 0, -4)
  progressText:SetPoint("TOPRIGHT", levelText, "BOTTOMRIGHT", 0, -4)
end

-- ===== Drag & Auto-Align support =====
local displayOrder = {}  -- which button index occupies row 1..N

local function LayoutFrames()
  ResizeContainer()
  for row, idx in ipairs(displayOrder) do
    local btn = partyFrames[idx]
    btn:ClearAllPoints()
    if layoutMode == "vertical" then
      btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, - (row - 1) * (ROW_H + ROW_GAP))
    else
      btn:SetPoint("TOPLEFT", content, "TOPLEFT", (row - 1) * (ROW_W + ROW_GAP), 0)
    end
    btn:SetFrameStrata("MEDIUM")
  end
  -- ensure HUD snaps to new size/position
  LayoutHUD()
end

local function RecomputeOrder()
  local arr = {}
  for idx, btn in ipairs(partyFrames) do
    local x, y = btn:GetCenter()
    table.insert(arr, { idx = idx, x = x or 0, y = y or 0 })
  end

  if layoutMode == "vertical" then
    table.sort(arr, function(a, b) return a.y > b.y end)   -- top to bottom
  else
    table.sort(arr, function(a, b) return a.x < b.x end)   -- left to right
  end

  wipe(displayOrder)
  for row, e in ipairs(arr) do displayOrder[row] = e.idx end
  LayoutFrames()
end

-- =========================
-- Party-style stacked frames (draggable)
-- =========================
for i = 1, #labels do
  local btn = CreateFrame("Button", "TTButton"..i, f, "SecureActionButtonTemplate")
  btn:SetSize(ROW_W, ROW_H)
  btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, - (i - 1) * (ROW_H + ROW_GAP))
  
  -- outer border
  btn.bg = CreateFrame("Frame", nil, btn, "BackdropTemplate")
  btn.bg:SetAllPoints()
  btn.bg:SetBackdrop({
    bgFile   = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 14,
    insets   = {left=3,right=3,top=3,bottom=3}
  })
  btn.bg:SetBackdropColor(0,0,0,0.55)

  -- statusbar
  local sb = CreateFrame("StatusBar", nil, btn)
  sb:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  sb:SetMinMaxValues(0,100)
  sb:SetValue(100)
  sb:SetPoint("TOPLEFT", 4, -4)
  sb:SetPoint("BOTTOMRIGHT", -4, 4)
  sb:SetStatusBarColor(slotColors[i].r, slotColors[i].g, slotColors[i].b)

  local bg = sb:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface/Buttons/WHITE8x8")
  bg:SetVertexColor(0,0,0,0.35)

  local nameFS = sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  nameFS:SetPoint("TOPLEFT", 6, -4)
  nameFS:SetText(("*%s"):format(labels[i]))

  local pctFS = sb:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  pctFS:SetPoint("CENTER")
  pctFS:SetText("100%")

  -- === MATCHING-BORDER HIGHLIGHT (replaces your old tint/hl/pulse) ===

-- (optional) a very light red wash inside the bar
local tint = btn:CreateTexture(nil, "BORDER", nil, 1)
tint:SetAllPoints(btn._sb or btn)
tint:SetTexture("Interface/Buttons/WHITE8x8")
tint:SetVertexColor(1, 0, 0, 0.12) -- subtle; raise to 0.18–0.25 if you want more fill
tint:Hide()

-- border frame that uses the SAME border art/size as your normal frame (btn.bg)
local hl = CreateFrame("Frame", nil, btn, "BackdropTemplate")
hl:SetPoint("TOPLEFT", btn.bg, "TOPLEFT", 0, 0)          -- no offset so it matches exactly
hl:SetPoint("BOTTOMRIGHT", btn.bg, "BOTTOMRIGHT", 0, 0)
hl:SetBackdrop({
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  edgeSize = 40,                                          -- must match btn.bg edgeSize
  insets   = { left = 3, right = 3, top = 3, bottom = 3 } -- must match btn.bg insets
})
hl:ClearAllPoints()
hl:SetPoint("TOPLEFT",  btn.bg, "TOPLEFT",  -10,  10)
hl:SetPoint("BOTTOMRIGHT", btn.bg, "BOTTOMRIGHT",  10, -10)

hl:SetBackdropColor(0, 0, 0, 0)
hl:SetBackdropBorderColor(1, 0.15, 0.15, 1)               -- bright red border
hl:Hide()

-- pulse the highlight (alpha on the border frame)
local pulse = hl:CreateAnimationGroup()
local a1 = pulse:CreateAnimation("Alpha"); a1:SetFromAlpha(0.45); a1:SetToAlpha(1.0); a1:SetDuration(0.25); a1:SetOrder(1)
local a2 = pulse:CreateAnimation("Alpha"); a2:SetFromAlpha(1.0); a2:SetToAlpha(0.45); a2:SetDuration(0.25); a2:SetOrder(2)
pulse:SetLooping("REPEAT")
pulse:SetToFinalAlpha(true)
pulse:SetScript("OnPlay", function() hl:Show(); tint:Show() end)
pulse:SetScript("OnStop", function() hl:Hide(); tint:Hide() end)

-- store refs (keep your existing names consistent)
btn._tint, btn._highlight, btn._pulse = tint, hl, pulse

  -- SHIFT + drag to reorder
  btn:SetMovable(true)
  btn:RegisterForDrag("LeftButton")
  btn:SetClampedToScreen(true)
  btn:SetScript("OnDragStart", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() then
      self:StartMoving()
      self:SetFrameStrata("DIALOG")
    end
  end)
  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetFrameStrata("MEDIUM")
    RecomputeOrder()
  end)

  partyFrames[i] = btn
  displayOrder[i] = i
end

-- Initial layout AFTER the loop (LayoutHUD is already defined)
LayoutFrames()

-- ===== STATE =====
local currentTarget = nil
local interval      = 3.0
local ticker
local running       = false

local score         = 0
local attempts      = 0
local level         = 1
local correctHits   = 0
-- ===== HARDCORE MODE =====
local hardcore = false          -- toggled via /tt hardcore
local baseInterval = 3.0        -- your starting speed

-- ===== UPDATERS =====
local function UpdateScore()
  scoreText:SetText(string.format("Score: %d / %d", score, attempts))
end
local function UpdateLevel()
  levelText:SetText(string.format("Level: %d", level))
end
local function UpdateProgress()
  progressText:SetText(string.format("Hits: %d / 20", correctHits))
end

-- initialize HUD text contents
UpdateScore()
UpdateLevel()
UpdateProgress()

-- Clear all highlights
local function ClearHighlights()
  for _, btn in ipairs(partyFrames) do
    if btn._pulse then btn._pulse:Stop() end
  end
end

local function HardcoreReset(reason)
  level = 1
  correctHits = 0
  interval = baseInterval
  UpdateLevel()
  UpdateProgress()
  if reason then
    print(("Hardcore: reset to Level 1 (%s)."):format(reason))
  end
end

local function ShowNewTarget(timedOut)
  -- If timer fired and player didn't press anything, it's a timeout
  if timedOut then
    attempts = attempts + 1
    correctHits = 0
    UpdateScore()
    UpdateProgress()

    if hardcore then
      PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE, "Master")
      UIErrorsFrame:AddMessage("Time's up! Hardcore reset.", 1, 0.2, 0.2)
      HardcoreReset("timeout")
    else
      -- Normal mode: just streak reset
      PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE, "Master")
      UIErrorsFrame:AddMessage("Time's up! Progress reset.", 1, 0.8, 0.2)
    end
  end

  ClearHighlights()

  local n = #partyFrames
  if n == 0 then return end

  if not currentTarget then
    currentTarget = math.random(1, n)
  else
    local r = math.random(1, n - 1)
    if r >= currentTarget then r = r + 1 end
    currentTarget = r
  end

  local btn = partyFrames[currentTarget]
  if btn and btn._pulse then btn._pulse:Play() end

  -- restart timer; pass true so next fire is considered a timeout
  if ticker then ticker:Cancel() end
  ticker = C_Timer.NewTimer(interval, function() ShowNewTarget(true) end)
end

ShowNewTarget()  -- NOT ShowNewTarget(true)

-- Start/Stop API
local function StartTrainer()
  if ticker then ticker:Cancel() end
  ShowNewTarget()
  running = true
  print("TargetTrainer: started")
end

local function StopTrainer()
  if ticker then ticker:Cancel() end
  ClearHighlights()
  currentTarget = nil
  running = false
  print("TargetTrainer: stopped")

  -- save to leaderboard if meaningful run
  if attempts > 0 then
    local entry = {
      score = score,
      attempts = attempts,
      level = level,
      date = date("%Y-%m-%d %H:%M:%S"),
    }
    table.insert(TargetTrainerDB.leaderboard, entry)

    -- keep only top 5 by score
    table.sort(TargetTrainerDB.leaderboard, function(a, b)
      if a.score == b.score then
        return a.attempts < b.attempts -- tiebreaker: fewer attempts
      else
        return a.score > b.score
      end
    end)
    while #TargetTrainerDB.leaderboard > 5 do
      table.remove(TargetTrainerDB.leaderboard)
    end
  end
end

-- Handle presses (sounds, no screen flash)
local function HandlePress(slot)
  attempts = attempts + 1

  if slot == currentTarget then
    -- success
    score = score + 1
    correctHits = correctHits + 1
    UpdateScore()
    UpdateProgress()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")

    -- level-up after 20 correct hits
    if correctHits >= 20 then
      correctHits = 0
      level = level + 1
      interval = math.max(0.5, interval * 0.9) -- faster each level (floor 0.5s)
      UpdateLevel()
      UpdateProgress()

      -- Profession-style celebration (NEW_RECIPE_LEARNED = 18019)
      PlaySound(18019, "Master")
      print(("🎉 Level %d! Speed increased (interval now %.1fs)"):format(level, interval))
    end

    ShowNewTarget()  -- pick a new target on success

  else
    -- fail
    correctHits = 0
    UpdateScore()
    UpdateProgress()
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE, "Master") -- ESC sound
    UIErrorsFrame:AddMessage("Wrong key! Expected "..labels[currentTarget], 1, 0.2, 0.2)

    if hardcore then
      HardcoreReset("wrong key")
    end

    -- optional: choose a new target after a miss (keeps flow going)
    ShowNewTarget()
  end
end


-- Click handlers (these are what our override bindings will "click")
for i, btn in ipairs(partyFrames) do
  btn:SetScript("OnClick", function() HandlePress(i) end)
end

---------------------------------------------------------------------
-- Only use the user's existing binds (no hardcoded keys)
-- We mirror whatever is bound to these WoW actions:
--   TARGETPARTYMEMBER1..4, TARGETSELF
-- We attach temporary overrides to *this frame* so ESC/chat/etc. work.
---------------------------------------------------------------------
-- Action mapping per visible slot (1=Tank, 2=Self, 3=DPS1, 4=DPS2, 5=DPS3)
local actionForSlot = {
  [1] = "TARGETPARTYMEMBER1", -- Tank
  [2] = "TARGETSELF",         -- Self
  [3] = "TARGETPARTYMEMBER3", -- DPS1
  [4] = "TARGETPARTYMEMBER2", -- DPS2
  [5] = "TARGETPARTYMEMBER4", -- DPS3
}

local function RebindToUserKeys()
  ClearOverrideBindings(f)

  for slot = 1, 5 do
    local action = actionForSlot[slot]
    local buttonName = "TTButton"..slot
    if action then
      local key1, key2 = GetBindingKey(action)
      if key1 then SetOverrideBindingClick(f, true, key1, buttonName) end
      if key2 then SetOverrideBindingClick(f, true, key2, buttonName) end
    end
  end
end

-- Re-apply when keybinds change or when frame shows
f:SetScript("OnShow", function()
  RebindToUserKeys()
  if running then StartTrainer() end
end)
f:SetScript("OnHide", function()
  ClearOverrideBindings(f)
  if ticker then ticker:Cancel() end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:SetScript("OnEvent", function()
  if f:IsShown() then RebindToUserKeys() end
end)

-- Slash commands
SLASH_TARGETTRAINER1 = "/tt"
SlashCmdList.TARGETTRAINER = function(msg)
  local cmd, arg = msg:match("^(%S+)%s*(.*)$")
  cmd = (cmd or ""):lower()

  if cmd == "show" then
    f:Show()
    print("TargetTrainer: shown")
    if running then StartTrainer() end

  elseif cmd == "hide" then
    f:Hide()
    print("TargetTrainer: hidden")

  elseif cmd == "speed" and tonumber(arg) then
    interval = math.max(0.3, tonumber(arg))
    print(("TargetTrainer: speed set to %.1fs"):format(interval))
    if running then StartTrainer() end

  elseif cmd == "reset" then
    score, attempts  = 0, 0
    level, correctHits = 1, 0
    interval = baseInterval
    UpdateScore(); UpdateLevel(); UpdateProgress()
    if running then ShowNewTarget() end
    print("TargetTrainer: score/level reset.")

  elseif cmd == "start" then
    StartTrainer()

  elseif cmd == "stop" then
    StopTrainer()

  elseif cmd == "layout" then
  if arg == "horizontal" or arg == "h" then
    layoutMode = "horizontal"
    print("TargetTrainer: layout set to horizontal")
  else
    layoutMode = "vertical"
    print("TargetTrainer: layout set to vertical")
  end
  TargetTrainerDB.layout = layoutMode   -- save!
  LayoutFrames()

  elseif cmd == "keys" then
    print("|cffffd200TargetTrainer key map (action -> key(s)):|r")
    for slot = 1, 5 do
      local action = actionForSlot[slot]
      local k1, k2 = GetBindingKey(action)
      local label = labels[slot]
      local keys = (k1 or "UNBOUND") .. (k2 and (", "..k2) or "")
      print(string.format("  %-5s -> %-20s | %s", label, action, keys))
    end

  elseif cmd == "leaderboard" then
  print("|cffffd200TargetTrainer Leaderboard (Top 5):|r")
  if #TargetTrainerDB.leaderboard == 0 then
    print("  (no scores yet)")
  else
    for i, entry in ipairs(TargetTrainerDB.leaderboard) do
      print(string.format("  %d) Score: %d / %d  |  Level %d  |  %s",
        i, entry.score, entry.attempts, entry.level, entry.date))
    end
  end

  elseif cmd == "hardcore" then
    local a = arg and arg:lower() or ""
    if a == "on" or a == "1" or a == "true" then
      hardcore = true
    elseif a == "off" or a == "0" or a == "false" then
      hardcore = false
    else
    hardcore = not hardcore -- toggle if no explicit arg
  end
  TargetTrainerDB.hardcore = hardcore   -- save!
  print("TargetTrainer: Hardcore mode is now " .. (hardcore and "|cffff5555ON|r" or "|cff55ff55OFF|r"))

  else
    print("|cffffd200TargetTrainer commands:|r")
    print("  /tt show              - show the trainer")
    print("  /tt hide              - hide the trainer")
    print("  /tt start             - begin highlights")
    print("  /tt stop              - stop highlights")
    print("  /tt speed <seconds>   - set interval (default 3.0)")
    print("  /tt reset             - reset score/level/speed")
    print("  /tt layout <v|h>      - vertical or horizontal layout")
    print("  /tt keys              - print captured keybinds")
    print("  /tt leaderboard       - show top 5 local scores")
	print("  /tt hardcore [on|off] - reset to L1 on miss/timeout")
  end
end


-- Start visible by default (not running until /tt start)
f:Show()
=======
-- Respect the user's real keybinds:
--   Target Party Member 1..4  -> Tank/DPS1/DPS2/DPS3
--   Target Self               -> Self
-- We bind clicks ONLY to those keys while the trainer is visible.

local f = CreateFrame("Frame", "TargetTrainerFrame", UIParent, "BackdropTemplate")
f:SetSize(360, 200)
f:SetPoint("CENTER")
f:EnableMouse(true)
f:EnableMouseWheel(true)

-- Title (also acts as drag handle with SHIFT)
local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 10, -10)
title:SetText("Target Trainer")

-- Make frame movable by dragging the title with Shift
f:SetMovable(true)
title:EnableMouse(true)
title:SetScript("OnMouseDown", function(_, button)
  if button == "LeftButton" and IsShiftKeyDown() then
    f:StartMoving()
  end
end)
title:SetScript("OnMouseUp", function(_, button)
  if button == "LeftButton" then
    f:StopMovingOrSizing()
    -- Save position (optional)
    TargetTrainerDB = TargetTrainerDB or {}
    local point, _, _, x, y = f:GetPoint()
    TargetTrainerDB.point, TargetTrainerDB.x, TargetTrainerDB.y = point, x, y
  end
end)

-- Restore saved position + settings
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
  TargetTrainerDB = TargetTrainerDB or {}

  -- restore frame position
  if TargetTrainerDB.point then
    f:ClearAllPoints()
    f:SetPoint(TargetTrainerDB.point, UIParent, TargetTrainerDB.point, TargetTrainerDB.x or 0, TargetTrainerDB.y or 0)
  end

  -- restore layout
  if TargetTrainerDB.layout then
    layoutMode = TargetTrainerDB.layout
    LayoutFrames()
  end

  -- restore hardcore toggle
  if TargetTrainerDB.hardcore ~= nil then
    hardcore = TargetTrainerDB.hardcore
  end
  
  -- in PLAYER_LOGIN restore:
  TargetTrainerDB = TargetTrainerDB or {}
  TargetTrainerDB.leaderboard = TargetTrainerDB.leaderboard or {}
end)

-- =========================
-- Party-style stacked frames
-- =========================
local partyFrames = {}
local labels = {"Tank", "Self", "DPS1", "DPS2", "DPS3"}

-- colors (approx role vibes)
local slotColors = {
  {r=0.25, g=0.78, b=0.92}, -- tank-ish
  {r=0.92, g=0.52, b=0.52}, -- self/red
  {r=0.95, g=0.77, b=0.36}, -- dps gold
  {r=0.60, g=0.95, b=0.60}, -- dps green
  {r=0.60, g=0.77, b=1.00}, -- dps blue
}

local ROW_W, ROW_H, ROW_GAP = 180, 80, 6

-- Layout mode + padding around the bars (room for the title at the top)
local layoutMode = "vertical"  -- or "horizontal"

local PAD_L, PAD_R = 10, 10
local PAD_T, PAD_B = 40, 10    -- ~40 leaves room for the "Target Trainer" title

-- Group container that holds the player frames
local content = CreateFrame("Frame", "TargetTrainerContent", f)
content:SetPoint("TOPLEFT", f, "TOPLEFT", PAD_L, -PAD_T)
content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD_R, PAD_B)

-- Recompute container size based on layout & number of frames.
local function ResizeContainer()
  local n = #partyFrames
  if n == 0 then return end

  local width, height
  if layoutMode == "vertical" then
    width  = PAD_L + ROW_W + PAD_R
    height = PAD_T + (n * ROW_H) + ((n - 1) * ROW_GAP) + PAD_B
  else
    width  = PAD_L + (n * ROW_W) + ((n - 1) * ROW_GAP) + PAD_R
    height = PAD_T + ROW_H + PAD_B
  end

  f:SetSize(width, height)
  -- content auto-fills via its TOPLEFT/BOTTOMRIGHT anchors set above
end

-- ===== HUD TEXTS (define early) =====
local scoreText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
local levelText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
local progressText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

-- Re-anchor the HUD texts after the container resizes / layout changes
local function LayoutHUD()
  scoreText:ClearAllPoints()
  levelText:ClearAllPoints()
  progressText:ClearAllPoints()

  -- anchor to the content group so it follows the bars
  scoreText:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 50)
  levelText:SetPoint("TOPRIGHT", scoreText, "BOTTOMRIGHT", 0, -4)
  progressText:SetPoint("TOPRIGHT", levelText, "BOTTOMRIGHT", 0, -4)
end

-- ===== Drag & Auto-Align support =====
local displayOrder = {}  -- which button index occupies row 1..N

local function LayoutFrames()
  ResizeContainer()
  for row, idx in ipairs(displayOrder) do
    local btn = partyFrames[idx]
    btn:ClearAllPoints()
    if layoutMode == "vertical" then
      btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, - (row - 1) * (ROW_H + ROW_GAP))
    else
      btn:SetPoint("TOPLEFT", content, "TOPLEFT", (row - 1) * (ROW_W + ROW_GAP), 0)
    end
    btn:SetFrameStrata("MEDIUM")
  end
  -- ensure HUD snaps to new size/position
  LayoutHUD()
end

local function RecomputeOrder()
  local arr = {}
  for idx, btn in ipairs(partyFrames) do
    local x, y = btn:GetCenter()
    table.insert(arr, { idx = idx, x = x or 0, y = y or 0 })
  end

  if layoutMode == "vertical" then
    table.sort(arr, function(a, b) return a.y > b.y end)   -- top to bottom
  else
    table.sort(arr, function(a, b) return a.x < b.x end)   -- left to right
  end

  wipe(displayOrder)
  for row, e in ipairs(arr) do displayOrder[row] = e.idx end
  LayoutFrames()
end

-- =========================
-- Party-style stacked frames (draggable)
-- =========================
for i = 1, #labels do
  local btn = CreateFrame("Button", "TTButton"..i, f, "SecureActionButtonTemplate")
  btn:SetSize(ROW_W, ROW_H)
  btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, - (i - 1) * (ROW_H + ROW_GAP))
  
  -- outer border
  btn.bg = CreateFrame("Frame", nil, btn, "BackdropTemplate")
  btn.bg:SetAllPoints()
  btn.bg:SetBackdrop({
    bgFile   = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 14,
    insets   = {left=3,right=3,top=3,bottom=3}
  })
  btn.bg:SetBackdropColor(0,0,0,0.55)

  -- statusbar
  local sb = CreateFrame("StatusBar", nil, btn)
  sb:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  sb:SetMinMaxValues(0,100)
  sb:SetValue(100)
  sb:SetPoint("TOPLEFT", 4, -4)
  sb:SetPoint("BOTTOMRIGHT", -4, 4)
  sb:SetStatusBarColor(slotColors[i].r, slotColors[i].g, slotColors[i].b)

  local bg = sb:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface/Buttons/WHITE8x8")
  bg:SetVertexColor(0,0,0,0.35)

  local nameFS = sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  nameFS:SetPoint("TOPLEFT", 6, -4)
  nameFS:SetText(("*%s"):format(labels[i]))

  local pctFS = sb:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  pctFS:SetPoint("CENTER")
  pctFS:SetText("100%")

  -- === MATCHING-BORDER HIGHLIGHT (replaces your old tint/hl/pulse) ===

-- (optional) a very light red wash inside the bar
local tint = btn:CreateTexture(nil, "BORDER", nil, 1)
tint:SetAllPoints(btn._sb or btn)
tint:SetTexture("Interface/Buttons/WHITE8x8")
tint:SetVertexColor(1, 0, 0, 0.12) -- subtle; raise to 0.18–0.25 if you want more fill
tint:Hide()

-- border frame that uses the SAME border art/size as your normal frame (btn.bg)
local hl = CreateFrame("Frame", nil, btn, "BackdropTemplate")
hl:SetPoint("TOPLEFT", btn.bg, "TOPLEFT", 0, 0)          -- no offset so it matches exactly
hl:SetPoint("BOTTOMRIGHT", btn.bg, "BOTTOMRIGHT", 0, 0)
hl:SetBackdrop({
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  edgeSize = 40,                                          -- must match btn.bg edgeSize
  insets   = { left = 3, right = 3, top = 3, bottom = 3 } -- must match btn.bg insets
})
hl:ClearAllPoints()
hl:SetPoint("TOPLEFT",  btn.bg, "TOPLEFT",  -10,  10)
hl:SetPoint("BOTTOMRIGHT", btn.bg, "BOTTOMRIGHT",  10, -10)

hl:SetBackdropColor(0, 0, 0, 0)
hl:SetBackdropBorderColor(1, 0.15, 0.15, 1)               -- bright red border
hl:Hide()

-- pulse the highlight (alpha on the border frame)
local pulse = hl:CreateAnimationGroup()
local a1 = pulse:CreateAnimation("Alpha"); a1:SetFromAlpha(0.45); a1:SetToAlpha(1.0); a1:SetDuration(0.25); a1:SetOrder(1)
local a2 = pulse:CreateAnimation("Alpha"); a2:SetFromAlpha(1.0); a2:SetToAlpha(0.45); a2:SetDuration(0.25); a2:SetOrder(2)
pulse:SetLooping("REPEAT")
pulse:SetToFinalAlpha(true)
pulse:SetScript("OnPlay", function() hl:Show(); tint:Show() end)
pulse:SetScript("OnStop", function() hl:Hide(); tint:Hide() end)

-- store refs (keep your existing names consistent)
btn._tint, btn._highlight, btn._pulse = tint, hl, pulse

  -- SHIFT + drag to reorder
  btn:SetMovable(true)
  btn:RegisterForDrag("LeftButton")
  btn:SetClampedToScreen(true)
  btn:SetScript("OnDragStart", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() then
      self:StartMoving()
      self:SetFrameStrata("DIALOG")
    end
  end)
  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetFrameStrata("MEDIUM")
    RecomputeOrder()
  end)

  partyFrames[i] = btn
  displayOrder[i] = i
end

-- Initial layout AFTER the loop (LayoutHUD is already defined)
LayoutFrames()

-- ===== STATE =====
local currentTarget = nil
local interval      = 3.0
local ticker
local running       = false

local score         = 0
local attempts      = 0
local level         = 1
local correctHits   = 0
-- ===== HARDCORE MODE =====
local hardcore = false          -- toggled via /tt hardcore
local baseInterval = 3.0        -- your starting speed

-- ===== UPDATERS =====
local function UpdateScore()
  scoreText:SetText(string.format("Score: %d / %d", score, attempts))
end
local function UpdateLevel()
  levelText:SetText(string.format("Level: %d", level))
end
local function UpdateProgress()
  progressText:SetText(string.format("Hits: %d / 20", correctHits))
end

-- initialize HUD text contents
UpdateScore()
UpdateLevel()
UpdateProgress()

-- Clear all highlights
local function ClearHighlights()
  for _, btn in ipairs(partyFrames) do
    if btn._pulse then btn._pulse:Stop() end
  end
end

local function HardcoreReset(reason)
  level = 1
  correctHits = 0
  interval = baseInterval
  UpdateLevel()
  UpdateProgress()
  if reason then
    print(("Hardcore: reset to Level 1 (%s)."):format(reason))
  end
end

local function ShowNewTarget(timedOut)
  -- If timer fired and player didn't press anything, it's a timeout
  if timedOut then
    attempts = attempts + 1
    correctHits = 0
    UpdateScore()
    UpdateProgress()

    if hardcore then
      PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE, "Master")
      UIErrorsFrame:AddMessage("Time's up! Hardcore reset.", 1, 0.2, 0.2)
      HardcoreReset("timeout")
    else
      -- Normal mode: just streak reset
      PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE, "Master")
      UIErrorsFrame:AddMessage("Time's up! Progress reset.", 1, 0.8, 0.2)
    end
  end

  ClearHighlights()

  local n = #partyFrames
  if n == 0 then return end

  if not currentTarget then
    currentTarget = math.random(1, n)
  else
    local r = math.random(1, n - 1)
    if r >= currentTarget then r = r + 1 end
    currentTarget = r
  end

  local btn = partyFrames[currentTarget]
  if btn and btn._pulse then btn._pulse:Play() end

  -- restart timer; pass true so next fire is considered a timeout
  if ticker then ticker:Cancel() end
  ticker = C_Timer.NewTimer(interval, function() ShowNewTarget(true) end)
end

ShowNewTarget()  -- NOT ShowNewTarget(true)

-- Start/Stop API
local function StartTrainer()
  if ticker then ticker:Cancel() end
  ShowNewTarget()
  running = true
  print("TargetTrainer: started")
end

local function StopTrainer()
  if ticker then ticker:Cancel() end
  ClearHighlights()
  currentTarget = nil
  running = false
  print("TargetTrainer: stopped")

  -- save to leaderboard if meaningful run
  if attempts > 0 then
    local entry = {
      score = score,
      attempts = attempts,
      level = level,
      date = date("%Y-%m-%d %H:%M:%S"),
    }
    table.insert(TargetTrainerDB.leaderboard, entry)

    -- keep only top 5 by score
    table.sort(TargetTrainerDB.leaderboard, function(a, b)
      if a.score == b.score then
        return a.attempts < b.attempts -- tiebreaker: fewer attempts
      else
        return a.score > b.score
      end
    end)
    while #TargetTrainerDB.leaderboard > 5 do
      table.remove(TargetTrainerDB.leaderboard)
    end
  end
end

-- Handle presses (sounds, no screen flash)
local function HandlePress(slot)
  attempts = attempts + 1

  if slot == currentTarget then
    -- success
    score = score + 1
    correctHits = correctHits + 1
    UpdateScore()
    UpdateProgress()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")

    -- level-up after 20 correct hits
    if correctHits >= 20 then
      correctHits = 0
      level = level + 1
      interval = math.max(0.5, interval * 0.9) -- faster each level (floor 0.5s)
      UpdateLevel()
      UpdateProgress()

      -- Profession-style celebration (NEW_RECIPE_LEARNED = 18019)
      PlaySound(18019, "Master")
      print(("🎉 Level %d! Speed increased (interval now %.1fs)"):format(level, interval))
    end

    ShowNewTarget()  -- pick a new target on success

  else
    -- fail
    correctHits = 0
    UpdateScore()
    UpdateProgress()
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE, "Master") -- ESC sound
    UIErrorsFrame:AddMessage("Wrong key! Expected "..labels[currentTarget], 1, 0.2, 0.2)

    if hardcore then
      HardcoreReset("wrong key")
    end

    -- optional: choose a new target after a miss (keeps flow going)
    ShowNewTarget()
  end
end


-- Click handlers (these are what our override bindings will "click")
for i, btn in ipairs(partyFrames) do
  btn:SetScript("OnClick", function() HandlePress(i) end)
end

---------------------------------------------------------------------
-- Only use the user's existing binds (no hardcoded keys)
-- We mirror whatever is bound to these WoW actions:
--   TARGETPARTYMEMBER1..4, TARGETSELF
-- We attach temporary overrides to *this frame* so ESC/chat/etc. work.
---------------------------------------------------------------------
-- Action mapping per visible slot (1=Tank, 2=Self, 3=DPS1, 4=DPS2, 5=DPS3)
local actionForSlot = {
  [1] = "TARGETPARTYMEMBER1", -- Tank
  [2] = "TARGETSELF",         -- Self
  [3] = "TARGETPARTYMEMBER3", -- DPS1
  [4] = "TARGETPARTYMEMBER2", -- DPS2
  [5] = "TARGETPARTYMEMBER4", -- DPS3
}

local function RebindToUserKeys()
  ClearOverrideBindings(f)

  for slot = 1, 5 do
    local action = actionForSlot[slot]
    local buttonName = "TTButton"..slot
    if action then
      local key1, key2 = GetBindingKey(action)
      if key1 then SetOverrideBindingClick(f, true, key1, buttonName) end
      if key2 then SetOverrideBindingClick(f, true, key2, buttonName) end
    end
  end
end

-- Re-apply when keybinds change or when frame shows
f:SetScript("OnShow", function()
  RebindToUserKeys()
  if running then StartTrainer() end
end)
f:SetScript("OnHide", function()
  ClearOverrideBindings(f)
  if ticker then ticker:Cancel() end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:SetScript("OnEvent", function()
  if f:IsShown() then RebindToUserKeys() end
end)

-- Slash commands
SLASH_TARGETTRAINER1 = "/tt"
SlashCmdList.TARGETTRAINER = function(msg)
  local cmd, arg = msg:match("^(%S+)%s*(.*)$")
  cmd = (cmd or ""):lower()

  if cmd == "show" then
    f:Show()
    print("TargetTrainer: shown")
    if running then StartTrainer() end

  elseif cmd == "hide" then
    f:Hide()
    print("TargetTrainer: hidden")

  elseif cmd == "speed" and tonumber(arg) then
    interval = math.max(0.3, tonumber(arg))
    print(("TargetTrainer: speed set to %.1fs"):format(interval))
    if running then StartTrainer() end

  elseif cmd == "reset" then
    score, attempts  = 0, 0
    level, correctHits = 1, 0
    interval = baseInterval
    UpdateScore(); UpdateLevel(); UpdateProgress()
    if running then ShowNewTarget() end
    print("TargetTrainer: score/level reset.")

  elseif cmd == "start" then
    StartTrainer()

  elseif cmd == "stop" then
    StopTrainer()

  elseif cmd == "layout" then
  if arg == "horizontal" or arg == "h" then
    layoutMode = "horizontal"
    print("TargetTrainer: layout set to horizontal")
  else
    layoutMode = "vertical"
    print("TargetTrainer: layout set to vertical")
  end
  TargetTrainerDB.layout = layoutMode   -- save!
  LayoutFrames()

  elseif cmd == "keys" then
    print("|cffffd200TargetTrainer key map (action -> key(s)):|r")
    for slot = 1, 5 do
      local action = actionForSlot[slot]
      local k1, k2 = GetBindingKey(action)
      local label = labels[slot]
      local keys = (k1 or "UNBOUND") .. (k2 and (", "..k2) or "")
      print(string.format("  %-5s -> %-20s | %s", label, action, keys))
    end

  elseif cmd == "leaderboard" then
  print("|cffffd200TargetTrainer Leaderboard (Top 5):|r")
  if #TargetTrainerDB.leaderboard == 0 then
    print("  (no scores yet)")
  else
    for i, entry in ipairs(TargetTrainerDB.leaderboard) do
      print(string.format("  %d) Score: %d / %d  |  Level %d  |  %s",
        i, entry.score, entry.attempts, entry.level, entry.date))
    end
  end

  elseif cmd == "hardcore" then
    local a = arg and arg:lower() or ""
    if a == "on" or a == "1" or a == "true" then
      hardcore = true
    elseif a == "off" or a == "0" or a == "false" then
      hardcore = false
    else
    hardcore = not hardcore -- toggle if no explicit arg
  end
  TargetTrainerDB.hardcore = hardcore   -- save!
  print("TargetTrainer: Hardcore mode is now " .. (hardcore and "|cffff5555ON|r" or "|cff55ff55OFF|r"))

  else
    print("|cffffd200TargetTrainer commands:|r")
    print("  /tt show              - show the trainer")
    print("  /tt hide              - hide the trainer")
    print("  /tt start             - begin highlights")
    print("  /tt stop              - stop highlights")
    print("  /tt speed <seconds>   - set interval (default 3.0)")
    print("  /tt reset             - reset score/level/speed")
    print("  /tt layout <v|h>      - vertical or horizontal layout")
    print("  /tt keys              - print captured keybinds")
    print("  /tt leaderboard       - show top 5 local scores")
	print("  /tt hardcore [on|off] - reset to L1 on miss/timeout")
  end
end


-- Start visible by default (not running until /tt start)
f:Show()
>>>>>>> c21aae15c321754128a192f2a805029e3388b1ac
