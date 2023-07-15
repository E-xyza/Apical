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

## Future planned support 

### These features are in approximate order of priority

- support for plug-only (no phoenix use)
- more sophisticated parsing and marshalling in request_body
- support for json libraries besides Jason
- data egress checking (conditional, compile-time)
- support for auto-rejecting based on accept: information
- multipart/form-data support
- authorization schema support (use `extra_plugs:` for now)
- remote $ref support
- $id-based $ref support
- Openapi 3.0 support
- Openapi 4.0 support