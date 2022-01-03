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

--- Represents the state of an asynchronous action that will be completed some time
-- in the future.
--
-- In rtk, asynchronous tasks, such as animations, will return an `rtk.Future` where
-- you have the opportunity to register callbacks to optionally perform subsequent
-- actions (`after()`), or callbacks to be invoked when the Future is fully resolved
-- (`done()`).
--
-- If the asynchronous task supports it, it can also be cancelled (`cancel()`).
--
-- @example
--   -- Kick off an animation sequence.  rtk.Widget:animate() returns an rtk.Future.
--   widget:animate{'bg', dst='red'}
--      :after(function()
--          -- Once the background color animates to red, now animate it to
--          -- turquoise with a different easing.
--          return widget:animate{'bg', dst='turquoise', easing='in-out-elastic'}
--      end)
--      :after(function()
--          -- And now once the animation to turquoise completes, animate the
--          -- width to 60% of the widget's parent's width.
--          return widget:animate{'w', dst=0.6}
--      end)
--      :done(function()
--          -- Finally all 'after' callbacks have completed.
--          log.info('animation sequence complete')
--      end)
--      :cancelled(function()
--          -- If cancel() was called on the Future then we'll log this message.
--          log.warning('animation sequence was cancelled')
--      end)
--
-- @class rtk.Future
rtk.Future = rtk.class('rtk.Future')

--- Future State Constants.
--
-- Used with the `state` attribute.
--
-- @section futurestateconst
-- @compact

--- The asynchronous task is currently still running and hasn't completed or been cancelled.
rtk.Future.static.PENDING = false
--- The Future was @{resolve|resolved} successfully.
rtk.Future.static.DONE = true
--- The Future was `cancelled`.
rtk.Future.static.CANCELLED = 0

--- Class API
--- @section api

--- Create a new Future object.
--
-- @display rtk.Future
-- @treturn rtk.Future the new Future object
function rtk.Future:initialize()
    --- Represents the current state of the Future.
    -- @meta read-only
    -- @type futurestateconst
    self.state = rtk.Future.PENDING
    --- The result returned by the asynchronous task as passed to either `resolve()`
    -- or `cancel()`.
    -- @meta read-only
    -- @type any
    self.result = nil
    --- If true, the owner of the asynchronous task has registered a `cancelled` callback
    -- to cancel the operation, which allows `cancel()` to be called.
    -- @meta read-only
    -- @type boolean
    self.cancellable = false
end

--- Register a callback to be invoked after the current task completes, but
-- before `done` callbacks are invoked.
--
-- Multiple callbacks can be registered and will be invoked in the order they
-- were added.
--
-- If the callback returns another `rtk.Future` then that Future is chained
-- to this one, such that the new Future must complete before any subsequent
-- `after` callbacks registered against this Future will be invoked (and likewise
-- for `done`).  If a dependent Future is in-flight and this one is @{cancel|cancelled},
-- then the dependent Future will also be cancelled.  The reverse is not true,
-- however: if a dependent Future is cancelled,
--
-- If the `rtk.Future` has already been @{resolve|resolved} before registering
-- `func`, it will still be executed at the beginning of the next
-- {rtk.Window.onupdate|update cycle}.
--
-- @tparam function func the function that's invoked after the asynchronous task
--   completes, and which receives as an argument the return value from the asynchronous
--   task if it's the first `after` callback, or the return value of the previously
--   invoked `after` callback.  If no value is returned by the callback, then
--   the previous non-nil return value in the chain will be passed.
-- @treturn rtk.Future returns self for method chaining
function rtk.Future:after(func)
    if not self._after then
        self._after = {func}
    else
        self._after[#self._after+1] = func
    end
    self:_check_defer_resolved_callbacks(rtk.Future.DONE)
    return self
end

--- Register a callback to be invoked when the Future completes (not cancelled) and
-- after all `after()` callbacks have been invoked.
--
-- Multiple callbacks can be registered and will be invoked in the order they
-- were added.
--
-- If the `rtk.Future` has already been @{resolve|resolved} before registering
-- `func`, it will still be executed at the beginning of the next
-- {rtk.Window.onupdate|update cycle}.
--
-- @tparam function func the function that's invoked after the asynchronous task
--   completes and all `after` callbacks.  This callback receives as an argument
--   the last non-nil value returned by the original asynchronous task or by
--   any `after()` callbacks.
-- @treturn rtk.Future returns self for method chaining
function rtk.Future:done(func)
    if not self._done then
        self._done = {func}
    else
        self._done[#self._done+1] = func
    end
    self:_check_defer_resolved_callbacks(rtk.Future.DONE)
    return self
end

--- Register a callback to be invoked when the Future is cancelled.
--
-- Multiple callbacks can be registered and will be invoked in the order
-- they were added.
--
-- If the `rtk.Future` has already been @{cancel|cancelled} before registering
-- `func`, then it will be immediately invoked.
--
-- @tparam function func the function that's invoked when `cancel()` is
--   called, and which receives as an argument the value passed to `cancel()`.
-- @treturn rtk.Future returns self for method chaining
function rtk.Future:cancelled(func)
    self.cancellable = true
    if self.state == rtk.Future.CANCELLED then
        func(self.result)
    elseif not self._cancelled then
        self._cancelled = {func}
    else
        self._cancelled[#self._cancelled+1] = func
    end
    return self
end

--- Cancels the Future and invokes all previously registered `cancelled` callbacks.
--
-- The `cancelled` callbacks are immediately invoked in order.
--
-- It is a runtime error to `cancel()` an `rtk.Future` that has no `cancelled`
-- callbacks.  You can check the `cancellable` attribute first to determine if
-- the Future can be cancelled.
--
-- @tparam any v the arbitrary value to be passed to the registered `cancelled` callbacks.
-- @treturn rtk.Future returns self for method chaining
function rtk.Future:cancel(v)
    assert(self._cancelled, 'Future is not cancelleable')
    assert(self.state == rtk.Future.PENDING, 'Future has already been resolved or cancelled')
    self.state = rtk.Future.CANCELLED
    self.result = v
    for i = 1, #self._cancelled do
        self._cancelled[i](v)
    end
    self._cancelled = nil
    return self
end

function rtk.Future:_resolve(value)
    self.result = value
    self:_invoke_resolved_callbacks(value)
end

function rtk.Future:_check_defer_resolved_callbacks(state, value)
    if self.state == state and not self._deferred then
        self._deferred = true
        rtk.defer(rtk.Future._invoke_resolved_callbacks, self, value or self.value)
    end
end

function rtk.Future:_invoke_resolved_callbacks(value)
    self._deferred = false
    self.result = value
    local nextval = value
    if self._after then
        while #self._after > 0 do
            local func = table.remove(self._after, 1)
            nextval = func(nextval) or nextval
            if rtk.isa(nextval, rtk.Future) then
                -- Ensure continuation after dependent Future is resolved
                nextval:done(function(v) self:_resolve(v) end)
                self:cancelled(function(v) nextval:cancel(v) end)
                return
            end
        end
    end
    self.state = rtk.Future.DONE
    if self._done and (not self._after or #self._after == 0) then
        for i = 1, #self._done do
            self._done[i](nextval)
        end
    end
    self._done = nil
    self._after = nil
    return self
end


--- Resolves the Future, causing all `after` and `done` callbacks to be invoked.
--
-- Usually this method will only be called by the originator of the asynchronous
-- task.
--
-- If there have been any `after` or `done` callbacks registered, they are
-- immediately invoked.  But if no callbacks have been attached, then they will be
-- rechecked after one {rtk.Window.onupdate|update cycle}, allowing the opportunity
-- for callbacks to be registered even after the `rtk.Future` is resolved.
--
-- The Future may not transition to the `DONE` `state` after calling this method:
-- if any `after` callbacks return a Future, they will be chained, and this Future
-- will not transition to `DONE` until all dependent Futures also complete.
--
-- @tparam any value the arbitrary value returned by the asynchronous task, and that
--   will be passed into the `after` and `done` callbacks (unless any `after` callback
--   returns a different non-nil value, in which case that takes precedence).
-- @treturn rtk.Future returns self for method chaining
function rtk.Future:resolve(value)
    assert(self.state == rtk.Future.PENDING, 'Future has already been resolved or cancelled')
    if not self._after and not self._done and not self._deferred then
        -- Nothing attached yet, defer resolution one cycle.
        self._deferred = true
        rtk.defer(self._resolve, self, value, true)
    else
        self:_resolve(value)
    end
    return self
end