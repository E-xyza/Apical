# Apical

![test status](https://github.com/e-xyza/apical/actions/workflows/on-push-pr.yaml/badge.svg)

Elixir Routers from OpenAPI schemas

## Installation

This package can be installed by adding `apical` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:apical, "~> 0.1.0"}
  ]
end
```

## Basic use

For the following router module:

```elixir
defmodule MyProjectWeb.ApiRouter do
    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: My API
        version: 1.0.0
      paths:
        "/":
          get:
            operationId: getOperation
            responses:
              "200":
                description: OK
      """,
      controller: MyProjectWeb.ApiController,
      encoding: "application/yaml"
    )
end
```

You would connect this to your endpoint as follows:

```elixir
defmodule MyProjectWeb.ApiEndpoint do
  use Phoenix.Endpoint, otp_app: :my_project

  plug(MyProjectWeb.ApiRouter)
end
```

And compose a controller as follows:

```elixir
defmodule MyProjectWeb.ApiController do
  use Phoenix.Controller

  alias Plug.Conn

  # NOTE THE CASING BELOW:
  def getOperation(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end
end
```

## From file:

You may also generate a router from a file:

```elixir
defmodule MyProjectWeb.ApiRouter do
    require Apical

    Apical.router_from_file("priv/assets/api/openapi.v1.yaml",
      controller: MyProjectWeb.ApiController
    )
end
```

### Embedding inside of an existing router

You may also embed apical inside of an existing phoenix router:

```elixir
scope "/api", MyProjectWeb.Api do
  require Apical

  Apical.router_from_file("priv/assets/api/openapi.v1.yaml",
    controller: MyProjectWeb.ApiController)
end
```
 
If you are embedding Apical in an existing router, be sure to delete
the following lines from the phoenix *endpoint*:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Phoenix.json_library()
``` 

As Apical will do its own parsing.

## Using it in tests:

If you're using OpenAPI as a client, you can use Apical to test that your
request wrapper conforms to the client schema:

https://hexdocs.pm/apical/apical-for-testing.html

## Advanced usage

For more advanced usage, consult the tests in the test directory.
Guides will be provided in the next version of apical

## Documentation

Documentation can be found at <https://hexdocs.pm/apical>.

