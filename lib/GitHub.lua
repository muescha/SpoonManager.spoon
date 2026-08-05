local GitHub = {}

function GitHub.archiveUrl(source)
    local ref = source.ref or source.branch or "main"
    return string.format(
        "%s/%s/archive/%s.zip",
        source.baseUrl or "https://github.com",
        source.repository,
        ref
    )
end

function GitHub.rawUrl(source, path)
    local ref = source.ref or source.branch or "main"
    return string.format(
        "%s/%s/raw/%s/%s",
        source.baseUrl or "https://github.com",
        source.repository,
        ref,
        path
    )
end

function GitHub.releaseAssetUrl(source)
    local release = source.release or "latest"

    if release == "latest" then
        return string.format(
            "%s/%s/releases/latest/download/%s",
            source.baseUrl or "https://github.com",
            source.repository,
            source.asset
        )
    end

    return string.format(
        "%s/%s/releases/download/%s/%s",
        source.baseUrl or "https://github.com",
        source.repository,
        release,
        source.asset
    )
end

return GitHub
