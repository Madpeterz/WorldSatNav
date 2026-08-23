# WorldSatNav

Version 1.2.0

World map navigation addon — treasure map tracking, sea box routing, world events, live location tracking, and shared location output for external tools.

## Features

### Treasure Maps

- Click and hold a map from your bag to show only its location on the map
- Click on a X from the map view to start navigation to it
- When your bag is open, shows you what region each map is in

### Lost Sea Boxes

- Click on a ship to start going to each node
- Shows a list of known good locations for sea boxes provided by Zelight
- After switching to show ships, use the next button to go to the next location

> **Note:** Traveling salesman problem — the sea is split into multiple vertical groups and route
> planning is used to find the shortest paths within each group. While not perfect, it works well.

### Events

- If "Enable world events" is checked, world events like Crates, Delphinad Ghostships, Perdita,
  Leviathan, Sunfish, Warehouse Raids and Warehouse Unlocks show on the map
- Events remain on the map for 5 mins; clicking one navigates to it

### Tracking a Location (Guide mode)

Player rotation is not exposed by the API, so a makeshift direction indicator based on multiple
location reads is used instead. Start moving to get a direction indicator.

### Shared Data

If `LocationOutput` is enabled, your sextant coordinates are written to file, letting tools
outside the game read your current location — e.g. an external heatmap/wandering tracker.

### Zoom

Hold CTRL and click on the map to zoom in.

### Move It

Hold shift and drag any element to reposition it. Positions are saved.

## Project Structure

```
main.lua        addon entry point (OnLoad/OnUnload, update loop)
helpers.lua     facade re-exporting helpers/* as a single `helpers` table

core/           foundational modules: api stub, constants, settings, coordinates, eventbus, eventtopics
ui/             rendering/config windows: maprendering, regionmap, configui, alertwindow
features/       gameplay logic: tracking, gps, ships, treasuremaps, gotolocation, worldevents, demos
helpers/        UI widget builders, date/time utils, geo/distance math, building name lookups, misc utils
```

Modules `require` each other via `WorldSatNav/<folder>/<module>` paths (e.g.
`require("WorldSatNav/core/settings")`), except `helpers`, which stays at the addon root so its
public API (`helpers.X`) doesn't need updating across call sites when its internals change.

## Credits

Based on code / assets / ideas from:

**AA-Clissic/Map**
- World map for the game version this addon targets

**IvanLeviathan/Navigate**
- First version of the tracking code; also the plugin used to create stage 1 of data
- Used for node-based route finding

**michaelqtz/aac-addon-dawnsdrop_map**
- Used to get up to speed with the addon library for rendering windows

**FungusMungus/Treasure Track**
- Didn't do what I had hoped, which led to a new version of my old OCR app — liked the map
  labeling but not having to type it all in yourself

**michaelqtz/aac-addon-tier_2_sextant**
- Showed how to hook up world events so they could be included in this addon

**Madpeterz/mapocr_aa**
- A C# app used in retail that read map text via OCR, allowing multiple tracked maps to be added
  to a display

**michaelqtz/aac-addon-dawnsdrop_map**
- PNG location maps for items under Dawnsdrop
