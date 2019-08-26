local SWp_name, SWp = ...

SLASH_SmartWaypoints1 = '/smartwaypoints'
SLASH_SmartWaypoints2 = '/swpt'

local MODE_MARK = 'mark'
local MODE_NEVER = 'never'
local MODE_ONLYTARGET = 'onlytarget'
local MODE_BLIZZARD = 'blizzard'

function SWp:log(msg)
  print('|cFF4499FF' .. SWp_name .. ': |cffffff00' .. msg)
end

function SWp:initialize_orig()
  self.orig = {
    GetNextWaypoint = C_QuestLog.GetNextWaypoint,
    GetNextWaypointForMap = C_QuestLog.GetNextWaypointForMap,
    GetNextWaypointText = C_QuestLog.GetNextWaypointText,
    GetQuestUiMapID = GetQuestUiMapID,
  }
end

function SWp:initialize_modes()
  self.modes = {}

  self.modes[MODE_NEVER] = {
    GetNextWaypoint = function()
      return nil, nil, nil
    end,
    GetNextWaypointForMap = function()
      return nil, nil
    end,
    GetNextWaypointText = function()
      return nil
    end,
    GetQuestUiMapID = function(questID)
      local uiMapID = self.orig.GetQuestUiMapID(questID)
      return self:most_likely_actual_target_map (questID, uiMapID)
    end,
  }

  self.modes[MODE_MARK] = {
    GetNextWaypoint = self.orig.GetNextWaypoint,
    GetNextWaypointForMap = self.orig.GetNextWaypointForMap,
    GetNextWaypointText = function(questID)
      local waypointText = self.orig.GetNextWaypointText(questID)

      local to_reach = self:most_likely_actual_target_map_name(questID)
      return waypointText and (self.L.reach(to_reach) .. '\n' .. self.L.suggestion(waypointText))
    end,
    GetQuestUiMapID = self.orig.GetQuestUiMapID,
  }

  self.modes[MODE_ONLYTARGET] = {
    GetNextWaypoint = function(...)
      return self.modes[MODE_NEVER].GetNextWaypoint(...)
    end,
    GetNextWaypointForMap = function(...)
      return self.modes[MODE_NEVER].GetNextWaypointForMap(...)
    end,
    GetNextWaypointText = function(questID)
      local waypointText = self.orig.GetNextWaypointText(questID)

      local to_reach = self:most_likely_actual_target_map_name(questID)
      return waypointText and self.L.reach(to_reach)
    end,
    GetQuestUiMapID = function(...)
      return self.modes[MODE_NEVER].GetQuestUiMapID(...)
    end,
  }

  self.modes[MODE_BLIZZARD] = {
    GetNextWaypoint = self.orig.GetNextWaypoint,
    GetNextWaypointForMap = self.orig.GetNextWaypointForMap,
    GetNextWaypointText = self.orig.GetNextWaypointText,
    GetQuestUiMapID = self.orig.GetQuestUiMapID,
  }
end

function SWp:initialize_localization()
  local kconcat = function(tab, ...)
    local ctab = {}
    for k, _ in pairs(tab) do
      table.insert(ctab, k)
    end
    return table.concat(ctab, ...)
  end
  local known_modes = kconcat(self.modes, ', ')

  local Ls = {
    enGB = {
      suggestion = function(how)
        return 'Travel suggestion: ' .. how
      end,
      reach = function(to_reach)
        return 'Reach ' .. to_reach
      end,
      annotated_mode = function(mode)
        return self.L[mode] .. ' (' .. mode .. ')'
      end,
      changed_mode = function(mode)
        return 'Changed mode: ' .. self.L.annotated_mode(mode)
      end,
      unknown_mode = function(mode)
        return 'Unknown mode: ' .. mode .. ' (known: ' .. known_modes .. ')'
      end,
      UNKNOWN_TARGET = 'Unknown target',
      [MODE_NEVER] = 'Never show any waypoints',
      [MODE_MARK] = 'Mark waypoints as suggestions',
      [MODE_ONLYTARGET] = 'Show only the target to reach, no suggestions',
      [MODE_BLIZZARD] = 'Use Blizzard behaviour',
      SLASHHELP = 'help',
      SLASHHELP_CYCLE = 'cycle between available modes',
      SLASHHELP_CURRENT_MODE = function(mode)
        return 'current mode: ' .. self.L.annotated_mode(mode)
      end,
    },
    deDE = {
      suggestion = function(how)
        return 'Wegvorschlag: ' .. how
      end,
      reach = function(to_reach)
        return 'Erreiche ' .. to_reach
      end,
      changed_mode = function(mode)
        return 'Modus gewechselt: ' .. self.L.annotated_mode(mode)
      end,
      unknown_mode = function(mode)
        return 'Unbekannter Modus: ' .. mode .. ' (verfügbar: ' .. known_modes .. ')'
      end,
      UNKNOWN_TARGET = 'Unbekanntes Ziel',
      [MODE_NEVER] = 'Zeige niemals Wegpunkte',
      [MODE_MARK] = 'Markiere Wegpunkte als Vorschläge',
      [MODE_ONLYTARGET] = 'Zeige nur das Ziel, keine Vorschläge',
      [MODE_BLIZZARD] = 'Nutze Blizzard Verhalten',
      SLASHHELP = 'hilfe',
      SLASHHELP_CYCLE = 'Wechsle zwischen den verschiedenen Modi',
      SLASHHELP_CURRENT_MODE = function(mode)
        return 'Aktueller Modus: ' .. self.L.annotated_mode(mode)
      end,
    },
  }

  self.L = setmetatable (Ls[GetLocale()] or {}, {
    __index = function(self, key) return Ls['enGB'][key] end
  })
end

function SWp:most_likely_actual_target_map (questID, fallback)
  if not self.UIMAPIDS then
    self.UIMAPIDS = {}
    -- todo: heuristic: as of 8.2.5 there are 1k-something ids, so scan a lot more
    -- for future proofing.
    for mapID = 0, 10000 do
      local info = C_Map.GetMapInfo(mapID)
      if info then
      self.UIMAPIDS[mapID] = info
      end
    end
  end

  local result = fallback or self.orig.GetQuestUiMapID(questID)

  if not self.orig.GetNextWaypoint(questID) then
    return result
  end

  local curr_info = { mapType = -1, parentMapID = 0 }

  local current_mapID = C_Map.GetBestMapForUnit('player')
  for mapID, cand_info in pairs(self.UIMAPIDS) do
   local questsOnMap = C_QuestLog.GetQuestsOnMap(mapID);
   if questsOnMap and mapID ~= current_mapID then
    for _, info in ipairs(questsOnMap) do
      if info.questID == questID then
      if (cand_info.mapType > curr_info.mapType) or (cand_info.parentMapID ~= 0 and curr_info.parentMapID == 0) then
        curr_info = cand_info
        result = mapID
      end
      end
    end
   end
  end

  return result
end
function SWp:most_likely_actual_target_map_name (questID, fallback)
  local best_map = self:most_likely_actual_target_map(questID, fallback)
  return best_map and best_map ~= 0 and self.UIMAPIDS[best_map].name or self.L.UNKNOWN_TARGET
end

function SWp:initialize_hook()
  C_QuestLog.GetNextWaypoint = function(...)
    return self.modes[SmartWaypointsMode].GetNextWaypoint(...)
  end
  C_QuestLog.GetNextWaypointForMap = function(...)
    return self.modes[SmartWaypointsMode].GetNextWaypointForMap(...)
  end
  C_QuestLog.GetNextWaypointText = function(...)
    return self.modes[SmartWaypointsMode].GetNextWaypointText(...)
  end
  GetQuestUiMapID = function(...)
    return self.modes[SmartWaypointsMode].GetQuestUiMapID(...)
  end
end

function SWp:initialize_slashcmd()
  SlashCmdList['SmartWaypoints'] = function(msg)
    local old_mode = SmartWaypointsMode

    msg = string.lower(msg)
    if msg == '' or msg == 'help' or msg == self.L.SLASHHELP then
      self:log(self.L.SLASHHELP_CURRENT_MODE(SmartWaypointsMode))
      self:log('cycle: ' .. self.L.SLASHHELP_CYCLE)
      for k, _ in pairs(self.modes) do
        self:log(k .. ': ' .. self.L[k])
      end
    elseif msg == 'cycle' then
      if SmartWaypointsMode == MODE_NEVER then
        SmartWaypointsMode = MODE_MARK
      elseif SmartWaypointsMode == MODE_MARK then
        SmartWaypointsMode = MODE_ONLYTARGET
      elseif SmartWaypointsMode == MODE_ONLYTARGET then
        SmartWaypointsMode = MODE_BLIZZARD
      elseif SmartWaypointsMode == MODE_BLIZZARD then
        SmartWaypointsMode = MODE_NEVER
      end
    else
      if self.modes[msg] then
        SmartWaypointsMode = msg
      else
        self:log (self.L.unknown_mode(msg))
      end
    end

    if old_mode ~= SmartWaypointsMode then
      self:log (self.L.changed_mode(SmartWaypointsMode))
      QuestMapFrame:Refresh()
    end
  end
end

function SWp:ADDON_LOADED (addon)
  SmartWaypointsMode = SmartWaypointsMode or MODE_MARK

  self:initialize_orig()
  self:initialize_modes()
  self:initialize_localization()
  self:initialize_hook()
  self:initialize_slashcmd()
end

local function EventHandler(self, event, ...)
  if ( event == "PLAYER_ENTERING_WORLD" ) then
    HideOrShowGeneral()
  end
end
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(frame, event, addon)
  if addon ~= SWp_name then return end
  SWp:ADDON_LOADED (addon)
end)
frame:RegisterEvent("ADDON_LOADED")
