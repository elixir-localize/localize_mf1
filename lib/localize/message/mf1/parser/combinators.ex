defmodule Localize.Message.MF1.Parser.Combinators do
  @moduledoc false

  # The ICU MessageFormat 1 grammar, ported from `ex_cldr_messages` 2.0.1
  # (`Cldr.Message.V1.Parser.Combinator`). Grammar comments quote ICU's
  # `MessageFormat` documentation. Unlike the original, nothing here makes an
  # atom from message text (a message is untrusted input), a missing `other`
  # clause is returned as an error rather than raised, and the `plural`
  # options are ICU's `offset:` only.

  import NimbleParsec

  @syntax_characters [?{, ?}]
  @plural_syntax_characters [?#, ?{, ?}]

  # Characters an argument name may not contain: Pattern_Syntax and
  # Pattern_White_Space (see `arg_name/0`).
  @not_name_characters [
    {:not, 0x00..0x2F},
    {:not, 0x3A..0x40},
    {:not, 0x5B..0x5E},
    {:not, 0x60},
    {:not, 0x7B..0x7F},
    {:not, 0x85},
    {:not, 0xA1..0xA7},
    {:not, 0xA9},
    {:not, 0xAB..0xAC},
    {:not, 0xAE},
    {:not, 0xB0..0xB1},
    {:not, 0xB6},
    {:not, 0xBB},
    {:not, 0xBF},
    {:not, 0xD7},
    {:not, 0xF7},
    {:not, 0x200E..0x200F},
    {:not, 0x2010..0x2029},
    {:not, 0x2030..0x203E},
    {:not, 0x2041..0x2053},
    {:not, 0x2055..0x205E},
    {:not, 0x2190..0x245F},
    {:not, 0x2500..0x2775},
    {:not, 0x2794..0x2BFF},
    {:not, 0x2E00..0x2E7F},
    {:not, 0x3001..0x3003},
    {:not, 0x3008..0x3020},
    {:not, 0x3030},
    {:not, 0xFD3E..0xFD3F},
    {:not, 0xFE45..0xFE46}
  ]

  def message do
    optional(message_text())
    |> repeat(argument() |> concat(message_text()))
    |> label("a MessageFormat 1 message")
  end

  def message_text do
    repeat(literal())
  end

  def plural_message do
    optional(plural_message_text())
    |> repeat(argument() |> concat(plural_message_text()))
    |> label("a plural or selectordinal clause")
  end

  def plural_message_text do
    choice([plural_literal(), arg_value()])
    |> repeat()
  end

  # Text up to the next brace. A quoted syntax character ('{') and a doubled
  # apostrophe ('') are literal; any other apostrophe is itself, as in ICU's
  # default apostrophe mode, so "don't" needs no escaping.
  def literal do
    choice([
      escaped_string(),
      escaped_single_quote(),
      utf8_char([{:not, ?{}, {:not, ?}}])
    ])
    |> times(min: 1)
    |> reduce(:literal)
  end

  # In a plural or selectordinal clause `#` is the number, so it ends text.
  # Quoting is the same as in other text, checked at every character so that
  # a doubled or quoting apostrophe mid-text is not taken as plain text.
  def plural_literal do
    choice([
      escaped_string(@plural_syntax_characters),
      escaped_single_quote(),
      utf8_char([{:not, ?{}, {:not, ?}}, {:not, ?#}])
    ])
    |> times(min: 1)
    |> reduce(:literal)
  end

  def literal(chars) do
    {:literal, List.to_string(chars)}
  end

  def arg_value do
    utf8_char([?#])
    |> replace(:value)
  end

  # A quote starts quoted text only before a syntax character: `{` or `}`,
  # and `#` in a plural or selectordinal clause, where it is special. So, as
  # in ICU, `'#'` outside those clauses is text with its apostrophes.
  def escaped_string(syntax_characters \\ @syntax_characters) do
    choice([
      escaped_single_quote(),
      ignore(ascii_char([?']))
      |> concat(ascii_char(syntax_characters))
      |> repeat(non_closing_quote())
      |> ignore(ascii_char([?']))
    ])
    |> times(min: 1)
  end

  def escaped_single_quote do
    string("''")
    |> replace("'")
  end

  def non_closing_quote do
    choice([
      string("''") |> replace("'"),
      utf8_char([{:not, ?'}])
    ])
  end

  def whitespace do
    times(ascii_char([?\s, ?\t, ?\n, ?\r]), min: 1)
  end

  def optional_whitespace do
    ignore(optional(whitespace()))
  end

  def left_brace do
    optional_whitespace()
    |> ignore(utf8_char([?{]))
  end

  def right_brace do
    optional_whitespace()
    |> ignore(utf8_char([?}]))
  end

  def comma do
    optional_whitespace()
    |> ignore(utf8_char([?,]))
    |> concat(optional_whitespace())
  end

  # argument = noneArg | simpleArg | complexArg
  def argument do
    choice([
      none_argument(),
      simple_format(),
      complex_argument()
    ])
  end

  # noneArg = '{' argNameOrNumber '}'
  def none_argument do
    left_brace()
    |> concat(arg_name_or_number())
    |> concat(right_brace())
  end

  # simpleArg = '{' argNameOrNumber ',' argType [',' argStyle] '}'
  def simple_format do
    left_brace()
    |> concat(arg_name_or_number())
    |> concat(comma())
    |> concat(arg_type())
    |> optional(comma() |> concat(arg_style()))
    |> concat(right_brace())
    |> reduce(:simple_format)
  end

  def simple_format([argument, type]) do
    {:simple_format, argument, type}
  end

  def simple_format([argument, type, style]) do
    {:simple_format, argument, type, style}
  end

  # complexArg = pluralArg | selectArg | selectordinalArg
  def complex_argument do
    choice([
      plural_argument(),
      select_argument(),
      select_ordinal_argument()
    ])
  end

  # pluralArg = '{' argNameOrNumber ',' "plural" ',' pluralStyle '}'
  def plural_argument do
    left_brace()
    |> concat(arg_name_or_number())
    |> concat(comma())
    |> ignore(keyword_argument("plural"))
    |> concat(plural_style())
    |> concat(right_brace())
    |> reduce(:plural)
  end

  def plural([argument, options, clauses]) do
    {:plural, argument, options, clauses}
  end

  # selectArg = '{' argNameOrNumber ',' "select" ',' selectStyle '}'
  def select_argument do
    left_brace()
    |> concat(arg_name_or_number())
    |> concat(comma())
    |> ignore(keyword_argument("select"))
    |> concat(comma())
    |> concat(select_style())
    |> concat(right_brace())
    |> reduce(:select)
  end

  def select([argument, clauses]) do
    {:select, argument, clauses}
  end

  # selectordinalArg = '{' argNameOrNumber ',' "selectordinal" ',' pluralStyle '}'
  def select_ordinal_argument do
    left_brace()
    |> concat(arg_name_or_number())
    |> concat(comma())
    |> ignore(keyword_argument("selectordinal"))
    |> concat(plural_style())
    |> concat(right_brace())
    |> reduce(:select_ordinal)
  end

  def select_ordinal([argument, options, clauses]) do
    {:select_ordinal, argument, options, clauses}
  end

  def keyword_argument(type) do
    optional_whitespace()
    |> string(type)
    |> concat(optional_whitespace())
  end

  # selectStyle = (selector '{' message '}')+
  def select_style do
    times(
      wrap(
        choice_selector()
        |> concat(left_brace())
        |> parsec(:message)
        |> concat(right_brace())
      ),
      min: 1
    )
    |> post_traverse({__MODULE__, :clauses, ["other"]})
  end

  # pluralStyle = [offsetValue] (selector '{' message '}')+
  def plural_style do
    plural_options()
    |> optional(comma())
    |> concat(
      times(
        wrap(
          plural_selector()
          |> concat(left_brace())
          |> parsec(:plural_message)
          |> concat(right_brace())
        ),
        min: 1
      )
      |> post_traverse({__MODULE__, :clauses, [:other]})
    )
  end

  # The clauses of a selector as a map of selector to message, which must
  # have an `other` clause and, as in ICU, no selector twice.
  def clauses(rest, clauses, context, _line, _offset, other) do
    map = Map.new(clauses, fn [selector | message] -> {selector, message} end)

    cond do
      map_size(map) != length(clauses) ->
        {:error, "a plural, select or selectordinal argument has a selector twice"}

      not Map.has_key?(map, other) ->
        {:error, "a plural, select or selectordinal argument has no other clause"}

      true ->
        {rest, [map], context}
    end
  end

  def plural_options do
    repeat(comma() |> concat(offset_value()))
    |> reduce(:plural_options)
  end

  def plural_options(offsets) do
    Enum.map(offsets, fn offset -> {:offset, offset} end)
  end

  # offsetValue = "offset:" number
  def offset_value do
    optional_whitespace()
    |> ignore(string("offset:"))
    |> concat(optional_whitespace())
    |> integer(min: 1)
  end

  # selector = explicitValue | keyword
  def plural_selector do
    optional_whitespace()
    |> choice([explicit_value(), keyword()])
    |> concat(optional_whitespace())
  end

  # A select clause's selector: any word up to white space or a brace.
  def choice_selector do
    optional_whitespace()
    |> utf8_string([{:not, ?\s}, {:not, ?\n}, {:not, ?\t}, {:not, ?\r}, {:not, ?{}], min: 1)
    |> concat(optional_whitespace())
  end

  # explicitValue = '=' number  // adjacent, no white space in between
  def explicit_value do
    ignore(string("="))
    |> integer(min: 1)
  end

  # keyword = zero | one | two | few | many | other
  def keyword do
    choice([
      string("zero") |> replace(:zero),
      string("one") |> replace(:one),
      string("two") |> replace(:two),
      string("few") |> replace(:few),
      string("many") |> replace(:many),
      string("other") |> replace(:other)
    ])
  end

  def arg_name_or_number do
    optional_whitespace()
    |> choice([arg_number(), arg_name()])
    |> concat(optional_whitespace())
  end

  def arg_number do
    integer(min: 1)
    |> unwrap_and_tag(:pos_arg)
  end

  # argName = [^[[:Pattern_Syntax:][:Pattern_White_Space:]]]+, as in ICU,
  # so a name may be written in any script. Both properties are immutable
  # under Unicode's stability policy, so their ranges are written out here.
  # An argument number (argNameOrNumber) is tried first.
  def arg_name do
    utf8_string(@not_name_characters, min: 1)
    |> unwrap_and_tag(:named_arg)
  end

  # argType = "number" | "date" | "time" | "spellout" | "ordinal" | "duration",
  # with "datetime", "unit", "list" and "money" added as ex_cldr_messages does.
  # "datetime" is tried before "date", of which it is an extension.
  def arg_type do
    optional_whitespace()
    |> choice([
      string("number") |> replace(:number),
      string("datetime") |> replace(:datetime),
      string("date") |> replace(:date),
      string("time") |> replace(:time),
      string("spellout") |> replace(:spellout),
      string("ordinal") |> replace(:ordinal),
      string("unit") |> replace(:unit),
      string("list") |> replace(:list),
      string("money") |> replace(:money)
    ])
    |> concat(optional_whitespace())
  end

  # argStyle = "short" | "medium" | "long" | "full" | "integer" | "currency" |
  # "percent" | argStyleText | "::" argSkeletonText. The longer keyword of a
  # shared prefix is tried first ("or_narrow" before "or").
  def arg_style do
    optional_whitespace()
    |> choice([
      style_keyword("integer", :integer),
      style_keyword("currency", :currency),
      style_keyword("percent", :percent),
      style_keyword("permille", :permille),
      style_keyword("verbose", :verbose),
      style_keyword("year", :year),
      style_keyword("ordinal", :ordinal),
      style_keyword("short", :short),
      style_keyword("medium", :medium),
      style_keyword("long", :long),
      style_keyword("full", :full),
      style_keyword("or_narrow", :or_narrow),
      style_keyword("or_short", :or_short),
      style_keyword("or", :or),
      style_keyword("standard_narrow", :standard_narrow),
      style_keyword("standard_short", :standard_short),
      style_keyword("standard", :standard),
      style_keyword("unit_narrow", :unit_narrow),
      style_keyword("unit_short", :unit_short),
      style_keyword("unit", :unit),
      skeleton_text(),
      named_style(),
      style_text()
    ])
    |> concat(optional_whitespace())
  end

  # A keyword style is a whole word: "longer" is style text, not "long".
  def style_keyword(text, atom) do
    string(text)
    |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
    |> replace(atom)
  end

  # `:name` names a format the caller supplies. It stays a string: an atom
  # made from message text would grow the atom table without bound.
  def named_style do
    ignore(ascii_char([?:]))
    |> utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 1)
    |> unwrap_and_tag(:named_format)
  end

  # `::` starts skeleton text, which is tagged so that it is not read as a
  # pattern: the skeleton `::yMMMd` and the pattern `yMMMd` differ.
  def skeleton_text do
    ignore(string("::"))
    |> concat(style_text())
    |> unwrap_and_tag(:skeleton)
  end

  # Any other style is pattern text, to the closing brace.
  def style_text do
    repeat(choice([escaped_string(), utf8_char([{:not, ?}}, {:not, ?\n}])]))
    |> reduce({List, :to_string, []})
  end
end
