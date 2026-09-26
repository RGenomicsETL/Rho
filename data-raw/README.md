# Model catalog sources

The installed catalog in `R/sysdata.rda` is generated. Do not edit it directly.
Its inputs have two different roles.

`model-registry.R` is the executable provider manifest. Each profile declares
its models.dev source, an unevaluated S7 provider constructor, an unevaluated
protocol constructor, and the functions that derive endpoint-specific facts.
R's lazy argument evaluation captures constructors such as
`KimiCodeModelCatalogProvider(...)` as language objects: the data compiler can
inspect and store the call without loading `rho.ai`, and the installed package
evaluates it inside its namespace. There is no parallel string-to-class table.
The models.dev updater derives its provider projection from this same manifest.

`models-dev-selected.json` is a derived, reviewable projection of
<https://models.dev/api.json>. It retains only providers and fields used by
Rho, including each source API, adapter package, and documentation URL,
together with the SHA-256 digest of the complete response from which it was
produced. A profile may declare a source contract. Compilation then stops if
the pinned endpoint or adapter no longer matches the protocol represented by
the captured R constructor.

`github-copilot-models.json` is a sanitized projection of the authenticated
GitHub Copilot `/models` response. For each model in the models.dev projection,
it records only whether the model was observed, its declared vendor, and its
`supported_endpoints`. It contains no credential, account identifier, policy,
billing field, or response header. The compiler maps exact endpoint declarations
to provider protocols and transports. It never infers a protocol from a model
name or family name.

`model-overrides.json` is curated. Offline records name a registry profile
instead of repeating its provider and protocol. It contains only facts that
cannot be derived from the selected models.dev fields:

- endpoint-specific corrections, such as a GitHub Copilot transport behavior;
- an offline supported model subset for an authenticated endpoint that is not
  represented as a distinct models.dev provider.

Model names, prices, limits, and capabilities belong in the derived snapshot
whenever models.dev supplies them. A profile override is not a convenient way
to replace derivation. If a source field can express the fact, extend
`update-models-dev.R` and derive it in `compile-model-catalog.R`.

## Refreshing derived data

From the repository root:

```sh
make update-models CREDENTIAL=/path/to/credentials.json
make check-models
```

`make update-models` downloads models.dev through nanonext, rewrites the
selected snapshot, resolves the explicitly supplied GitHub Copilot credential,
captures the sanitized endpoint projection, and compiles `R/sysdata.rda`.
`make update-copilot-models CREDENTIAL=/path/to/credentials.json` refreshes only
the endpoint projection. Review both source snapshots and the compiled
behavioral changes. The refresh must remain deterministic: a second
`make models` must produce no diff.

An active models.dev model that was not observed at the authenticated endpoint,
or was observed without `supported_endpoints`, is not compiled as a Copilot
model. A non-empty endpoint declaration unknown to the compiler is an error.
This keeps absence and new protocol shapes visible instead of assigning them a
plausible-looking API from their names.

## Adding a provider

Add one profile to `model-registry.R`. Its list name must equal the literal
`id` in the captured provider constructor. A profile normally supplies:

- `source`, the exact models.dev provider key;
- `provider`, an S7 constructor call carrying endpoint identity;
- `protocol`, an S7 protocol constructor call justified by the endpoint;
- derivation functions only for facts whose meaning differs at that endpoint.

Do not add the provider key to `update-models-dev.R`; the updater reads it from
the registry. Do not generate R source containing one constructor per model;
the compiled package data already stores constructor calls and the runtime
creates lazy, read-only model bindings.

Kimi illustrates why endpoint and credential products stay separate. The
`kimi-coding` profile derives the subscription catalog from the
`kimi-for-coding` source and uses the Anthropic Messages endpoint. Its provider
accepts either an explicit Kimi Code subscription key or an explicit OAuth
credential obtained by device-code login. A Moonshot Platform key belongs to a
different provider profile and base URL: `moonshotai` for `platform.kimi.ai`
and `moonshotai-cn` for `platform.kimi.com`. It must not be stored under
`kimi-coding` merely because both products serve Kimi models.

The authentication endpoints and client identifier are pinned to the official
[Kimi Code OAuth source](https://github.com/MoonshotAI/kimi-code/blob/4f3c7240c4adc7c748e536bf578e468c1b5bcd7b/packages/oauth/src/constants.ts).
The product split and Platform endpoints are pinned to the official
[Open Platform definitions](https://github.com/MoonshotAI/kimi-code/blob/4f3c7240c4adc7c748e536bf578e468c1b5bcd7b/packages/oauth/src/open-platform.ts).
Kimi-specific Chat Completions behavior is checked against the official
[provider implementation](https://github.com/MoonshotAI/kimi-code/blob/4f3c7240c4adc7c748e536bf578e468c1b5bcd7b/packages/kosong/src/providers/kimi.ts).

## Adding curated data

Every object in `profile_overrides` and `records` must include:

- `reason`: why the fact cannot be derived from models.dev;
- `evidence.kind`: the kind of observation or upstream contract;
- `evidence.reference`: an immutable documentation, test, or source-code URL.

Prefer primary provider documentation or an authenticated endpoint fixture.
When Rho follows an upstream compatibility decision, link to an exact commit,
not a moving branch. Never put credentials, response headers, account
identifiers, or unredacted endpoint responses in catalog inputs.

After editing curated data:

```sh
make models
make check-models
Rscript scripts/purl-tests.R
make test
```

Add or update an Rmd fixture that observes the resulting S7 capability value
and request translation. Request builders must consume the compiled typed
capability; they must not repeat model-name tests.

## Hosted operation capabilities

The curated `web_search` field exists only in catalog input. The compiler maps
its values to runtime classes:

- OpenAI `text` and `text_and_image` become `OpenAIWebSearchText` and
  `OpenAIWebSearchTextAndImage`.
- Anthropic `basic`, `dynamic`, and `response_inclusion` become the versioned
  `AnthropicWebSearchProtocol` classes.
- An absent declaration becomes `RhoWebSearchUnavailable`.

Unknown values, duplicate profile keys, and profiles that match no compiled
model are compiler errors. Provider request code sees only the S7 capability;
it neither reads these strings nor tests model identifiers.

## Removing curated data

During each refresh, check whether models.dev now expresses a curated fact. If
it does, add the field to the selected projection when necessary, derive the
typed capability, remove the curated entry, and keep the behavioral fixture.

The Codex OAuth records are an offline supported subset, not a claim that the
endpoint exposes only those models. Login-time discovery may narrow or enrich
availability for an account, but it does not silently rewrite the package
catalog.
