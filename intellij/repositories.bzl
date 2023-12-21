load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file", "http_jar")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_WORKER_PROTO_COMMIT = "c17f1b7f9b93bf034046d0973bf2b7e9a64815bf"
_WORKER_PROTO_SHA256 = "9e628d17d5e6ee0f9925576c0346ab1c452f94b6219bee00dbee3ff21d13b341"

_BAZEL_SKYLIB_VERSION = "1.5.0"
_BAZEL_SKYLIB_SHA256 = "cd55a062e763b9349921f0f5db8c3933288dc8ba4f76dd9416aac68acee3cb94"
_BAZEL_SKYLIB_URLS = [ x.format(version = _BAZEL_SKYLIB_VERSION) for x in [
    "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/{version}/bazel-skylib-{version}.tar.gz",
    "https://github.com/bazelbuild/bazel-skylib/releases/download/{version}/bazel-skylib-{version}.tar.gz",
]]

PROTOBUF_VERSION = "25.1"
_PROTOBUF_VERSION = PROTOBUF_VERSION
_PROTOBUF_SHA256 = "5c86c077b0794c3e9bb30cac872cf883043febfb0f992137f0a8b1c3d534617c"

_RULES_JVM_EXTERNAL_VERSION = "5.3"
_RULES_JVM_EXTERNAL_SHA256 = "6cc8444b20307113a62b676846c29ff018402fd4c7097fcd6d0a0fd5f2e86429"

GRPC_JAVA_VERSION = "1.60.0"
_GRPC_JAVA_VERSION = GRPC_JAVA_VERSION
_GRPC_JAVA_SHA256 = "468faf564245021d896040595c1b5d41baaea939ae0382882cbe37884d79974a"

_RULES_KOTLIN_VERSION = "1.9.0"
_RULES_KOTLIN_SHA256 = "5766f1e599acf551aa56f49dab9ab9108269b03c557496c54acaf41f98e2b8d6"

_GRPC_KOTLIN_VERSION = "1.4.1"
_GRPC_KOTLIN_SHA256 = "b576019f9222f47eef42258e5d964c04d87a01532c0df1a40a8f9fa1acc301c8"

_RULES_PKG_VERSION = "0.9.1"
_RULES_PKG_SHA256 = "8f9ee2dc10c1ae514ee599a8b42ed99fa262b757058f65ad3c384289ff70c4b8"


def rules_intellij_repositories():
    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = _BAZEL_SKYLIB_SHA256,
        urls = _BAZEL_SKYLIB_URLS,
    )

    maybe(
        http_archive,
        name = "io_bazel_rules_kotlin",
        url = "https://github.com/bazelbuild/rules_kotlin/releases/download/v{ver}/rules_kotlin-v{ver}.tar.gz".format(ver = _RULES_KOTLIN_VERSION),
        sha256 = _RULES_KOTLIN_SHA256,
    )
    maybe(
        http_archive,
        name = "com_google_protobuf",
        sha256 = _PROTOBUF_SHA256,
        strip_prefix = "protobuf-%s" % _PROTOBUF_VERSION,
        repo_mapping = { "@maven": "@rules_intellij_maven" },
        url = "https://github.com/protocolbuffers/protobuf/releases/download/v{ver}/protobuf-{ver}.zip".format(ver = _PROTOBUF_VERSION),
    )

    maybe(
        http_archive,
        name = "rules_jvm_external",
        sha256 = _RULES_JVM_EXTERNAL_SHA256,
        strip_prefix = "rules_jvm_external-%s" % _RULES_JVM_EXTERNAL_VERSION,
        url = "https://github.com/bazelbuild/rules_jvm_external/archive/%s.zip" % _RULES_JVM_EXTERNAL_VERSION,
    )

    maybe(
        http_archive,
        name = "io_grpc_grpc_java",
        sha256 = _GRPC_JAVA_SHA256,
        strip_prefix = "grpc-java-%s" % _GRPC_JAVA_VERSION,
        url = "https://github.com/grpc/grpc-java/archive/refs/tags/v%s.zip" % _GRPC_JAVA_VERSION,
    )

    maybe(
        http_archive,
        name = "com_github_grpc_grpc_kotlin",
        sha256 = _GRPC_KOTLIN_SHA256,
        strip_prefix = "grpc-kotlin-%s" % _GRPC_KOTLIN_VERSION,
        url = "https://github.com/grpc/grpc-kotlin/archive/refs/tags/v%s.zip" % _GRPC_KOTLIN_VERSION,
        repo_mapping = { 
            "@maven": "@rules_intellij_maven",
        },
        patches = [ "@rules_intellij//intellij/internal/misc:grpc_kotlin.patch" ],
    )

    maybe(
        http_archive,
        name = "rules_pkg",
        url = "https://github.com/bazelbuild/rules_pkg/releases/download/{version}/rules_pkg-{version}.tar.gz".format(version = _RULES_PKG_VERSION),
        sha256 = _RULES_PKG_SHA256,
    )

    http_file(
        name = "workers_proto",
        urls = ["https://raw.githubusercontent.com/bazelbuild/bazel/%s/src/main/protobuf/worker_protocol.proto" % _WORKER_PROTO_COMMIT ],
        sha256 = _WORKER_PROTO_SHA256,
    )
