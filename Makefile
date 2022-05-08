DATE := $(shell date)
VERSION := $(or $(shell git describe --tags 2>/dev/null), $(shell echo 1.0.0))-dev

build/rtk.lua: rtk/*.lua
	mkdir -p build
	python3 tools/luaknit.py rtk=rtk/ -c "\nWARNING: DEV BUILD!  Use for testing only!\n\nThis is generated code. See https://reapertoolkit.dev/ for more info.\n\nversion: $(VERSION)\nbuild: $(DATE)\n" -p "__RTK_VERSION='$(VERSION)'" > build/rtk.lua