rho_non_empty_string <- S7::new_property(S7::class_character, validator = function(value) {
  if (length(value) != 1L || is.na(value) || !nzchar(value)) "must be one non-empty string"
})

rho_optional_string <- S7::new_property(
  S7::class_character,
  default = "",
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) "must be one string"
  }
)

rho_scalar_string <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value)
}

rho_non_empty_scalar_string <- function(value) {
  rho_scalar_string(value) && nzchar(value)
}

rho_scalar_number <- function(value) {
  is.numeric(value) && length(value) == 1L && !is.na(value)
}

rho_valid_oauth_token_fields <- function(access, refresh, expires_in) {
  rho_non_empty_scalar_string(access) &&
    rho_non_empty_scalar_string(refresh) &&
    rho_scalar_number(expires_in) &&
    expires_in > 0
}

rho_unique_non_empty_strings <- S7::new_property(
  S7::class_character,
  default = character(),
  validator = function(value) {
    if (anyNA(value) || any(!nzchar(value))) {
      return("must contain only non-empty strings")
    }
    if (anyDuplicated(value)) "must not contain duplicates"
  }
)

rho_form_urlencode <- function(fields) {
  if (!length(fields)) {
    return("")
  }
  values <- vapply(
    fields,
    function(value) utils::URLencode(as.character(value), reserved = TRUE),
    character(1)
  )
  paste(paste(utils::URLencode(names(values), reserved = TRUE), values, sep = "="), collapse = "&")
}

rho_base64url_encode <- function(value) {
  encoded <- base64enc::base64encode(value)
  sub("=+$", "", chartr("+/", "-_", encoded))
}

rho_base64url_decode <- function(value) {
  encoded <- chartr("-_", "+/", value)
  padding <- (4L - nchar(encoded) %% 4L) %% 4L
  if (padding) {
    encoded <- paste0(encoded, strrep("=", padding))
  }
  base64enc::base64decode(encoded)
}

rho_pkce <- function() {
  verifier <- rho_base64url_encode(nanonext::random(32L, convert = FALSE))
  list(
    verifier = verifier,
    challenge = rho_base64url_encode(digest::digest(
      charToRaw(verifier),
      algo = "sha256",
      serialize = FALSE,
      raw = TRUE
    )),
    state = nanonext::random(16L)
  )
}

rho_query_fields <- function(input) {
  value <- trimws(input)
  if (!nzchar(value)) {
    return(list())
  }
  query <- if (grepl("?", value, fixed = TRUE)) {
    sub("^[^?]*\\?", "", value)
  } else {
    value
  }
  query <- sub("#.*$", "", query)
  fields <- strsplit(query, "&", fixed = TRUE)[[1L]]
  pairs <- lapply(fields, function(field) strsplit(field, "=", fixed = TRUE)[[1L]])
  names <- vapply(pairs, function(pair) utils::URLdecode(pair[[1L]]), character(1))
  values <- vapply(
    pairs,
    function(pair) utils::URLdecode(paste(pair[-1L], collapse = "=")),
    character(1)
  )
  as.list(stats::setNames(values, names))
}

rho_authorization_code <- function(input, expected_state, provider) {
  value <- trimws(input)
  parsed <- if (grepl("#", value, fixed = TRUE) && !grepl("?", value, fixed = TRUE)) {
    pieces <- strsplit(value, "#", fixed = TRUE)[[1L]]
    list(code = pieces[[1L]], state = pieces[[2L]] %||% "")
  } else if (grepl("code=", value, fixed = TRUE) || grepl("?", value, fixed = TRUE)) {
    rho_query_fields(value)
  } else {
    list(code = value, state = "")
  }
  if (nzchar(parsed$state %||% "") && !identical(parsed$state, expected_state)) {
    return(rho_auth_error(sprintf("%s authorization state mismatch", provider), code = "state"))
  }
  if (!rho_non_empty_scalar_string(parsed$code)) {
    return(rho_auth_error(
      sprintf("%s authorization code is missing", provider),
      code = "authorization_code"
    ))
  }
  parsed$code
}
