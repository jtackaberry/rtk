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
local log = require('rtk.log')

---
-- @module animate

-- Animation constants used by easing functions
local c1 = 1.70158
local c2 = c1 * 1.525
local c3 = c1 + 1
local c4 = (2 * math.pi) / 3
local c5 = (2 * math.pi) / 4.5
local n1 = 7.5625
local d1 = 2.75

--- Easing functions.
--
-- Easing functions control the rate of change of the attribute being animated over
-- time, and define the basic contour of the animation.
--
-- These easing function names can be used as the `easing` argument to either
-- `rtk.Widget:animate()` (the preferred way to animate a widget) or
-- `rtk.queue_animation()`.
--
-- @note Visual aid
--   See [easings.net](https://easings.net/) for an excellent visual aid on the behavior
--   of each easing functions.  All the easing functions listed on that website are supported
--   by rtk.
--
-- You can add custom easing functions to this table as well, keyed on the easing function
-- name.  The function receives one parameter -- a value between 0.0 and 1.0 that represents
-- the animation's current position in time within the animation -- and returns the transformed
-- value.
--
-- @table rtk.easing
-- @compact
rtk.easing = {
    --- @meta ![linear]()
    ['linear'] = function(x)
        return x
    end,
    --- @meta ![in-sine]()
    ['in-sine'] = function(x)
        return 1 - math.cos((x * math.pi) / 2)
    end,
    --- @meta ![out-sine]()
    ['out-sine'] = function(x)
        return math.sin((x * math.pi) / 2)
    end,
    --- @meta ![in-out-sine]()
    ['in-out-sine'] = function(x)
        return -(math.cos(math.pi * x) - 1) / 2
    end,
    --- @meta ![in-quad]()
    ['in-quad'] = function(x)
        return x * x
    end,
    --- @meta ![out-quad]()
    ['out-quad'] = function(x)
        return 1 - (1 - x) * (1 - x)
    end,
    --- @meta ![in-out-quad]()
    ['in-out-quad'] = function(x)
        return (x < 0.5) and (2*x*x) or (1 - (-2 * x + 2)^2 / 2)
    end,
    --- @meta ![in-cubic]()
    ['in-cubic'] = function(x)
        return x * x * x
    end,
    --- @meta ![out-cubic]()
    ['out-cubic'] = function(x)
        return 1 - (1-x)^4
    end,
    --- @meta ![in-out-cubic]()
    ['in-out-cubic'] = function(x)
        return (x < 0.5) and (4*x*x*x) or (1 - (-2 * x + 2)^3 / 2)
    end,
    --- @meta ![in-quart]()
    ['in-quart'] = function(x)
        return x * x * x * x
    end,
    --- @meta ![out-quart]()
    ['out-quart'] = function(x)
        return 1 - (1 - x)^4
    end,
    --- @meta ![in-out-quart]()
    ['in-out-quart'] = function(x)
        return (x < 0.5) and (8*x*x*x*x) or (1 - (-2 * x + 2)^4 / 2)
    end,
    --- @meta ![in-quint]()
    ['in-quint'] = function(x)
        return x * x * x * x * x
    end,
    --- @meta ![out-quint]()
    ['out-quint'] = function(x)
        return 1 - (1 - x)^5
    end,
    --- @meta ![in-out-quint]()
    ['in-out-quint'] = function(x)
        return (x < 0.5) and (16*x*x*x*x*x) or (1 - (-2 * x + 2)^5 / 2)
    end,
    --- @meta ![in-expo]()
    ['in-expo'] = function(x)
        return (x == 0) and 0 or 2^(10*x - 10)
    end,
    --- @meta ![out-expo]()
    ['out-expo'] = function(x)
        return (x == 1) and 1 or (1 - 2^(-10*x))
    end,
    --- @meta ![in-out-expo]()
    ['in-out-expo'] = function(x)
        return (x == 0) and 0 or
          (x == 1) and 1 or
          (x < 0.5) and 2^(20*x - 10)/2 or (2 - 2^(-20*x + 10)) / 2
    end,
    --- @meta ![in-circ]()
    ['in-circ'] = function(x)
        return 1 - math.sqrt(1 - x^2)
    end,
    --- @meta ![out-circ]()
    ['out-circ'] = function(x)
        return math.sqrt(1 - (x - 1)^2)
    end,
    --- @meta ![in-out-circ]()
    ['in-out-circ'] = function(x)
        return (x < 0.5) and (1 - math.sqrt(1 - (2 * x)^2)) / 2 or (math.sqrt(1 - (-2 * x + 2)^2) + 1) / 2
    end,
    --- @meta ![in-back]()
    ['in-back'] = function(x)
        return c3*x*x*x - c1*x*x
    end,
    --- @meta ![out-back]()
    ['out-back'] = function(x)
        return 1 + (c3 * (x - 1)^3) + (c1 * (x - 1)^2)
    end,
    --- @meta ![in-out-back]()
    ['in-out-back'] = function(x)
        return (x < 0.5) and
            ((2 * x)^2 * ((c2 + 1) * 2 * x - c2)) / 2 or
                ((2 * x - 2)^2 * ((c2 + 1) * (x * 2 - 2) + c2) + 2) / 2
    end,
    --- @meta ![in-elastic]()
    ['in-elastic'] = function(x)
        return (x == 0) and 0 or
            (x == 1) and 1 or
                -2^(10 * x - 10) * math.sin((x * 10 - 10.75) * c4)
    end,
    --- @meta ![out-elastic]()
    ['out-elastic'] = function(x)
        return (x == 0) and 0 or
            (x == 1) and 1 or
                2^(-10 * x) * math.sin((x * 10 - 0.75) * c4) + 1
    end,
    --- @meta ![in-out-elastic]()
    ['in-out-elastic'] = function(x)
        return (x == 0) and 0 or
            (x == 1) and 1 or
                (x < 0.5) and  -(2^(20 * x - 10) * math.sin((20 * x - 11.125) * c5)) / 2 or
                    (2^(-20 * x + 10) * math.sin((20 * x - 11.125) * c5)) / 2 + 1
    end,
    --- @meta ![in-bounce]()
    ['in-bounce'] = function(x)
        return 1 - rtk.easing['out-bounce'](1 - x)
    end,
    --- @meta ![out-bounce]()
    ['out-bounce'] = function(x)
        if x < 1 / d1 then
            return n1 * x * x
        elseif x < (2 / d1) then
            x = x - 1.5/d1
            return n1 * x * x + 0.75
        elseif x < (2.5 / d1) then
            x = x - 2.25/d1
            return n1 * x * x + 0.9375
        else
            x = x - 2.625/d1
            return n1 * x * x + 0.984375
        end
    end,
    --- @meta ![in-out-bounce]()
    ['in-out-bounce'] = function(x)
        return (x < 0.5) and
            (1 - rtk.easing['out-bounce'](1 - 2 * x)) / 2 or
            (1 + rtk.easing['out-bounce'](2 * x - 1)) / 2
    end,
}


local function _resolve(x, src, dst)
    return src + x*(dst-src)
end

-- Step functions for tables containing strictly numeric elements.  Here we include
-- unrolled functions for tables 1-4 elements as these are the most common, plus
-- a slow version that supports arbitrary sized tables by looping.
local _table_stepfuncs = {
    [1] = function(widget, anim)
        local x = anim.easingfunc(anim.pct)
        return {_resolve(x, anim.src[1], anim.dst[1])}
    end,
    [2] = function(widget, anim)
        local x = anim.easingfunc(anim.pct)
        local src, dst = anim.src, anim.dst
        local f1 = _resolve(x, src[1], dst[1])
        local f2 = _resolve(x, src[2], dst[2])
        return {f1, f2}
    end,
    [3] = function(widget, anim)
        local x = anim.easingfunc(anim.pct)
        local src, dst = anim.src, anim.dst
        local f1 = _resolve(x, src[1], dst[1])
        local f2 = _resolve(x, src[2], dst[2])
        local f3 = _resolve(x, src[3], dst[3])
        return {f1, f2, f3}
    end,
    [4] = function(widget, anim)
        local x = anim.easingfunc(anim.pct)
        local src, dst = anim.src, anim.dst
        local f1 = _resolve(x, src[1], dst[1])
        local f2 = _resolve(x, src[2], dst[2])
        local f3 = _resolve(x, src[3], dst[3])
        local f4 = _resolve(x, src[4], dst[4])
        return {f1, f2, f3, f4}
    end,
    any = function(widget, anim)
        local x = anim.easingfunc(anim.pct)
        local src, dst = anim.src, anim.dst
        local result = {}
        for i=1, #src do
            result[i] = _resolve(x, src[i], dst[i])
        end
        return result
    end
}

-- Execute the next step of all queued animations.
--
-- Called from rtk.Window:_update() and returns true if any animations were
-- stepped, so _update() knows it needs to redraw.
function rtk._do_animations(now)
    -- Calculate frame rate (rtk.fps)
    if not rtk._frame_times then
        rtk._frame_times = {now}
    else
        local times = rtk._frame_times
        local c = #times
        times[c+1] = now
        if c > 30 then
            table.remove(times, 1)
        end
        rtk.fps = c / (times[c] - times[1])
    end

    -- Execute pending animations
    if rtk._animations_len > 0 then
        -- Queue tracking done for completed animations.  We don't want to
        -- invoke the callbacks within the loop in case the callback queues
        -- another animation.
        local donefuncs = nil
        local done = nil
        for key, anim in pairs(rtk._animations) do
            local widget = anim.widget
            local target = anim.target or anim.widget
            local attr = anim.attr
            local finished = anim.pct >= 1.0
            local elapsed = now - anim._start_time
            local newval, exterior
            if anim.stepfunc then
                newval, exterior = anim.stepfunc(target, anim)
            else
                newval = anim.resolve(anim.easingfunc(anim.pct))
            end
            anim.frames = anim.frames + 1
            if not finished and elapsed > anim.duration*1.5 then
                log.warning('animation: %s %s - failed to complete within 1.5x of duration (fps: current=%s expected=%s)',
                            target, attr, rtk.fps, anim.startfps)
                finished = true
            end
            if anim.update then
                -- Per-frame user-custom callback.  Can be used for animations against things
                -- other than widget attributes.
                anim.update(finished and anim.doneval or newval, target, attr, anim)
            end
            if widget then
                if not finished then
                    -- widget:attr(attr, newval) is more correct but much slower (about
                    -- 4x) due to all the indirect callbacks and event handlers.  Set the
                    -- calculated value directly, but still use the attribute's calc function
                    -- if it exists.
                    local value = newval
                    if exterior == nil and anim.calculate then
                        -- If no exterior value was returned by stepfunc() then we infer it wasn't
                        -- a widget attribute animate function and call out to the attr's calculate
                        -- function instead, whose result we use as both the calculated and exterior
                        -- value.
                        value = anim.calculate(widget, attr, newval, widget.calc)
                        exterior = value
                    end
                    widget.calc[attr] = value
                    -- We don't want to override the exterior value with the mid-animation
                    -- calculated value, but we do that if specifically requested via the
                    -- sync_exterior_value flag, which is used for w/h attributes as we
                    -- want to be able to animate these but reflow acts on the exterior
                    -- values (as the point of reflow is to calculate geometry).
                    if anim.sync_exterior_value then
                        widget[attr] = exterior or value
                    end
                else
                    -- However for the final value, we *do* use onattr() so that the
                    -- relevant event handlers get called.
                    widget:attr(attr, exterior or anim.doneval)
                end
                -- What we lose by not calling onattr() for each intermediate step is the
                -- automatic reflow provided by onattr.  So a bit of a kludge here, where
                -- we check the attribute's reflow flag ourselves, and do a full reflow if
                -- the attribute indicates needing it (unless the reflow flag for the
                -- animation explicitly disables it).
                --
                -- This definitely violates the boundary of the widget interface, but does
                -- so in the name of performance.
                local reflow = anim.reflow or (anim.attrmeta and anim.attrmeta.reflow) or rtk.Widget.REFLOW_PARTIAL
                if reflow and reflow ~= rtk.Widget.REFLOW_NONE then
                    widget:queue_reflow(reflow)
                end
                -- And likewise for window attributes that require window sync.
                if anim.attrmeta and anim.attrmeta.window_sync then
                    -- Widget must be an rtk.Window
                    widget._sync_window_attrs_on_update = true
                end
            end
            if finished then
                rtk._animations[key] = nil
                rtk._animations_len = rtk._animations_len - 1
                if not done then
                    done = {}
                end
                done[#done + 1] = anim
            else
                anim.pct = anim.pct + anim.pctstep
            end
        end
        if done then
            for _, anim in ipairs(done) do
                anim.future:resolve(anim.widget or anim.target)
                local took = reaper.time_precise() - anim._start_time
                local missed = took - anim.duration
                log.log(
                    math.abs(missed) > 0.05 and log.DEBUG or log.DEBUG2,
                    'animation: done %s: %s -> %s on %s frames=%s current-fps=%s expected-fps=%s took=%.1f (missed by %.3f)',
                    anim.attr, anim.src, anim.dst, anim.target or anim.widget, anim.frames, rtk.fps, anim.startfps, took, missed
                )
            end
        end
        -- True indicates animations were performed
        return true
    end
end

local function _is_equal(a, b)
    local ta = type(a)
    if ta ~= type(b) then
        return false
    elseif ta == 'table' then
        if #a ~= #b then
            return false
        end
        for i = 1, #a do
            if a[i] ~= b[i] then
                return false
            end
        end
        return true
    end
    return a == b
end

--- Low level function to begin an animation.
--
-- @warning
--   Using `rtk.Widget:animate()` instead is strongly preferred.  You probably never need to
--   call this global function directly, unless you're doing some low level operation and
--   want to animate a non-widget attribute.
--
-- The arguments are the same as `rtk.Widget:animate()`, plus:
--
--   * `key`: a globally unique string that identifies this animation
--   * `widget`: an optional `rtk.Widget` to act upon.  If defined, the `attr` field specifies
--      a particular attribute to animate.  If nil, you'll want to specify `update` in
--      order to receive frame updates during the animation.
--   * `attr`: if `widget` is not nil, this is the widget's attribute that's being animated.
--   * `update`: an optional function that's invoked on each step of the animation,
--      and which receives as arguments `(value, target, attr, anim)`, where `value` is
--      the current mid-animation value, `target` and `attr` correspond to the fields in
--      the table passed to this function, and `anim` is the overall table holding the
--      animation state (see below). The `update` callback is useful when you want to
--      animate something other than a widget attribute.
--   * `target`: the target table against which the animation is occurring.  This defaults
--      to `widget` if nil.
--   * `stepfunc`: a function invoked to yield the next step of the animation, which
--      is manditory when src/dst are neither scalar numbers nor tables containing
--      numbers. The function takes two arguments `(target, anim)` which are the same as
--      described in the `update` field above. The function must return the attribute
--      value for the next frame in the animation.
--   * `doneval`: when the animation is finished, the target attribute will be set to this
--     final value.  Defaults to `dst` if not specified.
--
-- The animation state table passed to `stepfunc` is also the same table returned here and
-- by `rtk.Widget:get_animation()`.  It contains all user-supplied fields, fully resolved
-- `src` and `dst` values, as well as these fields:
--
--   * `pct`: the percentage of the next step in the animation (from 0.0 to 1.0)
--   * `pctstep`: the percentage increase for each step in the animation (from 0.0 to 1.0).
--     This is adaptive based on the value of `rtk.fps` at the time the animation is started.
--   * `easingfunc`: the easing function that the `easing` name resolved to
--   * `future`: an `rtk.Future` representing the state of the running animation
--   * `resolve`: a convenience function that can be used by custom step functions to
--     translate `pct` value (from 0.0 to 1.0) to the actual value between `src` and `dst`.
--
-- Custom `stepfunc` functions can use the above fields from the animation state
-- table to determine the attribute value for each frame in the animation.  When
-- `stepfunc` is invoked, the `pct` field represents the current value that's needed.
--
-- @tparam table kwargs of attributes describing the animation
-- @treturn rtk.Future a Future object tracking the state of the asynchronous animation
function rtk.queue_animation(kwargs)
    assert(kwargs and kwargs.key, 'animation table missing key field')
    local future = rtk.Future()
    local key = kwargs.key
    local anim = rtk._animations[key]
    if anim then
        -- There's an existing animation.  If the destination value is the same, return
        -- the existing animation's Future.
        if _is_equal(anim.dst, kwargs.dst) then
            return anim.future
        else
            -- New destination value for this attribute, so we'll replace the current
            -- animation.  Cancel it first.
            anim.future:cancel()
        end
    end
    if _is_equal(kwargs.src, kwargs.dst) then
        -- There's nothing to animate.
        future:resolve()
        return future
    end
    -- Add callback to clean up animation state table if the Future is cancelled.
    future:cancelled(function()
        rtk._animations[key] = nil
        rtk._animations_len = rtk._animations_len - 1
    end)

    local duration = kwargs.duration or 0.5
    local easingfunc = rtk.easing[kwargs.easing or 'linear']
    assert(type(easingfunc) == 'function', string.format('unknown easing function: %s', kwargs.easing))
    if not kwargs.stepfunc then
        -- Without a step function we support interpolation of numeric values or tables
        -- comprised purely of numerical values by default.
        local tp = type(kwargs.src or 0)
        if tp == 'table' then
            -- Sanity check that all elements of this table are numeric
            local sz = #kwargs.src
            for i = 1, sz do
                assert(type(kwargs.src[i]) == 'number', 'animation src value table must not have non-numeric elements')
            end
            kwargs.stepfunc = _table_stepfuncs[sz]
            if not kwargs.stepfunc then
                -- Table has more than 4 elements, so need to use the slower
                -- looping step function.
                kwargs.stepfunc = _table_stepfuncs.any
            end
        else
            assert(tp == 'number', string.format('animation src value %s is invalid', kwargs.src))
        end
    end
    if not rtk._animations[kwargs.key] then
        rtk._animations_len = rtk._animations_len + 1
    end
    local step = 1.0 / (rtk.fps * duration)
    anim = table.shallow_copy(kwargs, {
        easingfunc = easingfunc,
        -- If no step function is provided, we can default src to 0 if nil.
        src = kwargs.src or (not kwargs.stepfunc and 0 or nil),
        dst = kwargs.dst or 0,
        doneval = kwargs.doneval or kwargs.dst,
        pct = step,
        pctstep = step,
        duration = duration,
        future = future,
        frames = 0,
        startfps = rtk.fps,
        _start_time = reaper.time_precise()
    })
    anim.resolve = function(x) return _resolve(x, anim.src, anim.dst) end
    rtk._animations[kwargs.key] = anim
    log.debug2('animation: scheduled %s', kwargs.key)
    return future
end
