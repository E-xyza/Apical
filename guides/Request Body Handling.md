# Request Body Handling

Apical automatically parses and validates request bodies based on content type.
This guide covers the built-in handlers and customization options.

## Supported Content Types

### JSON (`application/json`)

JSON bodies are automatically parsed and validated:

```yaml
paths:
  "/users":
    post:
      operationId: createUser
      requestBody:
        content:
          "application/json":
            schema:
              type: object
              properties:
                name:
                  type: string
                age:
                  type: integer
              required:
                - name
```

The parsed JSON is merged into `conn.params`:

```elixir
def createUser(conn, %{"name" => name, "age" => age}) do
  # name is a string, age is an integer
end
```

### Form Data (`application/x-www-form-urlencoded`)

Form-encoded bodies are parsed and marshalled to proper types:

```yaml
requestBody:
  content:
    "application/x-www-form-urlencoded":
      schema:
        type: object
        properties:
          count:
            type: integer
          enabled:
            type: boolean
```

```elixir
# POST with body: count=42&enabled=true
def myOperation(conn, %{"count" => 42, "enabled" => true}) do
  # Values are marshalled from strings to proper types
end
```

## Disabling Validation

Disable request body validation while keeping parsing:

```elixir
Apical.router_from_file("api.yaml",
  controller: MyController,
  operation_ids: [
    createUser: [
      request_body: [validate: false]
    ]
  ]
)
```

## Custom Validators

### Whole-Body Validation

Validate the entire parsed body:

```elixir
defmodule BodyValidators do
  def validate_create_user(body) do
    cond do
      is_nil(body["email"]) ->
        {:error, reason: "email is required"}
      !valid_email?(body["email"]) ->
        {:error, reason: "invalid email format"}
      true ->
        :ok
    end
  end

  defp valid_email?(email), do: String.contains?(email, "@")
end

operation_ids: [
  createUser: [
    request_body: [
      validate: {BodyValidators, :validate_create_user}
    ]
  ]
]
```

### Property-Level Validation

Validate individual properties:

```elixir
defmodule PropertyValidators do
  def validate_email(email) do
    if String.contains?(email, "@"), do: :ok, else: {:error, reason: "invalid email"}
  end

  def validate_age(age) when age >= 0 and age <= 150, do: :ok
  def validate_age(_), do: {:error, reason: "age must be 0-150"}
end

operation_ids: [
  createUser: [
    request_body: [
      properties: [
        email: [validate: {PropertyValidators, :validate_email}],
        age: [validate: {PropertyValidators, :validate_age}]
      ]
    ]
  ]
]
```

### Validators with Arguments

Pass additional arguments to validator functions:

```elixir
def validate_range(value, min, max) do
  cond do
    value < min -> {:error, reason: "must be >= #{min}"}
    value > max -> {:error, reason: "must be <= #{max}"}
    true -> :ok
  end
end

properties: [
  score: [validate: {Validators, :validate_range, [0, 100]}]
]
```

## Chunked Transfer Encoding

Apical supports chunked transfer encoding for request bodies. Instead of requiring
a `Content-Length` header, clients can send `Transfer-Encoding: chunked`:

```
POST /api/upload HTTP/1.1
Content-Type: application/json
Transfer-Encoding: chunked

{"large": "payload..."}
```

The body is accumulated incrementally, with a maximum size limit enforced
(default 8MB).

## Custom Content Sources

For content types not built-in, implement the `Apical.Plugs.RequestBody.Source`
behaviour:

```elixir
defmodule MyApp.XmlSource do
  @behaviour Apical.Plugs.RequestBody.Source

  alias Apical.Plugs.RequestBody.Source

  @impl true
  def validate!(_parameters, _operation_id), do: :ok

  @impl true
  def fetch(conn, validator, marshal_context, opts) do
    with {:ok, body, conn} <- Source.fetch_body(conn, opts),
         {:ok, parsed} <- parse_xml(body),
         {:ok, marshalled} <- Source.apply_marshal(parsed, marshal_context),
         :ok <- Source.apply_validator(marshalled, validator) do
      {:ok, %{conn | params: Map.merge(conn.params, marshalled)}}
    end
  end

  defp parse_xml(body) do
    # Your XML parsing logic
  end
end
```

Register the custom source:

```elixir
Apical.router_from_file("api.yaml",
  controller: MyController,
  content_sources: [
    {"application/xml", MyApp.XmlSource}
  ]
)
```

## Error Types

Request body errors include:

| Error | Status | Cause |
|-------|--------|-------|
| `MissingContentTypeError` | 400 | No Content-Type header |
| `InvalidContentTypeError` | 400 | Malformed Content-Type |
| `MissingContentLengthError` | 411 | No Content-Length (unless chunked) |
| `RequestBodyTooLargeError` | 413 | Body exceeds size limit |
| `ParameterError` | 400 | Validation failure |

All errors implement `Apical.ToJson`:

```elixir
error
|> Apical.ToJson.to_json()
|> Jason.encode!()
```
