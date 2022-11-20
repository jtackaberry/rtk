# Change Log

## 1.3.0 - TBD (not yet released)

#### New Features

* Added a new experimental `xml` module, which can be used to parse a subset of XML. The API is in preview and is not considered stable. Feedback appreciated.
* `rtk.Slider`'s API has been promoted to stable (however vertical orientiation is not yet implemented)
* Added a new mode `auto` for `rtk.Viewport.vscrollbar` that will reserve space for the scrollbar if scrolling is required to see all content
* `rtk.Window` now supports relative values (i.e. between 0 and 1.0 inclusive) for `minw`, `minh`, `maxw`, and `maxh` attributes
* Implemented customizable widget "hot zones" controlled via the `rtk.Widget.hotzone` attribute, which allows adjusting the area around the widget's normal boundary where mouse interactions will register. This can be useful to allow a widget to be clickable even if the user inadvertently clicks within the margin or spacing in a box, for example, which in particular can improve UX on touch screens


#### Minor Enhancements

* Containers now receive `onkeypress` events when any descendant of the container is focused
* When `rtk.Viewport.vscrollbar` is set to `hover` (default) the scrollbar now becomes visible when the mouse enters anywhere within the viewport, rather than only when near the scrollbar gutter
* Improved `rtk.Window` autosizing (i.e. when width or height is not set) when the window contains "greedy" widgets that want to fill their parent containers as much as possible
* `rtk.Window:open()` now defaults to center alignment
* `rtk.Widget.onclick`, `rtk.Widget.ondoubleclick`, and `rtk.Widget.onlongpress` no longer require `rtk.Widget.autofocus` to be explicitly set or have a custom `rtk.Widget.onmousedown` handler to fire. They will be invoked on all widgets unless `rtk.Widget.onmousedown` explicitly returns false to disable this behavior
* `rtk.Widget.autofocus` now defaults to true if an `onclick` is set on the widget, but it can be explicitly set to `false` to never autofocus
* Allow newlines in `rtk.Application.status` text
* Expand the number of scenarios in which a full reflow is avoided when setting `rtk.Text.text`
* Icons created by `rtk.Image.icon()` are no longer automatically recolored when the image is found in an image path that was registered without an explicit icon style
* Allow passing the file extension to `rtk.Image.icon()`
* Added `rtk.Popup.onopen` and `rtk.Popup.onclose` event handlers
* Enhanced `rtk.Popup.autoclose` to be able to distinguish between clicks that occur outside the popup but still within the ReaScript window, or outside the window entirely
* Allow `rtk.Popup.overlay` to be themed
* Added support for alpha channels in named colors in the form `colorname#aa` where `colorname` is the name of the color and `aa` is the hex code of the alpha channel.  For example, `bg='chartreuse#7f'`
* Implemented luma-adaptive color for `rtk.Text.color` which is now default. Unless the attribute is explicitly set, the text color will use `rtk.themes.text` from either the dark theme or the light theme, depending on the luminance of the background the text will be rendered over
* Improved luminance detection for adaptive coloring (for example `rtk.Entry.icon`) to take into account parent's background when the widget has a translucent background such that it that would blend with the parent's background color
* Avoid recalculating layout (full reflow) if `rtk.Widget.bg` or `rtk.Widget.ghost` are set as these do not affect geometry
* Added a new field `rtk.tick` that increments with each gfx update cycle, and add `rtk.Event.tick` to reflect the tick at which the event occurred
* Improved handling of the case where a widget defines `minw`/`minh` but the minimum size would exceed the allowed cell size in a box
* Optimized overhead of instantiating new widgets


#### Bug Fixes

* Fixed a bug where key press events could be missed/dropped if there were other non-keyboard events (such as mouse move events) that occurred during the same gfx update cycle
* Properly respect the `maxw` cell attribute for expanded cells in `rtk.HBox`
* Fixed a bug where the first expanded cell in a box would have a different size than other expanded cells when `rtk.Box.spacing` was non-zero
* Fixed 1px tall scrollbar bug when `rtk.Viewport.vscrollbar` was set to `always`
* Ensure `rtk.ImageBox` borders and background color is drawn even if `rtk.ImageBox.image` is nil
* Respect `rtk.ImageBox.bg`, if set, when determining which luma-adaptive image variant to use
* Fixed animating `rtk.Widget.w` and `rtk.Widget.h` to 0, or to `rtk.Attribute.NIL` (nil was already supported)
* Fixed animating `rtk.Widget.bg` to nil
* Fixed animating `rtk.Window.x` and `rtk.Window.y` with undocked windows
* Apply `rtk.scale.value` to `rtk.Widget.minw`, `minh`, `maxw`, and `maxh` when `rtk.Widget.scalability` allows it
* Fixed centered vertical alignment for `rtk.Button` when the button label wraps
* Removed allowing passing `rtk.Window.title` as the first positional value during initialization. In principle this is a breaking change however it never actually worked properly, so this just removes a broken feature.
* Fixed a bug where `rtk.Window.onclose` could fire multiple times when the window closes
* Fixed flickering when resizing an `rtk.Window` when the border attribute was set
* Fixed autosizing of `rtk.Window` when REAPER's native UI scaling was enabled
* Fixed a minor visual flicker that could occur when setting certain `rtk.Window` attributes
* `rtk.Window` padding is now accounted for by the resize grip when `rtk.Window.borderless` is true
* Fixed a bug where `rtk.Button` would not always respect the parent container's bounding box
* Fixed subtle misalignment of button labels on Mac
* Fixed the `rtk.Popup.opened` attribute which wasn't being properly updated to reflect current state
* Fixed a bug that calculates the popup width when `rtk.Popup.anchor` is defined and `rtk.scale.value` is > 1
* Fixed a bug where popups with `rtk.Popup.autoclose` enabled could inadvertently close when `rtk.touchscroll` was enabled
* Fixed a visual flicker that occurred when fading out an `rtk.Popup` at the same time as its `rtk.Popup.anchor` widget is hidden
* Fixed issue where the blinking cursor of `rtk.Entry` could be drawn outside its box
* Still allow scrolling `rtk.Viewport` even when `rtk.Viewport.vscrollbar` is set to `never`
* Fixed scroll offsets when `rtk.Viewport` has non-zero padding
* Fixed a bug where `rtk.FlowBox` would only ever use a single column if it contained any greedy children (e.g. those using relative dimensions, or belonging to a box container with `expand` or `fillw` cell attributes set)
* Fixed an edge case where `rtk.FlowBox` could layout with zero columns
* Fixed `rtk.Spacer` failing to take into account padding when calculating its size
* Perform a redraw when the mouse cursor leaves the `rtk.Window` to ensure widget draw functions that reference `rtk.Window.in_window` reflect the proper state visually
* Fixed a bug where `rtk.Widget.cursor` was not being respected when long-pressing over a widget with `rtk.touchscroll` enabled
* `rtk.Widget.onclick` no longer fires if `rtk.Widget.onlongpress` fires and its handler returns true to mark the event as handled
* Fixed incorrect rendering of `rtk.Entry` background when its parent container's background changes
* The `targetidx` parameter for `rtk.Container:reorder()` previously required offseting the index by 1 of the target was after the widget's current cell position, which is now fixed. Technically this is a breaking API change, but the previous semantics were extremely counterintuitive and this API was not widely used by scripts so this is being slipped in as a bug fix.
* Fixed millisecond precision in `rtk.log` timestamps
* Fixed some janky behavior that could occur during mouse cursor position restoration when `rtk.touchscroll` is enabled


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
