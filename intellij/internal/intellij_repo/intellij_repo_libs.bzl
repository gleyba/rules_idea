_LIBS = """\
load("@rules_java//java:defs.bzl", "java_import")

_JARS = [
    "platform-loader.jar",
    "util-8.jar",
    "util.jar",
    "app-client.jar",
    "util_rt.jar",
    "product.jar",
    "product-client.jar",
    "app.jar",
    "lib-client.jar",
    "modules.jar",
    "lib.jar",
    "stats.jar",
    "jps-model.jar",
    "external-system-rt.jar",
    "rd.jar",
    "protobuf.jar",
    "bouncy-castle.jar",
    "forms_rt.jar",
    "intellij-test-discovery.jar",
    "annotations.jar",
    "groovy.jar",
    "externalProcess-rt.jar",
    "async-profiler.jar",
    "byte-buddy-agent.jar",
    "error-prone-annotations.jar",
    "grpc.jar",
    "idea_rt.jar",
    "intellij-coverage-agent-1.0.738.jar",
    "jsch-agent.jar",
    "junit4.jar",
    "nio-fs.jar",
    "ant/lib/ant.jar",
]

java_import(
    name = "lib",
    jars = _JARS,
    visibility = ["//visibility:public"],
)

java_import(
    name = "no_link_lib",
    jars = _JARS,
    neverlink = 1,
    visibility = ["//visibility:public"],
)

_JNILIBS = glob([
    "**/*.so",
    "**/*.jnilib", 
])

filegroup(
    name = "jnilibs",
    srcs = _JNILIBS,
    visibility = ["//visibility:public"],
)

filegroup(
    name = "runfiles",
    srcs = glob(
        include = [ "**" ], 
        exclude = [ 
            "src/**",
            "*.bazel",    
        ],
    ),
    visibility = ["//visibility:public"],
)
"""

def intellij_repo_libs(rctx):
    rctx.file(
        "lib/BUILD.bazel",
        content = _LIBS,
    )