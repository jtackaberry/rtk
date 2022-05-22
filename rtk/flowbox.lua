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

--- Container where children are arranged in rows, wrapping around to a flexible
-- number of columns as permitted by the width of the parent container.  Widgets
-- are arranged vertically first, and then wrap over to the next column if space is
-- available.
--
-- @example
--  local box = window:add(rtk.FlowBox{vspacing=5, hspacing=10})
--  for i = 1, 6 do
--      box:add(rtk.Button{'Hello ' .. tostring(i)})
--  end
--
-- ![](../img/flowbox.gif)
--
-- @warning WIP
--   This class is currently missing support for cell alignment attributes (`halign`/`valign`).
--
-- @class rtk.FlowBox
-- @inherits rtk.Container
-- @see rtk.VBox rtk.HBox
rtk.FlowBox = rtk.class('rtk.FlowBox', rtk.Container)

--- Class API.
--
-- In addition to all the methods and attributes of the base `rtk.Container` class, FlowBox
-- also adds the following:
--
--- @section api
rtk.FlowBox.register{
    --- Amount of vertical spacing (in pixels) between adjacent cells (default 0).
    -- @type number
    -- @meta read/write
    vspacing = rtk.Attribute{
        default=0,
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- Amount of horizontal spacing (in pixels) between adjacent cells (default 0).
    -- @type number
    -- @meta read/write
    hspacing = rtk.Attribute{
        default=0,
        reflow=rtk.Widget.REFLOW_FULL,
    },
}

function rtk.FlowBox:initialize(attrs, ...)
    rtk.Container.initialize(self, attrs, self.class.attributes.defaults, ...)
end

function rtk.FlowBox:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, uiscale, viewport, window, greedyw, greedyh)
    local calc = self.calc
    local x, y = self:_get_box_pos(boxx, boxy)
    local w, h, tp, rp, bp, lp, minw, maxw, minh, maxh = self:_get_content_size(
        boxw, boxh, fillw, fillh, clampw, clamph, nil, greedyw, greedyh
    )
    -- Our default size is the given box without our padding
    local inner_maxw = rtk.clamp(w or (boxw - lp - rp), minw, maxw)
    local inner_maxh = rtk.clamp(h or (boxh - tp - bp), minh, maxh)
    -- If we have a constrained width or height, ensure we tell children to clamp to it
    -- regardless of what our parent told us.
    clampw = clampw or w ~= nil or fillw
    clamph = clamph or h ~= nil or fillh
    local child_geometry = {}
    local hspacing = (calc.hspacing or 0) * rtk.scale.value
    local vspacing = (calc.vspacing or 0) * rtk.scale.value

    self._reflowed_children = {}
    self._child_index_by_id = {}

    -- First pass to determine the intrinsic size of each child widget.  We use this to
    -- calculate number of columns and height of each row.
    local child_maxw = 0
    local child_totalh = 0
    for _, widgetattrs in ipairs(self.children) do
        local widget, attrs = table.unpack(widgetattrs)
        local wcalc = widget.calc
        if wcalc.visible == true and wcalc.position & rtk.Widget.POSITION_INFLOW ~= 0 then
            local ctp, crp, cbp, clp = self:_get_cell_padding(widget, attrs)
            -- Calculate effective min/max cell values, which adjusts the scale of
            -- non-relative values when scalability is full, and converts relative sizes
            -- to absolute values relative to the box (w/h in this case) when reflow is
            -- greedy.
            attrs._minw = self:_adjscale(attrs.minw, uiscale, greedyw and inner_maxw)
            attrs._maxw = self:_adjscale(attrs.maxw, uiscale, greedyw and inner_maxw)
            attrs._minh = self:_adjscale(attrs.minh, uiscale, greedyh and inner_maxh)
            attrs._maxh = self:_adjscale(attrs.maxh, uiscale, greedyh and inner_maxh)
            local wx, wy, ww, wh = widget:reflow(
                0,
                0,
                rtk.clamp(inner_maxw, attrs._minw, attrs._maxw),
                rtk.clamp(inner_maxh, attrs._minh, attrs._maxh),
                nil,
                nil,
                clampw, clamph,
                uiscale,
                viewport,
                window,
                -- Perform a non-greedy reflow on the first pass to allow children to use
                -- fill/expand.  Otherwise a greedy reflow with fill/expand children would
                -- force us down to a single column.
                false,
                false
            )
            ww = ww + clp + crp
            wh = wh + ctp + cbp
            child_maxw = math.min(math.max(child_maxw, ww, attrs._minw or 0), inner_maxw)
            child_totalh = child_totalh + math.max(wh, attrs._minh or 0)
            child_geometry[#child_geometry+1] = {x=wx, y=wy, w=ww, h=wh}
        end
    end
    child_totalh = child_totalh + (#self.children - 1) * vspacing

    -- All columns are equal size based on the widest child.
    local col_width = math.ceil(child_maxw)
    local num_columns = math.floor((inner_maxw + hspacing) / (col_width + hspacing))
    -- If flowbox height is specified use that as a fixed column height, otherwise
    -- calculate a column height that fits all the children within num_columns.
    local col_height = h
    if not col_height and #child_geometry > 0 then
        -- Brute-force compute column height by incrementally summing the heights of
        -- the first n children until we find an n such that all children fit within
        -- num_columns.
        --
        -- This is begging for optimization but for lower child counts (under 100 or so)
        -- it's pretty quick (about 10-20 usec on my 2950X).
        col_height = child_geometry[1].h
        for i = 2, #child_geometry do
            local need_columns = 1
            local cur_colh = 0
            for j = 1, #child_geometry do
                local wh = child_geometry[j].h
                if cur_colh + wh > col_height then
                    need_columns = need_columns + 1
                    cur_colh = 0
                end
                cur_colh = cur_colh + wh + (j > 1 and vspacing or 0)
            end
            if need_columns <= num_columns then
                num_columns = need_columns
                break
            end
            col_height = col_height + vspacing + child_geometry[i].h
        end
    end
    -- rtk.log.info('reflow pass 1: content=%s,%s ncol=%d totalh=%s col_height=%s', w, h, num_columns, child_totalh, col_height)

    -- FIXME: if a child as relative size to parent (e.g. width=-10) then we end up
    -- shrinking the child in the second pass compared to the first, because we offer it
    -- less space.  We should expand col_width to fit the offered size provided we can
    -- still fit the number of columns.  Maybe round up to inner_maxw / col_width?

    -- Max column width for children set to fill.
    local col_width_max = math.floor((inner_maxw - ((num_columns-1) * hspacing)) / num_columns)
    -- Running total of children width/height on current column.
    local col = {w=0, h=0, n=1}
    -- Current position offsets for children
    local offset = {x=0, y=0}
    -- Total cumulative inner dimensions
    local inner = {w=0, h=0}
    -- Horizontal spacing for the current cell
    local chspacing = (col.n < num_columns) and hspacing or 0
    -- TODO: implement cell alignments
    for _, widgetattrs in ipairs(self.children) do
        local widget, attrs = table.unpack(widgetattrs)
        local wcalc = widget.calc
        attrs._cellbox = nil
        if widget == rtk.Box.FLEXSPACE then
            col.w = inner_maxw
        elseif wcalc.visible == true then
            local ctp, crp, cbp, clp = self:_get_cell_padding(widget, attrs)
            child_maxw = (attrs.fillw and attrs.fillw ~= 0) and col_width_max or col_width

            local wx, wy, ww, wh = widget:reflow(
                clp,
                ctp,
                child_maxw - clp - crp,
                inner_maxh,
                attrs.fillw and attrs.fillw ~= 0,
                attrs.fillh and attrs.fillh ~= 0,
                clampw, clamph,
                uiscale,
                viewport,
                window,
                greedyw,
                greedyh
            )
            wh = math.max(wh, attrs.minh or 0)
            if col.h + wh > col_height then
                -- Wrap to new column.
                inner.w = inner.w + col.w
                offset.x = offset.x + col.w
                offset.y = 0
                col.w, col.h = 0, 0
                col.n = col.n + 1
                chspacing = (col.n < num_columns) and hspacing or 0
            end

            wcalc.x = wx + offset.x + lp
            wcalc.y = wy + offset.y + tp
            widget.box[1] = widget.box[1] + offset.x + lp
            widget.box[2] = widget.box[2] + offset.y + tp
            self:_set_cell_box(attrs, lp + offset.x, tp + offset.y, child_maxw, wh + ctp + cbp)
            if wcalc.position & rtk.Widget.POSITION_INFLOW ~= 0 then
                -- This is a bit of a heuristic.  We don't actually know if there's enough
                -- room in the box for the next widget.  But assuming the box geometry is
                -- based on its intrinsic size, this will work.
                local cvspacing = (col.h + wh < col_height) and vspacing or 0
                offset.y = offset.y + wy + wh + cvspacing
                col.w = math.max(col.w, child_maxw + chspacing)
                col.h = col.h + wh + cvspacing + ctp + cbp
                inner.h = math.max(inner.h, col.h)
            end
            widget:_realize_geometry()
            self:_add_reflowed_child(widgetattrs, attrs.z or widget.z or 0)
        else
            widget.realized = false
        end
    end

    self:_determine_zorders()

    inner.w = inner.w + col.w
    calc.x, calc.y = x, y
    calc.w = math.ceil(rtk.clamp((w or inner.w) + lp + rp, minw, maxw))
    calc.h = math.ceil(rtk.clamp((h or inner.h) + tp + bp, minh, maxh))
end
