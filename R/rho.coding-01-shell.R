rho_shell_executable <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty executable path"
    }
  }
)

RhoPlatform <- S7::new_class("RhoPlatform", abstract = TRUE)
RhoUnixPlatform <- S7::new_class(
  "RhoUnixPlatform",
  parent = RhoPlatform,
  properties = list(bash = S7::class_character)
)
RhoWindowsPlatform <- S7::new_class(
  "RhoWindowsPlatform",
  parent = RhoPlatform,
  properties = list(bash = S7::class_character)
)

RhoShellResolution <- S7::new_class("RhoShellResolution", abstract = TRUE)
RhoShellConfig <- S7::new_class(
  "RhoShellConfig",
  parent = RhoShellResolution,
  abstract = TRUE,
  properties = list(executable = rho_shell_executable, reason = S7::class_character)
)
RhoArgumentShell <- S7::new_class(
  "RhoArgumentShell",
  parent = RhoShellConfig,
  abstract = TRUE
)
RhoBashShell <- S7::new_class("RhoBashShell", parent = RhoArgumentShell)
RhoLegacyWslBashShell <- S7::new_class(
  "RhoLegacyWslBashShell",
  parent = RhoShellConfig
)
RhoShellUnavailable <- S7::new_class(
  "RhoShellUnavailable",
  parent = RhoShellResolution,
  properties = list(message = S7::class_character, searched = S7::class_character)
)

RhoShellBackend <- S7::new_class("RhoShellBackend", abstract = TRUE)
RhoMiraiShellBackend <- S7::new_class(
  "RhoMiraiShellBackend",
  parent = RhoShellBackend,
  properties = list(compute = S7::class_any)
)

RhoShellOutcome <- S7::new_class("RhoShellOutcome", abstract = TRUE)
RhoShellCompleted <- S7::new_class(
  "RhoShellCompleted",
  parent = RhoShellOutcome,
  properties = list(
    output = S7::class_character,
    status = S7::class_integer,
    timed_out = S7::class_logical
  )
)
RhoShellFailure <- S7::new_class(
  "RhoShellFailure",
  parent = RhoShellOutcome,
  properties = list(message = S7::class_character, source = S7::class_any)
)

rho_resolve_bash <- S7::new_generic(
  "rho_resolve_bash",
  "platform",
  function(platform, shell_path = NULL, ...) S7::S7_dispatch()
)
rho_run_shell <- S7::new_generic(
  "rho_run_shell",
  c("backend", "shell"),
  function(backend, shell, command, cwd, timeout = Inf, environment = character(), ...) {
    S7::S7_dispatch()
  }
)
rho_shell_outcome <- S7::new_generic(
  "rho_shell_outcome",
  "value",
  function(value, ...) S7::S7_dispatch()
)
rho_shell_tool_result <- S7::new_generic(
  "rho_shell_tool_result",
  "outcome",
  function(outcome, command, ...) S7::S7_dispatch()
)

rho_current_platform <- function() {
  if (identical(.Platform$OS.type, "windows")) {
    roots <- unname(Sys.getenv(c("ProgramFiles", "ProgramFiles(x86)"), unset = NA_character_))
    roots <- roots[!is.na(roots) & nzchar(roots)]
    candidates <- c(
      file.path(roots, "Git", "bin", "bash.exe"),
      unname(Sys.which("bash.exe")),
      unname(Sys.which("bash"))
    )
    return(RhoWindowsPlatform(bash = unique(candidates[nzchar(candidates)])))
  }

  bash <- c(
    if (file.exists("/bin/bash")) "/bin/bash" else character(),
    unname(Sys.which("bash"))
  )
  RhoUnixPlatform(bash = unique(bash[nzchar(bash)]))
}

rho_is_legacy_wsl_bash <- function(path) {
  normalized <- tolower(chartr("/", "\\", path))
  grepl("^[a-z]:\\\\windows\\\\(system32|sysnative)\\\\bash\\.exe$", normalized)
}

rho_bash_shell <- function(path, reason) {
  if (rho_is_legacy_wsl_bash(path)) {
    RhoLegacyWslBashShell(executable = path, reason = reason)
  } else {
    RhoBashShell(executable = path, reason = reason)
  }
}

rho_existing_shell <- function(candidates) {
  candidates <- unique(candidates[nzchar(candidates)])
  candidates[file.exists(candidates)]
}

S7::method(rho_resolve_bash, RhoUnixPlatform) <- function(platform, shell_path = NULL, ...) {
  if (!is.null(shell_path)) {
    if (file.exists(shell_path)) {
      return(rho_bash_shell(shell_path, "the tool definition supplied this shell path"))
    }
    return(RhoShellUnavailable(
      message = sprintf("The configured shell does not exist: %s", shell_path),
      searched = shell_path
    ))
  }

  bash <- rho_existing_shell(platform@bash)
  if (length(bash)) {
    return(rho_bash_shell(bash[[1L]], "Bash was available on this Unix platform"))
  }
  RhoShellUnavailable(
    message = "No Bash executable is available on this Unix platform",
    searched = platform@bash
  )
}

S7::method(rho_resolve_bash, RhoWindowsPlatform) <- function(platform, shell_path = NULL, ...) {
  if (!is.null(shell_path)) {
    if (file.exists(shell_path)) {
      return(rho_bash_shell(shell_path, "the tool definition supplied this shell path"))
    }
    return(RhoShellUnavailable(
      message = sprintf("The configured Bash executable does not exist: %s", shell_path),
      searched = shell_path
    ))
  }

  bash <- rho_existing_shell(platform@bash)
  if (length(bash)) {
    return(rho_bash_shell(
      bash[[1L]],
      "Git Bash or another Bash executable was available on Windows"
    ))
  }
  RhoShellUnavailable(
    message = "No Bash executable is available on Windows; install Git Bash or supply shell_path",
    searched = platform@bash
  )
}

rho_shell_worker <- function(
  executable,
  working_directory,
  timeout_seconds,
  child_environment,
  command,
  command_from_stdin
) {
  input_file <- NULL
  shell_arguments <- if (command_from_stdin) "-s" else c("-c", command)
  if (command_from_stdin) {
    input_file <- tempfile("rho-shell-input-")
    writeLines(command, input_file, useBytes = TRUE)
    on.exit(unlink(input_file), add = TRUE)
  }
  processx::run(
    executable,
    shell_arguments,
    error_on_status = FALSE,
    wd = working_directory,
    timeout = timeout_seconds,
    stdout = "|",
    stderr = "2>&1",
    stdin = input_file,
    env = child_environment,
    windows_hide_window = TRUE,
    encoding = "UTF-8",
    cleanup_tree = TRUE
  )
}

rho_mirai_shell_process <- function(
  backend,
  shell,
  command,
  cwd,
  timeout,
  environment,
  command_from_stdin
) {
  rho_mirai_call(
    rho_shell_worker,
    args = list(
      executable = shell@executable,
      working_directory = cwd,
      timeout_seconds = timeout,
      child_environment = environment,
      command = command,
      command_from_stdin = command_from_stdin
    ),
    compute = backend@compute
  )
}

S7::method(
  rho_run_shell,
  list(RhoMiraiShellBackend, RhoArgumentShell)
) <- function(backend, shell, command, cwd, timeout = Inf, environment = character(), ...) {
  task <- rho_mirai_shell_process(
    backend,
    shell,
    command,
    cwd,
    timeout,
    environment,
    command_from_stdin = FALSE
  )
  rho_then(task, rho_shell_outcome)
}

S7::method(
  rho_run_shell,
  list(RhoMiraiShellBackend, RhoLegacyWslBashShell)
) <- function(backend, shell, command, cwd, timeout = Inf, environment = character(), ...) {
  task <- rho_mirai_shell_process(
    backend,
    shell,
    command,
    cwd,
    timeout,
    environment,
    command_from_stdin = TRUE
  )
  rho_then(task, rho_shell_outcome)
}

S7::method(
  rho_run_shell,
  list(RhoShellBackend, RhoShellUnavailable)
) <- function(backend, shell, command, cwd, timeout = Inf, environment = character(), ...) {
  rho_task(RhoShellFailure(message = shell@message, source = shell))
}

S7::method(rho_shell_outcome, RhoComputeErrorValue) <- function(value, ...) {
  RhoShellFailure(message = value@message, source = value)
}

S7::method(rho_shell_outcome, S7::class_list) <- function(value, ...) {
  required <- c("status", "stdout", "timeout")
  if (!all(required %in% names(value))) {
    return(RhoShellFailure(
      message = "The shell backend returned an invalid process result",
      source = value
    ))
  }
  RhoShellCompleted(
    output = value$stdout,
    status = as.integer(value$status),
    timed_out = isTRUE(value$timeout)
  )
}

S7::method(rho_shell_tool_result, RhoShellFailure) <- function(outcome, command, ...) {
  rho_tool_error_result(
    list(rho_text(outcome@message)),
    details = list(command = command, shell_failure = outcome)
  )
}

S7::method(rho_shell_tool_result, RhoShellCompleted) <- function(outcome, command, ...) {
  details <- list(
    command = command,
    exit_status = outcome@status,
    timed_out = outcome@timed_out
  )
  output <- if (nzchar(outcome@output)) outcome@output else "(no output)"
  if (outcome@timed_out) {
    return(rho_tool_error_result(
      list(rho_text(paste0(output, "\n\nCommand timed out"))),
      details = details
    ))
  }
  if (is.na(outcome@status) || outcome@status != 0L) {
    return(rho_tool_error_result(
      list(rho_text(paste0(
        output,
        "\n\nCommand exited with status ",
        outcome@status
      ))),
      details = details
    ))
  }
  rho_tool_result(list(rho_text(output)), details = details)
}

rho_tool_bash <- function(
  cwd = getwd(),
  shell = rho_resolve_bash(rho_current_platform()),
  backend = RhoMiraiShellBackend(compute = NULL),
  environment = "current"
) {
  rho_tool_spec(
    name = "bash",
    label = "Bash",
    description = paste(
      "Execute a Bash-compatible shell command in the configured working directory.",
      "Returns combined stdout and stderr."
    ),
    parameters = list(
      type = "object",
      properties = list(
        command = list(type = "string"),
        timeout = list(type = "number")
      ),
      required = "command"
    ),
    execute = function(tool_call_id, params, signal, on_update, ctx) {
      timeout <- params$timeout %||% Inf
      rho_then(
        rho_run_shell(
          backend,
          shell,
          command = params$command,
          cwd = cwd,
          timeout = timeout,
          environment = environment
        ),
        function(outcome) rho_shell_tool_result(outcome, params$command)
      )
    }
  )
}
