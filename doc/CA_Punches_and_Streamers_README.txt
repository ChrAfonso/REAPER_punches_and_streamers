ChrAfonso Punches and Streamers Scripts for REAPER
--------------------------------------------------

Prerequisites:
--------------
- A REAPER install
- SWS/S&M extensions installed

Installation:
-------------
- Copy the three folders in this zip (Data, MenuSets, Scripts) into your REAPER installation's Application Data directory:
    Windows: C:\Users\<USERNAME>\AppData\Roaming\REAPER\
    Mac: /Users/<USERNAME>/Library/Application Support/REAPER/
    Portable Install: directly into its root directory
  If prompted by your OS, choose "replace"/"merge" to copy the folder structure even if some of the directories/files already exist.

Setup:
------
Actions:
- Open the Actions List (shortcut "?") and select "New action.../Load ReaScript...".
- Navigate to your Application Data's directory "Scripts/ChrAfonso/Punches_and_Streamers", select all .lua-Files (apart from "CA_streamers_lib.lua"), and click "Open".

Toolbar:
- Right-click your main toolbar, select "Open Toolbar/Toolbar 1"
- Right-click the new toolbar, select "Customize toolbar", click "Import...", and select the file "MenuSets/FilmSync.ReaperMenu" in your REAPER Application Storage.
(- Right-click the new toolbar, select "Position Toolbar", and set an option of your choice (e.g. "At top of main window"))

Now all needed scripts should be setup and available from the toolbar buttons (you can also set keyboard shortcuts to them from the Actions list):

Usage:
------
Variant 1 (create from Markers)
- Update Punches and Streamers from Markers:
  Creates Punches and Streamers from all Markers with the following names:
  "P" - Punch
  "S [N] [-][COLOR]", Streamer (ending at the marker) with a duration of N seconds (default 2) with the color COLOR (default white, also available: green, yellow, red, blue, magenta, cyan). A "-" before the color suppressed the Punch at the end.
  e.g.: "S 3.5 -red" creates a 3.5-second red streamer, without a punch.

- Update Click Track from Markers:
  Creates Rendered Click track regions between pairs of "C IN" and "C OUT" markers

Variant 2 (create via tool buttons)
- Start Inside Frame / End Inside Frame (toggle buttons):
  Sets whether streamers created afterwards should start/end inside or outside the frame (default: outside)
  
- Add Punch:
  Creates a Punch at the current cursor position
- Add Flutter:
  Creates a 3-Punch flutter centered at the current cursor position

- Add green/red/white/yellow 2s streamer:
  Adds a 2-second streamer of the specified color, ending at the current cursor position, with a punch at the end
  
- Add custom streamer:
  Shows a popup to add a streamer with a custom color (name or #rrggbb html code) and custom duration specify either seconds or beats)
  
- Show Streamers List (WIP)
  Shows a list of all streamers in the project