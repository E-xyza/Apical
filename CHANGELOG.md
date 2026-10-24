# Apical Changelog

## 1.0.0

### feature

- **Egress (response) schema validation.**  Response bodies can be validated
  against the schemas declared for them under `responses` in the OpenAPI
  document.  Enable it through the application environment:

  ```elixir
  # config/test.exs
  config :apical, egress_testing: true
  ```

  It is read with `Application.compile_env/3`, so when it is false (the
  default) nothing of the feature is compiled: no egress plug, no response
  validators, and neither `Apical.Plugs.Egress` nor
  `Apical.Exceptions.EgressError` exists in the build.

  A nonconforming response raises `Apical.Exceptions.EgressError`, which
  carries a **500** status.  The status is 5xx rather than 4xx deliberately:
  responses are validated after the operation has run, so its side effects
  have already happened, and a 4xx would wrongly tell the client that their
  request was rejected and nothing occurred.  The fault is the server's.

  Validation happens in a `Plug.Conn.register_before_send/2` callback, so a
  failure cannot produce a half-sent response.  Responses are matched on
  status code and content type, falling back to the `default` response
  object; a response with no schema, or a body that is not JSON, passes
  through unvalidated.  Works on both the Phoenix and Plug adapters.

### bugfix

- Malformed `matrix`-style parameters now return a 400 instead of a 500.  A
  segment carrying more than one `=` (e.g. `;a=b=c`) fell through an
  incomplete `case` and raised `CaseClauseError`, which carries no
  `plug_status`.  This affected all four matrix shapes -- array, object,
  exploded object and primitive -- since the split runs before the type
  dispatch.

### maintenance

- `mox` and `bypass` are now scoped `only: :test` in addition to
  `optional: true`.  They were previously only `optional: true`, which governs
  whether *consumers* are forced to install them but does not scope them by
  environment -- so Apical's own `dev` and `prod` builds compiled bypass and
  the entire cowboy stack it hard-depends on (`plug_cowboy`, `cowboy`,
  `cowlib`, `ranch`), including the one package with an unfixed advisory.
  Both are referenced only inside `quote` blocks in `Apical.Testing`, so they
  are never resolved when this library compiles; the generated code needs them
  in the *user's* test environment, which is what `optional: true` is for.

- Updated dependencies, clearing 46 of 47 security advisories reported by
  `mix hex.audit` (`plug` 1.19.1 -> 1.20.3, `phoenix` 1.8.5 -> 1.8.16,
  `bandit` 1.10.4 -> 1.13.1, `req` 0.5.17 -> 0.7.5, `exonerate` 1.2.1 ->
  1.3.0, plus transitives including `cowboy`, `cowlib`, `hpax`, `mint` and
  `plug_crypto`).  `plug` was the only affected *runtime* dependency, so it
  was the only one whose advisories reached consumers.

  `cowboy` and `cowlib` are pinned (`~> 2.18.0` / `~> 2.19.0`, `only: :test`,
  `override: true`) rather than taken at latest.  `cowlib` 2.20.0 introduced a
  `maybe ... ?=` expression in `cow_capsule.erl`, which is an OTP-27 feature,
  so 2.20.0+ cannot compile on OTP 26 -- still part of the supported matrix
  for `elixir: "~> 1.17"`.  Upstream now targets OTP 27+ only
  (`AUTO_CI_OTP ?= OTP-LATEST-27+`).  2.19.0 is the last OTP-26-safe release,
  and cowboy 2.18.0 the newest release whose requirement it satisfies.

  Three advisories therefore remain, all in `cowlib` 2.19.0 and none with a
  fix available on OTP 26: EEF-CVE-2026-43966 (MEDIUM), -43971 (MEDIUM) and
  -43969 (LOW).  They arrive transitively via `bypass` -> `plug_cowboy` ->
  `cowboy`; bypass is hard-wired to cowboy (its own `mix.exs` requires
  `plug_cowboy` unconditionally, it depends on `ranch` directly, and it has
  had no release since 2020), so the cowboy stack is unavoidable while bypass
  is a dependency.  With bypass now `only: :test`, none of it reaches `dev` or
  `prod` builds or any consumer of this library.

  No version requirements in `mix.exs` needed to change; all updates were
  already permitted by the existing constraints.

- Resolved all seven outstanding `TODO`s in `lib/`.  Three described work
  already done or that would have made the code less idiomatic and were
  removed; `content_sources` is no longer embedded in full in every generated
  request-body plug; the `catch` in the query parser is now documented as
  deliberate.

## 0.3.2

### feature

- `router_from_string/2`: new opt-in `eval: true` option. The spec argument is
  evaluated at compile time in the caller's context (via `Code.eval_quoted/3`)
  instead of being required to be a bare string literal, so the OpenAPI document
  can be composed from string literals and helper-module function calls — e.g.
  `router_from_string("...\n#{for m <- Registry.variants(), do: m.paths()}", eval: true, ...)`.
  Defaults to `false` (literal-only, unchanged). Opt-in because evaluating an
  expression at compile time is a sharper tool than accepting a literal.
- `router_from_string/2` now stashes the resolved spec string on the calling
  module as `@apical_spec_string`, so a router can serve or introspect its own
  OpenAPI document at runtime (e.g. `def spec, do: @apical_spec_string`).

## 0.3.1

### bugfix

- Plug adapter: prefix the per-operation module name with `Op` so a hex digest
  starting with a digit still forms a valid alias segment (previously raised
  `:as, expected an alias` at compile time for ~40% of operations).
- Plug adapter: re-register the Exonerate resource inside each operation's nested
  module so its parameter/body validators resolve the resource against their own
  module's cache. Previously any operation with a `requestBody`/parameter schema
  failed to compile with `resource ... not found in cache` (the Phoenix adapter
  is unaffected — it emits validators in the router module).
- request body marshalling: handle a boolean `additionalProperties` (`true`/
  `false`), valid in OpenAPI 3.1. Previously it assumed a schema object and did
  `get_in(true, ["type"])`, crashing at compile time on both adapters.

## 0.3.0

### New Features

- **Accept header validation** (Issue #45)
  - Validates incoming Accept headers against response content types defined in OpenAPI schema
  - Returns 406 Not Acceptable if client's Accept preferences don't match
  - Supports quality factors (q=X) and wildcards (*/* and type/*)
  - Can be disabled globally or per-operation with `validate_accept: false`

- **Remote $ref resolution** (Issue #31)
  - Support for resolving $refs to external URLs from a local cache
  - Configure with `remote_refs_cache: "path/to/cache"` option
  - Supports JSON and YAML files with fragment resolution

- **Chunked transfer-encoding support** (Issue #36)
  - Request bodies with `Transfer-Encoding: chunked` are now accepted
  - No Content-Length header required for chunked requests

- **Common parameters** (Issue #58)
  - Path-level parameters are now inherited by all operations on that path
  - Operation-level parameters can override path-level parameters

- **Complete $ref resolution** (Issue #28)
  - Added $ref support for Response, Header, SecurityScheme, and Callback objects
  - Both local and remote refs are fully supported

- **Documentation guides** (Issue #38)
  - Added comprehensive guides for Getting Started, Parameter Validation,
    Request Body Handling, Remote References, and Testing

### Improvements

- Custom validators for request body properties
- Option to disable request body validation with `validate: false`
- ToJson protocol for converting errors to JSON-compatible maps

## 0.2.1
- fixes issue with nested refs

## 0.2.0

- support for grouping operationId by "group"
- support for using Plug only, with no Phoenix dependency
- support for aliasing operationId to functions
- support for custom parameter marshalling functions
- support for disabling marshalling or validation
- support for using Apical to test requests against OpenAPI schemas

## 0.1.0

### initial release

- supports from file or from string
- supports injecting extra plugs
- supports versioning 
  - by matching on assigns `api_version` field
  - by targeting controllers
  - by chaining routers
- parameter marshalling support
  - path
  - query
  - headers
  - cookies
- validation of parameters using Exonerate (https://github.com/E-xyza/Exonerate)
- generates routes into phoenix header
- inbound request body payloads into params
  - application/json
  - application/form-encoded
- options targettable by tag or operation_id
- supports internal $refs

## Future planned support

### These features are in approximate order of priority

- more sophisticated parsing and marshalling in request_body
- support for json libraries besides Jason
- multipart/form-data support
- authorization schema support (use `extra_plugs:` for now)
- $id-based $ref support
- OpenAPI 3.0 support
- OpenAPI 4.0 support
