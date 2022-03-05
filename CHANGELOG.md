# Change Log

## 1.1.1 - 2022-03-05

#### Bug Fixes

* Fixed a bug with `rtk.Window:open()` alignment options when reopening windows on Macs with Retina displays
* Fixed a potential hard REAPER crash when updating window attributes after `rtk.Window:close()` is called


## 1.1.0 - 2022-02-28

#### New Features

* Added `rtk.scale.framebuffer`, which indicates the ratio of the internal gfx frame buffer to the OS window geometry

#### Bug Fixes

* Fixed widgets not properly respecting changes to `rtk.font.multiplier` on reflow
* Fixed window height clamping on Windows and Linux when `rtk.Window:open()` is called with constrain option
* When setting the `rtk.Window.w` or `rtk.Window.h` attribute, fixed a bug where the other dimension would end up being halved on MacOS systems with Retina displays


## 1.0.0 - 2022-02-18

Initial release marking API stability.
