DATE := $(shell date)

build/rtk.lua: rtk/*.lua
	mkdir -p build
	python3 tools/luaknit.py rtk=rtk/ -c "This is generated code. See https://reapertoolkit.dev/ for more info.\nversion: dev\nbuild: $(DATE)" > build/rtk.lua
