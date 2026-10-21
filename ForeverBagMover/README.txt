Forever Bag Mover 1.2.5
By DonManDee and Deanie Bobeanie

Move the normal WoW Forever bags and remember their positions.
Targets WoW Forever 1.60.1, interface 16001. No other add-ons required.

Install

1. Close WoW.
2. Extract the ZIP and copy its ForeverBagMover folder into your Forever
   client's Interface\AddOns folder.
3. Check that the path ends in
   Interface\AddOns\ForeverBagMover\ForeverBagMover.toc.
4. Start WoW and enable Forever Bag Mover at character selection.

Use

Open your bags. Drag the small "Drag bag" handle beside a bag window.
The add-on remembers the position when you close and reopen the bag,
reload the interface, or log out and return.

Click the square Movebag icon beside the open backpack's X button.
It appears outside combat, even when the drag handles are locked.
- Lock bags and hide handles. Uncheck it to show the handles again.
- Escape closes bags. Off by default, which keeps your current behaviour.
- Open reagent bag with backpack. On by default.

Closing the backpack also closes its reagent bag. This applies whether
or not automatic reagent opening is enabled. Escape keeps both open when
Escape closes bags is off. You can still open the reagent bag alone.

These settings save per character. The icon works with the combined
backpack and the separate backpack. It remains visible when handles are
locked and hides during combat. /bagmove options opens the same menu.

By default, Escape leaves your bags open. Close bags with their X buttons
or the normal bag key. Dialogs and other windows still receive Escape.

With Escape closing disabled, the add-on restores bags on the next update.
You may hear the bag-close sound. WoW may consume Escape while bags are open, so close the
bags with the bag key before using Escape to open the game menu.
Restricted frames cannot be restored during combat.

Right-click a handle to switch all handles between the top and bottom
of the bags. Use the bottom handles to move bags all the way to the top
of the screen. The side setting saves per character and applies to both
combined and separate bags. Existing saved positions are kept, with
adjustments when needed to fit the bag and handle on screen.

To update from an earlier version, close WoW and replace the
ForeverBagMover folder in Interface\AddOns with the folder from this ZIP.
Keep your WTF folder to preserve saved settings.
Restart WoW after updating from 1.1.1 or 1.1.2. Those versions registered
an Escape callback that remains active until the interface restarts.

The combined bag window has one saved position. Separate bags each have
their own saved position, based on the bag slot. Switch bag modes through
WoW's normal bag options. Each mode keeps its own positions.

/bagmove lock     Hide the handles and keep the saved positions.
/bagmove unlock   Show the handles again.
/bagmove reset    Clear all saved positions and restore WoW's default layout.
/bagmove anchor bottom   Put the handles below the bags.
/bagmove anchor top      Put the handles above the bags.
/bagmove options  Open the bag options menu.
/bagmove status   Show version and combat/Escape diagnostics.
/bagmove          Show help. /fbm also works.

Positions and the handle setting save separately for each character.
WoW writes saved settings to disk on a normal logout or /reload.
Move bags outside combat. Handles disappear during combat and return
afterward if unlocked. The add-on keeps restoring saved positions during
combat when WoW permits changes to the frame. It leaves restricted frames
alone until combat ends.
Saved windows are kept within the screen where their size allows it.

This add-on controls Blizzard's bag windows. It does not control Bagnon,
other replacement bag windows, or the bank. Another add-on that moves the
same windows may conflict with it.

Troubleshooting

If handles are missing, leave combat, type /bagmove unlock, and reopen
your bags. If a bag is off screen, type /bagmove reset outside combat.
To reach the top of the screen, use /bagmove anchor bottom.

If Escape still closes bags, confirm you installed 1.2.5 and restarted WoW.
Check that Escape has WoW's normal game menu binding, then test with other
bag or window-moving add-ons disabled. Type /bagmove status while the
problem is visible. It reports whether the game allows frame changes,
whether Escape was detected, and how many bags were restored.

When reporting a problem, include add-on version 1.2.5, your game build,
whether you use combined or separate bags, the steps that reproduce it,
and the full Lua error if WoW displays one. Do not share your account files.

To uninstall, close WoW and remove the ForeverBagMover add-on folder.
This disables the add-on. Saved settings remain available for a reinstall.

Credits and license

DonManDee and Deanie Bobeanie. MIT license, included in LICENSE.txt.
Independent add-on. Not affiliated with or endorsed by Blizzard Entertainment.

Validation

Automated checks pass for the options menu, saved settings, both Escape
choices and reagent opening, alongside the earlier movement checks.
Version 1.1.6 was confirmed working in game. Version 1.2.5 is packaged for
sharing at the user's request. The later changes have automated checks;
no separate full in-game checklist was recorded for them.

Source reference

https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua
