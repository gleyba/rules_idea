package rules_intellij.worker

import rules_intellij.domain_socket.NettyDomainSocketChannelBuilder

import com.intellij.indexing.shared.ultimate.persistent.rpc.DaemonGrpcKt.DaemonCoroutineStub
import com.intellij.indexing.shared.ultimate.persistent.rpc.IndexRequest
import com.intellij.indexing.shared.ultimate.persistent.rpc.IndexResponse
import com.intellij.indexing.shared.ultimate.persistent.rpc.StartupRequest
import io.grpc.ManagedChannel
import io.grpc.ManagedChannelBuilder
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.io.*
import java.nio.file.Path
import java.nio.file.Paths
import java.util.*
import kotlin.io.path.createTempDirectory
import kotlin.io.path.exists


interface IntellijIndexingClientArgs {
    val logger: WorkerLogger
    val projectDir: String
    val channel: ManagedChannel
}

abstract class IntellijIndexingClient(args: IntellijIndexingClientArgs) {
    val logger = args.logger.apply {
        log("IntellijIndexingClient", args.projectDir)
    }
    private val projectDir = args.projectDir
    private val stub = DaemonCoroutineStub(args.channel)

    suspend fun index(request: IndexRequest): Result<IndexResponse> = runCatching {
        logger.log("IndexRequest", request)

        val response = stub.index(request)

        logger.log("IndexResponse", request)

        response
    }


    suspend fun getProjectId(): Result<Long> = runCatching {
        val request = StartupRequest.newBuilder()
            .setProjectDir(System.getProperty("user.dir") + "/" + projectDir)
            .build()

        logger.log("StartupRequest", request)

        val response = stub.start(request)

        logger.log("StartupResponse", response)

        response.projectId
    }

    open suspend fun start(): Result<Unit> = getProjectId().map {}
}

class IntellijIndexingClientDebugArgs(
    override val logger: WorkerLogger,
    override val projectDir: String,
    private val isDomainSocket: Boolean,
    val endpoint: String
): IntellijIndexingClientArgs {
    override val channel: ManagedChannel =
        if (isDomainSocket)
            NettyDomainSocketChannelBuilder
                .forDomainSocket(Path.of(endpoint).toAbsolutePath().toString())
                .usePlainText()
                .build()
        else
            ManagedChannelBuilder.forTarget(endpoint)
                .usePlaintext()
                .build()
}

class IntellijIndexingClientDebug(args: IntellijIndexingClientDebugArgs): IntellijIndexingClient(args) {
}

class IntellijIndexingClientStarterArgs(
    override val logger: WorkerLogger,
    override val projectDir: String,
    val javaBin: String,
    val ideHomeDir: String,
    val ideRunner: String,
    val pluginsDir: String,
): IntellijIndexingClientArgs {

    companion object {
        fun getRandomString(length: Int) : String {
            val allowedChars = ('A'..'Z') + ('a'..'z') + ('0'..'9')
            return (1..length)
                .map { allowedChars.random() }
                .joinToString("")
        }
    }

    val dir: Path = createTempDirectory().resolve(getRandomString(10))
    val socket = dir.resolve("intellij.socket")

    override val channel: ManagedChannel =
        NettyDomainSocketChannelBuilder
            .forDomainSocket(socket.toAbsolutePath().toString())
            .usePlainText()
            .build()
}

class IntellijIndexingClientStarter(args: IntellijIndexingClientStarterArgs): IntellijIndexingClient(args) {
    private val dir = args.dir
    private val socket = args.socket
    private val javaBin = args.javaBin
    private val ideHomeDir = args.ideHomeDir
    private val ideRunner = args.ideRunner
    private val pluginsDir = args.pluginsDir
    private val scope = CoroutineScope(Dispatchers.IO)

    @ExperimentalCoroutinesApi
    fun <T> Flow<T>.throttleCombine(periodMillis: Long): Flow<List<T>> {
        require(periodMillis > 0) { "period should be positive" }

        return channelFlow {
            var values = mutableListOf<T>()
            var timer: Timer? = null

            val sendValues = fun(){
                if (values.isEmpty()) {
                    return
                }
                val curValues = values
                values = mutableListOf<T>()
                scope.launch {
                    send(curValues)
                }
            }

            onCompletion { 
                timer?.cancel()
                sendValues()
            }
            collect { value ->
                values.add(value)

                if (timer == null) {
                    timer = Timer()
                    timer?.scheduleAtFixedRate(
                        object : TimerTask() {
                            override fun run() {
                                sendValues()
                            }
                        },
                        0,
                        periodMillis
                    )
                }
            }
        }
    }

    private fun logStream(tag: String, stream: InputStream) {
        scope.launch {
            stream
                .bufferedReader()
                .lineSequence()
                .asFlow()
                .throttleCombine(1000)
                .flowOn(Dispatchers.IO)
                .collect { values ->
                    logger.log(tag) { out ->
                        for (v in values) {
                            out.println(v)
                        }
                    }
                }
        }
    }

    private fun closeAll(process: Process) {
        process.toHandle().descendants().forEach { it.destroyForcibly() }
        process.destroyForcibly()
        dir.toFile().deleteRecursively()
    }

    private fun onProcessStopped(process: Process) {
        closeAll(process)
        val stdout = process.inputStream.bufferedReader().use(BufferedReader::readText)
        val stderr = process.errorStream.bufferedReader().use(BufferedReader::readText)
        throw IOException("Intellij stopped with: ${process.exitValue()}, \nstdout:\n$stdout\nstderr:\n$stderr}")
    }

    private suspend fun startIntellij(): Unit = withContext(Dispatchers.IO) {
        val path = Paths.get("").toAbsolutePath().toString()
        val cmdLine = listOf(
            listOf(ideRunner),
            listOf(
                "idea.home.path=$path/$ideHomeDir",
                "idea.config.path=$dir/config",
                "idea.system.path=$dir/system",
                "idea.plugins.path=$path/$pluginsDir",
                "idea.platform.prefix=Idea",
                "idea.initially.ask.config=false",
                "idea.skip.indices.initialization=true",
                "idea.force.dumb.queue.tasks=true",
                "idea.suspend.indexes.initialization=true",
                "intellij.disable.shared.indexes=true",
                "shared.indexes.download=false",
                "intellij.hash.as.local.file.timestamp=true",
                "idea.trust.all.projects=true",
                "caches.indexerThreadsCount=1",
                "java.system.class.loader=com.intellij.util.lang.PathClassLoader",
                "jna.boot.library.path=$path/$ideHomeDir/lib/jna/aarch64",
                "jna.nosys=true",
                "jna.noclasspath=true",
                "sun.java2d.metal=true",
                "splash=true",
                "aether.connector.resumeDownloads=true",
            ).map { "--jvm_flag=-D$it" } + listOf(
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
            ).map { "--jvm_flag=--add-opens=$it=ALL-UNNAMED" },
            listOf(
                "dump-shared-index",
                "persistent-project",
                "--socket=$socket",
            )
        ).flatten()

        logger.log("INTELLIJ") {
            it.println("Starting intellij...")
            it.println("Working Directory = $path")
            for (x in cmdLine) {
                it.println(x)
            }
        }

        val pb = ProcessBuilder()
        pb.environment().remove("RUNFILES_MANIFEST_FILE")
        pb.environment().remove("JAVA_RUNFILES")
        val process = pb.command(cmdLine).start()

        Runtime.getRuntime().addShutdownHook(Thread { closeAll(process) })

        logStream("INTELLIJ STDOUT", process.inputStream)
        logStream("INTELLIJ STDERR", process.errorStream)

        process.waitFor()
        onProcessStopped(process)
    }

    private suspend fun waitStarted() {
        for (i in 0..180) {
            if (socket.exists()) {
                return
            }

            delay(1000)
        }

        throw RuntimeException("No domaiun socket at path: ${socket.toAbsolutePath()} after 3 minutes")
    }

    override suspend fun start(): Result<Unit> = runCatching  {
        scope.launch {
            runCatching { startIntellij() }
                .onFailure { logger.err("INTELLIJ Exception", it) }
        }

        waitStarted()
        super.start().getOrThrow()
    }
}

fun createIntellijIndexingClient(args: IndexingWorkerArgs, logger: WorkerLogger): Result<IntellijIndexingClient> =  runCatching{
    val projectDir = args.projectDir ?: throw IllegalArgumentException("No project dir")
    if (args.debugEndpoint != null || args.debugDomainSocket != null) {
        IntellijIndexingClientDebug(IntellijIndexingClientDebugArgs(
            logger,
            projectDir,
            args.debugDomainSocket != null,
            args.debugEndpoint ?: args.debugDomainSocket!!
        ))
    } else {
        IntellijIndexingClientStarter(IntellijIndexingClientStarterArgs(
            logger,
            projectDir,
            args.javaBinary ?: throw IllegalArgumentException("No java binary"),
            args.ideHomeDir ?: throw IllegalArgumentException("No ide home dir"),
            args.ideBinary ?: throw IllegalArgumentException("No ide runner"),
            args.pluginsDirectory ?: throw IllegalArgumentException("No ide runner"),
        ))
    }
}