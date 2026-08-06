return function(T)
    T.test("definition stages enrich state only when requested", function()
        local definition = T.SpoonManager.from.github("owner/repo")
            .path("Source/A.spoon")

        local plain = definition.explain()
        T.assertFalse(plain.resolved)
        T.assertFalse(plain.command)

        local resolved = definition.resolve().explain()
        T.assertTrue(resolved.resolved)
        T.assertFalse(resolved.command)
        T.assertEqual(resolved.resolved.installName, "A")

        local commanded = definition.command("install").explain()
        T.assertTrue(commanded.resolved)
        T.assertTrue(commanded.command)
        T.assertEqual(commanded.command.to.name, "A")
    end)

    T.test("definition stores raw builder values before resolve", function()
        local definition = T.SpoonManager.from.github("owner/repo")
            .spoonZipPattern("dist/{name}.spoon.zip")
            .spoon("A.spoon")
            .withName("B.spoon")

        local plain = definition.explain()
        T.assertEqual(plain.config.target.selection_spoon, "A.spoon")
        T.assertEqual(plain.config.target.name_withName, "B.spoon")
        T.assertFalse(plain.resolved)

        local commanded = definition.command("install").explain()
        T.assertEqual(commanded.config.target.selection_spoon, "A.spoon")
        T.assertEqual(commanded.config.target.name_withName, "B.spoon")
        T.assertEqual(commanded.resolved.installName, "B")
        T.assertEqual(commanded.command.name, "B")
        T.assertEqual(commanded.command.from.url, "https://github.com/owner/repo/raw/main/dist/A.spoon.zip")
    end)

    T.test("definition rejects source changes after resolve", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .path("Source/A.spoon")
                .resolve()
                .branch("main")
        end, "definition already has resolved values; cannot call %.branch%('main'%)")
    end)

    T.test("definition rejects target changes after command", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .path("Source/A.spoon")
                .command("install")
                .withName("B")
        end, "definition already has command values; cannot call %.withName%('B'%)")
    end)

    T.test("definition rejects rebuilding command with another action", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .path("Source/A.spoon")
                .command("install")
                .command("update")
        end, "definition already has command values for install; cannot build command for update%.")
    end)

    T.test("definition rejects branch after spoon selection", function()
        T.assertError(function()
            T.SpoonManager.from.default
                .spoon("Emojis")
                .branch("main")
        end, "spoon%('Emojis'%) already selected")
    end)

    T.test("definition rejects duplicate revision group", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .branch("main")
                .ref("v1.2.3")
        end, "%.branch%('main'%) already set; cannot call %.ref%('v1%.2%.3'%)")
    end)

    T.test("definition rejects duplicate source path", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .path("Source/A.spoon")
                .path("Source/B.spoon")
        end, "%.path%('Source/A%.spoon'%) already set; cannot call %.path%('Source/B%.spoon'%)")
    end)

    T.test("definition rejects duplicate spoon pattern group", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .spoonZipPattern("dist/{name}.zip")
                .spoonFolderPattern("Source/{name}.spoon")
        end, "%.spoonZipPattern%('dist/{name}%.zip'%) already set; cannot call %.spoonFolderPattern%('Source/{name}%.spoon'%)")
    end)

    T.test("definition rejects spoon without spoon pattern", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .spoon("A")
        end, "%.spoon%(%) requires %.spoonZipPattern%(%.%.%.%) or %.spoonFolderPattern%(%.%.%.%) on this source%.")
    end)

    T.test("definition rejects duplicate release group", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .releaseLatest()
                .release("v1.2.3")
        end, "%.releaseLatest%(%) already set; cannot call %.release%('v1%.2%.3'%)")
    end)

    T.test("definition rejects spoon then folder selection", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .spoonZipPattern("dist/{name}.zip")
                .spoon("A")
                .path("Source/A.spoon")
        end, "%.spoon%('A'%) already selected; cannot call %.path%('Source/A%.spoon'%)")
    end)

    T.test("definition rejects duplicate explicit name", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .withName("A")
                .withName("B")
        end, "%.withName%('A'%) already set; cannot call %.withName%('B'%)")
    end)

    T.test("definition rejects unsupported source capabilities", function()
        T.assertError(function()
            T.SpoonManager.from.remoteZip("https://example.com/A.zip")
                .branch("main")
        end, "remoteZip source does not support %.branch")

        T.assertError(function()
            T.SpoonManager.from.localZip("~/Downloads/A.zip")
                .zipFile("A.zip")
        end, "localZip source does not support %.zipFile")

        T.assertError(function()
            T.SpoonManager.from.localFolder("~/Projects/A.spoon")
                .releaseLatest()
        end, "localFolder source does not support %.releaseLatest")

        T.assertError(function()
            T.SpoonManager.from.remoteZip("https://example.com/A.zip")
                .spoonZipPattern("Spoons/{name}.spoon.zip")
        end, "remoteZip source does not support %.spoonZipPattern")
    end)

    T.test("definition does not expose replaced builder methods", function()
        local definition = T.SpoonManager.from.github("owner/repo")

        T.assertEqual(definition.folder, nil)
        T.assertEqual(definition.asset, nil)
    end)

    T.test("definition rejects non string arguments", function()
        T.assertError(function()
            T.SpoonManager.from.github({
                "owner/repo",
            })
        end, "GitHub repository must be a string")

        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .path({
                    "Source/A.spoon",
                })
        end, "Source path must be a string")

        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .withName(123)
        end, "Spoon name must be a string")
    end)

    T.test("definition rejects non zip release asset", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .releaseLatest()
                .zipFile("A.tar.gz")
        end, "ZIP file must point to a %.zip file")
    end)

    T.test("installer rejects non zip release asset from config", function()
        local result, err =
            T.SpoonManager.from.config({
                source = {
                    type = "github",
                    repository = "owner/repo",
                    release_releaseLatest = true,
                    zipFile = "A.tar.gz",
                },
                target = {
                    name_withName = "A",
                },
            }).install()

        T.assertFalse(result)
        T.assertEqual(err, "GitHub release asset must point to a .zip file")
    end)

    T.test("resolver rejects release without zip file", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .releaseLatest()
                .resolve()
        end, "GitHub release sources require %.zipFile%(%.%.%.%)%.")
    end)
end
