rho_embedded_executor <- function(execute) {
  RhoFunctionEmbeddedExecutor(execute = execute)
}

rho_embedded_provider <- function(executor, provider_id = "embedded") {
  RhoEmbeddedProvider(provider_id = provider_id, executor = executor)
}

rho_embedded_error_stream <- function(model, message, code, details = list()) {
  rho_provider_error_stream(
    model,
    rho_provider_error(
      message = message,
      kind = "embedded",
      code = code,
      details = details
    )
  )
}

rho_embedded_result_stream <- function(result, model, executor) {
  if (rho_is_stream(result)) {
    return(result)
  }
  if (rho_is_task(result)) {
    stream_task <- rho_then(
      result,
      function(value) rho_embedded_result_stream(value, model, executor),
      function(error) {
        rho_embedded_error_stream(
          model,
          "Embedded execution failed",
          "embedded_execution",
          details = list(
            executor = rho_class_label(executor),
            parent = error
          )
        )
      }
    )
    return(rho_stream_from_task(stream_task))
  }
  rho_embedded_error_stream(
    model,
    "Embedded execution must return a RhoStream or RhoTask<RhoStream>",
    "embedded_return",
    details = list(
      executor = rho_class_label(executor),
      result_class = rho_class_label(result)
    )
  )
}

S7::method(
  rho_embedded_stream,
  list(RhoFunctionEmbeddedExecutor, RhoEmbeddedProvider, Model, Context)
) <- function(executor, provider, model, context, options = list(), ...) {
  result <- tryCatch(
    executor@execute(provider, model, context, options),
    error = identity
  )
  if (inherits(result, "error")) {
    return(rho_embedded_error_stream(
      model,
      "Embedded execution failed",
      "embedded_execution",
      details = list(
        executor = rho_class_label(executor),
        parent = result
      )
    ))
  }
  rho_embedded_result_stream(result, model, executor)
}

S7::method(rho_provider_transports, list(RhoEmbeddedProvider, Model)) <- function(
  provider,
  model,
  ...
) {
  list(EmbeddedTransport())
}

S7::method(
  rho_open_provider_transport,
  list(EmbeddedTransport, RhoEmbeddedProvider, Model, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  rho_embedded_stream(provider@executor, provider, model, context, options = options)
}
