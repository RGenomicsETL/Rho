RhoExtensionRuntime <- S7::new_class(
  "RhoExtensionRuntime",
  properties = list(state = S7::class_environment)
)
RhoExtensionAPI <- S7::new_class(
  "RhoExtensionAPI",
  properties = list(runtime = RhoExtensionRuntime, state = S7::class_environment)
)
RhoExtensionContext <- S7::new_class(
  "RhoExtensionContext",
  properties = list(runtime = RhoExtensionRuntime, signal = S7::class_any, data = S7::class_list)
)

rho_extension_runtime <- function() {
  RhoExtensionRuntime(
    state = rho_ext_new_state(
      handlers = new.env(parent = emptyenv()),
      tools = new.env(parent = emptyenv()),
      commands = new.env(parent = emptyenv()),
      providers = new.env(parent = emptyenv()),
      stale = FALSE,
      bound = FALSE,
      pending_provider_registrations = list()
    )
  )
}

rho_extension_api <- function(runtime = rho_extension_runtime(), source = "<memory>") {
  RhoExtensionAPI(runtime = runtime, state = rho_ext_new_state(source = source))
}

rho_on <- S7::new_generic(
  "rho_on",
  c("api", "event", "handler"),
  function(api, event, handler, ...) S7::S7_dispatch()
)
rho_register_tool <- S7::new_generic(
  "rho_register_tool",
  c("api", "tool"),
  function(api, tool, ...) {
    S7::S7_dispatch()
  }
)
rho_register_command <- S7::new_generic(
  "rho_register_command",
  c("api", "name", "handler"),
  function(api, name, handler, description = NULL, ...) S7::S7_dispatch()
)
rho_register_provider <- S7::new_generic(
  "rho_register_provider",
  "api",
  function(api, name, provider, ...) S7::S7_dispatch()
)
rho_dispatch_event <- S7::new_generic(
  "rho_dispatch_event",
  "runtime",
  function(runtime, event, ctx = NULL, ...) S7::S7_dispatch()
)

S7::method(
  rho_on,
  list(RhoExtensionAPI, S7::class_character, S7::class_function)
) <- function(api, event, handler, ...) {
  handlers <- api@runtime@state$handlers
  current <- if (exists(event, handlers, inherits = FALSE)) get(event, handlers) else list()
  current[[length(current) + 1L]] <- handler
  assign(event, current, handlers)
  invisible(api)
}

S7::method(
  rho_register_tool,
  list(RhoExtensionAPI, ToolSpec)
) <- function(api, tool, ...) {
  assign(tool@name, tool, api@runtime@state$tools)
  invisible(api)
}

S7::method(
  rho_register_command,
  list(RhoExtensionAPI, S7::class_character, S7::class_function)
) <- function(
  api,
  name,
  handler,
  description = NULL,
  ...
) {
  assign(
    name,
    list(name = name, handler = handler, description = description),
    api@runtime@state$commands
  )
  invisible(api)
}

S7::method(rho_register_provider, RhoExtensionAPI) <- function(api, name, provider, ...) {
  if (!isTRUE(api@runtime@state$bound)) {
    api@runtime@state$pending_provider_registrations[[
      length(api@runtime@state$pending_provider_registrations) + 1L
    ]] <- list(name = name, provider = provider)
  } else {
    assign(name, provider, api@runtime@state$providers)
  }
  invisible(api)
}

rho_dispatch_handlers <- function(handlers, event, ctx, index = 1L, values = list()) {
  if (index > length(handlers)) {
    return(rho_task(values))
  }
  value <- tryCatch(handlers[[index]](event, ctx), error = identity)
  if (inherits(value, "error")) {
    return(rho_rejected(value))
  }
  rho_then(rho_as_task(value), function(value) {
    if (!is.null(value)) {
      values[[length(values) + 1L]] <- value
    }
    rho_dispatch_handlers(handlers, event, ctx, index + 1L, values)
  })
}

S7::method(rho_dispatch_event, RhoExtensionRuntime) <- function(runtime, event, ctx = NULL, ...) {
  name <- event$type %||% event[["type"]]
  if (is.null(name) || !exists(name, runtime@state$handlers, inherits = FALSE)) {
    return(rho_task(list()))
  }
  rho_dispatch_handlers(get(name, runtime@state$handlers), event, ctx)
}
