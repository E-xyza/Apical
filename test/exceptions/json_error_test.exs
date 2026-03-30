defmodule ApicalTest.Exceptions.JsonErrorTest do
  @moduledoc """
  Tests for JSON error conversion protocol.

  This is Issue #22: JSON marshal errors
  """

  use ExUnit.Case

  alias Apical.Exceptions.ParameterError
  alias Apical.Exceptions.MissingContentTypeError
  alias Apical.Exceptions.MultipleContentTypeError
  alias Apical.Exceptions.InvalidContentTypeError
  alias Apical.Exceptions.MissingContentLengthError
  alias Apical.Exceptions.MultipleContentLengthError
  alias Apical.Exceptions.InvalidContentLengthError
  alias Apical.Exceptions.RequestBodyTooLargeError

  describe "Apical.ToJson protocol" do
    test "ParameterError converts to JSON map" do
      error = %ParameterError{
        operation_id: "testOp",
        in: :query,
        reason: "required parameter `name` not present"
      }

      json = Apical.ToJson.to_json(error)

      assert is_map(json)
      assert json[:error] == "parameter_error"
      assert json[:status] == 400
      assert json[:operation_id] == "testOp"
      assert json[:location] == "query"
      assert json[:message] =~ "required parameter"
    end

    test "ParameterError with validation error converts properly" do
      error = %ParameterError{
        operation_id: "testOp",
        in: :path,
        error_value: "\"invalid\"",
        absolute_keyword_location: "#/paths/test/schema/type",
        instance_location: "/value"
      }

      json = Apical.ToJson.to_json(error)

      assert is_map(json)
      assert json[:error] == "parameter_error"
      assert json[:status] == 400
      assert json[:details][:value] == "\"invalid\""
      assert json[:details][:schema_location] == "#/paths/test/schema/type"
    end

    test "MissingContentTypeError converts to JSON" do
      error = %MissingContentTypeError{}

      json = Apical.ToJson.to_json(error)

      assert json[:error] == "missing_content_type"
      assert json[:status] == 400
      assert json[:message] =~ "content-type"
    end

    test "MultipleContentTypeError converts to JSON" do
      error = %MultipleContentTypeError{}

      json = Apical.ToJson.to_json(error)

      assert json[:error] == "multiple_content_type"
      assert json[:status] == 400
    end

    test "InvalidContentTypeError converts to JSON" do
      error = %InvalidContentTypeError{invalid_string: "bad/type"}

      json = Apical.ToJson.to_json(error)

      assert json[:error] == "invalid_content_type"
      assert json[:status] == 400
      assert json[:invalid_value] == "bad/type"
    end

    test "MissingContentLengthError converts to JSON" do
      error = %MissingContentLengthError{}

      json = Apical.ToJson.to_json(error)

      assert json[:error] == "missing_content_length"
      assert json[:status] == 411
    end

    test "MultipleContentLengthError converts to JSON" do
      error = %MultipleContentLengthError{}

      json = Apical.ToJson.to_json(error)

      assert json[:error] == "multiple_content_length"
      assert json[:status] == 411
    end

    test "InvalidContentLengthError converts to JSON" do
      error = %InvalidContentLengthError{invalid_string: "abc"}

      json = Apical.ToJson.to_json(error)

      assert json[:error] == "invalid_content_length"
      assert json[:status] == 411
      assert json[:invalid_value] == "abc"
    end

    test "RequestBodyTooLargeError converts to JSON" do
      error = %RequestBodyTooLargeError{max_length: 1000, content_length: 2000}

      json = Apical.ToJson.to_json(error)

      assert json[:error] == "request_body_too_large"
      assert json[:status] == 413
      assert json[:max_length] == 1000
      assert json[:content_length] == 2000
    end
  end

  describe "Jason.encode" do
    test "errors can be encoded to JSON string" do
      error = %ParameterError{
        operation_id: "testOp",
        in: :query,
        reason: "test error"
      }

      json_map = Apical.ToJson.to_json(error)
      {:ok, json_string} = Jason.encode(json_map)

      assert is_binary(json_string)
      assert json_string =~ "parameter_error"
      assert json_string =~ "testOp"
    end
  end
end
