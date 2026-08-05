local repoRoot = os.getenv("PWD")

local assertions = dofile(repoRoot .. "/tests/helpers/assertions.lua")
local loadSpoonManager = dofile(repoRoot .. "/tests/helpers/load_spoonmanager.lua")

local tests = {}

local T = assertions.new({
    repoRoot = repoRoot,
    tests = tests,
})

T.SpoonManager, T.context = loadSpoonManager(repoRoot)

local testFiles = {
    "tests/examples/base_definitions.lua",
    "tests/examples/config_sources.lua",
    "tests/examples/default_spoon.lua",
    "tests/examples/github_folder.lua",
    "tests/examples/github_patterns.lua",
    "tests/examples/github_release.lua",
    "tests/examples/github_repository.lua",
    "tests/examples/local_sources.lua",
    "tests/examples/zip_sources.lua",
    "tests/unit/name_resolver_test.lua",
    "tests/unit/json_test.lua",
    "tests/unit/definition_test.lua",
    "tests/unit/manager_test.lua",
    "tests/unit/resolver_test.lua",
}

for _, file in ipairs(testFiles) do
    dofile(repoRoot .. "/" .. file)(T)
end

local passed = 0

for _, item in ipairs(tests) do
    io.write("test: " .. item.name .. " ... ")

    local ok, err = xpcall(item.fn, debug.traceback)
    if ok then
        passed = passed + 1
        print("ok")
    else
        print("failed")
        print(err)
        os.exit(1)
    end
end

print(string.format("%d tests passed", passed))
