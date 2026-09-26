#' Graphic specifications, devices, and artifacts
#'
#' Graphics are rendered from an explicit specification to an explicit device.
#' [rho_render_graphic()] returns a task resolving to `RhoGraphicArtifact` or a
#' typed `RhoGraphicErrorValue`. The mirai backend closes the graphics device
#' before hashing the resulting file.
#'
#' Device and backend behavior are S7 generics so extension packages may add
#' formats and renderers without changing this package.
#'
#' @name rho_graphics_contracts
#' @aliases RhoGraphicSpec RhoBaseGraphicSpec RhoGraphicDeviceSpec
#' @aliases RhoPngDeviceSpec RhoPdfDeviceSpec RhoSvgDeviceSpec
#' @aliases RhoGraphicBackend RhoMiraiGraphicBackend RhoGraphicArtifact
#' @aliases RhoGraphicErrorValue rho_base_graphic rho_png_device rho_pdf_device
#' @aliases rho_svg_device rho_render_graphic rho_open_graphic_device
#' @aliases rho_graphic_media_type rho_graphic_outcome
#' @export RhoGraphicSpec
#' @export RhoBaseGraphicSpec
#' @export RhoGraphicDeviceSpec
#' @export RhoPngDeviceSpec
#' @export RhoPdfDeviceSpec
#' @export RhoSvgDeviceSpec
#' @export RhoGraphicBackend
#' @export RhoMiraiGraphicBackend
#' @export RhoGraphicArtifact
#' @export RhoGraphicErrorValue
#' @export rho_base_graphic
#' @export rho_png_device
#' @export rho_pdf_device
#' @export rho_svg_device
#' @export rho_render_graphic
#' @export rho_open_graphic_device
#' @export rho_graphic_media_type
#' @export rho_graphic_outcome
NULL
