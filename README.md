*SmartWaypoints* aims at improving the 8.2-introduced quest waypoint suggestions which often are misleading people due to incomplete data on Blizzard's side.

To do so, it mainly offers to change the way waypoints are displayed in the quest tracker, marking those automatic waypoints more obviously.

There are four modes of operation:

- `NEVER`: Never show any waypoints
- `MARK` (*default*): Mark waypoints as suggestions
- `ONLYTARGET`: Show only the target to reach, no suggestions
- `BLIZZARD`: Use Blizzard behaviour

To cycle between modes, use `/smartwaypoints cycle`. Alternatively choose a mode directly with `/smartwaypoints {modechoice}`.

**Note:** The minimap waypoint will still show up regardless of mode.
