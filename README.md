# WorldSatNav

Even now im still lost

## Using the map / addon

### Zoom

to zoom in CTRL + mouse wheel up/down to zoom in and out, 3 real zoom levels plus a virtual 4th level 

### Pan

when not in the full map view click and drag on the map to pan around the world, you can also click on the my location button
from the right hand side menu to goto your current location (looks like a crosshair)

### Move it around

all on screen elements can be moved by holding left shift and holding left mouse button 


## Features

### Treasure Maps

Placing Treasure maps with coordinates into your back and opening the main UI will label the region they are in
you can then click on the X marker to be guided to its location.

### Lost Sea Boxes

Time to get recover what has been lost, selecting "Ships" from the UI right side menu will give you
a map of ship locations and you can normally find 1 to 3 lost treasure boxs, float them back up
to recover them with recovery pouches

- Shows a list of known good locations for sea boxes provided by Zelight and Kargor

### Events

if enabled world events like 
- swarm of Sunfish
- Perdita Statue Torso
- Leviathan carcass
- Warehouse (unlock and raid)
- mysterious crates being found
- Delphinad Ghostships being destroyed

will show on the map and give an alert allow you to attempt to get a cut of the profit

### Demos

Looking to get some land, then recording land that is due to be destroyed will allow you to get
alerts before it happens and view a table of upcoming demos.
you can also use the share code system to import/export with friends and guild members


### Dawnsdrop 

Had too much PVP today? then switching to dawnsdrop and selecting a type and target 
will allow to find items from the world like Iron Veins, Trees for logging,
Plants for food and potions, and points of interest for Exploration.

for locations with lots of that type you will get a bigger X

starting with a smaller yellow, then green and finally blue

The location data is an guide not a 100% sextant track, but will get you close


### Customize your settings

clicking the cog icon will give you the setting menu

- Tracking mode
  - Guide (will attempt to point the direction of travel you need to move in) up is forwards
  - Compass (will show you the direction to move in based on fixed world direction) up is north

- Demos
  - Show only in the next hour (Demos happening more than 60 mins from now will not be rendered on the map)
  - Enable + for add (the UI when targeting buildings to add a demo will be enabled if checked)
  - Enable alerts (a red alert window will show 5 mins before the demo window starts)
  - Sort demos by type (when viewing the list of demos the ones happening sooner will be at the top)

- Events
  - Track events (world events will be captured for X mins and rendered on the map)
  - Enable alerts for events (a red alert window will open when a world event happens so you can track it)
  - Keep events for [X] mins (How long to keep world events before removing them from the map)

- Location
  - Output location to file (your sextant coordinates are written to file, letting tools outside the game read your current location — e.g. an external heatmap/wandering tracker.)
  - Open real map on click (When starting tracking by clicking on an icon or clicking the track button from alert the in game map opens and marks the location with a pointer if enabled)
  - Tracking use region name (When you are too far away from a location it will tell you to teleport to a region otherwise it will just give distance)
  - Show target info in chat (When you start tracking it gives the details of where you're going in chat for just you)
  - Enable Show on trackking (when enabled a show button will appear when tracking to allow you to reopen the map)
  - Auto goto next map (after you pickup a map at that location if there are none left then it will auto click next)
  - Next map behavior (which map "Next" / auto goto picks)
    - [A] Nearest (in region) (default - only maps in the region you are standing in, closest first)
    - [B] Nearest (closest map in your bag, ignoring region)
    - [C] A then B (prefer maps in your current region, fall back to the closest anywhere once none are left in region)

- Time
  - DST +1 hour forces the clock used to add 60 mins

### I want to help fix the dawnsdrop data 

please create a fork of this repo, empty the addons folder for SatNav and then 
clone to that folder.

then enable dev tools by clicking on the my location repeatedly (about 9 times)
please note your console will get very spammy with this turned on, repeat the action to turn it off
then on the dawnsdrop page you can select "Add" to add a new icon, clicking it again will increase the size
going past stage 3 will remove the entry.

you can also click "Mark here" to create a icon at your current sextent location.

once your done commit your changes and create a pull request to merge the changes to the addon
after its been reviewed.


## Credits

Based on code / assets / ideas from:

**Madpeterz/mapocr_aa**
- A C# app used in retail that read map text via OCR, allowing multiple tracked maps to be added
  to a display

**AA-Clissic/Map**
- World map for the game version this addon targets

**IvanLeviathan/Navigate**
- First version of the tracking code

**michaelqtz/aac-addon-dawnsdrop_map**
- Used to get up to speed with the addon library for rendering windows
- PNG location maps for items under Dawnsdrop that have been converted into locations

**michaelqtz/aac-addon-tier_2_sextant**
- Showed how to hook up world events so they could be included in this addon

**FungusMungus/Treasure Track**
- Didn't do what I had hoped, which led to a new version of my old OCR app — liked the map
  labeling but not having to type it all in yourself


## AI usage

Claud - used all over the place to help add new features

co-pilot - Adds itself when i auto gen commit messages (not used for anything worthwhile)