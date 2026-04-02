# Getting Started with Apical

Apical generates web routers from OpenAPI 3.1.0 documents at compile time. It handles
parameter parsing, validation, and request body processing automatically based on
your OpenAPI schema.

## Installation

Add `apical` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:apical, "~> 0.3"},
    {:exonerate, "~> 1.2", runtime: false},  # compile-time JSON schema validation
    {:jason, "~> 1.4"},                       # for JSON parsing
    {:yaml_elixir, "~> 2.9"}                  # for YAML parsing (optional)
  ]
end
```

## Basic Setup

### Phoenix Router

Create a router that generates routes from your OpenAPI document:

```elixir
defmodule MyAppWeb.ApiRouter do
  use Phoenix.Router

  require Apical

  Apical.router_from_file(
    "priv/openapi/api.yaml",
    controller: MyAppWeb.ApiController,
    root: "/api/v1"
  )
end
```

Or inline the schema:

```elixir
defmodule MyAppWeb.ApiRouter do
  use Phoenix.Router

  require Apical

  Apical.router_from_string(
    """
    openapi: 3.1.0
    info:
      title: My API
      version: 1.0.0
    paths:
      "/users/{id}":
        get:
          operationId: getUser
          parameters:
            - name: id
              in: path
              required: true
              schema:
                type: integer
    """,
    controller: MyAppWeb.ApiController,
    content_type: "application/yaml"
  )
end
```

### Controller

Implement controller functions matching the `operationId` values in your schema:

```elixir
defmodule MyAppWeb.ApiController do
  use Phoenix.Controller

  # Receives validated and type-coerced params
  def getUser(conn, %{"id" => user_id}) do
    # user_id is already an integer (marshalled from path string)
    user = MyApp.Users.get!(user_id)
    json(conn, user)
  end
end
```

### Include in Main Router

Forward requests to your API router:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router

  forward "/api", MyAppWeb.ApiRouter
end
```

## Key Concepts

### Parameters

Apical automatically handles parameters from all locations:

- **Path parameters** (`/users/{id}`)
- **Query parameters** (`?limit=10`)
- **Header parameters** (`X-Custom-Header`)
- **Cookie parameters**

Parameters are:
1. **Parsed** according to their style (simple, form, etc.)
2. **Marshalled** to their declared types (string -> integer, etc.)
3. **Validated** against JSON schemas

### Request Bodies

Request bodies are automatically parsed for common content types:

- `application/json` - JSON parsing
- `application/x-www-form-urlencoded` - Form data parsing

Parsed content is validated against the schema and merged into params.

### Validation Errors

When validation fails, Apical raises `Apical.Exceptions.ParameterError`:

```elixir
plug :handle_errors

defp handle_errors(conn, _opts) do
  conn
rescue
  error in [Apical.Exceptions.ParameterError] ->
    conn
    |> put_status(error.plug_status)
    |> json(%{error: Exception.message(error)})
end
```

## Common Options

### Global Options

```elixir
Apical.router_from_file("api.yaml",
  # Required
  controller: MyController,

  # Optional
  root: "/api/v1",           # URL prefix for all routes
  for: Phoenix,              # or Plug for non-Phoenix apps
  content_type: "application/yaml"
)
```

### Per-Operation Options

```elixir
Apical.router_from_file("api.yaml",
  controller: MyController,
  operation_ids: [
    getUser: [
      controller: DifferentController,  # override controller
      validate: false,                  # disable parameter validation
      parameters: [
        id: [marshal: false]            # disable type coercion for specific param
      ]
    ]
  ]
)
```

## Next Steps

- [Parameter Validation](Parameter%20Validation.md) - Custom validators and validation options
- [Request Body Handling](Request%20Body%20Handling.md) - JSON, form data, and custom parsers
- [Remote References](Remote%20References.md) - Using $ref to external schemas
