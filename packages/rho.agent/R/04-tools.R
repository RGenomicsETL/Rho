rho_tool_calls <- function(message) {
  Filter(
    function(content) S7::S7_inherits(content, rho.ai::ToolCall),
    message@content
  )
}

rho_agent_tool <- function(agent, name) {
  agent@state$tools[[name]]
}

rho_error_tool_result <- function(message) {
  rho.ai::rho_tool_error_result(
    content = list(rho.ai::rho_text(message)),
    details = list(error = rho_agent_error(message, "tool_execution"))
  )
}

rho_message_from_tool_result <- function(call, result, is_error) {
  rho.ai::rho_tool_result_message(
    tool_call_id = call@id,
    tool_name = call@name,
    content = result@content,
    details = result@details,
    is_error = is_error,
    terminate = result@terminate,
    added_tool_names = result@added_tool_names
  )
}

rho_emit_tool_result_message <- function(agent, message) {
  rho.async::rho_then(
    rho_emit_agent_event(agent, rho_message_start_event(message)),
    function(ignored) rho_emit_agent_event(agent, rho_message_end_event(message))
  )
}

rho_finish_tool_call <- function(agent, call, result, is_error) {
  rho.async::rho_then(
    rho_emit_agent_event(
      agent,
      rho_tool_execution_end_event(call, result, is_error)
    ),
    function(ignored) rho_message_from_tool_result(call, result, is_error)
  )
}

rho_fail_tool_call <- function(agent, call, message) {
  rho_finish_tool_call(agent, call, rho_error_tool_result(message), TRUE)
}

rho_schedule_tool_call <- function(
  agent,
  assistant,
  call,
  run_context,
  model_context
) {
  rho.async::rho_coro_task(
    function() {
      fail <- function(tool_call, message) {
        rho.async::rho_as_promise(rho_fail_tool_call(
          agent,
          tool_call,
          message
        ))
      }
      coro::await(rho.async::rho_as_promise(
        rho_emit_agent_event(agent, rho_tool_execution_start_event(call))
      ))
      if (isTRUE(agent@state$cancelled)) {
        failure <- coro::await(fail(
          call,
          rho_agent_cancel_message(agent, "Tool execution was cancelled")
        ))
        return(failure)
      }

      tool <- rho_agent_tool(agent, call@name)
      if (is.null(tool)) {
        failure <- coro::await(fail(
          call,
          sprintf("Tool %s not found", call@name)
        ))
        return(failure)
      }

      args <- tryCatch(
        rho.ai::rho_validate_tool_args(tool, call@arguments),
        error = function(error) error
      )
      if (inherits(args, "error")) {
        failure <- coro::await(fail(call, conditionMessage(args)))
        return(failure)
      }
      if (S7::S7_inherits(args, rho.ai::ToolErrorResult)) {
        failure <- coro::await(rho.async::rho_as_promise(rho_finish_tool_call(
          agent,
          call,
          args,
          TRUE
        )))
        return(failure)
      }

      prepared_call <- rho.ai::ToolCall(
        id = call@id,
        name = call@name,
        arguments = args,
        arguments_prepared = TRUE
      )
      updates <- new.env(parent = emptyenv())
      updates$tasks <- list()
      context <- rho_tool_context(
        run_context,
        tool,
        prepared_call,
        assistant = assistant,
        model_context = model_context,
        on_update = function(partial_result) {
          updates$tasks[[length(updates$tasks) + 1L]] <- rho_emit_agent_event(
            agent,
            rho_tool_execution_update_event(prepared_call, partial_result)
          )
        }
      )

      decision <- tryCatch(
        coro::await(rho.async::rho_as_promise(rho_before_tool_call(
          agent@options@policy,
          context
        ))),
        error = function(error) error
      )
      if (inherits(decision, "error")) {
        failure <- coro::await(fail(call, conditionMessage(decision)))
        return(failure)
      }
      if (!S7::S7_inherits(decision, RhoBeforeToolCallDecision)) {
        failure <- coro::await(fail(
          call,
          "before-tool policy returned an invalid decision"
        ))
        return(failure)
      }
      if (decision@block) {
        if (nzchar(decision@reason)) {
          reason <- decision@reason
        } else {
          reason <- "Tool execution was blocked without a policy reason"
        }
        failure <- coro::await(fail(call, reason))
        return(failure)
      }
      if (isTRUE(agent@state$cancelled)) {
        failure <- coro::await(fail(
          prepared_call,
          rho_agent_cancel_message(agent, "Tool execution was cancelled")
        ))
        return(failure)
      }

      tool_task <- tryCatch(
        rho.ai::rho_execute_tool(
          tool,
          prepared_call,
          context = context,
          signal = context@signal,
          on_update = context@on_update
        ),
        error = function(error) error
      )
      if (inherits(tool_task, "error")) {
        failure <- coro::await(fail(prepared_call, conditionMessage(tool_task)))
        return(failure)
      }
      agent@state$active_tool_sequence <- agent@state$active_tool_sequence + 1L
      active_id <- as.character(agent@state$active_tool_sequence)
      agent@state$active_tool_tasks[[active_id]] <- tool_task
      on.exit(
        {
          agent@state$active_tool_tasks[[active_id]] <- NULL
        },
        add = TRUE
      )

      result <- tryCatch(
        coro::await(rho.async::rho_as_promise(tool_task)),
        error = function(error) error
      )
      for (update_task in updates$tasks) {
        coro::await(rho.async::rho_as_promise(update_task))
      }
      if (inherits(result, "error")) {
        failure <- coro::await(fail(prepared_call, conditionMessage(result)))
        return(failure)
      }
      if (S7::S7_inherits(result, rho.async::RhoCancellation)) {
        failure <- coro::await(fail(prepared_call, result@message))
        return(failure)
      }
      if (!S7::S7_inherits(result, rho.ai::ToolResult)) {
        failure <- coro::await(fail(
          prepared_call,
          "Tool did not return a ToolResult value"
        ))
        return(failure)
      }

      result_is_error <- S7::S7_inherits(result, rho.ai::ToolErrorResult)
      completed_context <- rho_completed_tool_context(
        context,
        result,
        result_is_error
      )
      after <- tryCatch(
        coro::await(rho.async::rho_as_promise(rho_after_tool_call(
          agent@options@policy,
          completed_context
        ))),
        error = function(error) error
      )
      if (inherits(after, "error")) {
        failure <- coro::await(fail(prepared_call, conditionMessage(after)))
        return(failure)
      }
      if (!S7::S7_inherits(after, RhoAfterToolCallDecision)) {
        failure <- coro::await(fail(
          prepared_call,
          "after-tool policy returned an invalid decision"
        ))
        return(failure)
      }
      coro::await(rho.async::rho_as_promise(rho_finish_tool_call(
        agent,
        prepared_call,
        after@result,
        after@is_error
      )))
    },
    label = paste0("tool-", call@name)
  )
}

S7::method(
  rho_resolve_tool_execution,
  list(RhoToolExecutionMode, rho.ai::ToolOverlap)
) <- function(mode, overlap, ...) {
  mode
}

S7::method(
  rho_resolve_tool_execution,
  list(RhoParallelToolExecution, rho.ai::ToolRequiresExclusiveExecution)
) <- function(mode, overlap, ...) {
  RhoSequentialToolExecution()
}

rho_tool_batch_execution <- function(
  mode,
  agent,
  assistant,
  calls,
  run_context,
  model_context
) {
  for (call in calls) {
    tool <- rho_agent_tool(agent, call@name)
    if (is.null(tool)) {
      next
    }
    context <- rho_tool_context(
      run_context,
      tool,
      call,
      assistant = assistant,
      model_context = model_context
    )
    overlap <- rho.ai::rho_tool_overlap(tool, call, context = context)
    mode <- rho_resolve_tool_execution(mode, overlap)
  }
  mode
}

rho_tool_batch <- function(messages) {
  terminate <- length(messages) > 0L &&
    all(vapply(
      messages,
      function(message) isTRUE(message@terminate),
      logical(1)
    ))
  RhoToolBatch(messages = messages, terminate = terminate)
}

S7::method(
  rho_execute_tool_batch,
  RhoToolExecutionMode
) <- function(mode, agent, assistant, run_context, model_context, calls, ...) {
  rho.async::rho_coro_task(
    function() {
      messages <- vector("list", length(calls))
      for (index in seq_along(calls)) {
        message <- coro::await(rho.async::rho_as_promise(
          rho_schedule_tool_call(
            agent,
            assistant,
            calls[[index]],
            run_context,
            model_context
          )
        ))
        messages[[index]] <- message
        coro::await(rho.async::rho_as_promise(
          rho_emit_tool_result_message(agent, message)
        ))
      }
      rho_tool_batch(messages)
    },
    label = "sequential-tool-batch"
  )
}

S7::method(
  rho_execute_tool_batch,
  RhoParallelToolExecution
) <- function(mode, agent, assistant, run_context, model_context, calls, ...) {
  rho.async::rho_coro_task(
    function() {
      tasks <- lapply(
        calls,
        function(call) {
          rho_schedule_tool_call(
            agent,
            assistant,
            call,
            run_context,
            model_context
          )
        }
      )
      messages <- coro::await(rho.async::rho_as_promise(rho.async::rho_all(tasks)))
      for (message in messages) {
        coro::await(rho.async::rho_as_promise(
          rho_emit_tool_result_message(agent, message)
        ))
      }
      rho_tool_batch(messages)
    },
    label = "parallel-tool-batch"
  )
}

rho_fail_truncated_tool_calls <- function(agent, calls) {
  rho.async::rho_coro_task(
    function() {
      messages <- vector("list", length(calls))
      for (index in seq_along(calls)) {
        call <- calls[[index]]
        coro::await(rho.async::rho_as_promise(
          rho_emit_agent_event(agent, rho_tool_execution_start_event(call))
        ))
        message <- coro::await(rho.async::rho_as_promise(rho_fail_tool_call(
          agent,
          call,
          sprintf(
            "Tool call %s was not executed because its arguments may be truncated after an output-token limit",
            call@name
          )
        )))
        messages[[index]] <- message
        coro::await(rho.async::rho_as_promise(
          rho_emit_tool_result_message(agent, message)
        ))
      }
      rho_tool_batch(messages)
    },
    label = "truncated-tool-batch"
  )
}

rho_execute_assistant_tools <- function(
  agent,
  assistant,
  run_context,
  model_context
) {
  calls <- rho_tool_calls(assistant)
  if (!length(calls)) {
    return(rho.async::rho_task(rho_tool_batch(list())))
  }
  agent@state$pending_tool_calls <- vapply(calls, function(call) call@id, character(1))

  task <- if (identical(assistant@stop_reason, "length")) {
    rho_fail_truncated_tool_calls(agent, calls)
  } else {
    mode <- rho_tool_batch_execution(
      agent@options@tool_execution,
      agent,
      assistant,
      calls,
      run_context,
      model_context
    )
    rho_execute_tool_batch(
      mode,
      agent,
      assistant,
      run_context,
      model_context,
      calls
    )
  }

  rho.async::rho_then(
    task,
    function(batch) {
      agent@state$pending_tool_calls <- character()
      batch
    },
    function(error) {
      agent@state$pending_tool_calls <- character()
      rho.async::rho_rejected(error)
    }
  )
}
