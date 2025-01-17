load("//intellij/internal/intellij_repo:intellij_repo.bzl", "intellij_repo")
load("//intellij/internal/intellij_defs:intellij_defs.bzl", "intellij_defs")

RULES_INTELLIJ = Label("//:all")


def intellij(name, register = False, **kwargs):
    kotlin_version = kwargs.pop("kotlin_version")
    intellij_repo_name = "%s_distr" % name

    intellij_repo(
        name = intellij_repo_name, 
        rules_intellij_repo = RULES_INTELLIJ.workspace_name,
        rules_kotlin_repo = "io_bazel_rules_kotlin",
        **kwargs
    )

    intellij_defs(
        name = name,
        intellij_repo = intellij_repo_name,
        kotlin_version = kotlin_version,
        rules_intellij_repo = RULES_INTELLIJ.workspace_name,
        rules_kotlin_repo = "io_bazel_rules_kotlin",
    )

    if register:
        native.register_toolchains("@%s//:kt_toolchain" % name)
        native.register_toolchains("@%s//:toolchain" % name)
        native.register_execution_platforms("@%s//:platform" % name)
