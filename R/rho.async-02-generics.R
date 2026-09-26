rho_pending <- S7::new_generic("rho_pending", "x", function(x, ...) S7::S7_dispatch())
rho_await <- S7::new_generic("rho_await", "x", function(x, timeout = NULL, ...) S7::S7_dispatch())
rho_cancel <- S7::new_generic("rho_cancel", "x", function(x, reason = NULL, ...) S7::S7_dispatch())
rho_then <- S7::new_generic("rho_then", "x", function(x, on_fulfilled, on_rejected = NULL, ...) {
  S7::S7_dispatch()
})
rho_catch <- S7::new_generic("rho_catch", "x", function(x, on_rejected, ...) S7::S7_dispatch())
rho_as_task <- S7::new_generic("rho_as_task", "x", function(x, ...) S7::S7_dispatch())
rho_as_promise <- S7::new_generic("rho_as_promise", "x", function(x, ...) S7::S7_dispatch())

rho_enqueue <- S7::new_generic(
  "rho_enqueue",
  "queue",
  function(queue, action, label = NULL, ...) S7::S7_dispatch()
)

rho_stream_next <- S7::new_generic(
  "rho_stream_next",
  "stream",
  function(stream, timeout = NULL, ...) S7::S7_dispatch()
)
rho_stream_close <- S7::new_generic("rho_stream_close", "stream", function(stream, ...) {
  S7::S7_dispatch()
})
rho_duplex_send <- S7::new_generic(
  "rho_duplex_send",
  "duplex",
  function(duplex, value, timeout = NULL, ...) S7::S7_dispatch()
)
rho_stream_collect <- S7::new_generic(
  "rho_stream_collect",
  "stream",
  function(stream, limit = Inf, timeout = NULL, ...) S7::S7_dispatch()
)
rho_stream_map <- S7::new_generic("rho_stream_map", "stream", function(stream, f, ...) {
  S7::S7_dispatch()
})
rho_stream_flat_map <- S7::new_generic("rho_stream_flat_map", "stream", function(stream, f, ...) {
  S7::S7_dispatch()
})
