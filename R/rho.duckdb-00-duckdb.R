rho_non_empty_sql <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(trimws(value))) {
      "must be one non-empty string"
    }
  }
)

RhoSqlStatement <- S7::new_class(
  "RhoSqlStatement",
  properties = list(sql = rho_non_empty_sql)
)

RhoSqlGuard <- S7::new_class("RhoSqlGuard", abstract = TRUE)
RhoConservativeSqlGuard <- S7::new_class(
  "RhoConservativeSqlGuard",
  parent = RhoSqlGuard
)

RhoSqlGuardResult <- S7::new_class("RhoSqlGuardResult", abstract = TRUE)
RhoSqlAccepted <- S7::new_class(
  "RhoSqlAccepted",
  parent = RhoSqlGuardResult,
  properties = list(statement = RhoSqlStatement)
)
RhoSqlRejected <- S7::new_class(
  "RhoSqlRejected",
  parent = RhoSqlGuardResult,
  properties = list(
    statement = RhoSqlStatement,
    message = rho_non_empty_sql
  )
)

RhoDuckDbErrorValue <- S7::new_class(
  "RhoDuckDbErrorValue",
  properties = list(message = rho_non_empty_sql, source = S7::class_any)
)

RhoDuckDbConn <- S7::new_class(
  "RhoDuckDbConn",
  properties = list(conn = S7::class_any, guard = RhoSqlGuard)
)

rho_sql_guard <- S7::new_generic(
  "rho_sql_guard",
  c("guard", "statement"),
  function(guard, statement, ...) S7::S7_dispatch()
)

S7::method(
  rho_sql_guard,
  list(RhoConservativeSqlGuard, RhoSqlStatement)
) <- function(guard, statement, ...) {
  text <- trimws(statement@sql)
  first <- tolower(strsplit(text, "\\s+")[[1L]][[1L]])
  allowed <- c("select", "with", "describe", "pragma", "explain")
  if (!first %in% allowed) {
    return(RhoSqlRejected(
      statement = statement,
      message = sprintf(
        "SQL must be read-only; got statement starting with '%s'",
        first
      )
    ))
  }
  forbidden <- "\\b(insert|update|delete|merge|create|drop|alter|copy|attach|detach|install|load)\\b"
  if (grepl(forbidden, tolower(text), perl = TRUE)) {
    return(RhoSqlRejected(
      statement = statement,
      message = "SQL contains a forbidden write, DDL, or extension keyword"
    ))
  }
  RhoSqlAccepted(statement = statement)
}

rho_check_readonly_sql <- function(sql, guard = RhoConservativeSqlGuard()) {
  rho_sql_guard(guard, RhoSqlStatement(sql = sql))
}

rho_duckdb_connect <- function(
  path = ":memory:",
  read_only = FALSE,
  guard = RhoConservativeSqlGuard(),
  ...
) {
  if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("duckdb", quietly = TRUE)) {
    stop("Packages 'DBI' and 'duckdb' are required for the DuckDB backend", call. = FALSE)
  }
  conn <- DBI::dbConnect(duckdb::duckdb(), dbdir = path, read_only = read_only, ...)
  RhoDuckDbConn(conn = conn, guard = guard)
}

rho_duckdb_disconnect <- function(conn, shutdown = TRUE) {
  DBI::dbDisconnect(conn@conn, shutdown = shutdown)
  invisible(TRUE)
}

rho_duckdb_query <- function(conn, sql, params) {
  decision <- rho_check_readonly_sql(sql, conn@guard)
  if (S7::S7_inherits(decision, RhoSqlRejected)) {
    return(decision)
  }
  tryCatch(
    DBI::dbGetQuery(conn@conn, decision@statement@sql, params = params),
    error = function(error) {
      RhoDuckDbErrorValue(message = conditionMessage(error), source = error)
    }
  )
}

rho_duckdb_execute <- function(conn, sql, params) {
  decision <- rho_check_readonly_sql(sql, conn@guard)
  if (S7::S7_inherits(decision, RhoSqlRejected)) {
    return(decision)
  }
  tryCatch(
    {
      DBI::dbExecute(conn@conn, decision@statement@sql, params = params)
      NULL
    },
    error = function(error) {
      RhoDuckDbErrorValue(message = conditionMessage(error), source = error)
    }
  )
}

S7::method(rho_sql_all, RhoDuckDbConn) <- function(conn, sql, params = list(), ...) {
  rho_task_from_function(
    function() rho_duckdb_query(conn, sql, params),
    label = "duckdb-query"
  )
}

S7::method(rho_sql_run, RhoDuckDbConn) <- function(conn, sql, params = list(), ...) {
  rho_task_from_function(
    function() rho_duckdb_execute(conn, sql, params),
    label = "duckdb-run"
  )
}
