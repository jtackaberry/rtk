# 1.4.0 - 2023-10-09

## Minor Enhancements

* Improved logic for generating debug box overlay colors when setting `rtk.debug` to true. Previously `math.random()` was used with a fixed seed, which significantly weakened random number generation for other uses.
* The `rtk.Window.onclose()` event handler is now invoked on all script exit conditions if the window is open
* Minor documentation improvements


## Bug Fixes

* Fixed a crash caused by setting `rtk.Window.w` or `rtk.Window.h` attributes to nil (which denotes autosizing) within an event handler ([#20](https://github.com/jtackaberry/rtk/issues/20))
* Fixed a crash when calling `rtk.Image:blur()` before the image has been loaded
* Fixed stack overflow caused by passing a recursive table (i.e. a table which contains either a direct or indirect value of itself) to `table.tostring()`
* Fixed `halign` / `valign` parameters for `rtk.Window:open()` sometimes not being respected
* Ensured `rtk.Entry.caret` reflects the correct position before firing `rtk.Entry.onchange` ([#19](https://github.com/jtackaberry/rtk/issues/19))


