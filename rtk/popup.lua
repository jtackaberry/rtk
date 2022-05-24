-- Copyright 2017-2022 Jason Tackaberry
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local rtk = require('rtk.core')

--- An `rtk.Viewport` that behaves as a modal pop-up which hijacks focus until the
-- popup is closed.  Because popups are viewports, scrolling of the child widget is
-- supported.
--
-- Unlike other widgets, `rtk.Popup`s don't need to be explicitly added to some
-- parent container.  They are automatically inserted into the current `rtk.Window`
-- when @{open|opened} and removed when @{close|closed}.
--
-- Also, unlike the parent `rtk.Viewport` class, `rtk.Popup` widgets have a drop shadow by
-- default.  Set @{rtk.Viewport.shadow|shadow} to false to explicitly disable.
--
-- The following examples assume an `rtk.Window` has already been created and is (or is
-- about to be) @{rtk.Window:open|open}.
--
--- @example
--   local button = some_container:add(rtk.Button{"Open Popup"})
--   local popup = rtk.Popup{
--       child=rtk.Text{'Hello world!'},
--       anchor=button,
--   }
--   button.onclick = function(b, event)
--       popup:open()
--   end
--
-- @example
--  local box = rtk.VBox{spacing=20}
--  local popup = rtk.Popup{child=box, padding=30, overlay='#000000cc', autoclose=false}
--  local text = box:add(rtk.Text{'Some very important message goes here.'})
--  local button = box:add(rtk.Button{'Close'}, {halign='right'})
--  button.onclick = function(b, event)
--      popup:close()
--  end
--  popup:open()
--
-- @class rtk.Popup
-- @inherits rtk.Viewport
rtk.Popup = rtk.class('rtk.Popup', rtk.Viewport)


--- Autoclose constants.
--
-- Used with the `autoclose` attribute to influence how the popup should be closed in
-- response to events that occur outside the popup area.
--
-- @section autocloseconst
-- @compact

--- Autoclose is disabled.  If the mouse is clicked outside the popup, it will not
-- be automatically closed.  To close it you must explicitly call `close()`.  This
-- is an alias of `false`.
-- @meta 'disabled'
rtk.Popup.AUTOCLOSE_DISABLED = 0
--- Autoclose when the mouse is clicked outside the popup but still within the
-- bounds of the `rtk.Window`.  This is an alias of `true`, and is the default
-- setting for the `autoclose` attribute.
-- @meta 'local'
rtk.Popup.AUTOCLOSE_LOCAL = 1
--- Autoclose when the mouse is clicked anywhere on the screen outside the popup,
-- which includes when the mouse is clicked outside the `rtk.Window` or when the
-- `rtk.Window` loses focus.
-- @meta 'global'
rtk.Popup.AUTOCLOSE_GLOBAL = 2

--- Class API
--- @section api
rtk.Popup.register{
    --- A widget against which to anchor the popup (default nil). The popup will be placed
    -- below the widget if there is sufficient room, otherwise will be placed above it,
    -- depending on which side has more space.  When @{rtk.Viewport.shadow|shadow} is
    -- defined (as it is by default the `rtk.Popup`s, the portion of the shadow against
    -- the anchor widget will be significantly reduced so that the anchor isn't
    -- obstructed.
    --
    -- @type rtk.Widget|nil
    -- @meta read/write
    anchor = rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL},
    --- When `anchor` is set, the height will be constrained so that the popup is this many
    -- pixels from the edge of the screen (default 20).  When `anchor` is not set, this
    -- behaves like @{rtk.Widget.margin|standard widget margin}.
    --
    -- @type number
    -- @meta read/write
    margin = rtk.Attribute{
        default=20,
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- When `anchor` is set, the width of the popup will be matched to the width of the
    -- anchor (default true).  This also has the effect of dropping the border of the
    -- edge of the popup against the anchor.
    --
    -- @type boolean
    -- @meta read/write
    width_from_anchor = rtk.Attribute{
        default=true,
        reflow=rtk.Widget.REFLOW_FULL,
    },

    --- If set, paints an overlay over top of the window in the given color before drawing
    -- the popup, which uses the theme's @{rtk.themes.popup_overlay|`popup_overlay`}
    -- by default.  The alpha channel of this color is respected, so if you want a
    -- translucent overlay specify a lower alpha (e.g. `#00000055`).
    --
    -- This option is useful for things like alert boxes and is a good visual cue that
    -- focus has been stolen by the popup.
    --
    -- This attribute is ignored if `anchor` is defined, because otherwise the overlay would
    -- be painted over the anchor widget.
    --
    -- @type colortype|nil
    -- @meta read/write
    overlay = rtk.Attribute{
        default=function(self, attr)
            return rtk.theme.popup_overlay
        end,
        calculate=rtk.Reference('bg'),
    },

    --- Allows automatically closing the popup if the mouse is clicked outside the popup
    -- bounds or when the `rtk.Window` loses focus, depending on the setting (default
    -- @{rtk.Popup.AUTOCLOSE_LOCAL|local}).
    --
    -- @type autocloseconst
    -- @meta read/write
    autoclose = rtk.Attribute{
        default=rtk.Popup.AUTOCLOSE_LOCAL,
        calculate={
            ['disabled']=rtk.Popup.AUTOCLOSE_DISABLED,
            ['local']=rtk.Popup.AUTOCLOSE_LOCAL,
            ['global']=rtk.Popup.AUTOCLOSE_GLOBAL,
            [true]=rtk.Popup.AUTOCLOSE_LOCAL,
            [false]=rtk.Popup.AUTOCLOSE_DISABLED,
        }
    },
    --- True when the popup is `open`.  Calling `close()` will set to false.
    -- @type boolean
    -- @meta read-only
    opened = false,

    -- Superclass overrides
    bg=rtk.Attribute{
        default=function(self, attr)
            return rtk.theme.popup_bg or {rtk.color.mod(rtk.theme.bg, 1, 1, rtk.theme.popup_bg_brightness, 0.96)}
        end,
    },
    border=rtk.Attribute{
        default=function(self, attr)
            return rtk.theme.popup_border
        end,
    },
    shadow = rtk.Attribute{
        default=function()
            return rtk.theme.popup_shadow
        end,
    },
    -- Initialize as invisible
    visible = false,
    elevation = 35,
    padding = 10,
    -- Crazy high z-index to ensure popups are above everything
    z = 1000,
}

function rtk.Popup:initialize(attrs, ...)
    rtk.Viewport.initialize(self, attrs, self.class.attributes.defaults, ...)
    -- Subltly different than the opened attribute: this is true as long as the popup is
    -- visible even during a fade animation, even if opened may be false.
    self._popup_visible = false
end

function rtk.Popup:_handle_event(clparentx, clparenty, event, clipped, listen)
    listen = rtk.Viewport._handle_event(self, clparentx, clparenty, event, clipped, listen)
    -- Ensure we mark all activation events (MOUSEUP when touchscroll is enabled,
    -- MOUSEDOWN otherwise) within the viewport as handled to ensure we don't forfeit
    -- focus and close the popup when clicking within the viewport. Setting autofocus
    -- isn't good enough.
    if event.type == rtk._touch_activate_event and self.mouseover then
        event:set_handled(self)
    end
    return listen
end

function rtk.Popup:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, rescale, viewport, window, greedyw, greedyh)
    local calc = self.calc
    local anchor = calc.anchor
    if anchor then
        local y = anchor.clienty
        -- Before we reflow ourself, constrain the box height to fit either above or below
        -- the anchor, depending on which has more room.
        --
        -- Use the calculated window height directly, as our box size is going to depend
        -- on siblings (i.e. those other widgets directly added to the window).
        local wh = self.window.calc.h
        if y < wh / 2 then
            y = y + anchor.calc.h
            boxh = math.floor(math.min(boxh, wh - y - calc.bmargin))
        else
            boxh = math.floor(math.min(boxh, y - calc.tmargin))
        end
        if self.width_from_anchor then
            -- Set our widget to the full width of our anchor
            self.w = math.floor(anchor.calc.w)
        end
    end

    rtk.Viewport._reflow(self, boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, rescale, viewport, window, greedyw, greedyh)

    if anchor then
        -- We don't know if the anchor has been reflowed before or after us, which means
        -- we can't be sure that _realize_geometry() will work against the most up-to-date
        -- anchor geometry.
        --
        -- Since we're reflowing now, this flag tells us to do another _realize_geometry()
        -- pass on next draw.
        self._realize_on_draw = true
    end
end

function rtk.Popup:_realize_geometry()
    local calc = self.calc
    local anchor = calc.anchor
    local st, sb = calc.elevation, calc.elevation
    -- Also perform the anchor-relative calculations if the popup is currently visible,
    -- even if the anchor isn't realized.  This handles the scenario when the anchor is
    -- hidden as we are closing; during the fadeout animation we don't want our position
    -- to change. The opened attribute will not be flipped to false until after the
    -- animation is finished.
    if anchor and anchor.clientx and (anchor.realized or self._popup_visible) then
        -- If we are anchored to a wiget, determine our position now based on the anchor's
        -- geometry and our own.  Now that we've reflowed and know our own height, we place
        -- the viewport below the anchor if it fits, otherwise above.
        calc.x = anchor.clientx
        if anchor.clienty + anchor.calc.h + calc.h < self.window.calc.h then
            -- Position viewport below anchor
            calc.y = anchor.clienty + anchor.calc.h
            if calc.width_from_anchor then
                -- Adjust borders so the top edge is open
                calc.tborder = nil
                calc.bborder = calc.rborder
                calc.border_uniform = false
            end
            -- Change shadow elevation so there's less shadow on the top edge
            st = 5
        else
            calc.y = anchor.clienty - calc.h
            if calc.width_from_anchor then
                -- Adjust borders so the bottom edge is open
                calc.tborder = calc.rborder
                calc.bborder = nil
                calc.border_uniform = false
            end
            -- Change shadow elevation so there's less shadow on the bottom edge
            sb = 5
        end
    end
    rtk.Viewport._realize_geometry(self)
    -- Superclass method creates rtk.Shadow object if necessary, so now we can set the
    -- rectangle settings based on our position relative to the anchor
    self._shadow:set_rectangle(calc.w, calc.h, nil, st, calc.elevation, sb, calc.elevation)
end

function rtk.Popup:_draw(offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    -- Only draw the overlay when there's no anchor, otherwise we would paint over the
    -- anchor widget.
    if self.overlay and not self.anchor then
        self:setcolor(self.calc.overlay or self.calc.bg, alpha)
        gfx.rect(0, 0, self.window.calc.w, self.window.calc.h, 1)
    end
    -- This is a bit cheeky, and breaks the architecture of rtk (wherein calculated geometry
    -- is expected to be current after reflow), but because we can't ensure we will always be
    -- reflowed *after* our anchor, we need to do the match against the anchor's geometry
    -- during first draw after reflow.
    if self._realize_on_draw then
        self:_realize_geometry()
        self._realize_on_draw = false
    end
    rtk.Viewport._draw(self, offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
end

function rtk.Popup:_release_modal(event)
    local ac = self.calc.autoclose
    if ac == rtk.Popup.AUTOCLOSE_GLOBAL or (ac == rtk.Popup.AUTOCLOSE_LOCAL and not event.simulated) then
        self:_close(event)
    end
end

--- Opens the modal popup.
--
-- By default, the popup will be centered within the `rtk.Window` unless
-- `anchor` is defined, in which case the popup will be anchored to that
-- widget.  Without an `anchor`, to override the default positioning of
-- the popup, `attrs` can be specified.
--
-- @example
--   -- Open with default placement
--   popup:open()
--
--   -- Opens the popup centered horizontally while 30px from the top of the window
--   popup:open{valign='top', halign='center', tpadding=30}
--
-- @tparam table|nil attrs the cell attributes to use when the popup is
--   added to the `rtk.Window`.  See `rtk.Container` for more details on
--   available cell attributes.
-- @treturn rtk.Popup returns self for method chaining
function rtk.Popup:open(attrs)
    if self.calc.opened or self:onopen() == false then
        return self
    end
    local calc = self.calc
    local anchor = calc.anchor
    if not attrs and not anchor then
        -- Without an anchor and attrs to tell us otherwise, default to centered on
        -- screen.
        attrs = {valign='center', halign='center'}
    end
    if calc.visible and not self:get_animation('alpha') then
        -- Already open
        return self
    end
    rtk.reset_modal()
    if not self.parent then
        local window = (anchor and anchor.window) or (attrs and attrs.window) or rtk.window
        assert(window, 'no rtk.Window has been created or explicitly passed to open()')
        window:add(self, attrs)
        if anchor and not anchor.clientx then
            -- _open() will set visible to true, causing a reflow, but our reflow depends
            -- upon the anchor's client coordinates in order to calculate our own geometry.
            -- Consequently, defer _open() to next update cycle, after which time anchor
            -- would have been drawn.
            rtk.defer(self._open, self, attrs)
            return self
        end
    end
    self:_open(attrs)
    return self
end

function rtk.Popup:_open(attrs)
    local anchor = self.calc.anchor
    if self:get_animation('alpha') then
        self:cancel_animation('alpha')
        self:attr('alpha', 1)
    elseif anchor and not anchor.realized then
        -- Anchor is hidden, so we can't open.
        return false
    end
    self:sync('opened', true)
    self._popup_visible = true
    rtk.add_modal(self, anchor)
    self:show()
    self:focus()
    self:scrollto(0, 0)
    return true
end

--- Closes the popup.
function rtk.Popup:close()
    return self:_close()
end

function rtk.Popup:_close(event)
    if not self.calc.visible or not self.calc.opened then
        return
    end
    if self:onclose(event) == false then
        return
    end
    self:sync('opened', false)
    self:animate{attr='alpha', dst=0, duration=0.15}
        :done(function()
            self:hide()
            self:attr('alpha', 1)
            self.window:remove(self)
            self._popup_visible = false
        end)
    rtk.reset_modal()
end

function rtk.Popup:_handle_windowclose(event)
    self:onclose(event)
    self:sync('opened', false)
end



--- Event Handlers.
--
-- See also @{widget.handlers|handlers for rtk.Widget}.
--
-- @section popup.handlers


--- Called just before the popup is opened.
--
-- This event handler has the opportunity block the popup from opening by
-- returning false.
--
-- @treturn bool Returning false will block the popup from opening, while
--   any other return value will allow it to be opened.
function rtk.Popup:onopen() end


--- Called just before the popup is closed.
--
-- The event argument indicates the type of event that is causing the
-- popup to close, if any.  This could be `rtk.Event.MOUSEDOWN` because
-- the user clicked outside the popup and `autoclose` was true, or it
-- could be `rtk.Event.WINDOWCLOSE` because the main window is closing.
-- Except in the latter case, this event handler may block closure of the
-- popup by returning false.  In the case of `rtk.Event.WINDOWCLOSE`, this
-- can't be aborted and the return value is ignored.
--
-- @tparam rtk.Event|nil event the event, if any, that is causing the popup
--   to close.  It is nil when the popup is programmatically closed.
-- @treturn bool Returning false will block the popup from closing, while
--   any other return value will allow its closure.
function rtk.Popup:onclose(event) end