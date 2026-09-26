rho_catalog_profile <- function(
  source = "",
  provider,
  protocol,
  validate_source = function(source) invisible(source),
  evidence = function(model, inputs) NULL,
  include = function(model, evidence) TRUE,
  resolve_protocol = function(model, evidence, declared) declared,
  capabilities = function(model, protocol, evidence) list(),
  transports = function(model, protocol, evidence) "sse",
  record_source = function(model, evidence) "models.dev",
  transform = function(record, model, evidence) record
) {
  provider_expression <- substitute(provider)
  protocol_expression <- substitute(protocol)
  if (!is.call(provider_expression)) {
    stop("A catalog profile provider must be an R constructor call", call. = FALSE)
  }
  if (!is.call(protocol_expression)) {
    stop("A catalog profile protocol must be an R constructor call", call. = FALSE)
  }
  list(
    source = source,
    provider = provider_expression,
    protocol = protocol_expression,
    validate_source = validate_source,
    evidence = evidence,
    include = include,
    resolve_protocol = resolve_protocol,
    capabilities = capabilities,
    transports = transports,
    record_source = record_source,
    transform = transform
  )
}

rho_catalog_source_contract <- function(api = NULL, package = NULL) {
  force(api)
  force(package)
  function(source) {
    if (!is.null(api) && !identical(source$api, api)) {
      stop(
        sprintf(
          "Catalog source %s declares API %s; expected %s",
          source$id,
          source$api %||% "<missing>",
          api
        ),
        call. = FALSE
      )
    }
    if (!is.null(package) && !identical(source$package, package)) {
      stop(
        sprintf(
          "Catalog source %s declares adapter %s; expected %s",
          source$id,
          source$package %||% "<missing>",
          package
        ),
        call. = FALSE
      )
    }
    invisible(source)
  }
}

rho_catalog_call_argument <- function(expression, name) {
  arguments <- as.list(expression)[-1L]
  position <- match(name, names(arguments))
  if (is.na(position)) {
    stop(
      sprintf("Catalog constructor %s must declare `%s`", expression[[1L]], name),
      call. = FALSE
    )
  }
  arguments[[position]]
}

rho_catalog_profile_provider_id <- function(profile) {
  id <- rho_catalog_call_argument(profile$provider, "id")
  if (!is.character(id) || length(id) != 1L || is.na(id) || !nzchar(id)) {
    stop("A catalog provider constructor must declare a literal non-empty `id`", call. = FALSE)
  }
  id
}

rho_catalog_registry_source_ids <- function(registry) {
  sources <- vapply(registry, function(profile) profile$source, character(1))
  sort(unique(sources[nzchar(sources)]))
}

rho_model_registry <- list(
  openai = rho_catalog_profile(
    source = "openai",
    provider = OpenAIModelCatalogProvider(
      id = "openai",
      name = "OpenAI",
      base_url = "https://api.openai.com/v1"
    ),
    protocol = OpenAIResponsesProtocol()
  ),
  anthropic = rho_catalog_profile(
    source = "anthropic",
    provider = AnthropicModelCatalogProvider(
      id = "anthropic",
      name = "Anthropic",
      base_url = "https://api.anthropic.com"
    ),
    protocol = AnthropicMessagesProtocol(),
    capabilities = function(model, protocol, evidence) {
      rho_anthropic_provider_capabilities(model)
    }
  ),
  `github-copilot` = rho_catalog_profile(
    source = "github-copilot",
    provider = GitHubCopilotModelCatalogProvider(
      id = "github-copilot",
      name = "GitHub Copilot",
      base_url = "https://api.individual.githubcopilot.com"
    ),
    protocol = OpenAIResponsesProtocol(),
    evidence = function(model, inputs) {
      descriptor <- inputs$github_copilot$models[[model$id]]
      if (is.null(descriptor)) {
        stop(
          sprintf("GitHub Copilot endpoint snapshot has no model %s", model$id),
          call. = FALSE
        )
      }
      descriptor
    },
    include = function(model, evidence) {
      !is.null(evidence) && isTRUE(evidence$observed) && length(evidence$supported_endpoints)
    },
    resolve_protocol = function(model, evidence, declared) {
      rho_copilot_protocol(evidence)
    },
    capabilities = function(model, protocol, evidence) {
      if (identical(protocol[[1L]], quote(AnthropicMessagesProtocol))) {
        rho_anthropic_provider_capabilities(model)
      } else {
        list()
      }
    },
    transports = function(model, protocol, evidence) {
      rho_copilot_transports(evidence, protocol)
    },
    record_source = function(model, evidence) "github-copilot"
  ),
  zai = rho_catalog_profile(
    source = "zai-coding-plan",
    provider = ZaiModelCatalogProvider(
      id = "zai",
      name = "Z.ai Coding Plan",
      base_url = "https://api.z.ai/api/coding/paas/v4",
      preserve_thinking = TRUE
    ),
    protocol = OpenAIChatCompletionsProtocol()
  ),
  `zai-coding-cn` = rho_catalog_profile(
    source = "zai-coding-plan",
    provider = ZaiModelCatalogProvider(
      id = "zai-coding-cn",
      name = "Z.ai Coding Plan China",
      base_url = "https://open.bigmodel.cn/api/coding/paas/v4",
      preserve_thinking = TRUE
    ),
    protocol = OpenAIChatCompletionsProtocol()
  ),
  `kimi-coding` = rho_catalog_profile(
    source = "kimi-for-coding",
    provider = KimiCodeModelCatalogProvider(
      id = "kimi-coding",
      name = "Kimi Code",
      base_url = "https://api.kimi.com/coding"
    ),
    protocol = AnthropicMessagesProtocol(),
    validate_source = rho_catalog_source_contract(
      api = "https://api.kimi.com/coding/v1",
      package = "@ai-sdk/anthropic"
    ),
    capabilities = function(model, protocol, evidence) {
      rho_kimi_code_provider_capabilities(model)
    }
  ),
  moonshotai = rho_catalog_profile(
    source = "moonshotai",
    provider = KimiPlatformModelCatalogProvider(
      id = "moonshotai",
      name = "Moonshot AI",
      base_url = "https://api.moonshot.ai/v1"
    ),
    protocol = OpenAIChatCompletionsProtocol(),
    validate_source = rho_catalog_source_contract(
      api = "https://api.moonshot.ai/v1",
      package = "@ai-sdk/openai-compatible"
    )
  ),
  `moonshotai-cn` = rho_catalog_profile(
    source = "moonshotai-cn",
    provider = KimiPlatformModelCatalogProvider(
      id = "moonshotai-cn",
      name = "Moonshot AI (China)",
      base_url = "https://api.moonshot.cn/v1"
    ),
    protocol = OpenAIChatCompletionsProtocol(),
    validate_source = rho_catalog_source_contract(
      api = "https://api.moonshot.cn/v1",
      package = "@ai-sdk/openai-compatible"
    )
  ),
  `openai-codex` = rho_catalog_profile(
    provider = OpenAICodexModelCatalogProvider(
      id = "openai-codex",
      name = "OpenAI Codex",
      base_url = "https://chatgpt.com/backend-api"
    ),
    protocol = OpenAIResponsesProtocol()
  )
)

for (profile_name in names(rho_model_registry)) {
  profile_id <- rho_catalog_profile_provider_id(rho_model_registry[[profile_name]])
  if (!identical(profile_name, profile_id)) {
    stop(
      sprintf(
        "Catalog profile `%s` constructs provider `%s`; these names must match",
        profile_name,
        profile_id
      ),
      call. = FALSE
    )
  }
}
