return function(T)
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

    T.test("definition rejects duplicate selection group", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .folder("Source/A.spoon")
                .asset("A.zip")
        end, "%.folder%('Source/A%.spoon'%) already set; cannot call %.asset%('A%.zip'%)")
    end)

    T.test("definition rejects duplicate spoon pattern group", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .spoonZipPattern("dist/{name}.zip")
                .spoonFolderPattern("Source/{name}.spoon")
        end, "%.spoonZipPattern%('dist/{name}%.zip'%) already set; cannot call %.spoonFolderPattern%('Source/{name}%.spoon'%)")
    end)

    T.test("definition rejects duplicate release group", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .releaseLatest()
                .release("v1.2.3")
        end, "%.releaseLatest%('latest'%) already set; cannot call %.release%('v1%.2%.3'%)")
    end)

    T.test("definition rejects spoon then folder selection", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .spoon("A")
                .folder("Source/A.spoon")
        end, "%.spoon%('A'%) already set; cannot call %.folder%('Source/A%.spoon'%)")
    end)

    T.test("definition rejects duplicate explicit name", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .withName("A")
                .withName("B")
        end, "%.withName%('A'%) already set; cannot call %.withName%('B'%)")
    end)

    T.test("definition rejects non string arguments", function()
        T.assertError(function()
            T.SpoonManager.from.github({
                "owner/repo",
            })
        end, "GitHub repository must be a string")

        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .folder({
                    "Source/A.spoon",
                })
        end, "Folder path must be a string")

        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .withName(123)
        end, "Spoon name must be a string")
    end)

    T.test("definition rejects non zip release asset", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .releaseLatest()
                .asset("A.tar.gz")
        end, "Release asset must point to a %.zip file")
    end)

    T.test("installer rejects non zip release asset from config", function()
        local result, err =
            T.SpoonManager.from.config({
                source = {
                    type = "github",
                    repository = "owner/repo",
                    release = "latest",
                },
                target = {
                    selection_asset = "A.tar.gz",
                    name_withName = "A",
                },
            }).install()

        T.assertFalse(result)
        T.assertEqual(err, "GitHub release asset must point to a .zip file")
    end)
end
