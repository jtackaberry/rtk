# Bundling Scripts

rtk uses a custom tool called LuaKnit to assemble all of the project files into a single
packed `rtk.lua` source file that makes it convenient for script authors to import and
distribute.

You can use LuaKnit yourself to combine your own source files, and even include
`rtk.lua` so you're able to distribute a single executable script.

In addition to consolidating into a single file, LuaKnit also does its best to minify
the code, stripping out comments and reducing the amount of redundant whitespace.  It's
not perfect -- it doesn't tokenize Lua source code, only uses naive regexps -- but it
does a decent enough job not to have motivated anything more sophisticated.


## Usage

[Fetch `luaknit.py` from rtk's git
repository](https://raw.githubusercontent.com/jtackaberry/rtk/master/tools/luaknit.py).
LuaKnit is a Python script and requires Python 3.6 or later to be installed.

Suppose you have a directory containing `rtk.lua`, and your own project files `main.lua`
and `commands.lua`.  It's easy to bundle all these together:

```bash
# Linux and OS X
$ python3 /path/to/luaknit.py rtk.lua main.lua commands.lua -o myscript.lua

# Windows
C:\projects\myscript> python3 \path\to\luaknit.py rtk.lua main.lua commands.lua -o myscript.lua
```

That's really all there is to it.  The file `myscript.lua` can now be executed directly by
REAPER.

If your script `require()`s another module, if the module is located in the current
directory, it will be automatically processed.  If not, you can pass it (either a
file or directory) directly to LuaKnit and specify the module name.

For example, you could bundle your script directly with rtk's raw source directory which
contains all its original files.  Suppose you have cloned [rtk's git repo](https://github.com/jtackaberry/rtk)
at `/path/to/rtk`, then:

```bash
$ python3 /path/to/luaknit.py rtk=/path/to/rtk/src main.lua commands.lua -o myscript.lua
```

