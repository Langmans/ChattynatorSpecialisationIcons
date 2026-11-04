-- Development dependencies only: the test tools, pinned. The addon itself is not a rock.
-- `luarocks install --only-deps chattynatorspecialisationicons-dev-1.rockspec` installs them, locally
-- (tests/setup-lua.ps1) and in CI alike.
rockspec_format = "3.0"
package = "chattynatorspecialisationicons"
version = "dev-1"
source = { url = "git+https://github.com/Langmans/ChattynatorSpecialisationIcons.git" }
description = { summary = "Chattynator Specialisation Icons' test tooling", license = "MIT" }
dependencies = {
    "lua ~> 5.1",
    "busted == 2.2.0",
    "luacov == 0.17.0",
    "luacov-reporter-lcov == 0.2",
    -- luacov's line hook in C: the covered test run stays fast.
    "cluacov == 1.0.0",
}
build = { type = "builtin", modules = {} }
