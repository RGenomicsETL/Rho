RhoTask <- S7::new_class(
  "RhoTask",
  properties = list(state = S7::class_environment),
  validator = function(self) {
    required <- c("status", "created_at", "cancelled")
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) sprintf("@state missing field(s): %s", paste(missing, collapse = ", "))
  }
)

RhoImmediateTask <- S7::new_class("RhoImmediateTask", parent = RhoTask)
RhoRejectedTask <- S7::new_class("RhoRejectedTask", parent = RhoTask)
RhoFunctionTask <- S7::new_class("RhoFunctionTask", parent = RhoTask)
RhoNanonextAioTask <- S7::new_class("RhoNanonextAioTask", parent = RhoTask)
RhoPromiseTask <- S7::new_class("RhoPromiseTask", parent = RhoTask)

RhoStream <- S7::new_class(
  "RhoStream",
  properties = list(state = S7::class_environment),
  validator = function(self) {
    required <- c("closed", "created_at")
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) sprintf("@state missing field(s): %s", paste(missing, collapse = ", "))
  }
)

RhoDuplex <- S7::new_class("RhoDuplex", parent = RhoStream)

RhoListStream <- S7::new_class("RhoListStream", parent = RhoStream)
RhoMappedStream <- S7::new_class("RhoMappedStream", parent = RhoStream)
RhoFlatMappedStream <- S7::new_class("RhoFlatMappedStream", parent = RhoStream)
RhoTaskStream <- S7::new_class("RhoTaskStream", parent = RhoStream)

RhoStreamItem <- S7::new_class("RhoStreamItem", abstract = TRUE)
RhoStreamValue <- S7::new_class(
  "RhoStreamValue",
  parent = RhoStreamItem,
  properties = list(value = S7::class_any)
)
RhoStreamEnd <- S7::new_class("RhoStreamEnd", parent = RhoStreamItem)

RhoAsyncError <- S7::new_class(
  "RhoAsyncError",
  properties = list(
    message = S7::class_character,
    parent = S7::class_any
  )
)

RhoTimeoutError <- S7::new_class("RhoTimeoutError", parent = RhoAsyncError)
RhoCancellation <- S7::new_class("RhoCancellation", parent = RhoAsyncError)

rho_nonnegative_milliseconds <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value < 0L) {
      "must be one non-negative integer number of milliseconds"
    }
  }
)

RhoPollDecision <- S7::new_class("RhoPollDecision", abstract = TRUE)
RhoPollPending <- S7::new_class(
  "RhoPollPending",
  parent = RhoPollDecision,
  properties = list(delay_ms = rho_nonnegative_milliseconds)
)
RhoPollComplete <- S7::new_class(
  "RhoPollComplete",
  parent = RhoPollDecision,
  properties = list(value = S7::class_any)
)
RhoPollFailed <- S7::new_class(
  "RhoPollFailed",
  parent = RhoPollDecision,
  properties = list(error = S7::class_any)
)

RhoSerialQueue <- S7::new_class(
  "RhoSerialQueue",
  properties = list(state = S7::class_environment),
  validator = function(self) {
    required <- c("entries", "active", "scheduled")
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) {
      sprintf("@state missing field(s): %s", paste(missing, collapse = ", "))
    }
  }
)

RhoQueueEntry <- S7::new_class(
  "RhoQueueEntry",
  properties = list(
    action = S7::class_function,
    label = S7::class_character,
    state = S7::class_environment
  ),
  validator = function(self) {
    required <- c("status", "resolve", "reject", "current", "monitor")
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) {
      sprintf("@state missing field(s): %s", paste(missing, collapse = ", "))
    }
  }
)
