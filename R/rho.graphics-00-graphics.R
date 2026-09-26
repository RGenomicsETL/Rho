rho_graphics_non_empty_string <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty string"
    }
  }
)

RhoGraphicSpec <- S7::new_class("RhoGraphicSpec", abstract = TRUE)
RhoBaseGraphicSpec <- S7::new_class(
  "RhoBaseGraphicSpec",
  parent = RhoGraphicSpec,
  properties = list(expression = S7::class_any, data = S7::class_list)
)

RhoGraphicDeviceSpec <- S7::new_class(
  "RhoGraphicDeviceSpec",
  abstract = TRUE,
  properties = list(
    format = rho_graphics_non_empty_string,
    width = S7::class_double,
    height = S7::class_double,
    units = S7::class_character,
    dpi = S7::class_double,
    bg = S7::class_character
  )
)
RhoPngDeviceSpec <- S7::new_class(
  "RhoPngDeviceSpec",
  parent = RhoGraphicDeviceSpec
)
RhoPdfDeviceSpec <- S7::new_class(
  "RhoPdfDeviceSpec",
  parent = RhoGraphicDeviceSpec
)
RhoSvgDeviceSpec <- S7::new_class(
  "RhoSvgDeviceSpec",
  parent = RhoGraphicDeviceSpec
)

RhoGraphicBackend <- S7::new_class("RhoGraphicBackend", abstract = TRUE)
RhoMiraiGraphicBackend <- S7::new_class(
  "RhoMiraiGraphicBackend",
  parent = RhoGraphicBackend,
  properties = list(compute = S7::class_any)
)

RhoGraphicArtifact <- S7::new_class(
  "RhoGraphicArtifact",
  properties = list(
    path = rho_graphics_non_empty_string,
    format = rho_graphics_non_empty_string,
    media_type = rho_graphics_non_empty_string,
    width = S7::class_double,
    height = S7::class_double,
    units = S7::class_character,
    dpi = S7::class_double,
    sha256 = S7::class_character,
    alt = S7::class_character,
    created_at = S7::class_character,
    provenance = S7::class_list
  )
)
RhoGraphicErrorValue <- S7::new_class(
  "RhoGraphicErrorValue",
  properties = list(message = S7::class_character, source = S7::class_any)
)

rho_render_graphic <- S7::new_generic(
  "rho_render_graphic",
  c("spec", "device", "backend"),
  function(
    spec,
    device = rho_png_device(),
    backend = RhoMiraiGraphicBackend(compute = NULL),
    path = NULL,
    alt = "",
    provenance = list(),
    ...
  ) {
    S7::S7_dispatch()
  }
)
rho_open_graphic_device <- S7::new_generic(
  "rho_open_graphic_device",
  "device",
  function(device, path, ...) S7::S7_dispatch()
)
rho_graphic_media_type <- S7::new_generic(
  "rho_graphic_media_type",
  "device",
  function(device, ...) S7::S7_dispatch()
)
rho_graphic_outcome <- S7::new_generic(
  "rho_graphic_outcome",
  "value",
  function(value, ...) S7::S7_dispatch()
)

rho_base_graphic <- function(expr, data = list()) {
  RhoBaseGraphicSpec(expression = substitute(expr), data = data)
}

rho_png_device <- function(width = 7, height = 5, units = "in", dpi = 144, bg = "white") {
  RhoPngDeviceSpec(
    format = "png",
    width = as.double(width),
    height = as.double(height),
    units = units,
    dpi = as.double(dpi),
    bg = bg
  )
}

rho_pdf_device <- function(width = 7, height = 5, units = "in", bg = "white") {
  RhoPdfDeviceSpec(
    format = "pdf",
    width = as.double(width),
    height = as.double(height),
    units = units,
    dpi = NA_real_,
    bg = bg
  )
}

rho_svg_device <- function(width = 7, height = 5, units = "in", bg = "white") {
  RhoSvgDeviceSpec(
    format = "svg",
    width = as.double(width),
    height = as.double(height),
    units = units,
    dpi = NA_real_,
    bg = bg
  )
}

S7::method(rho_open_graphic_device, RhoPngDeviceSpec) <- function(device, path, ...) {
  grDevices::png(
    filename = path,
    width = device@width,
    height = device@height,
    units = device@units,
    res = device@dpi,
    bg = device@bg
  )
}

S7::method(rho_open_graphic_device, RhoPdfDeviceSpec) <- function(device, path, ...) {
  grDevices::pdf(
    file = path,
    width = device@width,
    height = device@height,
    bg = device@bg
  )
}

S7::method(rho_open_graphic_device, RhoSvgDeviceSpec) <- function(device, path, ...) {
  grDevices::svg(
    filename = path,
    width = device@width,
    height = device@height,
    bg = device@bg
  )
}

S7::method(rho_graphic_media_type, RhoPngDeviceSpec) <- function(device, ...) {
  "image/png"
}
S7::method(rho_graphic_media_type, RhoPdfDeviceSpec) <- function(device, ...) {
  "application/pdf"
}
S7::method(rho_graphic_media_type, RhoSvgDeviceSpec) <- function(device, ...) {
  "image/svg+xml"
}

rho_render_graphic_expression <- function(
  expression,
  data,
  device,
  path,
  alt,
  provenance
) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  rho_open_graphic_device(device, path)
  open <- TRUE
  on.exit(
    {
      if (open) try(grDevices::dev.off(), silent = TRUE)
    },
    add = TRUE
  )

  environment <- list2env(data, parent = globalenv())
  value <- eval(expression, envir = environment)
  if (inherits(value, "ggplot")) {
    print(value)
  }

  grDevices::dev.off()
  open <- FALSE
  if (!file.exists(path)) {
    return(RhoGraphicErrorValue(
      message = sprintf("Graphics device did not create artifact: %s", path),
      source = list(path = path, device = device)
    ))
  }

  RhoGraphicArtifact(
    path = path,
    format = device@format,
    media_type = rho_graphic_media_type(device),
    width = device@width,
    height = device@height,
    units = device@units,
    dpi = device@dpi,
    sha256 = digest::digest(file = path, algo = "sha256"),
    alt = alt,
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"),
    provenance = provenance
  )
}

S7::method(
  rho_render_graphic,
  list(RhoBaseGraphicSpec, RhoGraphicDeviceSpec, RhoMiraiGraphicBackend)
) <- function(
  spec,
  device,
  backend,
  path = NULL,
  alt = "",
  provenance = list(),
  ...
) {
  if (is.null(path)) {
    path <- tempfile(fileext = paste0(".", device@format))
  }
  task <- rho_mirai_call(
    rho_render_graphic_expression,
    args = list(
      expression = spec@expression,
      data = spec@data,
      device = device,
      path = path,
      alt = alt,
      provenance = provenance
    ),
    compute = backend@compute
  )
  rho_then(task, rho_graphic_outcome)
}

S7::method(rho_graphic_outcome, RhoGraphicArtifact) <- function(value, ...) value
S7::method(rho_graphic_outcome, RhoGraphicErrorValue) <- function(value, ...) value
S7::method(rho_graphic_outcome, RhoComputeErrorValue) <- function(value, ...) {
  RhoGraphicErrorValue(message = value@message, source = value)
}
