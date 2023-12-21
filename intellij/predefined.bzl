load("@rules_intellij//intellij:intellij.bzl", "intellij")

# Shared Project Indexes plugin versions are from - https://plugins.jetbrains.com/plugin/14437-shared-project-indexes/versions
# Bazel plugin versins are from - https://plugins.jetbrains.com/plugin/8609-bazel-for-intellij/versions

def idea_UI_2023_3_2(
    name = "idea_UI_2023_3_2",
    plugins = {
        "indexing-shared-ultimate:intellij.indexing.shared:233.13135.65": "",
        "ijwb:com.google.idea.bazel.ijwb:2023.11.21.0.1-api-version-232": "",
    },
    default_plugins = [
        "indexing-shared:intellij.indexing.shared.core",
    ],
    **kwargs
):
    intellij(
        name = name,
        type = "idea",
        subtype = "ideaIU",
        version = "2023.3.2",
        sha256 = "ebee43276f29b825dc79a27842b803d26b74bbdb67a1789d698ee6c2cc816069",
        kotlin_version = "1.9",
        plugins = plugins,
        default_plugins = default_plugins,
        **kwargs
    )
