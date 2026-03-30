defmodule ApicalTest.Parameters.CommonParametersTest do
  @moduledoc """
  Tests for common parameters defined at the path level that are inherited
  by all operations on that path (per OpenAPI 3.1.0 spec).

  See: https://spec.openapis.org/oas/v3.1.0#path-item-object
  """

  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: CommonParametersTest
        version: 1.0.0
      paths:
        "/users/{id}":
          parameters:
            - name: id
              in: path
              required: true
              schema:
                type: integer
          get:
            operationId: getUser
          put:
            operationId: updateUser
          post:
            operationId: createUserRelated
            parameters:
              - name: relation
                in: query
                required: true
                schema:
                  type: string
        "/items/{item_id}":
          parameters:
            - name: item_id
              in: path
              required: true
              schema:
                type: integer
            - name: version
              in: query
              required: false
              schema:
                type: string
          get:
            operationId: getItem
          put:
            operationId: updateItem
            parameters:
              - name: version
                in: query
                required: true
                schema:
                  type: integer
        "/products/{product_id}":
          parameters:
            - $ref: "#/components/parameters/ProductId"
          get:
            operationId: getProduct
      components:
        parameters:
          ProductId:
            name: product_id
            in: path
            required: true
            schema:
              type: integer
      """,
      root: "/",
      controller: ApicalTest.Parameters.CommonParametersTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase
  alias Plug.Conn
  alias Apical.Exceptions.ParameterError

  for operation <- ~w(getUser updateUser createUserRelated getItem updateItem getProduct)a do
    def unquote(operation)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  describe "path-level parameters inheritance" do
    test "GET inherits path-level parameter", %{conn: conn} do
      assert %{"id" => 42} =
               conn
               |> get("/users/42")
               |> json_response(200)
    end

    test "PUT inherits path-level parameter", %{conn: conn} do
      assert %{"id" => 99} =
               conn
               |> put("/users/99")
               |> json_response(200)
    end

    test "path-level parameter validates type", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/fails schema criterion/,
                   fn ->
                     get(conn, "/users/not-an-integer")
                   end
    end
  end

  describe "operation-level parameters extend path-level parameters" do
    test "POST inherits path-level and adds operation-level parameter", %{conn: conn} do
      assert %{"id" => 1, "relation" => "friends"} =
               conn
               |> post("/users/1?relation=friends")
               |> json_response(200)
    end

    test "POST requires operation-level parameter", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation createUserRelated (in query): required parameter `relation` not present",
                   fn ->
                     post(conn, "/users/1")
                   end
    end
  end

  describe "operation-level parameters override path-level parameters" do
    test "GET uses path-level optional version parameter", %{conn: conn} do
      # version is optional at path level
      assert %{"item_id" => 5} =
               conn
               |> get("/items/5")
               |> json_response(200)

      # version can be provided as string
      assert %{"item_id" => 5, "version" => "v1"} =
               conn
               |> get("/items/5?version=v1")
               |> json_response(200)
    end

    test "PUT overrides version parameter to be required and integer", %{conn: conn} do
      # version is required at operation level and must be integer
      assert_raise ParameterError,
                   "Parameter Error in operation updateItem (in query): required parameter `version` not present",
                   fn ->
                     put(conn, "/items/5")
                   end

      # version must be an integer now
      assert %{"item_id" => 5, "version" => 2} =
               conn
               |> put("/items/5?version=2")
               |> json_response(200)
    end
  end

  describe "path-level $ref parameters" do
    test "GET inherits path-level $ref parameter", %{conn: conn} do
      assert %{"product_id" => 123} =
               conn
               |> get("/products/123")
               |> json_response(200)
    end

    test "path-level $ref parameter validates type", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/fails schema criterion/,
                   fn ->
                     get(conn, "/products/not-an-integer")
                   end
    end
  end
end
