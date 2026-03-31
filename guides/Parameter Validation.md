# Parameter Validation

Apical validates parameters against JSON schemas defined in your OpenAPI document.
This guide covers validation options and custom validators.

## Default Behavior

By default, Apical validates all parameters against their schemas:

```yaml
parameters:
  - name: age
    in: query
    schema:
      type: integer
      minimum: 0
      maximum: 150
```

A request with `?age=200` will raise `Apical.Exceptions.ParameterError`.

## Disabling Validation

### Per Operation

Disable validation for all parameters in an operation:

```elixir
Apical.router_from_file("api.yaml",
  controller: MyController,
  operation_ids: [
    myOperation: [validate: false]
  ]
)
```

### Per Parameter

Disable validation for specific parameters:

```elixir
Apical.router_from_file("api.yaml",
  controller: MyController,
  operation_ids: [
    myOperation: [
      parameters: [
        untrusted_param: [validate: false]
      ]
    ]
  ]
)
```

## Type Marshalling

Parameters are automatically marshalled (type-coerced) from strings:

| Schema Type | Input | Result |
|------------|-------|--------|
| `integer` | `"42"` | `42` |
| `number` | `"3.14"` | `3.14` |
| `boolean` | `"true"` | `true` |
| `array` | `"a,b,c"` | `["a", "b", "c"]` |

### Disabling Marshalling

Disable type coercion to receive raw strings:

```elixir
operation_ids: [
  myOperation: [
    parameters: [
      my_param: [marshal: false]
    ]
  ]
]
```

## Custom Validators

Add custom validation logic beyond JSON schema validation.

### For Request Bodies

Validate the entire request body:

```elixir
defmodule MyValidator do
  def validate_user(user) do
    cond do
      user["email"] && !String.contains?(user["email"], "@") ->
        {:error, reason: "invalid email format"}
      user["age"] && user["age"] < 18 ->
        {:error, reason: "must be 18 or older"}
      true ->
        :ok
    end
  end
end

Apical.router_from_file("api.yaml",
  controller: MyController,
  operation_ids: [
    createUser: [
      request_body: [
        validate: {MyValidator, :validate_user}
      ]
    ]
  ]
)
```

### For Individual Properties

Validate specific properties within a request body:

```elixir
defmodule PropertyValidators do
  def validate_email(email) when is_binary(email) do
    if String.contains?(email, "@"), do: :ok, else: {:error, reason: "invalid email"}
  end

  def validate_in_range(value, min, max) when is_integer(value) do
    cond do
      value < min -> {:error, reason: "must be >= #{min}"}
      value > max -> {:error, reason: "must be <= #{max}"}
      true -> :ok
    end
  end
end

Apical.router_from_file("api.yaml",
  controller: MyController,
  operation_ids: [
    createUser: [
      request_body: [
        properties: [
          email: [validate: {PropertyValidators, :validate_email}],
          score: [validate: {PropertyValidators, :validate_in_range, [0, 100]}]
        ]
      ]
    ]
  ]
)
```

## Error Handling

Validation errors raise `Apical.Exceptions.ParameterError`. Convert to JSON:

```elixir
# Using the ToJson protocol
json_error = Apical.ToJson.to_json(error)
# => %{
#   error: "parameter_error",
#   status: 400,
#   message: "...",
#   operation_id: "myOperation",
#   location: "query",
#   details: %{...}
# }
```

Example error handler plug:

```elixir
defmodule MyAppWeb.ErrorHandler do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
  rescue
    error in [Apical.Exceptions.ParameterError] ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(error.plug_status, Jason.encode!(Apical.ToJson.to_json(error)))
      |> halt()
  end
end
```

## Validation with Exonerate Options

Pass options to the underlying Exonerate JSON Schema validator:

```elixir
Apical.router_from_file("api.yaml",
  controller: MyController,
  draft: "2020-12",        # JSON Schema draft version
  format: :assertive       # Strict format validation
)
```
