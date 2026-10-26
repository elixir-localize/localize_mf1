defmodule Localize.Message.MF1.CldrMessagesTest do
  # The MessageFormat 1 tests of `ex_cldr_messages` 2.0.1
  # (`test/cldr_messages_test.exs`), ported with their expected results so
  # that messages migrate unchanged. Differences are noted where they occur.
  use ExUnit.Case, async: true

  alias Localize.Message.MF1
  alias Localize.Message.MF1.ParseError
  alias Localize.Message.MF1.PositionalArgumentError

  test "simple formatting of a number" do
    assert MF1.format("You have {number} jelly beans", number: 1234) ==
             {:ok, "You have 1,234 jelly beans"}

    assert MF1.format("You have {number} jelly beans", number: Decimal.new(1234)) ==
             {:ok, "You have 1,234 jelly beans"}
  end

  test "formatting a unit" do
    {:ok, height} = Localize.Unit.new(1.8, "meter")

    assert MF1.format("I am {height} tall", height: height) == {:ok, "I am 1.8 meters tall"}
  end

  test "formatting money" do
    assert MF1.format("I have {money}", money: Money.new(:USD, 123)) == {:ok, "I have $123.00"}

    assert MF1.format("I have {money, money, short}", money: Money.new(:USD, 123)) ==
             {:ok, "I have $123"}
  end

  test "arguments are inserted positionally" do
    assert MF1.format(
             "{0} {1, plural,
      one {est {2, select, female {allée} other  {allé}}}
      other {sont {2, select, female {allées} other {allés}}}
    } à {3}",
             ["You", 3, "female", "three"],
             []
           ) ==
             {:ok, "You sont allées à three"}
  end

  test "keyword selectors" do
    assert MF1.format(
             "You have {item_count, plural,
        =0 {no items}
        one {1 item}
        other {{item_count} items}
    }",
             item_count: 1,
             items: 3
           ) == {:ok, "You have 1 item"}
  end

  test "numbers in percent format" do
    assert MF1.format(
             "{taxable_area, select,
        yes {An additional {tax_rate, number, percent} tax will be collected.}
        other {No taxes apply.}
    }",
             taxable_area: "yes",
             tax_rate: 0.15
           ) ==
             {:ok, "An additional 15% tax will be collected."}
  end

  test "select other category" do
    assert MF1.format(
             "{taxable_area, select,
        yes {An additional {tax_rate, number, percent} tax will be collected.}
        other {No taxes apply.}
    }",
             taxable_area: "no",
             tax_rate: 0.15
           ) == {:ok, "No taxes apply."}
  end

  test "explicit selector" do
    assert MF1.format(
             "You have {item_count, plural,
        =0 {no items}
        one {1 item}
        other {{item_count} items}
    }",
             item_count: 0
           ) == {:ok, "You have no items"}
  end

  test "other keyword selector" do
    assert MF1.format(
             "You have {item_count, plural,
        =0 {no items}
        one {1 item}
        other {{item_count} items}
    }",
             item_count: 2
           ) == {:ok, "You have 2 items"}
  end

  @party "{gender_of_host, select,
      female {
        {num_guests, plural, offset: 1
          =0 {{host} does not give a party.}
          =1 {{host} invites {guest} to her party.}
          =2 {{host} invites {guest} and one other person to her party.}
          other {{host} invites {guest} and # other people to her party.}}}
      male {
        {num_guests, plural, offset: 1
          =0 {{host} does not give a party.}
          =1 {{host} invites {guest} to his party.}
          =2 {{host} invites {guest} and one other person to his party.}
          other {{host} invites {guest} and # other people to his party.}}}
      other {
        {num_guests, plural, offset: 1
          =0 {{host} does not give a party.}
          =1 {{host} invites {guest} to their party.}
          =2 {{host} invites {guest} and one other person to their party.}
          other {{host} invites {guest} and # other people to their party.}}}}"

  test "nested complex arguments" do
    assert MF1.format(@party, gender_of_host: "male", host: "kip", guest: "jim", num_guests: 1) ==
             {:ok, "kip invites jim to his party."}
  end

  test "offset" do
    assert MF1.format(@party, gender_of_host: "male", host: "kip", guest: "jim", num_guests: 4) ==
             {:ok, "kip invites jim and 3 other people to his party."}
  end

  test "select ordinal" do
    assert MF1.format(
             "It's my cat's {year, selectordinal,
        one {#st}
        two {#nd}
        few {#rd}
        other {#th}
    } birthday!",
             year: 3
           ) == {:ok, "It's my cat's 3rd birthday!"}
  end

  test "decimal selector" do
    assert MF1.format("{a, plural, =0 {zero} other {other #}}", a: Decimal.new(2)) ==
             {:ok, "other 2"}

    assert MF1.format("{a, plural, =0 {zero} other {other #}}", a: Decimal.new(0)) ==
             {:ok, "zero"}
  end

  # `ex_cldr_messages` returned `{:error, {Cldr.Message.ParseError, message}}`;
  # Localize returns the exception.
  test "plural, select and selectordinal with no other argument is an error" do
    for message <- [
          "{num, plural, =0 {it's zero}}",
          "{num, select, zero {it's zero}}",
          "{num, selectordinal, =0 {it's zero}}"
        ] do
      assert {:error, %ParseError{reason: reason}} = MF1.format(message, num: 1)
      assert reason =~ "no other clause"
    end
  end

  test "number formatting with tuple format" do
    assert MF1.format("this is {one, number, currency}", one: {1, currency: :MXP}) ==
             {:ok, "this is MXP 1.00"}
  end

  test "Extract variable bindings" do
    assert MF1.bindings(@party) == ["gender_of_host", "num_guests", "host", "guest"]
  end

  test "Extract variable bindings from simple_format messages" do
    assert MF1.bindings("Watched {percentage_watched, number, percent} of {video_name}") ==
             ["video_name", "percentage_watched"]
  end

  test "Extract variable bindings from simple_format messages with no style" do
    assert MF1.bindings("Hello, {num, number}") == ["num"]
  end

  # `ex_cldr_messages` returned
  # `{:error, {Cldr.Message.PositionalArgsNotPermitted, message}}`.
  test "That positional arguments can be prohibited" do
    assert MF1.format("Can you see {0}", ["me"], allow_positional_args: false) ==
             {:error, PositionalArgumentError.exception(arguments: [0])}
  end

  test "Ordinal formatting" do
    assert MF1.format("{ordering,number,:spellout_ordinal} jab date", ordering: 1) ==
             {:ok, "first jab date"}

    assert MF1.format("{ordering,number,ordinal} jab date", ordering: 1) ==
             {:ok, "1st jab date"}
  end

  test "Binding syntax escaping is correct" do
    assert MF1.format("''", []) == {:ok, "'"}
    assert MF1.format("'{foo}'", []) == {:ok, "{foo}"}
    assert MF1.format("This '{isn''t}' obvious") == {:ok, "This {isn't} obvious"}
  end

  test "canonical message formatting" do
    message1 =
      "It's my cat's {year, selectordinal, one {#st} two {#nd} few {#rd} other {#th}} birthday!"

    message2 = "It's my cat's {year, selectordinal,
        one {#st}
        two {#nd}
        few {#rd}
        other {#th}
    } birthday!"

    assert MF1.canonical_message(message1) == MF1.canonical_message(message2)
  end

  test "jaro distance" do
    message1 =
      "It's my cat's {year, selectordinal, one {#st} two {#nd} few {#rd} other {#th}} birthday!"

    message2 = "It's my cat's {year, selectordinal,
        one {#st}
        two {#nd}
        few {#rd}
        other {#th}
    } birthday!"

    assert MF1.jaro_distance(message1, message2) == {:ok, 1.0}
    assert MF1.jaro_distance!(message1, message2) == 1.0
  end
end
