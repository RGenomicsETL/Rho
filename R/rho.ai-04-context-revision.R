S7::method(rho_context_signature, S7::class_list) <- function(x, ...) {
  lapply(x, rho_context_signature)
}

S7::method(rho_context_signature, ToolSpec) <- function(x, ...) {
  list(
    class = S7::S7_class(x)@name,
    name = x@name,
    label = x@label,
    description = x@description,
    parameters = rho_context_signature(x@parameters),
    overlap = rho_context_signature(x@overlap)
  )
}

S7::method(rho_context_signature, Context) <- function(x, ...) {
  activations <- lapply(
    Filter(
      function(message) {
        S7::S7_inherits(message, ToolResultMessage) &&
          length(message@added_tool_names)
      },
      x@messages
    ),
    function(message) message@added_tool_names
  )
  list(
    system_prompt = x@system_prompt,
    tools = rho_context_signature(x@tools),
    operations = rho_context_signature(x@operations),
    tool_activations = activations
  )
}

S7::method(rho_context_signature, Model) <- function(x, ...) {
  list(provider = x@provider, id = x@id, api = x@api)
}

S7::method(rho_context_signature, S7::class_any) <- function(x, ...) {
  if (inherits(x, "S7_object")) {
    return(list(
      class = S7::S7_class(x)@name,
      properties = lapply(S7::props(x), rho_context_signature)
    ))
  }
  if (is.function(x)) {
    return(list(
      class = class(x),
      formals = rho_context_signature(as.list(formals(x))),
      body = paste(deparse(body(x), width.cutoff = 500L), collapse = "\n")
    ))
  }
  if (is.environment(x)) {
    return(list(class = class(x)))
  }
  x
}

S7::method(
  rho_context_revision,
  list(Context, Model)
) <- function(context, model, ...) {
  RhoContextRevision(
    digest = digest::digest(
      list(
        model = rho_context_signature(model),
        context = rho_context_signature(context)
      ),
      algo = "sha256"
    )
  )
}
