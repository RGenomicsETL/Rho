rho_bio_new_state <- function(...) {
  state <- new.env(parent = emptyenv())
  values <- list(...)
  for (name in names(values)) {
    assign(name, values[[name]], state)
  }
  state
}

rho_bio_non_empty_string <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty string"
    }
  }
)

rho_strict_keys <- function(x, allowed, label) {
  extra <- setdiff(names(x), allowed)
  if (length(extra)) {
    sprintf("%s has unknown key(s): %s", label, paste(extra, collapse = ", "))
  } else {
    character()
  }
}

rho_canonical_json <- function(x) {
  yyjsonr::write_json_str(x, auto_unbox = TRUE, null = "null", digits = -1L)
}
