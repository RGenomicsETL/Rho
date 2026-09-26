#' Asynchronous task and stream contracts
#'
#' Rho tasks represent one eventual value, while Rho streams represent an
#' asynchronous sequence of typed stream items. Effectful callers compose
#' tasks with [rho_then()] or coroutines and block only at [rho_await()].
#'
#' `rho_new_state()` and the concrete adapter task classes are exported for
#' packages implementing new async backends. Polling actions return one of the
#' typed `RhoPollDecision` subclasses; timing remains inside `rho.async`.
#' `rho_serial_queue()` orders asynchronous actions without blocking the event
#' loop. Cancelling a queued task removes only that entry; cancelling active
#' work propagates to the task returned by its action.
#'
#' @name rho_async_contracts
#' @aliases RhoTask RhoImmediateTask RhoRejectedTask RhoFunctionTask
#' @aliases RhoNanonextAioTask RhoPromiseTask RhoAsyncError RhoTimeoutError
#' @aliases RhoCancellation rho_contract_violation
#' @aliases rho_signal_contract_violation
#' @aliases RhoStream RhoDuplex RhoListStream RhoMappedStream RhoFlatMappedStream
#' @aliases RhoTaskStream RhoStreamItem RhoStreamValue RhoStreamEnd
#' @aliases RhoPollDecision RhoPollPending RhoPollComplete RhoPollFailed
#' @aliases RhoSerialQueue rho_serial_queue rho_enqueue
#' @aliases RhoAwaitable RhoStreamLike RhoDuplexChannel RhoTaskQueue
#' @aliases rho_task rho_rejected rho_task_from_function rho_task_from_promise
#' @aliases rho_coro_task rho_wrap_aio rho_pending rho_await rho_cancel
#' @aliases rho_then rho_catch rho_as_task rho_as_promise rho_all rho_race
#' @aliases rho_timeout
#' @aliases rho_list_stream rho_stream_from_task rho_stream_next rho_duplex_send
#' @aliases rho_stream_close rho_stream_collect rho_stream_map
#' @aliases rho_stream_flat_map rho_stream_value rho_stream_end
#' @aliases rho_poll rho_poll_pending rho_poll_complete rho_poll_failed
#' @aliases rho_is_task rho_is_stream rho_new_state
#' @aliases RhoEventPump RhoLaterEventPump RhoEventPumpResult RhoEventPumpIdle
#' @aliases RhoEventPumpProgress RhoEventPumpError RhoEventPumpUnsupported
#' @aliases RhoTaskCallbackBridge RhoTaskCallbackError
#' @aliases RhoTaskCallbackNameInUse RhoTaskCallbackRegistrationError
#' @aliases RhoTaskCallbackRemovalError rho_pump_events rho_later_event_pump
#' @aliases rho_task_callback_bridge rho_register_task_callback
#' @aliases rho_remove_task_callback
#' @export RhoTask
#' @export RhoImmediateTask
#' @export RhoRejectedTask
#' @export RhoFunctionTask
#' @export RhoNanonextAioTask
#' @export RhoPromiseTask
#' @export RhoAsyncError
#' @export RhoTimeoutError
#' @export RhoCancellation
#' @export rho_contract_violation
#' @export rho_signal_contract_violation
#' @export RhoStream
#' @export RhoDuplex
#' @export RhoListStream
#' @export RhoMappedStream
#' @export RhoFlatMappedStream
#' @export RhoTaskStream
#' @export RhoStreamItem
#' @export RhoStreamValue
#' @export RhoStreamEnd
#' @export RhoPollDecision
#' @export RhoPollPending
#' @export RhoPollComplete
#' @export RhoPollFailed
#' @export RhoSerialQueue
#' @export RhoAwaitable
#' @export RhoStreamLike
#' @export RhoDuplexChannel
#' @export RhoTaskQueue
#' @export rho_task
#' @export rho_rejected
#' @export rho_task_from_function
#' @export rho_task_from_promise
#' @export rho_coro_task
#' @export rho_wrap_aio
#' @export rho_pending
#' @export rho_await
#' @export rho_cancel
#' @export rho_then
#' @export rho_catch
#' @export rho_as_task
#' @export rho_as_promise
#' @export rho_all
#' @export rho_race
#' @export rho_timeout
#' @export rho_list_stream
#' @export rho_stream_from_task
#' @export rho_stream_next
#' @export rho_duplex_send
#' @export rho_stream_close
#' @export rho_stream_collect
#' @export rho_stream_map
#' @export rho_stream_flat_map
#' @export rho_stream_value
#' @export rho_stream_end
#' @export rho_poll
#' @export rho_poll_pending
#' @export rho_poll_complete
#' @export rho_poll_failed
#' @export rho_serial_queue
#' @export rho_enqueue
#' @export rho_is_task
#' @export rho_is_stream
#' @export rho_new_state
#' @export RhoEventPump
#' @export RhoLaterEventPump
#' @export RhoEventPumpResult
#' @export RhoEventPumpIdle
#' @export RhoEventPumpProgress
#' @export RhoEventPumpError
#' @export RhoEventPumpUnsupported
#' @export RhoTaskCallbackBridge
#' @export RhoTaskCallbackError
#' @export RhoTaskCallbackNameInUse
#' @export RhoTaskCallbackRegistrationError
#' @export RhoTaskCallbackRemovalError
#' @export rho_pump_events
#' @export rho_later_event_pump
#' @export rho_task_callback_bridge
#' @export rho_register_task_callback
#' @export rho_remove_task_callback
#' @importFrom s7contract new_interface
NULL
