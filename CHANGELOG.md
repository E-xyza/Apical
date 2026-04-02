# Apical Changelog

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

## 0.2.0

- support for grouping operationId by "group"
- support for using Plug only, with no Phoenix dependency
- support for aliasing operationId to functions
- support for custom parameter marshalling functions
- support for disabling marshalling or validation
- support for using Apical to test requests against OpenAPI schemas

## 0.2.1
- fixes issue with nested refs

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

## Future planned support

### These features are in approximate order of priority

- more sophisticated parsing and marshalling in request_body
- support for json libraries besides Jason
- data egress checking (conditional, compile-time)
- multipart/form-data support
- authorization schema support (use `extra_plugs:` for now)
- $id-based $ref support
- OpenAPI 3.0 support
- OpenAPI 4.0 support