# 1.2.0 - 2022-03-22

## New Features

* `rtk.Window` now supports automatic sizing when based on its contents when `rtk.Window.w` and/or `rtk.Window.h` are nil at the time `rtk.Window:open()` is called, which is now the default behavior
* Introduced a new slider widget `rtk.Slider`, which currently in beta and will be promoted in the next minor release
* Added a new window attribute `rtk.Window.resizable` which controls the resizability of undocked windows

## Minor Enhancements

* The `update` callback passed to `rtk.queue_animation()` now receives the animation table as the 4th argument
* The `rtk.Entry`'s value attribute can be be received as the first positional argument
* Full reflow is avoided when setting `rtk.Text.value` on a fixed-width text widget (optimization)
* Remove js_ReaScriptAPI requirement for `rtk.Window:get_normalized_y()`

## Bug Fixes

* Fixed center/right/bottom cell alignments for `rtk.Container` when `rtk.Container.padding` is nonzero
* Ensure redraw occurs when `rtk.Entry.value` changes
* Account for `rtk.Entry.placeholder` when calculating the entry widget's intrinsic size
* Respect the `alpha` attribute for `rtk.Window`
* Avoid updating attributes' surface values during animations
* Don't fire `rtk.OptionMenu:onchange()` when explicitly passing false to the trigger argument of `rtk.OptionMenu:select()` even if the selected item changed


