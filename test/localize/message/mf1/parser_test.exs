defmodule Localize.Message.MF1.ParserTest do
  use ExUnit.Case, async: true

  alias Localize.Message.MF1.ParseError
  alias Localize.Message.MF1.Parser
  alias Localize.Message.MF1.PositionalArgumentError

  doctest Parser

  describe "arguments" do
    test "text and named arguments" do
      assert Parser.parse("Hello {name}, welcome") ==
               {:ok, [literal: "Hello ", named_arg: "name", literal: ", welcome"]}
    end

    test "positional arguments" do
      assert Parser.parse("{0} and {1}") == {:ok, [pos_arg: 0, literal: " and ", pos_arg: 1]}
    end

    test "white space around an argument name" do
      assert Parser.parse("{ name }") == {:ok, [named_arg: "name"]}
    end

    test "a name in any script, as ICU allows" do
      assert {:ok, [named_arg: "名前"]} = Parser.parse("{名前}")
      assert {:ok, [named_arg: "straße"]} = Parser.parse("{straße}")
    end

    test "a name with Pattern_Syntax or white space is not an argument" do
      for message <- ["{a-b}", "{x y}", "{a.b}", "{a«b}"] do
        assert {:error, %ParseError{}} = Parser.parse(message)
      end
    end
  end

  describe "formatted arguments" do
    test "a type with no style" do
      assert Parser.parse("{count, number}") ==
               {:ok, [{:simple_format, {:named_arg, "count"}, :number}]}
    end

    test "every type" do
      for {text, type} <- [
            {"number", :number},
            {"date", :date},
            {"time", :time},
            {"datetime", :datetime},
            {"spellout", :spellout},
            {"ordinal", :ordinal},
            {"unit", :unit},
            {"list", :list},
            {"money", :money}
          ] do
        assert {:ok, [{:simple_format, {:named_arg, "x"}, ^type}]} = Parser.parse("{x, #{text}}")
      end
    end

    test "a keyword style is an atom" do
      assert Parser.parse("{n, number, integer}") ==
               {:ok, [{:simple_format, {:named_arg, "n"}, :number, :integer}]}

      assert Parser.parse("{d, date, short}") ==
               {:ok, [{:simple_format, {:named_arg, "d"}, :date, :short}]}

      assert Parser.parse("{l, list, or_narrow}") ==
               {:ok, [{:simple_format, {:named_arg, "l"}, :list, :or_narrow}]}
    end

    test "a keyword is a whole word" do
      assert Parser.parse("{d, date, longer}") ==
               {:ok, [{:simple_format, {:named_arg, "d"}, :date, "longer"}]}
    end

    test "a :name style stays a string, so no atom is made from the message" do
      name = "a_style_name_no_atom_exists_for_#{System.unique_integer([:positive])}"

      assert Parser.parse("{n, number, :#{name}}") ==
               {:ok, [{:simple_format, {:named_arg, "n"}, :number, {:named_format, name}}]}

      assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
    end

    test "pattern and skeleton text" do
      assert Parser.parse("{n, number, #,##0.0}") ==
               {:ok, [{:simple_format, {:named_arg, "n"}, :number, "#,##0.0"}]}

      assert Parser.parse("{n, number, ::currency/USD}") ==
               {:ok, [{:simple_format, {:named_arg, "n"}, :number, "currency/USD"}]}
    end
  end

  describe "plural and selectordinal" do
    test "keyword clauses and #" do
      assert Parser.parse("{n, plural, one {# item} other {# items}}") ==
               {:ok,
                [
                  {:plural, {:named_arg, "n"}, [],
                   %{one: [:value, {:literal, " item"}], other: [:value, {:literal, " items"}]}}
                ]}
    end

    test "every keyword, an explicit value and an offset" do
      message =
        "{n, plural, offset:1 =0 {none} zero {z} one {o} two {t} few {f} many {m} other {#}}"

      assert {:ok, [{:plural, {:named_arg, "n"}, [offset: 1], clauses}]} = Parser.parse(message)

      assert Map.keys(clauses) |> Enum.sort() ==
               Enum.sort([0, :zero, :one, :two, :few, :many, :other])
    end

    test "selectordinal" do
      assert {:ok, [{:select_ordinal, {:named_arg, "n"}, [], clauses}]} =
               Parser.parse("{n, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}")

      assert clauses.two == [:value, {:literal, "nd"}]
    end

    test "# is literal outside a plural clause" do
      assert Parser.parse("# {g, select, other {#}}") ==
               {:ok,
                [
                  {:literal, "# "},
                  {:select, {:named_arg, "g"}, %{"other" => [literal: "#"]}}
                ]}
    end
  end

  describe "select" do
    test "selector strings" do
      assert Parser.parse("{g, select, female {She} male {He} other {They}}") ==
               {:ok,
                [
                  {:select, {:named_arg, "g"},
                   %{
                     "female" => [literal: "She"],
                     "male" => [literal: "He"],
                     "other" => [literal: "They"]
                   }}
                ]}
    end

    test "nested selectors drop the layout white space before a nested selector" do
      message = "{a, select, x { {b, plural, one {#} other {##}}} other {o}}"

      assert Parser.parse(message) ==
               {:ok,
                [
                  {:select, {:named_arg, "a"},
                   %{
                     "x" => [
                       {:plural, {:named_arg, "b"}, [], %{one: [:value], other: [:value, :value]}}
                     ],
                     "other" => [literal: "o"]
                   }}
                ]}
    end

    test "layout white space is dropped at every depth" do
      message =
        "{a, select, other { {b, select, other { {c, plural, other {#}}}}}}"

      assert {:ok, [{:select, _, %{"other" => [{:select, _, %{"other" => [nested]}}]}}]} =
               Parser.parse(message)

      assert {:plural, {:named_arg, "c"}, [], %{other: [:value]}} = nested
    end
  end

  describe "quoting" do
    test "a quoted syntax character and a doubled apostrophe are literal" do
      assert Parser.parse("'{'literal'}' and ''") == {:ok, [literal: "{literal} and '"]}
    end

    test "an apostrophe before anything else is itself" do
      assert Parser.parse("It's {name}'s") ==
               {:ok, [literal: "It's ", named_arg: "name", literal: "'s"]}
    end

    test "a quoted # in a plural clause is literal" do
      assert {:ok, [{:plural, _, [], %{other: [literal: "#"]}}]} =
               Parser.parse("{n, plural, other {'#'}}")
    end
  end

  describe "errors" do
    test "a selector with no other clause" do
      for message <- [
            "{n, plural, one {x}}",
            "{n, selectordinal, one {x}}",
            "{g, select, male {x}}"
          ] do
        assert {:error, %ParseError{reason: reason}} = Parser.parse(message)
        assert reason =~ "no other clause"
      end
    end

    test "a selector given twice" do
      assert {:error, %ParseError{reason: reason}} =
               Parser.parse("{a, select, x {1} x {2} other {3}}")

      assert reason =~ "selector twice"
    end

    test "malformed messages give the position" do
      assert {:error, %ParseError{position: 7}} = Parser.parse("Hello {unclosed")
      assert {:error, %ParseError{position: 1}} = Parser.parse("}")
    end

    test "positional arguments can be refused" do
      assert Parser.parse("{0} {name} {1}", allow_positional_args: false) ==
               {:error, PositionalArgumentError.exception(arguments: [0, 1])}

      assert {:ok, _parsed} = Parser.parse("{name}", allow_positional_args: false)
    end

    test "a positional argument nested in a selector is found" do
      assert {:error, %PositionalArgumentError{arguments: [3]}} =
               Parser.parse("{g, select, other {{3}}}", allow_positional_args: false)
    end

    test "a message that is not a string" do
      for message <- [nil, 42, :atom, %{}, [~c"x"], {:a}] do
        assert {:error, %ParseError{position: nil}} = Parser.parse(message)
      end
    end

    test "errors have messages" do
      {:error, error} = Parser.parse("{n, plural, one {x}}")
      assert Exception.message(error) =~ "could not be parsed"

      {:error, error} = Parser.parse("{0}", allow_positional_args: false)
      assert Exception.message(error) == "Positional arguments are not permitted, found 0"
    end
  end

  test "malformed and extreme input returns a result, never raises" do
    inputs = [
      "",
      "{",
      "}",
      "{}",
      "{a,}",
      "{a, number,}",
      "{a, plural}",
      "{a, plural,}",
      "{a, select, other}",
      "{a, plural, =x {1} other {2}}",
      "{a, foo}",
      "'",
      "#",
      "\u0000{a}",
      <<255, 254>>,
      String.duplicate("x", 200_000),
      String.duplicate("{a, select, other {", 300) <> String.duplicate("}}", 300),
      String.duplicate("{", 10_000)
    ]

    for input <- inputs do
      assert {status, _result} = Parser.parse(input)
      assert status in [:ok, :error]
    end
  end
end
