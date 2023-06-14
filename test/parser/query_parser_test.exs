defmodule ApicalTest.Parser.QueryParserTest do
  use ExUnit.Case, async: true

  alias Apical.Parser.Query

  describe "for the query parser - basics" do
    test "it works with empty string" do
      assert {:ok, %{}} = Query.parse("")
    end

    test "it works with basic one key parameter" do
      assert {:ok, %{"foo" => "bar"}} = Query.parse("foo=bar", %{"foo" => %{}})
    end

    test "it works with basic multi key thing" do
      assert {:ok, %{"foo" => "bar"}} =
               Query.parse("foo=bar&baz=quux", %{"foo" => %{}, "baz" => %{}})
    end

    test "percent encoding works" do
      assert {:ok, %{"foo" => "bar baz"}} = Query.parse("foo=bar%20baz", %{"foo" => %{}})
    end
  end

  describe "exceptions with strange value strings" do
    test "value with no key defaults to empty string" do
      assert {:ok, %{"foo" => ""}} = Query.parse("foo=", %{"foo" => %{}})
    end

    test "standalone value with no key defaults to empty string" do
      assert {:ok, %{"foo" => ""}} = Query.parse("foo", %{"foo" => %{}})
    end
  end

  describe "array encoding" do
    test "with form encoding" do
      assert {:ok, %{"foo" => ["bar", "baz"]}} =
               Query.parse("foo=bar,baz", %{"foo" => %{type: [:array], style: :simple}})
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
               Query.parse("foo=bar,baz", %{"foo" => %{type: [:object], style: :simple}})

      assert {:ok, %{"foo" => %{"bar" => "baz", "quux" => "mlem"}}} =
               Query.parse("foo=bar,baz,quux,mlem", %{
                 "foo" => %{type: [:object], style: :simple}
               })
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
                 "foo" => %{type: [:array], style: :simple, elements: {[], [:integer]}}
               })
    end

    test "works with a tuple" do
      assert {:ok, %{"foo" => [1, true, "3"]}} =
               Query.parse("foo=1,true,3", %{
                 "foo" => %{
                   type: [:array],
                   style: :simple,
                   elements: {[[:integer], [:boolean]], [:string]}
                 }
               })
    end

    test "works with a tuple and a generic" do
      assert {:ok, %{"foo" => [1, true, 3]}} =
               Query.parse("foo=1,true,3", %{
                 "foo" => %{
                   type: [:array],
                   style: :simple,
                   elements: {[[:integer], [:boolean]], [:integer]}
                 }
               })
    end
  end

  describe "deep object type marshalling" do
    test "works with a parameter mapping" do
      assert {:ok, %{"foo" => %{"bar" => 1}}} =
               Query.parse("foo=bar,1", %{
                 "foo" => %{
                   type: [:object],
                   style: :simple,
                   properties: {%{"bar" => [:integer]}, %{}, [:string]}
                 }
               })
    end

    test "works with a regex mapping" do
      assert {:ok, %{"foo" => %{"bar" => 1}}} =
               Query.parse("foo=bar,1", %{
                 "foo" => %{
                   type: [:object],
                   style: :simple,
                   properties: {%{}, %{~r/b.*/ => [:integer]}, [:string]}
                 }
               })
    end

    test "works with a default mapping" do
      assert {:ok, %{"foo" => %{"bar" => 1}}} =
               Query.parse("foo=bar,1", %{
                 "foo" => %{
                   type: [:object],
                   style: :simple,
                   properties: {%{}, %{}, [:integer]}
                 }
               })
    end
  end

  describe "exploded types" do
    test "works for array" do
      assert {:ok, %{"foo" => ["bar", "baz"]}} =
               Query.parse("foo=bar&foo=baz", %{
                 "foo" => %{type: [:array]},
                 exploded_array_keys: ["foo"]
               })
    end

    test "works for object" do
      assert {:ok, %{"foo" => %{"bar" => "baz", "quux" => "mlem"}}} =
               Query.parse("foo[bar]=baz&foo[quux]=mlem", %{
                 "foo" => %{type: [:object]},
                 deep_object_keys: ["foo"]
               })
    end

    test "works for type marshalling array" do
      assert {:ok, %{"foo" => [1, true, 2]}} =
               Query.parse("foo=1&foo=true&foo=2", %{
                 "foo" => %{type: [:array], elements: {[[:integer], [:boolean]], [:integer]}},
                 exploded_array_keys: ["foo"]
               })
    end

    test "works for type marshalling object" do
      assert {:ok, %{"foo" => %{"foo" => 1, "bar" => true, "quux" => 3}}} =
               Query.parse("foo[foo]=1&foo[bar]=true&foo[quux]=3", %{
                 "foo" => %{
                   type: [:object],
                   properties: {%{"foo" => [:integer]}, %{~r/b.*/ => [:boolean]}, [:integer]}
                 },
                 deep_object_keys: ["foo"]
               })
    end
  end
end
