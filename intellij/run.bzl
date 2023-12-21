_HOME_PATH = "idea.home.path"
_CONFIG_PATH = "idea.config.path"
_SYSTEM_PATH = "idea.system.path"
_PLUGINS_PATH = "idea.plugins.path"
_INDEXES_JSON_PATH = "local.project.shared.index.json.path"

_OPENS = [
    "java.base/java.io",
    "java.base/java.lang",
    "java.base/java.lang.ref",
    "java.base/java.lang.reflect",
    "java.base/java.net",
    "java.base/java.nio",
    "java.base/java.nio.charset",
    "java.base/java.text",
    "java.base/java.time",
    "java.base/java.util",
    "java.base/java.util.concurrent",
    "java.base/java.util.concurrent.atomic",
    "java.base/java.util.concurrent.locks",
    "java.base/jdk.internal.vm",
    "java.base/sun.nio.ch",
    "java.base/sun.nio.fs",
    "java.base/sun.security.ssl",
    "java.base/sun.security.util",
    "java.base/sun.net.dns",
    "java.desktop/com.sun.java.swing.plaf.gtk",
    "java.desktop/java.awt",
    "java.desktop/java.awt.dnd.peer",
    "java.desktop/java.awt.event",
    "java.desktop/java.awt.image",
    "java.desktop/java.awt.peer",
    "java.desktop/java.awt.font",
    "java.desktop/javax.swing",
    "java.desktop/javax.swing.plaf.basic",
    "java.desktop/javax.swing.text.html",
    "java.desktop/sun.awt.X11",
    "java.desktop/sun.awt.datatransfer",
    "java.desktop/sun.awt.image",
    "java.desktop/sun.awt",
    "java.desktop/sun.lwawt",
    "java.desktop/sun.lwawt.macosx",
    "java.desktop/sun.font",
    "java.desktop/sun.java2d",
    "java.desktop/sun.swing",
    "java.desktop/com.sun.java.swing",
    "jdk.attach/sun.tools.attach",
    "jdk.compiler/com.sun.tools.javac.api",
    "jdk.internal.jvmstat/sun.jvmstat.monitor",
    "jdk.jdi/com.sun.tools.jdi",
    "java.desktop/com.apple.eawt",
    "java.desktop/com.apple.laf",
    "java.desktop/com.apple.eawt.event",
]

def _run_intellij_impl(ctx):
    out = ctx.actions.declare_file("%s.sh" % ctx.attr.name)

    intellij = ctx.toolchains["@rules_intellij//intellij:intellij_toolchain_type"].intellij
    intellij_project = ctx.toolchains["@rules_intellij//intellij:intellij_project_toolchain_type"].intellij_project
    java_runtime = ctx.toolchains["@bazel_tools//tools/jdk:runtime_toolchain_type"].java_runtime
    jvm_props = {
        "java.system.class.loader": "com.intellij.util.lang.PathClassLoader",
        "jna.boot.library.path": "%s/lib/jna/aarch64" % intellij.home_directory,
        "pty4j.preferred.native.folder": "%s/lib/pty4j" % intellij.home_directory,
        "jna.nosys": "true",
        "jna.noclasspath": "true",
        "sun.java2d.metal": "true",
        "splash": "true",
        "aether.connector.resumeDownloads": "false",
    } 

    jvm_props.update(ctx.attr.jvm_props)

    if not _HOME_PATH in jvm_props:
        jvm_props[_HOME_PATH] = intellij.home_directory

    if not _PLUGINS_PATH in jvm_props:
        jvm_props[_PLUGINS_PATH] = intellij.plugins_directory

    if _CONFIG_PATH in jvm_props and ctx.attr.config_dir:
        fail("%s already in jvm_props, but also config_dir attribute specified" % _CONFIG_PATH)
    elif ctx.attr.config_dir:
        jvm_props[_CONFIG_PATH] = ctx.attr.config_dir
    else:
        jvm_props[_CONFIG_PATH] = "~/.rules_intellij/%s/config" % intellij.id

    if _SYSTEM_PATH in jvm_props and ctx.attr.system_dir:
        fail("%s already in jvm_props, but also system_dir attribute specified" % _SYSTEM_PATH)
    elif ctx.attr.system_dir:
        jvm_props[_SYSTEM_PATH] = ctx.attr.system_dir
    else:
        jvm_props[_SYSTEM_PATH] = "~/.rules_intellij/%s/system" % intellij.id

    if _INDEXES_JSON_PATH in jvm_props and ctx.file.indexes:
        fail("%s already in jvm_props, but also indexes attribute specified" % _INDEXES_JSON_PATH)
    elif ctx.attr.indexes:
        jvm_props[_INDEXES_JSON_PATH] = ctx.file.indexes.path

    ctx.actions.expand_template(
        template = ctx.file._template,
        output = out,
        substitutions = {
            "%%binary%%": intellij.binary_path,
            "%%project_dir%%": intellij_project.project_dir,
            "%%jvm_flags%%": " \\\n    ".join(
                ['"--jvm_flag=-D%s=%s"' % (k, v) for k,v in jvm_props.items()] +
                ['"--jvm_flag=--add-opens=%s=ALL-UNNAMED"' %x for x in _OPENS]
            )
        },
        is_executable = True,
    )

    return DefaultInfo(
        files = depset([out]),
        executable = out,
        runfiles = ctx.runfiles(files =
            intellij.binary.files.to_list()
            + intellij.plugins 
            + intellij.files 
            + java_runtime.files.to_list()
        )
    )


_run_intellij = rule(
    implementation = _run_intellij_impl,
    attrs = {
        "indexes": attr.label(allow_single_file = True),
        "config_dir": attr.string(),
        "system_dir": attr.string(),
        "jvm_props": attr.string_dict(),
        "_template": attr.label(
            default = "@rules_intellij//intellij/internal/misc:run_intellij.sh.tp",
            allow_single_file = True,
        ),
    },
    toolchains = [
        "@rules_intellij//intellij:intellij_toolchain_type",
        "@rules_intellij//intellij:intellij_project_toolchain_type",
        "@bazel_tools//tools/jdk:runtime_toolchain_type",
    ],
    executable = True,
)

def run_intellij(**kwargs):
    _run_intellij(
        tags = [ "local" ],
        **kwargs
    )