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

-- TODO: use sync() for scroll positions (needed for reactives)
local rtk = require('rtk.core')

--- A scrollable single-child container.
--
-- Viewports intentionally only support a single child, but that child can of course be a
-- @{rtk.Container|container}.
--
-- When child widgets within the viewport are dragging (where `ondragstart()` returns a positive
-- value), the viewport's scrollbar will appear if the dragging child has its
-- `show_scrollbar_on_drag` attribute set to true (as is default).  This is a common idiom
-- for drag-and-drop as it reveals where in the viewport the user is dragging, and also
-- invites edge scrolling by dragging outside the boundary of the viewport (and this is
-- supported by `rtk.Viewport`).
--
--
-- The default `rtk.Viewport` behavior is optimized for vertical scrolling while trying to
-- minimize the need to scroll horizontally.
--
-- @warning Vertical scrollbars only
--  Currently only vertical scrollbars are supported.  Horizontal scrolling can be
--  achieved programmatically (e.g. via `scrollto()`) but horizontal scrollbars
--  haven't yet been implemented.
--
-- @class rtk.Viewport
-- @inherits rtk.Widget
rtk.Viewport = rtk.class('rtk.Viewport', rtk.Widget)

--- Scrollbar Constants.
--
-- Used with the `vscrollbar` attribute, where lowercase strings of these constants without
-- the `SCROLLBAR_` prefix can be used for convenience (e.g. `never` instead of
-- `rtk.Viewport.SCROLLBAR_NEVER`).
--
-- @section scrollbarconst
-- @compact

--- Never show the scrollbar. The user can only scroll the viewport by using the mouse wheel
-- or by touch scrolling (if enabled). Programmatic scrolling is also possible.
-- @meta 'never'
rtk.Viewport.static.SCROLLBAR_NEVER = 0
--- Only show the scrollbar when the mouse hovers over the viewport area. Space is not
-- reserved for the scrollbar: the child is able to consume this space and the scrollbar
-- will be drawn over top as a translucent overlay. This is the default mode.
-- @meta 'hover'
rtk.Viewport.static.SCROLLBAR_HOVER = 1
-- Spaces is reserved for the scrollbar only when there is content to be scrolled,
-- otherwise the child is allowed to fill the entire viewport size, which ensures the
-- scrollbar will never be drawn over child content.  As with `SCROLLBAR_HOVER`, the
-- scrollbar is only made visible when the mouse is moved within the viewport area.
-- @meta 'auto'
rtk.Viewport.static.SCROLLBAR_AUTO = 2
--- Always reserve space for the scrollbar, even if scrolling isn't required to see all the
-- viewport's contents.  The scrollbar is only visible when there are contents to be
-- scrolled, but unlike the other modes, in this case the scrollbar will always be drawn
-- even when the mouse isn't inside the viewport area.
-- @meta 'always'
rtk.Viewport.static.SCROLLBAR_ALWAYS = 3

--- Class API
--- @section api
rtk.Viewport.register{
    [1] = rtk.Attribute{alias='child'},
    --- The child widget that is to scroll within this viewport.
    --
    -- This attribute may be passed as the first positional argument during initialization:
    --
    -- @code
    --   -- This ...
    --   local vp = rtk.Viewport{box}
    --   -- ... is equivalent to this
    --   local vp = rtk.Viewport{child=box}
    --
    -- Because `rtk.Viewport` doesn't implement the `rtk.Container` interface (instead being
    -- a much simpler single-child type container), there's no method analogous to
    -- `rtk.Container:add()`. Placing the single child within the viewport is done by
    -- setting this attribute. It does mean that viewports don't provide the
    -- @{container.cellattrs|cell attributes} capability; the widget's
    -- @{rtk.Widget.margin|margin} is respected, however, and can be used to provide
    -- visual distance between the viewport boundary and the child widget.
    --
    -- @meta read/write
    -- @type rtk.Widget
    child = rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL},

    --- Vertical scroll offset in pixels.  See also `scrollby()` and `scrollto()`.
    -- @meta read/write
    -- @type number
    scroll_left = rtk.Attribute{
        default=0,
        -- Scrolling doesn't affect layout
        reflow=rtk.Widget.REFLOW_NONE,
        calculate=function(self, attr, value, target)
            return math.round(value)
        end,
    },
    --- Horizontal scroll offset in pixels.  See also `scrollby()` and `scrollto()`.
    -- @meta read/write
    -- @type number
    scroll_top=rtk.Reference('scroll_left'),
    --- Controls whether scrolling the viewport either programmatically or via the mouse wheel
    -- should animate smoothly (default nil).
    --
    -- If nil, the global `rtk.smoothscroll` value is used.  If true or false, it explicitly
    -- overrides the global default for this viewport.
    --
    -- @meta read/write
    -- @type boolean|nil
    smoothscroll = rtk.Attribute{reflow=rtk.Widget.REFLOW_NONE},
    --- The thickness of the scrollbar handle in pixels.  The scrollbar position ignores
    -- `padding` and is always aligned to the viewport's border.
    -- @meta read/write
    -- @type number
    scrollbar_size = 15,
    --- Visibility of the vertical scrollbar (default `SCROLLBAR_HOVER`).
    -- @meta read/write
    -- @type scrollbarconst
    vscrollbar = rtk.Attribute{
        default=rtk.Viewport.SCROLLBAR_HOVER,
        calculate={
            never=rtk.Viewport.SCROLLBAR_NEVER,
            always=rtk.Viewport.SCROLLBAR_ALWAYS,
            hover=rtk.Viewport.SCROLLBAR_HOVER,
            auto=rtk.Viewport.SCROLLBAR_AUTO,
        },
    },
    --- Number of pixels inside the viewport area to offset the vertical scrollbar, where
    -- 0 positions the scrollbar at the right edge of the viewport as normal (default 0).
    --
    -- Any positive value will draw the scrollbar that number of pixels inside the
    -- viewport.  Negative values will have undefined behavior.
    -- @meta read/write
    -- @type number
    vscrollbar_offset = rtk.Attribute{
        default=0,
        -- Scrollbar offset doesn't affect layout
        reflow=rtk.Widget.REFLOW_NONE,
    },
    --- Number of pixels from the edge of the viewport that defines the "hot zone" where,
    -- when the mouse enters this region, a `SCROLLBAR_HOVER` scrollbar will appear with a low
    -- opacity.  The opacity increases once the mouse moves directly over the scrollbar
    -- handle.
    -- @meta read/write
    -- @type number
    vscrollbar_gutter = 25,

    -- TODO: implement horizontal scrollbars
    hscrollbar = rtk.Attribute{
        default=rtk.Viewport.SCROLLBAR_NEVER,
        calculate=rtk.Reference('vscrollbar'),
    },
    hscrollbar_offset = 0,
    hscrollbar_gutter = 25,

    --- Controls whether the `child` widget should be asked to constrain its width to the
    -- viewport's box (false) or if the viewport's inner width should be flexible and
    -- allow the child infinite width under the assumption that we want to allow
    -- horizontal scrolling (true) (default is false).
    -- @meta read/write
    -- @type boolean
    flexw = false,
    --- Like `flexw` but for height (default true).
    -- @meta read/write
    -- @type boolean
    flexh = true,

    --- If set, a shadow will be drawn around the viewport with the specified color (default nil).
    -- The alpha channel in the color affects the weight of the shadow (e.g. `#00000066`).
    -- @meta read/write
    -- @type colortype
    shadow = nil,
    --- When `shadow` is set, this defines the apparent distance the viewport is hovering above
    -- what's underneath (default 20).
    -- @meta read/write
    -- @type number
    elevation = 20,

    -- Overides from rtk.Widget
    --
    -- Ensure dragging the scrollbar doesn't cause any outer viewport we belong to
    -- to show its scrollbar.
    show_scrollbar_on_drag = false,
    -- Ensure touch-dragging immediately calls `handle_dragstart` without any delay.
    touch_activate_delay = 0,
}


--- Create a new viewport with the given attributes.
--
-- @display rtk.Viewport
-- @treturn rtk.Viewport the new viewport widget
function rtk.Viewport:initialize(attrs, ...)
    rtk.Widget.initialize(self, attrs, self.class.attributes.defaults, ...)
    -- Force setting of child viewport/window
    self:_handle_attr('child', self.calc.child, nil, true)
    -- Force calculation of scrollbar colors based on bg color
    self:_handle_attr('bg', self.calc.bg)

    self._backingstore = nil
    -- If scroll*() is called then the offset is dirtied so that it can be clamped
    -- upon next draw or event.
    self._needs_clamping = false
    -- If not nil, then we need to emit onscroll() on next draw.  Value is the previous
    -- scroll position.  Initialize to non-nil value to ensure we trigger onscroll()
    -- after first draw.
    self._last_draw_scroll_left = nil
    self._last_draw_scroll_top = nil

    -- Scrollbar geometry updated during _reflow()
    --
    -- Vertical scrollbar position relative to parent
    self._vscrollx = 0
    self._vscrolly = 0
    self._vscrollh = 0
    self._vscrolla = {
        -- Initialize scrollbar alpha based on whether the scrollbar is always visible.
        current=self.calc.vscrollbar == rtk.Viewport.SCROLLBAR_ALWAYS and 0.1 or 0,
        target=0,
    }
    self._vscroll_in_gutter = false

end

function rtk.Viewport:_handle_attr(attr, value, oldval, trigger, reflow, sync)
    local ok = rtk.Widget._handle_attr(self, attr, value, oldval, trigger, reflow, sync)
    if ok == false then
        return ok
    end
    if attr == 'child' then
        if oldval then
            -- This is basically what rtk.Container:_unparent_child() does, reproduced
            -- here as rtk.Viewport doesn't subclass rtk.Container.
            oldval:_unrealize()
            oldval.viewport = nil
            oldval.parent = nil
            oldval.window = nil
            self:_sync_child_refs(oldval, 'remove')
            if rtk.focused == oldval then
                self:_set_focused_child(nil)
            end
        end
        if value then
            -- Similar to rtk.Container:_reparent_child()
            value.viewport = self
            value.parent = self
            value.window = self.window
            self:_sync_child_refs(value, 'add')
            if rtk.focused == value then
                self:_set_focused_child(value)
            end
        end
    elseif attr == 'bg' then
        -- If no bg is specified, use the window background.  It's not guaranteed
        value = value or rtk.theme.bg
        local luma = rtk.color.luma(value)
        -- Default alphas for scrollbar.  Recalculated based on bg luma when bg is set.
        -- The idea here is to increase opacity of the scrollbar when luma is within the
        -- middle range, and then taper off to 0 roughly below 0.2 and above 0.8 where
        -- the white or black scrollbar is more easily visible.
        -- around the middle range
        local offset = math.max(0, 1 - (1.5 - 3*luma)^2)
        self._scrollbar_alpha_proximity = 0.16 * (1+offset^0.2)
        self._scrollbar_alpha_hover = 0.40 * (1+offset^0.4)
        self._scrollbar_color = luma < 0.5 and '#ffffff' or '#000000'
    elseif attr == 'shadow' then
        -- Force regeneration on reflow.
        self._shadow = nil
    elseif attr == 'scroll_top' or attr == 'scroll_left' then
        self._needs_clamping = true
    end
    return true
end

-- For the next three methods, we hijack rtk.Container's implementations, which don't
-- depend on anything not already available in rtk.Viewport
function rtk.Viewport:_sync_child_refs(child, action)
    return rtk.Container._sync_child_refs(self, child, action)
end

function rtk.Viewport:_set_focused_child(child)
    return rtk.Container._set_focused_child(self, child)
end

function rtk.Viewport:focused(event)
    return rtk.Container.focused(self, event)
end

function rtk.Viewport:remove()
    self:attr('child', nil)
end

function rtk.Viewport:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, uiscale, viewport, window, greedyw, greedyh)
    local calc = self.calc
    calc.x, calc.y = self:_get_box_pos(boxx, boxy)
    local w, h, tp, rp, bp, lp, minw, maxw, minh, maxh = self:_get_content_size(
        boxw, boxh, fillw, fillh, clampw, clamph, nil, greedyw, greedyh
    )
    local hpadding = lp + rp
    local vpadding = tp + bp

    -- Determine bounding box for child
    local inner_maxw = rtk.clamp(w or (boxw - hpadding), minw, maxw)
    local inner_maxh = rtk.clamp(h or (boxh - vpadding), minh, maxh)

    -- Amount of the inner box we need to steal from children for scrollbar.  Only
    -- do so if scrollbar is always visible, or if the scrollbar is auto but the
    -- last reflow needed a scrollbar)
    local scrollw, scrollh = 0, 0
    if calc.vscrollbar == rtk.Viewport.SCROLLBAR_ALWAYS or
       (calc.vscrollbar == rtk.Viewport.SCROLLBAR_AUTO and self._vscrollh > 0) then
        -- Vertical scrollbar takes from width
        scrollw = calc.scrollbar_size * rtk.scale.value
        inner_maxw = inner_maxw - scrollw
    end
    if calc.hscrollbar == rtk.Viewport.SCROLLBAR_ALWAYS or
        (calc.hscrollbar == rtk.Viewport.SCROLLBAR_AUTO and self._hscrollh > 0) then
        -- Horizontal scrollbar takes from height
        scrollh = calc.scrollbar_size * rtk.scale.value
        inner_maxh = inner_maxh - scrollh
    end

    local child = calc.child
    local innerw, innerh
    local hmargin, vmargin
    local ccalc
    if child and child.visible == true then
        ccalc = child.calc
        hmargin = ccalc.lmargin + ccalc.rmargin
        vmargin = ccalc.tmargin + ccalc.bmargin
        -- Remove child margin from max inner size
        inner_maxw = inner_maxw - hmargin
        inner_maxh = inner_maxh - vmargin
        local wx, wy, ww, wh = self:_reflow_child(inner_maxw, inner_maxh, uiscale, window, greedyw, greedyh)
        -- Determine if we need to do a second reflow because scrollbar is auto and we
        -- guessed wrong as to whether one would be needed.
        local pass2 = false
        if calc.vscrollbar == rtk.Viewport.SCROLLBAR_AUTO then
            if scrollw == 0 and wh > inner_maxh then
                -- No scrollbar space reserved in first reflow, but we need one.
                scrollw = calc.scrollbar_size * rtk.scale.value
                inner_maxw = inner_maxw - scrollw
                -- Only need a second pass if child width had exceeded our new maxw
                pass2 = ww > inner_maxw
            elseif scrollw > 0 and wh <= inner_maxh then
                -- Scrollbar reserved, but we didn't need one.  Give the space back and
                -- reflow. Only need a second pass if child had consumed all offered width
                -- (rom which we can infer it was expanded), and now that we are adding
                -- more space to maxw, it will likely consume that as well.
                pass2 = ww == inner_maxw
                inner_maxw = inner_maxw + scrollw
                scrollw = 0
            end
        end
        if pass2 then
            -- We've changed inner_maxw (either adding or removing space for a scrollbar)
            -- and it seems like the child would be affected by this, so do a second
            -- reflow with the adjusted box.
            wx, wy, ww, wh = self:_reflow_child(inner_maxw, inner_maxh, uiscale, window, greedyw, greedyh)
        end
        if calc.halign == rtk.Widget.CENTER then
            wx = wx + math.max(0, inner_maxw - ccalc.w) / 2
        elseif calc.halign == rtk.Widget.RIGHT then
            wx = wx + math.max(0, (inner_maxw - ccalc.w) - rp)
        end
        if calc.valign == rtk.Widget.CENTER then
            wy = wy + math.max(0, inner_maxh - ccalc.h) / 2
        elseif calc.valign == rtk.Widget.BOTTOM then
            wy = wy + math.max(0, (inner_maxh - ccalc.h) - bp)
        end
        -- Update child position if alignment had changed it
        ccalc.x = wx
        ccalc.y = wy
        child:_realize_geometry()
        -- calc size of viewport takes into account widget's size and x/y offset within
        -- the viewport, clamping to the viewport's box.  We take the ceiling because technically
        -- dimensions could be fractional (thanks to rtk.scale) but we need to ensure we create
        -- a backing store image with integer dimensions.
        innerw = math.ceil(rtk.clamp(ww + wx, fillw and greedyw and inner_maxw, inner_maxw))
        innerh = math.ceil(rtk.clamp(wh + wy, fillh and greedyh and inner_maxh, inner_maxh))
    else
        -- Without a child to define influence our size, default to the child bounding
        -- box.
        innerw, innerh = inner_maxw, inner_maxh
        hmargin, vmargin = 0, 0
    end

    -- Only need to add child margin back in if we're using child's size.  If using our own
    -- size, w/h will be non-nil and that already incorporates child margin.
    calc.w = rtk.clamp((w or (innerw + scrollw + hmargin)) + hpadding, minw, maxw)
    calc.h = rtk.clamp((h or (innerh + scrollh + vmargin)) + vpadding, minh, maxh)

    if not self._backingstore then
        self._backingstore = rtk.Image(innerw, innerh)
    else
        self._backingstore:resize(innerw, innerh, false)
    end

    self._vscrollh = 0
    self._needs_clamping = true
    if ccalc then
        self._scroll_clamp_left = math.max(0, ccalc.w - calc.w + lp + rp + ccalc.lmargin + ccalc.rmargin)
        self._scroll_clamp_top = math.max(0, ccalc.h - calc.h + tp + bp + ccalc.tmargin + ccalc.bmargin)
    end
end

function rtk.Viewport:_reflow_child(maxw, maxh, uiscale, window, greedyw, greedyh)
    local calc = self.calc
    return calc.child:reflow(
        -- box
        0, 0,
        maxw,
        maxh,
        -- Explicitly pass false to child widget for fill flags to prevent clamping to
        -- the above box.  The child of a viewport should express its full size and
        -- reflow within that, while the viewport simply scrolls within it.
        false, false,
        not calc.flexw,
        not calc.flexh,
        uiscale,
        -- Set the child's viewport to ourself
        self,
        window,
        -- Unlike fill which we force to false, we do propagate the greedy flags to
        -- ensure fill children don't balloon us to our box.
        greedyw, greedyh
    )
end

function rtk.Viewport:_realize_geometry()
    local calc = self.calc
    local tp, rp, bp, lp = self:_get_padding_and_border()
    if self.child then
        local innerh = self._backingstore.h
        local ch = self.child.calc.h
        -- Calculate fixed scrollbar parameters even if vscrollbar=never so that scrolling by
        -- mousewheel or API still works.  For vertical scrollbars, x position and scrollbar
        -- height is fixed until next reflow.  y coordinate OTOH is not, as the thumb can be
        -- dragged without reflow.
        if ch > innerh then
            self._vscrollx = calc.x + calc.w - calc.scrollbar_size * rtk.scale.value - calc.vscrollbar_offset
            self._vscrolly = calc.y + calc.h * calc.scroll_top / ch + tp
            self._vscrollh = calc.h * innerh  / ch
        end
    end
    if self.shadow then
        if not self._shadow then
            self._shadow = rtk.Shadow(calc.shadow)
        end
        self._shadow:set_rectangle(calc.w, calc.h, calc.elevation)
    end
    self._pre = {tp=tp, rp=rp, bp=bp, lp=lp}
end

function rtk.Viewport:_unrealize()
    self._backingstore = nil
    if self.child then
        self.child:_unrealize()
    end
end

function rtk.Viewport:_draw(offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    rtk.Widget._draw(self, offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    local calc = self.calc
    local pre = self._pre
    -- Preserve drawing target client coordinates which are used to adjust scrollbar
    -- to client coordinates
    self.cltargetx = cltargetx
    self.cltargety = cltargety
    local x = calc.x + offx + pre.lp
    local y = calc.y + offy + pre.tp

    local lastleft, lasttop
    local scrolled = calc.scroll_left ~= self._last_draw_scroll_left or
                     calc.scroll_top ~= self._last_draw_scroll_top
    if scrolled then
        lastleft, lasttop = self._last_draw_scroll_left or 0, self._last_draw_scroll_top or 0
        if self:onscrollpre(lastleft, lasttop, event) == false then
            -- Scroll was rejected by the handler.  Revert.
            calc.scroll_left = lastleft or 0
            calc.scroll_top = lasttop
            -- Don't fire onscroll() later.
            scrolled = false
        else
            self._last_draw_scroll_left = calc.scroll_left
            self._last_draw_scroll_top = calc.scroll_top
        end
    end

    if y + calc.h < 0 or y > cliph or calc.ghost then
        -- Viewport would not be visible on current drawing target
        return false
    end

    self:_handle_drawpre(offx, offy, alpha, event)
    -- Force alpha to 1.0 here and when we draw the child just below as the correctv
    -- alpha will be applied when blitting.
    self:_draw_bg(offx, offy, 1.0, event)
    local child = calc.child
    if child and child.realized then
        self:_clamp()
        x = x + child.calc.lmargin
        y = y + child.calc.tmargin
        -- Redraw the backing store, first "clearing" it according to what's currently painted
        -- underneath it.
        self._backingstore:blit{src=gfx.dest, sx=x, sy=y, mode=rtk.Image.FAST_BLIT}
        self._backingstore:pushdest()
        -- Explicitly draw child with alpha=1.0 because ...
        child:_draw(
            -calc.scroll_left, -calc.scroll_top,
            1.0, event,
            calc.w, calc.h,
            cltargetx + x, cltargety + y,
            0, 0
        )
        child:_draw_debug_box(-calc.scroll_left, -calc.scroll_top, event)
        self._backingstore:popdest()
        -- ... we apply the proper alpha when blitting the viewport backing store onto the
        -- destination.
        self._backingstore:blit{dx=x, dy=y, alpha=alpha * calc.alpha}
        self:_draw_scrollbars(offx, offy, cltargetx, cltargety, alpha, event)
    end

    if calc.shadow then
        self._shadow:draw(calc.x + offx, calc.y + offy, alpha * calc.alpha)
    end
    self:_draw_borders(offx, offy, alpha)
    if scrolled then
        self:onscroll(lastleft, lasttop, event)
    end
    self:_handle_draw(offx, offy, alpha, event)

end

function rtk.Viewport:_draw_scrollbars(offx, offy, cltargetx, cltargety, alpha, event)
    if self._vscrolla.current == 0 or self._vscrollh == 0 then
        -- Nothing to draw
        return
    end
    local calc = self.calc
    local scrx = offx + self._vscrollx
    local scry = offy + calc.y + calc.h * calc.scroll_top / self.child.calc.h
    self:setcolor(self._scrollbar_color, self._vscrolla.current * alpha)
    gfx.rect(scrx, scry, calc.scrollbar_size * rtk.scale.value, self._vscrollh + 1, 1)
end

function rtk.Viewport:_calc_scrollbar_alpha(clparentx, clparenty, event, dragchild)
    local calc = self.calc
    if calc.vscrollbar == rtk.Viewport.SCROLLBAR_NEVER then
        return
    end
    local dragself = (rtk.dnd.dragging == self)
    -- Default alpha and animation step (lower values == slower)
    local alpha = 0
    local duration = 0.2

    if self._vscrollh > 0 then
        if not rtk._modal or rtk.is_modal(self) then
            -- Either no modal widgets, or we're modal, so it's business as usual.
            local overthumb = event:get_button_state(self.id)
            if self.mouseover then
                if overthumb == nil and self._vscroll_in_gutter then
                    overthumb = rtk.point_in_box(
                        event.x, event.y,
                        clparentx + self._vscrollx,
                        clparenty + calc.y + calc.h * calc.scroll_top / self.child.calc.h,
                        calc.scrollbar_size * rtk.scale.value, self._vscrollh
                    )
                end
                if event.type == rtk.Event.MOUSEDOWN then
                    -- Remember for subsequent drag-mousemove whether we were over the scroll
                    -- thumb at the time of mousedown.
                    event:set_button_state(self.id, overthumb)
                end
            end
            if self._vscroll_in_gutter or dragself then
                if overthumb then
                    alpha = self._scrollbar_alpha_hover
                    duration = 0.1
                else
                    alpha = self._scrollbar_alpha_proximity
                end
            elseif self.mouseover or calc.vscrollbar == rtk.Viewport.SCROLLBAR_ALWAYS then
                alpha = self._scrollbar_alpha_proximity
            elseif dragchild and dragchild.show_scrollbar_on_drag then
                alpha = self._scrollbar_alpha_proximity
                duration = 0.15
            end
        elseif calc.vscrollbar == rtk.Viewport.SCROLLBAR_ALWAYS then
            -- There are other modal widgets, but scrollbar is set to always
            alpha = self._scrollbar_alpha_proximity
        end
    end
    if alpha ~= self._vscrolla.target then
        if alpha == 0 then
            -- Slower fade-out animation
            duration = 0.3
        end
        rtk.queue_animation{
            key=string.format('%s.vscrollbar', self.id),
            src=self._vscrolla.current,
            dst=alpha,
            duration=duration,
            update=function(value)
                self._vscrolla.current = value
                self:queue_draw()
            end,
        }
        self._vscrolla.target = alpha
        self:queue_draw()
    end
end

function rtk.Viewport:_handle_event(clparentx, clparenty, event, clipped, listen)
    local calc = self.calc
    local pre = self._pre
    listen = self:_should_handle_event(listen)
    local x = calc.x + clparentx
    local y = calc.y + clparenty
    local hovering = rtk.point_in_box(event.x, event.y, x, y, calc.w, calc.h) and self.window.in_window
    local dragging = rtk.dnd.dragging
    local is_child_dragging = dragging and dragging.viewport == self
    local child = self.child

    -- Don't check for listen==true at this level as we want to handle the case where
    -- we are currently in proximity of the scrollbar and some other widget goes
    -- modal.  At that point we want to be able to hide the scrollbar.
    if event.type == rtk.Event.MOUSEMOVE then
        self._vscroll_in_gutter = false
        if listen and is_child_dragging and dragging.scroll_on_drag then
            -- If child is dragging against our boundary, autoscroll
            if event.y - 20 < y then
                self:scrollby(0, -math.max(5, math.abs(y - event.y)), false)
            elseif event.y + 20 > y + calc.h then
                self:scrollby(0, math.max(5, math.abs(y + calc.h - event.y)), false)
            end
        elseif listen and not dragging and not event.handled and hovering then
            if calc.vscrollbar ~= rtk.Viewport.SCROLLBAR_NEVER and self._vscrollh > 0 then
                local gutterx = self._vscrollx + clparentx - calc.vscrollbar_gutter
                local guttery = calc.y + clparenty
                -- Are we hovering in the scrollbar gutter?
                if rtk.point_in_box(event.x, event.y, gutterx, guttery,
                                    calc.vscrollbar_gutter + calc.scrollbar_size*rtk.scale.value, calc.h) then
                    self._vscroll_in_gutter = true
                    if event.x >= self._vscrollx + clparentx then
                        event:set_handled(self)
                    end
                end
            end
        end
    elseif listen and not event.handled and event.type == rtk.Event.MOUSEDOWN then
        if not self:cancel_animation('scroll_top') then
            self:_reset_touch_scroll()
        end
        if self._vscroll_in_gutter and event.x >= self._vscrollx + clparentx then
            local scrolly = self:_get_vscrollbar_client_pos()
            if event.y < scrolly or event.y > scrolly + self._vscrollh then
                self:_handle_scrollbar(event, nil, self._vscrollh / 2, true)
            end
            event:set_handled(self)
        end
    end

    if (not event.handled or event.type == rtk.Event.MOUSEMOVE) and
       not (event.type == rtk.Event.MOUSEMOVE and self.window:_is_touch_scrolling(self)) and
       child and child.visible and child.realized then
        self:_clamp()
        child:_handle_event(
            x - calc.scroll_left + pre.lp + child.calc.lmargin,
            y - calc.scroll_top + pre.tp + child.calc.tmargin,
            event,
            clipped or not hovering,
            listen
        )
    end
    if listen and hovering and not event.handled and event.type == rtk.Event.MOUSEWHEEL then
        -- Only scroll and handle this effect if the inner height is greater than the
        -- viewport height.  In other words, if we don't actually have anything to scroll,
        -- let this scroll event be handled by the parent viewport (if any).
        if child and self._vscrollh > 0 and event.wheel ~= 0 then
            local distance = event.wheel * math.min(calc.h/2, 120)
            self:scrollby(0, distance)
            event:set_handled(self)
        end
    end
    listen = rtk.Widget._handle_event(self, clparentx, clparenty, event, clipped, listen)
    -- Containers are considered in mouseover if any of their children are in mouseover
    self.mouseover = self.mouseover or (child and child.mouseover)
    -- Now that mouseover status is determined, calculate scrollbar visibility
    self:_calc_scrollbar_alpha(clparentx, clparenty, event, is_child_dragging and dragging)
    return listen
end

function rtk.Viewport:_get_vscrollbar_client_pos()
    local calc = self.calc
    return self.clienty + calc.h * calc.scroll_top / self.child.calc.h
end

function rtk.Viewport:_handle_scrollbar(event, hoffset, voffset, gutteronly, natural)
    local calc = self.calc
    local pre = self._pre
    if voffset ~= nil then
        self:cancel_animation('scroll_top')
        if gutteronly then
            local ssy = self:_get_vscrollbar_client_pos()
            if event.y >= ssy and event.y <= ssy + self._vscrollh then
                -- Mouse is not in the gutter.
                return false
            end
        end
        local target
        if natural then
            target = calc.scroll_top + (voffset - event.y)
        else
            local pct = rtk.clamp(event.y - self.clienty - voffset, 0, calc.h) / calc.h
            target = pct * (self.child.calc.h)
        end
        -- Explicitly don't smooth scroll with scollbar movements.
        self:scrollto(calc.scroll_left, target, false)
    end
end

function rtk.Viewport:_handle_dragstart(event, x, y, t)
    -- Superclass method disables dragging so don't call it.
    local draggable, droppable = self:ondragstart(self, event, x, y, t)
    if draggable ~= nil then
        return draggable, droppable
    end
    if math.abs(y - event.y) > 0 then
        if self._vscroll_in_gutter and event.x >= self._vscrollx + self.offx + self.cltargetx then
            -- If here, we are dragging the scroll handle itself. Second return value of false
            -- indicates we are not droppable
            return {true, y - self:_get_vscrollbar_client_pos(), nil, false}, false
        elseif rtk.touchscroll and event.buttons & rtk.mouse.BUTTON_LEFT ~= 0 and self._vscrollh > 0 then
            self.window:_set_touch_scrolling(self, true)
            return {true, y, {{x, y, t}}, true}, false
        end
    end
    return false, false
end

function rtk.Viewport:_handle_dragmousemove(event, arg)
    local ok = rtk.Widget._handle_dragmousemove(self, event)
    if ok == false or event.simulated then
        return ok
    end
    local vscrollbar, lasty, samples, natural = table.unpack(arg)
    if vscrollbar then
        self:_handle_scrollbar(event, nil, lasty, false, natural)
        if natural then
            -- We are touch scrolling. Update our internal drag state with the latest
            -- mouse y position.
            arg[2] = event.y
            samples[#samples+1] = {event.x, event.y, event.time}
        end
        -- Some widget above the viewport (and under the mouse) may already have requested
        -- a mouse cursor, but we want to override that in case we are touch scrolling, so
        -- we force-replace the cursor (by passing true here).
        self.window:request_mouse_cursor(rtk.mouse.cursors.POINTER, true)
    end
    return true
end

function rtk.Viewport:_reset_touch_scroll()
    -- Verify self.window is valid because if viewport was unparented or hidden while in
    -- the middle of a kinetic scroll, when the animation finishes this gets called, but
    -- self.window may be nil at that point.
    if self.window then
        self.window:_set_touch_scrolling(self, false)
    end
end

function rtk.Viewport:_handle_dragend(event, arg)
    local ok = rtk.Widget._handle_dragend(self, event)
    if ok == false then
        return ok
    end
    local vscrollbar, lasty, samples, natural = table.unpack(arg)
    if natural then
        local now = event.time
        local x1, y1, t1 = event.x, event.y, event.time
        for i = #samples, 1, -1 do
            local x, y, t = table.unpack(samples[i])
            if now - t > 0.2 then
                break
            end
            x1, y1, t1 = x, y, t
        end
        local v = 0
        if t1 ~= event.time then
            v = (event.y - y1) - (event.time - t1)
        end
        local distance = v * rtk.scale.value
        local x, y = self:_get_clamped_scroll(self.calc.scroll_left, self.calc.scroll_top - distance)
        -- FIXME: duration should be a function of distance
        local duration = 1

        self:animate{attr='scroll_top', dst=y, duration=duration, easing='out-cubic'}
            :done(function() self:_reset_touch_scroll() end)
            :cancelled(function() self:_reset_touch_scroll() end)
    end
    -- In case we release the mouse in a different location (off the scrollbar
    -- handle or even outside the gutter), ensure the new state gets redrawn.
    self:queue_draw()
    -- Handle the event to prevent mouseup from closing modal popups when rtk.touchscroll
    -- is true (in which case unhandled mouseups cause modal widgets to be cleared).
    event:set_handled(self)
    return true
end

function rtk.Viewport:_scrollto(x, y, smooth, animx, animy)
    local calc = self.calc
    if not smooth or not self.realized then
        x = x or self.scroll_left
        y = y or self.scroll_top
        if x == calc.scroll_left and y == calc.scroll_top then
            return
        end
        -- We blindly accept the provided positions as the child hasn't been reflowed so
        -- we can't sanity check the bounds.  Instead, the offsets will be clamped on next
        -- draw or event.
        self._needs_clamping = true
        calc.scroll_left = x
        calc.scroll_top = y
        -- Sync to user-facing attributes.
        self.scroll_left = calc.scroll_left
        self.scroll_top = calc.scroll_top
        self:queue_draw()
    else
        -- Unlike above, we can clamp now before starting the animation because we know
        -- we're realized.
        x, y = self:_get_clamped_scroll(x or calc.scroll_left, y or calc.scroll_top)
        animx = animx or self:get_animation('scroll_left')
        animy = animy or self:get_animation('scroll_top')
        if calc.scroll_left ~= x and (not animx or animx.dst ~= x) then
            self:animate{attr='scroll_left', dst=x, duration=0.15}
        end
        if calc.scroll_top ~= y and (not animy or animy.dst ~= y) then
            self:animate{attr='scroll_top', dst=y, duration=0.2, easing='out-sine'}
        end
    end
end

function rtk.Viewport:_get_smoothscroll(override)
    if override ~= nil then
        return override
    end
    local calc = self.calc
    if calc.smoothscroll ~= nil then
        return calc.smoothscroll
    end
    -- Fall back to global default
    return rtk.smoothscroll
end

--- Scrolls the viewport to a specific horizontal and/or vertical offset.
--
-- If either value is nil then the current position will be used, allowing you to scroll
-- only in one direction.  Values that exceed the viewport bounds will be clamped as
-- needed.
--
-- This is a shorthand for calling `attr()` on the `scroll_left` and `scroll_top` attributes,
-- but unlike `attr()` this also allows overriding `smoothscroll`.
--
-- @tparam number|nil x the offset from the left edge to scroll the viewport, or nil to not
--   scroll horizontally
-- @tparam number|nil y the offset from the top edge to scroll the viewport, or nil to
--   not scroll vertically
-- @tparam boolean|nil smooth true to force smooth scrolling even if `smoothscroll` is false,
--  false to force-disable smooth scrolling even if `smoothscroll` is true, or nil to use
--  the current value of `smoothscroll`
function rtk.Viewport:scrollto(x, y, smooth)
    self:_scrollto(x, y, self:_get_smoothscroll(smooth))
end


--- Scrolls the viewport horizontally and/or vertically by a relative offset.
--
-- @tparam number|nil offx the offset from the current `scroll_left` value, or nil to not
--   scroll horizontally
-- @tparam number|nil offy the offset from the current `scroll_top` value, or nil to
--   not scroll vertically
-- @tparam boolean|nil smooth true to force smooth scrolling even if `smoothscroll` is false,
--  false to force-disable smooth scrolling even if `smoothscroll` is true, or nil to use
--  the current value of `smoothscroll`
function rtk.Viewport:scrollby(offx, offy, smooth)
    local calc = self.calc
    local x, y, animx, animy
    smooth = self:_get_smoothscroll(smooth)
    if smooth then
        -- Compound the offset with any current animation(s) so that we maintain
        -- velocity with rapid scrolling.
        animx = self:get_animation('scroll_left')
        animy = self:get_animation('scroll_top')
        x = (animx and animx.dst or calc.scroll_left) + (offx or 0)
        y = (animy and animy.dst or calc.scroll_top) + (offy or 0)
    else
        x = calc.scroll_left + (offx or 0)
        y = calc.scroll_top + (offy or 0)
    end
    self:_scrollto(x, y, smooth, animx, animy)
end

--- Returns true if the viewport's child has at least one dimension greater
-- than the viewport's own bounding box such that scrolling would be necessary
-- to see the entire child.
--
-- @treturn boolean true if the viewport's child is larger than the viewport,
--   false otherwise.
function rtk.Viewport:scrollable()
    if not self.child then
        return false
    end
    local vcalc = self.calc
    local ccalc = self.child.calc
    return ccalc.w > vcalc.w or ccalc.h > vcalc.h
end

-- Clamp viewport position to fit child's current dimensions.  Caller must ensure child
-- has been realized.
function rtk.Viewport:_get_clamped_scroll(left, top)
    -- Clamp viewport position to fit child's current dimensions
    return rtk.clamp(left, 0, self._scroll_clamp_left),
           rtk.clamp(top, 0, self._scroll_clamp_top)
end

function rtk.Viewport:_clamp()
    if self._needs_clamping then
        local calc = self.calc
        calc.scroll_left, calc.scroll_top = self:_get_clamped_scroll(self.scroll_left, self.scroll_top)
        -- Sync to user-facing attributes.
        self.scroll_left, self.scroll_top = calc.scroll_left, calc.scroll_top
        self._needs_clamping = false
    end
end

--- Event Handlers.
--
-- See also @{widget.handlers|handlers for rtk.Widget}.
--
-- @section viewport.handlers


--- Called when the viewport scrolls *before* the `child` is drawn.
--
-- The `scroll_left` and `scroll_top` attributes indicate the new scroll
-- offsets.
--
-- This callback has the opportunity to block or mutate the scroll position before the
-- viewport `child` is drawn.  Because it's invoked before the child is drawn, handlers
-- must not access any of the child's attributes that are populated on draw, such as
-- `offx`/`offy` or `clientx`/`clienty`.
--
-- @tparam number last_left the last horizontal scroll offset before the change
-- @tparam number last_top the last vertical scroll offset before the change
-- @tparam rtk.Event event the event that occurred at the time of the redraw when
--   the change in scroll position was noticed
-- @treturn boolean|nil if false, the scroll is rejected and the previous scroll
--   offsets are restored, otherwise any other value allows the scroll to occur.
function rtk.Viewport:onscrollpre(last_left, last_top, event) end

--- Called when the viewport scrolls after the `child` is drawn.
--
-- The `scroll_left` and `scroll_top` attributes indicate the new scroll
-- offsets.
--
-- Because this is invoked after the child is drawn, draw-provided attributes such as
-- offx`/`offy` or `clientx`/`clienty` will be available.
--
-- This callback is invoked prior to `ondraw()`.
--
-- @tparam number last_left the last horizontal scroll offset before the change
-- @tparam number last_top the last vertical scroll offset before the change
-- @tparam rtk.Event event the event that occurred at the time of the redraw when
--   the change in scroll position was noticed
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Viewport:onscroll(last_left, last_top, event) end