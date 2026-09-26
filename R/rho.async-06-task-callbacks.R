RhoEventPump <- S7::new_class("RhoEventPump", abstract = TRUE)
RhoLaterEventPump <- S7::new_class("RhoLaterEventPump", parent = RhoEventPump)

RhoEventPumpResult <- S7::new_class("RhoEventPumpResult", abstract = TRUE)
RhoEventPumpIdle <- S7::new_class("RhoEventPumpIdle", parent = RhoEventPumpResult)
RhoEventPumpProgress <- S7::new_class(
  "RhoEventPumpProgress",
  parent = RhoEventPumpResult
)
RhoEventPumpError <- S7::new_class(
  "RhoEventPumpError",
  parent = RhoAsyncError
)
RhoEventPumpUnsupported <- S7::new_class(
  "RhoEventPumpUnsupported",
  parent = RhoEventPumpError
)

rho_task_callback_name <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty string"
    }
  }
)

rho_task_callback_registered <- S7::new_property(
  S7::class_logical,
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) {
      "must be one non-missing logical value"
    }
  }
)

RhoTaskCallbackBridge <- S7::new_class(
  "RhoTaskCallbackBridge",
  properties = list(
    pump = RhoEventPump,
    name = rho_task_callback_name,
    manager = S7::class_any,
    callback_id = S7::class_any,
    registered = rho_task_callback_registered,
    observations = S7::class_environment
  ),
  validator = function(self) {
    if (self@registered && (is.null(self@manager) || is.null(self@callback_id))) {
      return("a registered bridge requires its manager and callback identifier")
    }
    if (!self@registered && (!is.null(self@manager) || !is.null(self@callback_id))) {
      "an unregistered bridge cannot retain a manager or callback identifier"
    }
  }
)

RhoTaskCallbackError <- S7::new_class(
  "RhoTaskCallbackError",
  parent = RhoAsyncError,
  properties = list(name = rho_task_callback_name)
)
RhoTaskCallbackNameInUse <- S7::new_class(
  "RhoTaskCallbackNameInUse",
  parent = RhoTaskCallbackError
)
RhoTaskCallbackRegistrationError <- S7::new_class(
  "RhoTaskCallbackRegistrationError",
  parent = RhoTaskCallbackError
)
RhoTaskCallbackRemovalError <- S7::new_class(
  "RhoTaskCallbackRemovalError",
  parent = RhoTaskCallbackError
)

rho_pump_events <- S7::new_generic(
  "rho_pump_events",
  "pump",
  function(pump, ...) S7::S7_dispatch()
)

rho_register_task_callback <- S7::new_generic(
  "rho_register_task_callback",
  "bridge",
  function(bridge, ...) S7::S7_dispatch()
)

rho_remove_task_callback <- S7::new_generic(
  "rho_remove_task_callback",
  "bridge",
  function(bridge, ...) S7::S7_dispatch()
)

S7::method(rho_pump_events, RhoEventPump) <- function(pump, ...) {
  RhoEventPumpUnsupported(
    message = "This event pump does not implement rho_pump_events()",
    parent = pump
  )
}

S7::method(rho_pump_events, RhoLaterEventPump) <- function(pump, ...) {
  tryCatch(
    if (later::run_now(timeoutSecs = 0)) {
      RhoEventPumpProgress()
    } else {
      RhoEventPumpIdle()
    },
    error = function(error) {
      RhoEventPumpError(message = conditionMessage(error), parent = error)
    }
  )
}

rho_later_event_pump <- function() {
  RhoLaterEventPump()
}

rho_task_callback_bridge <- function(
  pump = rho_later_event_pump(),
  name = "rho.async.interactive"
) {
  RhoTaskCallbackBridge(
    pump = pump,
    name = name,
    manager = NULL,
    callback_id = NULL,
    registered = FALSE,
    observations = rho_new_state(
      invocations = 0L,
      last_result = RhoEventPumpIdle()
    )
  )
}

rho_task_callback_result <- function(pump) {
  tryCatch(
    rho_pump_events(pump),
    error = function(error) {
      RhoEventPumpError(message = conditionMessage(error), parent = error)
    }
  )
}

rho_task_callback_handler <- function(expr, value, ok, visible, bridge) {
  result <- rho_task_callback_result(bridge@pump)
  bridge@observations$invocations <- bridge@observations$invocations + 1L
  bridge@observations$last_result <- result
  TRUE
}

rho_registered_task_callback <- function(bridge, manager, callback_id) {
  RhoTaskCallbackBridge(
    pump = bridge@pump,
    name = bridge@name,
    manager = manager,
    callback_id = callback_id,
    registered = TRUE,
    observations = bridge@observations
  )
}

rho_unregistered_task_callback <- function(bridge) {
  RhoTaskCallbackBridge(
    pump = bridge@pump,
    name = bridge@name,
    manager = NULL,
    callback_id = NULL,
    registered = FALSE,
    observations = bridge@observations
  )
}

S7::method(rho_register_task_callback, RhoTaskCallbackBridge) <- function(
  bridge,
  ...
) {
  if (bridge@registered) {
    return(rho_task(bridge))
  }
  if (bridge@name %in% getTaskCallbackNames()) {
    return(rho_task(RhoTaskCallbackNameInUse(
      message = sprintf("Task callback `%s` is already registered", bridge@name),
      parent = NULL,
      name = bridge@name
    )))
  }

  manager <- taskCallbackManager(registered = FALSE)
  manager$add(
    rho_task_callback_handler,
    data = bridge,
    name = bridge@name,
    register = FALSE
  )
  callback_id <- tryCatch(
    manager$register(name = bridge@name),
    error = identity
  )
  if (inherits(callback_id, "condition")) {
    return(rho_task(RhoTaskCallbackRegistrationError(
      message = conditionMessage(callback_id),
      parent = callback_id,
      name = bridge@name
    )))
  }
  rho_task(rho_registered_task_callback(bridge, manager, callback_id))
}

S7::method(rho_remove_task_callback, RhoTaskCallbackBridge) <- function(
  bridge,
  ...
) {
  if (!bridge@registered) {
    return(rho_task(bridge))
  }
  if (!bridge@name %in% getTaskCallbackNames()) {
    return(rho_task(rho_unregistered_task_callback(bridge)))
  }
  removed <- tryCatch(
    removeTaskCallback(bridge@callback_id),
    error = identity
  )
  if (inherits(removed, "condition") || !isTRUE(removed)) {
    parent <- if (inherits(removed, "condition")) removed else NULL
    message <- if (inherits(removed, "condition")) {
      conditionMessage(removed)
    } else {
      sprintf("Task callback `%s` could not be removed", bridge@name)
    }
    return(rho_task(RhoTaskCallbackRemovalError(
      message = message,
      parent = parent,
      name = bridge@name
    )))
  }
  rho_task(rho_unregistered_task_callback(bridge))
}
