DATE := $(shell date)
TAG := $(or $(shell git describe --tags | cut -f1 -d- 2>/dev/null), $(shell echo 1.0.0))

build/rtk.lua: rtk/*.lua
	mkdir -p build
	python3 tools/luaknit.py rtk=rtk/ -c "This is generated code. See https://reapertoolkit.dev/ for more info.\nversion: $(TAG)-dev\nbuild: $(DATE)" -p "__RTK_VERSION='$(TAG)'" > build/rtk.lua
