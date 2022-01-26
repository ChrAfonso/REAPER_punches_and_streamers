Punches and Streamers
---------------------
by Christian Afonso

![Alt text](/doc/screenshot1.png?raw=true "Punches and Streamers screenshot")

REAPER script to overlay punches and streamers over video track. Still early version, some
things might not work all the time. Also contains a simple script to generate sections of
click track for rendering as audio stem.

Prerequisites:
- SWS/S&M Extensions (https://www.sws-extension.org/)

Installation:

- a) Install via ReaPack: https://github.com/ChrAfonso/REAPER_punches_and_streamers/raw/dev/reapack_index.xml
- b) Clone/download the repository and...
  1. place the contents into your REAPER Aplication Storage directory/Scripts/ChrAfonso Scripts/Film Scoring/Punches and Streamers/
  2. Move the png icons from [target dir as in 1.]/toolbar/icons into [AppStorage/REAPER]/Data/toolbar_icons/

To use the toolbar:

- right click on your toolbar -> Open -> Floating Toolbar 1
- right click the new toolbar -> Customize Toolbar -> Import, browse to and open [target dir as above]/toolbar/FilmSync.ReaperMenu

Usage:

Workflow 1 (Markers):

- Add markers named "P" or "PUNCH" for punches, "S [N COLOR]" or "STREAMER [N COLOR]"
  for streamers (with concluding punch). Optional parameters: N = streamer duration 
  in seconds (default 2), COLOR = streamer color (default white, currently also possible:
  [red yellow green blue magenta cyan black]; add a - in front to suppress the default
  punch at the end, e.g. "S 3 -red" for a 3-second red streamer without a punch)
- Call the script "CA_update punches and streamers from markers". It should add two tracks "Streamers" and "Punches" (if not already
  existing), add a "remove black" Video FX to the Punches track, and then add items for 
  every marker matching the specified patterns. The streamer items should automatically
  get a "streamer" Video FX. Additional "Streamers" tracks are created in case of over-
  lapping streamers (due to only one concurrent video effect being displayed per track).
- To use the simple "update_click_track" utility script, place marker pairs "C IN" and
  "C OUT" and call the script. It will create a Click Source item between each pair of
  markers on a new track "Click".
  
Workflow 2 (Toolbar):

- Import the included toolbar from Scripts/ChrAfonso Scripts/Film Scoring/Punches and Streamers/toolbar/FilmSync.ReaperMenu, as described above
- The first two buttons call the punches/streamers and click track scripts from workflow 1
- The next two buttons toggle whether streamers created afterwards start/end outside(default) or inside the frame
- Use the other buttons to place punches, flutters, predefined 2-second-streamers, or custom streamers at the current cursor position.
- The two buttons at the end can be used to load/save your current punches and streamers from/to a CSV file (requires js_ReaScript_API).

This script is a work-in-progress, provided as-is without any warranties.
You can use it however you like, but at your own risk (Meaning: save your project 
before using it!)
I'm very open for feedback and suggestions: chr.afonso AT gmail.com
