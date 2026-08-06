return function(T)
    local json = dofile(T.repoRoot .. "/tests/helpers/json.lua")

    T.test("json helper decodes network config shape", function()
        local decoded = json.decode([[
{
  "version": 1,
  "enabled": false,
  "tests": [
    {
      "id": "github-folder",
      "expect": {
        "files": [
          "init.lua"
        ]
      }
    }
  ]
}
]])

        T.assertEqual(decoded.version, 1)
        T.assertFalse(decoded.enabled)
        T.assertEqual(decoded.tests[1].id, "github-folder")
        T.assertEqual(decoded.tests[1].expect.files[1], "init.lua")
    end)

    T.test("json helper encodes stable object keys", function()
        local encoded = json.encode({
            beta = 2,
            alpha = 1,
        })

        T.assertEqual(encoded, [[{
  "alpha": 1,
  "beta": 2
}]])
    end)

    T.test("json helper encodes empty tables as objects", function()
        T.assertEqual(json.encode({}), "{}")
    end)
end
