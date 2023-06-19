# Apical Changelog

## 0.1

### initial release

- supports from file or from string
- supports injecting extra plugs
- supports versioning 
  - by matching on assigns `api_version` field
  - by targetting controllers
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

## Future planned support 

### These features are in approximate order of priority

- support for plug-only (no phoenix use)
- more sophisticated parsing and marshalling in request_body
- data egress checking (conditional, compile-time)
- support for auto-rejecting based on accept: information
- multipart/form-data support
- authorization schema support (use `extra_plugs:` for now)
- Openapi 3.0 support
- Openapi 4.0 support