# CLAUDE.md

This file provides guidance for AI assistants working with the Apical codebase.

## Project Overview

Apical is an OpenAPI 3.1.0 router generator for Elixir. It generates web routers at compile-time directly from OpenAPI schemas, with automatic parameter parsing, validation, and request body handling for both Phoenix and pure Plug frameworks.

## Common Commands

```bash
# Install dependencies
mix deps.get

# Run all tests
mix test

# Run a specific test file
mix test test/path/to/test.exs

# Format code
mix format

# Generate documentation
mix docs
```

## Architecture

### Directory Structure

- `lib/apical/` - Main library code
  - `adapters/` - Phoenix and Plug router code generators
  - `plugs/` - Request processing plugs (path, query, header, cookie, request_body)
  - `parser/` - Style parsing and type marshalling
  - `plug/` - Plug-only router implementation
  - `_exceptions/` - Custom exception types
- `test/` - Test suite organized by feature
- `guides/` - Additional documentation

### Key Modules

- `Apical` - Main entry point with `router_from_string/2` and `router_from_file/2` macros
- `Apical.Router` - Compiles OpenAPI schema into router code
- `Apical.Adapters.Phoenix` / `Apical.Adapters.Plug` - Framework-specific code generation
- `Apical.Plugs.*` - Parameter parsing and validation plugs
- `Apical.Parser.Style` - OpenAPI parameter style parsing
- `Apical.Parser.Marshal` - Type marshalling (string to proper types)
- `Apical.Validators` - Exonerate-based JSON Schema validation

### Request Processing Flow

1. Route matched by generated router
2. `SetVersion` and `SetOperationId` plugs tag the connection
3. Parameter plugs parse and validate path/query/header/cookie params
4. Request body plug parses and validates body content
5. Controller action receives validated `conn` with parsed params

## Coding Conventions

- Private modules are prefixed with underscore (e.g., `_parameter.ex`, `_exceptions/`)
- Heavy use of compile-time macros for code generation
- Parameter plugs implement a common behavior defined in `Apical.Plugs.Parameter`
- Three-stage parameter processing: style parsing -> type marshalling -> validation
- Use `Apical.Tools.assert/2` for compile-time validation assertions

## Testing

Tests are organized by feature area:
- `test/parameters/` - Parameter parsing tests
- `test/request_body/` - Request body handling tests
- `test/verbs/` - HTTP verb tests
- `test/plug/` - Plug-specific tests
- `test/versioning/` - API versioning tests
- `test/refs/` - Schema $ref resolution tests

Test infrastructure uses Mox for mocking controllers and Bypass for HTTP integration tests.

## Dependencies

Key dependencies:
- `pegasus` - Parser combinator for OpenAPI path parsing
- `exonerate` - JSON Schema validation at compile time
- `plug` - Core web framework abstraction
- `json_ptr` - JSON Pointer for $ref resolution
