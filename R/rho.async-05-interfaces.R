RhoAwaitable <- s7contract::new_interface("RhoAwaitable", generics = list(rho_await = rho_await))
RhoStreamLike <- s7contract::new_interface(
  "RhoStreamLike",
  generics = list(rho_stream_next = rho_stream_next)
)
RhoDuplexChannel <- s7contract::new_interface(
  "RhoDuplexChannel",
  generics = list(
    rho_stream_next = rho_stream_next,
    rho_duplex_send = s7contract::interface_requirement(
      rho_duplex_send,
      returns = RhoTask
    )
  )
)
RhoTaskQueue <- s7contract::new_interface(
  "RhoTaskQueue",
  generics = list(rho_enqueue = rho_enqueue)
)
