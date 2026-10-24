# Response Validation

Apical can check that the responses your API *sends* conform to the schemas
declared for them under `responses` in your OpenAPI document, the same way it
checks incoming parameters and request bodies.  This is called *egress*
validation.

It is off by default and is enabled through the application environment:

```elixir
# config/test.exs
config :apical, egress_testing: true
```

## Why the application environment, and not an option

The flag is read with `Application.compile_env/3`, which means it is resolved
when your router is compiled rather than consulted on each request.  When it is
false:

- the router emits no egress plug and no response validators, and
- `Apical.Plugs.Egress` and `Apical.Exceptions.EgressError` do not exist in the
  build at all.

So a production build carries nothing of this feature — not a branch, not a
struct definition. The tradeoff is that changing the setting requires
recompiling `:apical` and any module that generated a router:

```sh
mix deps.compile apical --force && mix compile --force
```

Elixir will also raise at runtime if the value it was compiled with no longer
matches the configured value, so a stale build tells you rather than silently
misbehaving.

## What it does

With the flag on, each operation with response schemas gets a plug that
registers a `Plug.Conn.register_before_send/2` callback.  After your controller
has built the response, but **before** any of it reaches the wire, the body is
decoded and checked against the schema for its status code and content type.

Given this document:

```yaml
paths:
  "/users/{id}":
    get:
      operationId: getUser
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema:
                type: object
                properties:
                  id: {type: string}
                  name: {type: string}
                required: [id, name]
```

a handler that forgets `name`:

```elixir
def getUser(conn, %{"id" => id}) do
  conn
  |> put_resp_content_type("application/json")
  |> send_resp(200, Jason.encode!(%{id: id}))
end
```

raises `Apical.Exceptions.EgressError`:

```
Egress Error in operation getUser (200 application/json): value `{"id":"abc"}` at `/`
fails schema criterion at `#/paths/~1users~1%7Bid%7D/get/responses/200/content/application~1json/schema/required/1`.
required: "/name"
```

In a test suite that surfaces as a failing test naming the operation, the status
code, the content type, the offending body and the exact schema location.

## Why a 500 and not a 4xx

`EgressError` carries a **500** status.  This is deliberate, and it matters if
you ever enable the flag outside of tests.

Responses are validated at the *end* of request handling, after your operation
has already run.  By that point its side effects have happened — rows have been
written, messages queued, external calls made.  A 4xx tells the client "your
request was rejected, nothing happened", which in that situation is simply
untrue.  A 500 correctly reports that the request was processed and the *server*
then produced something its own schema forbids.

Because the check runs in `before_send`, nothing has been written to the socket
when it raises, so a failure never produces a partially-sent response.

## What is not validated

Egress validation stays quiet where it has nothing to say:

- **Responses with no schema.**  A response object with no `content`, or a
  content entry with no `schema`, is passed through.
- **Bodies that are not JSON.**  Only JSON bodies can be checked against a JSON
  schema; anything that does not decode passes through.
- **Status codes with no matching response object.**  Lookup is by status code
  and content type, falling back to the `default` response object if one is
  declared.  With neither, the response is not validated.

## Using it in production

You can turn the flag on in production, but understand what you are choosing: a
mistake in your response schema turns a working endpoint into a 500.  The
schema becomes a hard runtime contract rather than documentation.  If you want
that — for an internal API where a malformed response is worse than an outage,
say — it is supported.  Most applications should enable it in `:test` only, where
a schema violation should fail a test rather than a request.
