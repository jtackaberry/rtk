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

--- A global logging module that logs to REAPER's console.
--
-- This module provides many conveniences and performance improvements over REAPER's
-- native [`ShowConsoleMsg()`](https://www.reaper.fm/sdk/reascript/reascripthelp.html#ShowConsoleMsg).
-- All log lines are prefixed with timestamp and log level, and format strings with variable
-- arguments are supported.
--
-- Messages logged within this module are queued until the end of the defer update cycle,
-- which provides significant performance benefits.  If for some reason you need the log
-- message to display immediately, you can use `log.flush()`.  But this is very rarely needed.
--
-- @note Use a module-local log variable
--   This module is automatically available under `rtk.log` but it is idiomatic to assign it to
--   a module-local `log` variable:
--
-- @code
--   local rtk = require('rtk')
--   local log = rtk.log
--
--   -- Set the current log level to INFO
--   log.level = log.INFO
--   -- This log line won't show on the console because DEBUG is less
--   -- severe than the current INFO level.
--   log.debug('the current log level is %s', log.level_name(log.level))
--   -- Meanwhile, this one will display.
--   log.critical('self destruct sequence initiated')
--
--
-- Another major feature of this module is for timing code blocks with microsecond precision,
-- and which can even be nested so you can see the time spent in the constituent parts of
-- an overall expensive task:
--
-- @code
--   function compute()
--      log.time_start('expensive-thing')
--      do_something_expensive()
--      log.time_end()
--   end
--
--   log.time_start('mytask')
--   preamble()
--   for i = 1, 42 do
--       compute()
--   end
--   log.time_end_report('finished doing some task')
--
-- The resulting output to the console would look something like:
--
-- ```
--   21:30:05.137 [DEBUG]  (162 / 162 ms)  finished doing some task
--           1.          mytask: 162.1551 ms  (1)
--           2. expensive-thing:  41.4113 ms  (42)
-- ```
--
-- @module log
local log = {
    levels = {
        [50] = 'CRITICAL',
        [40] = 'ERROR',
        [30] = 'WARNING',
        [20] = 'INFO',
        [10] = 'DEBUG',
        [9] = 'DEBUG2',
    },

    --- Current log level, set to one of the @{logconst|log level constants} (default `log.ERROR`).
    -- Lines logged levels equal to or more severe than this value will appear on REAPER's console.
    -- @type logconst
    -- @meta read/write
    level = 40,
    --- Log level at or *below* which timers are logged (default `log.INFO`).  See `log.time_start()`
    -- for more details
    -- @type logconst
    -- @meta read/write
    timer_threshold = 20,

    named_timers = nil,
    timers = {},
    queue = {},
    lua_time_start = os.time(),
    reaper_time_start = reaper.time_precise(),
}

--- Log Level Constants.
--
-- These constants are used to control the log `level`.  The numeric values for each of
-- the constants is included below, where higher values means greater severity.
--
-- You can define your own log levels, just don't reuse one of the numeric values below
-- for your custom log level.
-- @section logconst
-- @compact

--- 50
log.CRITICAL = 50
--- 40
log.ERROR = 40
--- 30
log.WARNING = 30
--- 20
log.INFO = 20
--- 10
log.DEBUG = 10
--- 9
log.DEBUG2 = 9


--- Module Functions
-- @section functions

--- Logs a message with level `CRITICAL`.
--
-- @tparam string fmt a format string according to Lua's native
--   [`string.format()`](http://lua-users.org/wiki/StringLibraryTutorial).
-- @tparam any ... zero or more optional arguments according to the given
--   format string.
function log.critical(fmt, ...) log._log(log.CRITICAL, nil, fmt, ...) end
--- Logs a message with level `ERROR`.  Arguments are as with `log.critical()`.
function log.error(fmt, ...)    log._log(log.ERROR, nil, fmt, ...) end
--- Logs a message with level `WARNING`.  Arguments are as with `log.critical()`.
function log.warning(fmt, ...)  log._log(log.WARNING, nil, fmt, ...) end
--- Logs a message with level `INFO`.  Arguments are as with `log.critical()`.
function log.info(fmt, ...)     log._log(log.INFO, nil, fmt, ...) end
--- Logs a message with level `DEBUG`.  Arguments are as with `log.critical()`.
function log.debug(fmt, ...)    log._log(log.DEBUG, nil, fmt, ...) end
--- Logs a message with level `DEBUG2`.  Arguments are as with `log.critical()`.
function log.debug2(fmt, ...)   log._log(log.DEBUG2, nil, fmt, ...) end


local function enqueue(msg)
    -- Handle the actual display of log messages asynchronously so as not to include any
    -- logging overhead in timing measurements and also lets us coalesce multiple log messages
    -- into a single ShowConsoleMsg() call which significantly improves performance.
    local qlen = #log.queue
    if qlen == 0 then
        reaper.defer(log.flush)
    end
    log.queue[qlen + 1] = msg
end

local function _get_precise_duration_string(t)
    if t < 0.1 then
        return string.format('%.03f', t)
    elseif t < 1 then
        return string.format('%.02f', t)
    elseif t < 10 then
        return string.format('%.01f', t)
    else
        return string.format('%.0f', t)
    end
end

--- Logs a message with level `ERROR` and includes a stack trace.
--
-- The stack trace displayed will include a frame from within this function, but that can
-- be ignored.
--
-- Arguments are as with `log.critical()`.
function log.exception(fmt, ...)
    log._log(log.ERROR, debug.traceback(), fmt, ...)
    log.flush()
end

--- Logs a stack trace at the given level.
--
-- The stack trace displayed will include a frame from within this function, but that can
-- be ignored.
--
-- @tparam logconst|nil level the log level at which to log the trace, or `log.DEBUG`
--   if not specified.
function log.trace(level)
    if log.level <= (level or log.DEBUG) then
        enqueue(debug.traceback() .. '\n')
    end
end

function log._log(level, tail, fmt, ...)
    if level < log.level then
        return
    end
    local r, err = pcall(string.format, fmt, ...)
    if not r then
        log.exception("exception formatting log string '%s': %s", fmt, err)
        return
    end

    local now = reaper.time_precise()
    local time = log.lua_time_start + (now - log.reaper_time_start)
    local ftime = math.floor(time)
    local msecs = string.sub(time - ftime, 3, 5)
    local label = '[' .. log.level_name(level) .. ']'
    local prefix = string.format('%s.%s %-9s ', os.date('%H:%M:%S', ftime), msecs, label)
    if level <= log.timer_threshold and #log.timers > 0 then
        local timer = log.timers[#log.timers]
        local total = _get_precise_duration_string((now - timer[1]) * 1000)
        local last = _get_precise_duration_string((now - timer[2]) * 1000)
        local name = timer[3] and string.format(' [%s]', timer[3]) or ''
        prefix = prefix .. string.format('(%s / %s ms%s) ', last, total, name)
        timer[2] = now
    end

    local msg = prefix .. err .. '\n'
    if tail then
        msg = msg .. tail .. '\n'
    end
    enqueue(msg)
end

--- Logs a message at any level.
--
-- @tparam logconst level the log level at which to log the message
-- @tparam string|nil tail an optional arbitrary string to dump to the console after the
--   format log message
-- @tparam string fmt a format string according to Lua's native
--   [`string.format()`](http://lua-users.org/wiki/StringLibraryTutorial).
-- @tparam any ... zero or more optional arguments according to the given
--   format string.
function log.log(level, fmt, ...)
    return log._log(level, nil, fmt, ...)
end

--- A variant of `log()` that allows format arguments to be passed as a function.
--
-- The supplied function would only be invoked if the log level was such that the
-- message would get written, and it's expected to return the arguments for the
-- format string.
--
-- This is useful for lazy-evaluating arguments to avoid the overhead of expensive
-- arguments if the log level is such that we would never print it anyway.
--
-- @code
--   log.logf(log.DEBUG, '%d of these arguments is expensive: %s', function()
--       return 1, get_expensive_thing()
--   end)
--
-- @tparam logconst level the log level at which to log the message
-- @tparam string fmt a format string according to Lua's native
--   [`string.format()`](http://lua-users.org/wiki/StringLibraryTutorial).
-- @tparam function func a function that returns the format string arguments.
function log.logf(level, fmt, func)
    if level >= log.level then
        return log._log(level, nil, fmt, func())
    end
end

--- Immediately write any queued log messages to the console.
--
-- Messages are normally queued and written to REAPER's console at the end of the update
-- cycle, which provides a noticeable performance improvement when logging a lot of
-- content. But this function can be called explicitly to immediately flush queued
-- messages to the console.
function log.flush()
    local str = table.concat(log.queue)
    if #str > 0 then
        reaper.ShowConsoleMsg(str)
    end
    log.queue = {}
end

--- Gets the printable name of one of the log level constants.
--
-- @tparam logconst level the log level whose name to fetch
-- @treturn string the name of the log level
function log.level_name(level)
    return log.levels[level or log.level] or 'UNKNOWN'
end

--- Clears REAPER's console.
--
-- @tparam logconst|nil level the level at or below which the @{level|current log level}
--   must be in order for the console to be cleared.  If nil, the console is cleared
--   regardless of current log level.
function log.clear(level)
    if not level or log.level <= level then
        reaper.ShowConsoleMsg("")
        log.queue = {}
    end
end

--- Begins a timer to track the duration between log events.
--
-- After this function is called, all subsequent logged messages will include
-- timer information (amount of time since the last log line, and the amount of
-- cumulative time since the last log.time_start() call was made) until the timer
-- is stopped with `log.time_end()`.
--
-- `log.time_start()` can safely be nested, but you must be sure to call
-- `log.time_end()` the same number of times.
--
-- **Named timers** can be used to track the total time spent in code sections and
-- provide a final report on execution time and number of calls, acting as a poor-man's
-- profiler.  See `log.time_end_report()` for more.
--
-- @tparam string|nil name the optional name of the timer for a final report.  If
--   no name is given, subsequent log messages still show delta time and total time,
--   but no final report is possible.
function log.time_start(name)
    if log.level > log.timer_threshold then
        return
    end
    local now = reaper.time_precise()
    table.insert(log.timers, {now, now, name})
    if name then
        if not log.named_timers then
            log.named_timers = {}
            log.named_timers_order = {}
        end
        if not log.named_timers[name] then
            log.named_timers[name] = {0, 0}
            log.named_timers_order[#log.named_timers_order+1] = name
        end
    end
end

--- Stops the last timer started by `log.time_start()`.
--
-- In addition to stopping the last timer, the optional log message, if provided, is
-- logged at `DEBUG` level.
--
-- Arguments are as with `log.critical()`.
function log.time_end(fmt, ...)
    if fmt then
        log._log(log.DEBUG, nil, fmt, ...)
    end
    log.time_end_report_if(false)
end

--- Stops the last timer started by `log.time_start()` and shows a summary of named timers.
--
-- The current state of any named timers (those where a name value was passed to
-- `log.time_start()`) will be dumped following the optional log message, which is logged
-- at `DEBUG`.
--
-- The timer report shows all named timers in the order they were started, the culumlative
-- total for each timer, and the number of times the code block was executed.
--
-- The report will only display when `log.level` is at or below `log.timer_threshold`.
--
-- Arguments are as with `log.critical()`.
function log.time_end_report(fmt, ...)
    if fmt then
        log._log(log.DEBUG, nil, fmt, ...)
    end
    log.time_end_report_if(true)
end


--- Stops the last timer started by `log.time_start()` and shows a summary of
-- named timers of the given conditional is true.
--
-- @note
--   This is bit more than just syntactic sugar for wrapping `log.time_end_report()` in an
--   if statement because the last timer started by `log.time_start()` is stopped
--   regardless.  The conditional `show` only controls whether the report is logged.
--
-- @tparam bool show if true, the report will be written to the console
-- @tparam string fmt a format string according to Lua's native
--   [`string.format()`](http://lua-users.org/wiki/StringLibraryTutorial).
-- @tparam any ... zero or more optional arguments according to the given
--   format string.
function log.time_end_report_if(show, fmt, ...)
    if log.level > log.timer_threshold then
        return
    end
    if fmt and show then
        log._log(log.DEBUG, nil, fmt, ...)
    end
    assert(#log.timers > 0, "time_end() with no previous time_start()")
    local t0, _, name = table.unpack(table.remove(log.timers))
    if log.named_timers then
        if name then
            local delta = reaper.time_precise() - t0
            local current = log.named_timers[name]
            if not current then
                log.named_timers[name] = {current + delta, 1}
            else
                log.named_timers[name] = {current[1] + delta, current[2] + 1}
            end
        end
        if show and log.level <= log.INFO then
            local output = ''
            local maxname = 0
            local maxtime = 0
            local times = {}
            for i, name in ipairs(log.named_timers_order) do
                local duration, _ = table.unpack(log.named_timers[name])
                times[#times+1] = string.format('%.4f ms', duration * 1000)
                maxtime = math.max(maxtime, #times[#times])
                maxname = math.max(maxname, #name)
            end
            local fmt = string.format('       %%2d. %%%ds: %%%ds  (%%d)\n', maxname, maxtime)
            for i, name in ipairs(log.named_timers_order) do
                local _, count = table.unpack(log.named_timers[name])
                output = output .. string.format(fmt, i, name, times[i], count)
            end
            enqueue(output)
        end
    end
    if #log.timers == 0 then
        log.named_timers = nil
    end
end

return log
