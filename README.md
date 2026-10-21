# Forever Bag Mover

Move WoW Forever's bag windows and save a layout for each character.

[Download beta 1.2.5](https://github.com/DeanieBobeanie/ForeverBagMover/releases/tag/v1.2.5) · [Report a bug](https://github.com/DeanieBobeanie/ForeverBagMover/issues) · [Contribute](CONTRIBUTING.md)

![Forever Bag Mover artwork](media/banner.png)

For WoW Forever 1.60.1, interface 16001.

## Features

- Drag the combined backpack or individual bag windows.
- Save positions separately for each character and bag mode.
- Lock the drag handles once your layout is set.
- Choose whether Escape closes your bags and whether the reagent bag opens with the backpack.

## Install

1. Download `ForeverBagMover-1.2.5.zip` from the [release page](https://github.com/DeanieBobeanie/ForeverBagMover/releases/tag/v1.2.5).
2. Close WoW and extract the ZIP.
3. Copy `ForeverBagMover` into your Forever client's `Interface/AddOns` folder.
4. Restart WoW and enable the add-on at character selection.

The path should end in `Interface/AddOns/ForeverBagMover/ForeverBagMover.toc`. Use the installable ZIP under Assets. GitHub's Source code archives contain the development repository.

To update, replace the add-on folder and keep your WTF folder to retain settings.

## Quick start

Open your bags and drag the handles. Type `/bagmove options` to change locking, Escape behavior and reagent-bag settings.

Use `/bagmove unlock` to show the handles or `/bagmove reset` to restore the default layout. Move bags outside combat.

See the [controls and troubleshooting guide](ForeverBagMover/README.txt) for all commands.

## Screenshot

![Bag Mover options beside the combined backpack and reagent bag](media/in-game.jpg)

Captured in WoW Forever on 21 October 2026. Other installed add-ons are visible around the bag windows.

## Known issues

- Combat restrictions can prevent the add-on from restoring bag positions.
- With Escape closing disabled, you may hear the bag-close sound. Close the bags before using Escape to open the game menu.
- Bag replacements such as Bagnon and bank windows are outside this add-on's scope.

The options window, bag opening and closing, and dragging the combined backpack with its reagent bag were checked in game. Combat behavior and saved positions across a full game restart still need testing.

## Help and contributions

[Open an issue](https://github.com/DeanieBobeanie/ForeverBagMover/issues) with your add-on version, client build, steps to reproduce and the first Lua error. Pull requests and gameplay feedback are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and checks.

## Credits and license

By DonManDee and Deanie Bobeanie. [MIT license](LICENSE). [Media credits](media/README.md).
