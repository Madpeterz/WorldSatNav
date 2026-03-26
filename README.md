# Treasure Maps

- Click and hold a map from your bag to show only its location on the map
- Click on a X from the map view to start navigation to it
- When your bag is open, shows you what region each map is in

# Lost Sea Boxes

- Click on a ship to start going to each node
- Shows a list of known good locations for sea boxes provided by Zelight.
- After switching to show ships, use the next button to go to the next location.

> **Note:** Traveling salesman problem — the sea is split into multiple vertical groups and route
> planning is used to find the shortest paths within each group. While not perfect, it works well.

# Events

- if Enable world events is checked world events like 
- Crates, Delphinad Ghostships, Perdita, Leviathan, Sunfish, Warehouse Raids and Warehouse Unlocks
- events will remain on the map for 5 mins, clicking on it will take you to it

# Tracking a Location (Guide mode)

Currently player rotation is not supported by the API, so a makeshift version based on multiple
location reads is used. Start moving to get a direction indicator.

# Shared data

if LocationOutput is enabled
the players sextent cords are written to file, allowing addons not in game
to be able to get your current location. helpfull for other apps like my WIP
wandering app to show my movement over time so I can create heatmaps.

# Zoom in

You can zoom in on the map by holding CTRL and then clicking

# move it!

you can move all elements by holding shift and dragging

# Based on Code / Assets / Ideas From 

**AA-Clissic/Map**
- for the world map for the version I play on

**IvanLeviathan/Navigate**
- First version of the tracking code; also the plugin used to create stage 1 of data
- Used for node-based route finding

**michaelqtz/aac-addon-dawnsdrop_map**
- Used to get up to speed with the addon library for rendering windows

**FungusMungus/Treasure Track**
- did not do what I had hoped todo, so resulted in the creation
- of a new version of my old OCR app, I liked the labeling of maps but not the 
- fact you had to type it all in yourself

**michaelqtz/aac-addon-tier_2_sextant**
- For showing me how to hook up the world events so we can include them as part of this addon

**Madpeterz/mapocr_aa**
- A C# app used in retail that would read map text via OCR
- Allowed adding maps to a display tracking multiple of them
