local SWp_name, SWp = ...

local MODE_MARK = 'mark'
local MODE_NEVER = 'never'
local MODE_ONLYTARGET = 'onlytarget'
local MODE_BLIZZARD = 'blizzard'

SmartWaypointsMode = SmartWaypointsMode or MODE_MARK

SLASH_SmartWaypoints1 = '/smartwaypoints'
SLASH_SmartWaypoints2 = '/swpt'
SlashCmdList['SmartWaypoints'] = function(msg)
  local old_mode = SmartWaypointsMode
  if msg == '' or msg == 'help' then
    SWp.log('cycle: ' .. SWp.L.SLASHHELP_CYCLE)
    for k, _ in pairs(SWp.modes) do
      SWp.log(k .. ': ' .. SWp.L[k])
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
    msg = string.lower(msg)
    if SWp.modes[msg] then
      SmartWaypointsMode = msg
    else
      SWp.log (SWp.L.unknown_mode(msg))
    end
  end

  if old_mode ~= SmartWaypointsMode then
    SWp.log (SWp.L.changed_mode(SWp.L[SmartWaypointsMode], SmartWaypointsMode))
    QuestMapFrame:Refresh()
  end
end

SWp.orig = {
  GetNextWaypoint = C_QuestLog.GetNextWaypoint,
  GetNextWaypointForMap = C_QuestLog.GetNextWaypointForMap,
  GetNextWaypointText = C_QuestLog.GetNextWaypointText,
  GetQuestUiMapID = GetQuestUiMapID,
}

SWp.modes = {
  [MODE_NEVER] = {
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
      local uiMapID = SWp.orig.GetQuestUiMapID(questID)
      return SWp.most_likely_actual_target_map (questID, uiMapID)
    end,
  },
  [MODE_MARK] = {
    GetNextWaypoint = SWp.orig.GetNextWaypoint,
    GetNextWaypointForMap = SWp.orig.GetNextWaypointForMap,
    GetNextWaypointText = function(questID)
      local waypointText = SWp.orig.GetNextWaypointText(questID)

      local to_reach = SWp.most_likely_actual_target_map_name(questID)
      return waypointText and (SWp.L.reach(to_reach) .. '\n' .. SWp.L.suggestion(waypointText))
    end,
    GetQuestUiMapID = SWp.orig.GetQuestUiMapID,
  },
  [MODE_ONLYTARGET] = {
    GetNextWaypoint = function(...)
      return SWp.modes[MODE_NEVER].GetNextWaypoint(...)
    end,
    GetNextWaypointForMap = function(...)
      return SWp.modes[MODE_NEVER].GetNextWaypointForMap(...)
    end,
    GetNextWaypointText = function(questID)
      local waypointText = SWp.orig.GetNextWaypointText(questID)

      local to_reach = SWp.most_likely_actual_target_map_name(questID)
      return waypointText and SWp.L.reach(to_reach)
    end,
    GetQuestUiMapID = function(...)
      return SWp.modes[MODE_NEVER].GetQuestUiMapID(...)
    end,
  },
  [MODE_BLIZZARD] = {
    GetNextWaypoint = SWp.orig.GetNextWaypoint,
    GetNextWaypointForMap = SWp.orig.GetNextWaypointForMap,
    GetNextWaypointText = SWp.orig.GetNextWaypointText,
    GetQuestUiMapID = SWp.orig.GetQuestUiMapID,
  }
}

C_QuestLog.GetNextWaypoint = function(...)
  return SWp.modes[SmartWaypointsMode].GetNextWaypoint(...)
end
C_QuestLog.GetNextWaypointForMap = function(...)
  return SWp.modes[SmartWaypointsMode].GetNextWaypointForMap(...)
end
C_QuestLog.GetNextWaypointText = function(...)
  return SWp.modes[SmartWaypointsMode].GetNextWaypointText(...)
end
GetQuestUiMapID = function(...)
  return SWp.modes[SmartWaypointsMode].GetQuestUiMapID(...)
end

SWp.log = function(msg)
  print('|cFF4499FF' .. SWp_name .. ': |cffffff00' .. msg)
end

local kconcat = function(tab, ...)
  local ctab = {}
  for k, _ in pairs(tab) do
    table.insert(ctab, k)
  end
  return table.concat(ctab, ...)
end
local known_modes = kconcat(SWp.modes, ', ')

local Ls = {
  enGB = {
    suggestion = function(how)
      return 'Travel suggestion: ' .. how
    end,
    reach = function(to_reach)
      return 'Reach ' .. to_reach
    end,
    changed_mode = function(new_mode, id)
      return 'Changed mode: ' .. new_mode .. ' (' .. id .. ')'
    end,
    unknown_mode = function(mode)
      return 'Unknown mode: ' .. mode .. ' (known: ' .. known_modes .. ')'
    end,
    UNKNOWN_TARGET = 'Unknown target',
    MODE_NEVER = 'Never show any waypoints',
    MODE_MARK = 'Mark waypoints as suggestions',
    MODE_ONLYTARGET = 'Show only the target to reach, no suggestions',
    MODE_BLIZZARD = 'Use Blizzard behaviour',
    SLASHHELP_CYCLE = 'cycle between available modes',
  },
  deDE = {
    suggestion = function(how)
      return 'Wegvorschlag: ' .. how
    end,
    reach = function(to_reach)
      return 'Erreiche ' .. to_reach
    end,
    changed_mode = function(new_mode, id)
      return 'Modus gewechselt: ' .. new_mode .. ' (' .. id .. ')'
    end,
    unknown_mode = function(mode)
      return 'Unbekannter Modus: ' .. mode .. ' (verfügbar: ' .. known_modes .. ')'
    end,
    UNKNOWN_TARGET = 'Unbekanntes Ziel',
    MODE_NEVER = 'Zeige niemals Wegpunkte',
    MODE_MARK = 'Markiere Wegpunkte als Vorschläge',
    MODE_ONLYTARGET = 'Zeige nur das Ziel, keine Vorschläge',
    MODE_BLIZZARD = 'Nutze Blizzard Verhalten',
    SLASHHELP_CYCLE = 'Wechsle zwischen den verschiedenen Modi',
  },
}

SWp.L = setmetatable (Ls[GetLocale()], {
  __index = function(self, key) return Ls['enGB'][key] end
})

-- todo: heuristic: as of 8.2.5 there are 1k-something ids, so scan a lot more
-- for future proofing.
local MAXIMUM_UIMAPID = 10000
local UIMAPIDS = {}
for mapID = 0, MAXIMUM_UIMAPID do
  local info = C_Map.GetMapInfo(mapID)
  if info then
    UIMAPIDS[mapID] = info
  end
end

SWp.most_likely_actual_target_map = function(questID, fallback)
  local result = fallback or SWp.orig.GetQuestUiMapID(questID)

  if not SWp.orig.GetNextWaypoint(questID) then
    return result
  end

  local curr_info = { mapType = -1, parentMapID = 0 }

  local current_mapID = C_Map.GetBestMapForUnit('player')
  for mapID, cand_info in pairs(UIMAPIDS) do
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
SWp.most_likely_actual_target_map_name = function(questID, fallback)
  local best_map = SWp.most_likely_actual_target_map(questID, fallback)
  return best_map and best_map ~= 0 and UIMAPIDS[best_map].name or SWp.L.UNKNOWN_TARGET
end
