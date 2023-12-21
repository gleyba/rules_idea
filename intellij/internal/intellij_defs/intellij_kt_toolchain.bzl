_KT_TOOLCHAIN_TP = """\
def _wrap_kt_toolchain_impl(ctx):
    compile_time_providers = [
        JavaInfo(
            output_jar = jar,
            compile_jar = jar,
            # neverlink = True,
        )
        for jar in ctx.files.jvm_stdlibs
    ]

    base_toolchain = ctx.attr.base[platform_common.ToolchainInfo]
    mapped = {{}}
    for key in dir(base_toolchain):
        if key == "to_json" or key == "to_proto":
            continue
        if key == "jvm_stdlibs":
            mapped["jvm_stdlibs"] = java_common.merge(compile_time_providers)
            continue
        mapped[key] = getattr(base_toolchain, key)
    return [platform_common.ToolchainInfo(**mapped)]


wrap_kt_toolchain = rule(
    attrs = {{
        "base": attr.label(
            doc = "Base toolchain to edit.",
            providers = [platform_common.ToolchainInfo],
        ),
        "jvm_stdlibs": attr.label_list(
            doc = "The jvm stdlibs.",
            providers = [JavaInfo],
            cfg = "target",
            default = [
                "@{intellij_repo}//lib:no_link_runtime",
            ],
        ),
    }},
    implementation = _wrap_kt_toolchain_impl,
    provides = [platform_common.ToolchainInfo],
)

"""

_KT_TOOLCHAIN_BUILD_TP = """\
load("@{rules_kotlin_repo}//kotlin/internal:toolchains.bzl", "define_kt_toolchain")
# load(":kt_toolchain.bzl", "wrap_kt_toolchain")

define_kt_toolchain(
    name = "kt_toolchain",
    language_version = "{kotlin_version}",
    api_version = "{kotlin_version}",
)

# wrap_kt_toolchain(
#     name = "kt_toolchain",
#     base = ":base_kt_toolchain_impl",
#     visibility = ["//visibility:public"],    
# )
"""


def intellij_kt_toolchain(rctx):
    # Original here - https://github.com/bazelbuild/rules_kotlin/blob/v1.7.0-RC-3/kotlin/internal/toolchains.bzl
    """The kotlin toolchain used among with specific intellij"""
    # rctx.file(
    #     "kt_toolchain/kt_toolchain.bzl", 
    #     _KT_TOOLCHAIN_TP.format(
    #         intellij_repo = rctx.attr.intellij_repo,
    #         rules_kotlin_repo = rctx.attr.rules_kotlin_repo,
    #     ),
    # )
    rctx.file(
        "kt_toolchain/BUILD.bazel", 
        _KT_TOOLCHAIN_BUILD_TP.format(
            rules_kotlin_repo = rctx.attr.rules_kotlin_repo,
            kotlin_version = rctx.attr.kotlin_version,
        ),
    )