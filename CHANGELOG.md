# Change Log

## 1.3.0 - 2022-11-20

#### New Features


#### Minor Enhancements

* Allow newlines in `rtk.Application.status` text
* Expand the number of scenarios in which a full reflow is avoided when setting `rtk.Text.text`

#### Bug Fixes



## 1.2.0 - 2022-03-22

#### New Features

* `rtk.Window` now supports automatic sizing based on its contents when `rtk.Window.w` and/or `rtk.Window.h` are nil at the time `rtk.Window:open()` is called, which is now the default behavior
* Introduced a new slider widget `rtk.Slider`, which currently in beta and will be promoted in the next minor release
* Added a new window attribute `rtk.Window.resizable` which controls the resizability of undocked windows

#### Minor Enhancements

* The `update` callback passed to `rtk.queue_animation()` now receives the animation table as the 4th argument
* The `rtk.Entry`'s value attribute can be be received as the first positional argument
* Full reflow is avoided when setting `rtk.Text.text` on a fixed-width text widget (optimization)
* Removed js_ReaScriptAPI requirement for `rtk.Window:get_normalized_y()`

#### Bug Fixes

* Fixed center/right/bottom cell alignments for `rtk.Container` when `rtk.Container.padding` is nonzero
* Ensure redraw occurs when `rtk.Entry.value` changes
* Account for `rtk.Entry.placeholder` when calculating the entry widget's intrinsic size
* Respect the `alpha` attribute for `rtk.Window`
* Avoid updating attributes' surface values during animations
* Don't fire `rtk.OptionMenu:onchange()` when explicitly passing false to the trigger argument of `rtk.OptionMenu:select()` even if the selected item changed


## 1.1.2 - 2022-03-08

#### Bug Fixes

* Fixed calculation of `rtk.scale.framebuffer` when docked
* Ensure `rtk.Window:onresize()` handler fires when dock state changes
* Detect display based on current values of `rtk.Window.x` and `rtk.Window.y` attributes


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
