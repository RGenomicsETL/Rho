rho_r_code <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty R expression"
    }
  }
)

RhoRExpression <- S7::new_class(
  "RhoRExpression",
  parent = RhoOperation,
  properties = list(code = rho_r_code)
)

RhoREvaluator <- S7::new_class("RhoREvaluator", abstract = TRUE)
RhoCurrentSessionREvaluator <- S7::new_class(
  "RhoCurrentSessionREvaluator",
  parent = RhoREvaluator,
  properties = list(environment = S7::class_environment)
)
RhoMiraiExpressionEvaluator <- S7::new_class(
  "RhoMiraiExpressionEvaluator",
  parent = RhoREvaluator,
  properties = list(compute = S7::class_any)
)
RhoREvaluationBinding <- S7::new_class(
  "RhoREvaluationBinding",
  parent = RhoOperationBinding
)

RhoREvaluationOutcome <- S7::new_class("RhoREvaluationOutcome", abstract = TRUE)
RhoREvaluationSuccess <- S7::new_class(
  "RhoREvaluationSuccess",
  parent = RhoREvaluationOutcome,
  properties = list(
    value = S7::class_any,
    output = S7::class_character,
    visible = S7::class_logical
  )
)
RhoREvaluationFailure <- S7::new_class(
  "RhoREvaluationFailure",
  parent = RhoREvaluationOutcome,
  properties = list(
    message = S7::class_character,
    output = S7::class_character,
    source = S7::class_any
  )
)

rho_evaluate_r <- S7::new_generic(
  "rho_evaluate_r",
  c("evaluator", "expression"),
  function(evaluator, expression, ...) S7::S7_dispatch()
)
rho_r_evaluation_outcome <- S7::new_generic(
  "rho_r_evaluation_outcome",
  "value",
  function(value, ...) S7::S7_dispatch()
)
rho_r_tool_result <- S7::new_generic(
  "rho_r_tool_result",
  "outcome",
  function(outcome, expression, ...) S7::S7_dispatch()
)
rho_r_evaluator_overlap <- S7::new_generic(
  "rho_r_evaluator_overlap",
  "evaluator",
  function(evaluator, ...) S7::S7_dispatch()
)
rho_r_evaluator_reason <- S7::new_generic(
  "rho_r_evaluator_reason",
  "evaluator",
  function(evaluator, ...) S7::S7_dispatch()
)

rho_r_evaluation_binding <- function(evaluator, expression) {
  RhoREvaluationBinding(
    operation = expression,
    handler = evaluator,
    reason = rho_r_evaluator_reason(evaluator)
  )
}

rho_evaluate_r_code <- function(code, environment) {
  parsed <- parse(text = code, keep.source = FALSE)
  evaluated <- withVisible(NULL)
  output <- capture.output({
    for (expression in parsed) {
      evaluated <- withVisible(eval(expression, envir = environment))
      if (evaluated$visible) print(evaluated$value)
    }
  })
  list(
    value = evaluated$value,
    output = paste(output, collapse = "\n"),
    visible = evaluated$visible
  )
}

S7::method(
  rho_evaluate_r,
  list(RhoCurrentSessionREvaluator, RhoRExpression)
) <- function(evaluator, expression, ...) {
  rho_task_from_function(
    function() {
      value <- tryCatch(
        rho_evaluate_r_code(expression@code, evaluator@environment),
        error = function(error) {
          RhoREvaluationFailure(
            message = conditionMessage(error),
            output = "",
            source = error
          )
        }
      )
      rho_r_evaluation_outcome(value)
    },
    label = "current-session-r-evaluation"
  )
}

S7::method(
  rho_bind_operation,
  list(RhoREvaluator, Model, RhoRExpression)
) <- function(handler, model, operation, context, ...) {
  rho_r_evaluation_binding(handler, operation)
}

S7::method(
  rho_execute_operation,
  RhoREvaluationBinding
) <- function(binding, context, ...) {
  rho_evaluate_r(binding@handler, binding@operation)
}

S7::method(
  rho_evaluate_r,
  list(RhoMiraiExpressionEvaluator, RhoRExpression)
) <- function(evaluator, expression, ...) {
  worker <- function(code, evaluate_code) {
    evaluation_environment <- new.env(parent = globalenv())
    evaluate_code(code, evaluation_environment)
  }
  task <- rho_mirai_call(
    worker,
    args = list(
      code = expression@code,
      evaluate_code = rho_evaluate_r_code
    ),
    compute = evaluator@compute
  )
  rho_then(task, rho_r_evaluation_outcome)
}

S7::method(rho_r_evaluation_outcome, S7::class_list) <- function(value, ...) {
  required <- c("value", "output", "visible")
  if (!all(required %in% names(value))) {
    return(RhoREvaluationFailure(
      message = "The R evaluator returned an invalid result",
      output = "",
      source = value
    ))
  }
  RhoREvaluationSuccess(
    value = value$value,
    output = value$output,
    visible = isTRUE(value$visible)
  )
}

S7::method(rho_r_evaluation_outcome, RhoComputeErrorValue) <- function(value, ...) {
  RhoREvaluationFailure(message = value@message, output = "", source = value)
}

S7::method(rho_r_evaluation_outcome, RhoREvaluationOutcome) <- function(value, ...) {
  value
}

S7::method(rho_r_tool_result, RhoREvaluationSuccess) <- function(outcome, expression, ...) {
  text <- if (nzchar(outcome@output)) outcome@output else "(invisible result)"
  rho_tool_result(
    list(rho_text(text)),
    details = list(
      expression = expression@code,
      value = outcome@value,
      visible = outcome@visible
    )
  )
}

S7::method(rho_r_tool_result, RhoREvaluationFailure) <- function(outcome, expression, ...) {
  rho_tool_error_result(
    list(rho_text(outcome@message)),
    details = list(expression = expression@code, evaluation_failure = outcome)
  )
}

S7::method(rho_r_evaluator_overlap, RhoCurrentSessionREvaluator) <- function(evaluator, ...) {
  ToolRequiresExclusiveExecution()
}

S7::method(rho_r_evaluator_reason, RhoCurrentSessionREvaluator) <- function(
  evaluator,
  ...
) {
  "The tool author selected explicit mutation of the supplied R environment"
}

S7::method(rho_r_evaluator_overlap, RhoMiraiExpressionEvaluator) <- function(evaluator, ...) {
  ToolMayOverlap()
}

S7::method(rho_r_evaluator_reason, RhoMiraiExpressionEvaluator) <- function(
  evaluator,
  ...
) {
  "The tool author selected isolated evaluation in a mirai worker"
}

rho_tool_r <- function(evaluator = RhoMiraiExpressionEvaluator(compute = NULL)) {
  rho_tool_spec(
    name = "r",
    label = "R",
    description = paste(
      "Evaluate R code using the configured evaluator.",
      "The returned content is the visible console value; structured value is retained in details."
    ),
    parameters = list(
      type = "object",
      properties = list(code = list(type = "string")),
      required = "code"
    ),
    overlap = rho_r_evaluator_overlap(evaluator),
    execute = function(tool_call_id, params, signal, on_update, ctx) {
      expression <- RhoRExpression(code = params$code)
      binding <- rho_r_evaluation_binding(evaluator, expression)
      rho_then(
        rho_execute_operation(binding, ctx),
        function(outcome) rho_r_tool_result(outcome, expression)
      )
    }
  )
}
