defmodule ApicalTest.Parser.QueryParserTest do
  use ExUnit.Case, async: true

  alias Apical.Parser.Query

  describe "for the query parser - basics" do
    test "it works with empty string" do
      assert {:ok, %{}} = Query.parse("")
    end

    test "it works with basic one key parameter" do
      assert {:ok, %{"foo" => "bar"}} = Query.parse("foo=bar")
    end

    test "it works with basic multi key thing" do
      assert {:ok, %{"foo" => "bar"}} = Query.parse("foo=bar&baz=quux")
    end

    test "percent encoding works" do
      assert {:ok, %{"foo" => "bar baz"}} = Query.parse("foo=bar%20baz")
    end
  end

  describe "exceptions with strange value strings" do
    test "value with no key defaults to empty string" do
      assert {:ok, %{"foo" => ""}} = Query.parse("foo=")
    end

    test "standalone value with no key defaults to empty string" do
      assert {:ok, %{"foo" => ""}} = Query.parse("foo")
    end
  end

  describe "array encoding" do
    test "with form encoding" do
      assert {:ok, %{"foo" => ["bar", "baz"]}} =
               Query.parse("foo=bar,baz", %{"foo" => %{type: [:array], style: :form}})
    end

    test "with space delimited encoding" do
      assert {:ok, %{"foo" => ["bar", "baz"]}} =
               Query.parse("foo=bar%20baz", %{"foo" => %{type: [:array], style: :space_delimited}})
    end

    test "with pipe delimited encoding" do
      assert {:ok, %{"foo" => ["bar", "baz"]}} =
               Query.parse("foo=bar%7Cbaz", %{"foo" => %{type: [:array], style: :pipe_delimited}})

      assert {:ok, %{"foo" => ["bar", "baz"]}} =
               Query.parse("foo=bar%7cbaz", %{"foo" => %{type: [:array], style: :pipe_delimited}})
    end
  end

  describe "object encoding" do
    test "with form encoding" do
      assert {:ok, %{"foo" => %{"bar" => "baz"}}} =
               Query.parse("foo=bar,baz", %{"foo" => %{type: [:object], style: :form}})

      assert {:ok, %{"foo" => %{"bar" => "baz", "quux" => "mlem"}}} =
               Query.parse("foo=bar,baz,quux,mlem", %{"foo" => %{type: [:object], style: :form}})
    end

    test "with space delimited encoding" do
      assert {:ok, %{"foo" => %{"bar" => "baz"}}} =
               Query.parse("foo=bar%20baz", %{
                 "foo" => %{type: [:object], style: :space_delimited}
               })
    end

    test "with pipe delimited encoding" do
      assert {:ok, %{"foo" => %{"bar" => "baz"}}} =
               Query.parse("foo=bar%7Cbaz", %{"foo" => %{type: [:object], style: :pipe_delimited}})

      assert {:ok, %{"foo" => %{"bar" => "baz"}}} =
               Query.parse("foo=bar%7cbaz", %{"foo" => %{type: [:object], style: :pipe_delimited}})
    end
  end

  describe "deep object encoding" do
    test "works" do
      assert {:ok, %{"foo" => %{"bar" => "baz"}}} =
               Query.parse("foo[bar]=baz", %{deep_object_keys: ["foo"]})

      assert {:ok, %{"foo" => %{"bar" => "baz", "quux" => "mlem"}}} =
               Query.parse("foo[bar]=baz&foo[quux]=mlem", %{deep_object_keys: ["foo"]})
    end
  end

  describe "deep array type marshalling" do
    test "works with a generic" do
      assert {:ok, %{"foo" => [1, 2, 3]}} =
               Query.parse("foo=1,2,3", %{
                 "foo" => %{type: [:array], style: :form, elements: {[], [:integer]}}
               })
    end

    test "works with a tuple" do
      assert {:ok, %{"foo" => [1, true, "3"]}} =
               Query.parse("foo=1,true,3", %{
                 "foo" => %{
                   type: [:array],
                   style: :form,
                   elements: {[[:integer], [:boolean]], [:string]}
                 }
               })
    end

    test "works with a tuple and a generic" do
      assert {:ok, %{"foo" => [1, true, 3]}} =
               Query.parse("foo=1,true,3", %{
                 "foo" => %{
                   type: [:array],
                   style: :form,
                   elements: {[[:integer], [:boolean]], [:integer]}
                 }
               })
    end
  end

  describe "deep object type marshalling" do
    test "works with a parameter mapping" do
      assert {:ok, %{"foo" => %{"bar" => 1}}} =
               Query.parse("foo=bar,1", %{
                 "foo" => %{type: [:object], style: :form, parameters: {%{"bar" => [:integer]}, %{}, [:string]}}
               })
    end

    test "works with a regex mapping" do
      assert {:ok, %{"foo" => %{"bar" => 1}}} =
               Query.parse("foo=bar,1", %{
                 "foo" => %{type: [:object], style: :form, parameters: {%{}, %{~r/b.*/ => [:integer]}, [:string]}}
               })
    end

    test "works with a default mapping" do
      assert {:ok, %{"foo" => %{"bar" => 1}}} =
               Query.parse("foo=bar,1", %{
                 "foo" => %{type: [:object], style: :form, parameters: {%{}, %{}, [:integer]}}
               })
    end
  end
end
