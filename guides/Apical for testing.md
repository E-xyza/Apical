# Using Apical for Testing OpenAPI requests

You may use Apical in your test environment to make sure that client requests 
you perform against a 3rd party OpenAPI server are well-formed.

Often times, tests for API compliance are not performed because they can look
like your tests are merely duplicative of the code that you already have.
Moreover, if the API changes, then you will have to rewrite all of the tests
to remain in compliance with API.

With Apical, you have an easy way of testing that the parameter requirements
are fulfilled and that they should not cause 400 or 404 errors when you 
make the request.  You can also use this to test that the parameters you're
assigning are correctly bound into the OpenAPI parameters.

## Prerequisites

In "test" mode, Apical expects that you are using the following two Elixir
libraries:

- `Mox` to mock out the API controllers.
- `Bypass` to stand up transient http servers.

### Installation

1. in your `mix.exs` file, add the following dependencies:

  ```elixir
    defp deps do
      [
          ...
        {:apical, "~> 0.2", only: :test},
        {:mox, "~> 1.0", only: :test},
        {:bypass, "~> 2.1", only: :test},
      ]
    end
  ```

2. If you haven't already, set up your elixir compilers to compile to a support directory:

  In `mix.exs`, `project` function
  
  ```elixir
    def project do
      [
        ...
        elixirc_paths: elixirc_paths(Mix.env()),
      ]
    end
  ```

  In `mix.exs` module top level:

  ```elixir
    def elixirc_paths(:test), do: ["lib", "test/support"]
    def elixirc_paths(_), do: ["lib"]
  ```

3. Make sure `mox` and `bypass` are running when tests are running:

  in `test/test_helper.exs`:

  ```elixir
  Application.ensure_all_started(:bypass)
  Application.ensure_all_started(:mox)
  ```

## Router setup

Create a router in your `test/support` directory.

For example:

```elixir
defmodule MyAppTest.SomeSAAS do
  use Phoenix.Router

  require Apical

  Apical.router_from_file("path/to/some_saas.yaml", encoding: "application/yaml", testing: :auto)
end
```

Note that this macro creates `MyAppTest.SomeSAAS.Mock` which is the mock for controller serviced
by the `some_saas` OpenAPI schema, as well as the `bypass/1,2` function which configures bypass
to use the router.

For details on how to set up more fine-grained testing settings, see documentation for `Apical` module.

## Testing module setup

In your test module, start with the following code:

```elixir
defmodule MyAppTest.SaasRequestTest do
  # tests using Apical in "test" mode where it creates a bypass server.

  use ExUnit.Case, async: true

  alias MyAppTest.SomeSAAS
  alias MyAppTest.SomeSAAS.Mock

  alias MyApp.ClientModule

  setup do
    bypass = Bypass.open()
    SomeSAAS.bypass(bypass)
    {:ok, bypass: bypass}
  end
```

This sets up bypass to serve an http server on its own port for each test
run in the test module.  Since it's async, the `Mox` expectations are set
up to work with the bypass server.

## Testing your API consumer

> ### Required for your API consumer {: .warning }
>
> In order to use this feature, your API consumer functions MUST be able to
> use a host other than the API's "normal" host.

we'll assume that some `ClientModule` has 

1. Testing to see that the issued request is compliant (no 400/404 errors)

  In this case, we have function `some_operation` is compliant and doesn't
  issue a request to an incorrect path or present invalid parameters.

  ```elixir
  test "someOperation" %{bypass: bypass} do
    Mox.expect(Mock, :someOperation, fn conn, _params ->
      send_resp(conn, 200, @dummy_result)
    end)

    ClientModule.some_operation(host: "localhost:#{bypass.port}")
  end
  ```

2. Testing to see that parameters are serialized as expected

  This test is an example verification that content issued through a client
  module into a OpenAPI operation is serialized as expected. 
  
  > ### Scope of parameters {: .info }
  >
  > Keep in mind that parameters can be in cookies, headers, query string, path,
  > or content serialized from the body of the http request
  > parameters taken from the body have lower precedence than taken from the 
  > request, if you could potentially have a collision in keys, use the 
  > `nest_all_json` option in your Apical router configuration.

  ```elixir
  @test_parameter 47

  test "someOperation" %{bypass: bypass} do
    Mox.expect(Mock, :someOperation, fn conn, %{"parameter-name" => parameter} ->
      assert parameter == @test_parameter
      send_resp(conn, 201, @dummy_result)
    end)

    ClientModule.some_operation(@test_parameter, host: "localhost:#{bypass.port}")
  end
  ```

  > ### Json Encoding {: .warning }
  >
  > note that your client function input parameter might have atom keys (or might
  > be a struct), in which case, strict equality might not be the correct test 
  > inside your mox expectation, as Apical will typically render it as a JSON with 
  > string keys.