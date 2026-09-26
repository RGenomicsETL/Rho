rho_normalize_http_headers <- function(headers) {
  if (is.null(headers) || !length(headers)) {
    return(NULL)
  }
  unlist(headers, use.names = TRUE)
}

rho_encode_http_body <- function(body, headers) {
  if (is.null(body)) {
    return(list(data = NULL, headers = headers))
  }
  if (is.raw(body) || is.character(body)) {
    return(list(data = body, headers = headers))
  }
  if (is.list(body)) {
    if (!any(tolower(names(headers %||% character())) == "content-type")) {
      headers <- c(headers %||% character(), `Content-Type` = "application/json")
    }
    return(list(
      data = yyjsonr::write_json_str(body, auto_unbox = TRUE, null = "null"),
      headers = headers
    ))
  }
  rho_signal_contract_violation(
    "A RhoHttpRequest body escaped its S7 property validation"
  )
}
