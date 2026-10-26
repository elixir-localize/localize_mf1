defmodule Localize.Message.MF1.Printer do
  @moduledoc false

  # Prints a parsed MessageFormat 1 message back to a string: the canonical
  # form that `Localize.Message.MF1.canonical_message/2` and the `~M` sigil
  # return, which Gettext uses as a message id.
  #
  # The output is byte for byte that of `ex_cldr_messages` 2.0.1
  # (`Cldr.Message.V1.Print`) wherever that printed a message that parses
  # again, so that msgids carry over unchanged. It differs only where the
  # original raised or printed text that does not parse: a formatted
  # argument with no style, a `selectordinal` with an offset, a nested
  # `plural` with no offset when pretty printed, nesting deeper than five
  # levels, and a literal with a syntax character after its first character.

  @syntax_characters ["{", "}"]
  @plural_syntax_characters ["{", "}", "#"]

  @doc """
  Prints a parsed message. The option `:pretty` indents nested selectors.

  """
  @spec to_string(list(), Keyword.t()) :: String.t()
  def to_string(parsed, options \\ []) do
    options = %{pretty: Keyword.get(options, :pretty, false), level: 0, plural: false}

    parsed
    |> print(options)
    |> IO.iodata_to_binary()
  end

  defp print([], _options) do
    []
  end

  defp print([head], options) do
    print(head, options)
  end

  # Pretty printing puts a nested selector on a line of its own, so the
  # line break and indent that end the text before it are dropped.
  defp print([{:literal, literal}, nested | _rest] = parts, %{pretty: true} = options)
       when elem(nested, 0) in [:select, :plural, :select_ordinal] do
    [_literal | rest] = parts
    trimmed = Regex.replace(~r/\n[^\S\n]*\z/, literal, "")
    [print({:literal, trimmed}, options), print(rest, options)]
  end

  defp print([head | rest], options) do
    [print(head, options), print(rest, options)]
  end

  defp print({:literal, literal}, options) do
    literal
    |> String.replace("'", "''")
    |> quote_syntax(options)
  end

  defp print(:value, _options) do
    "#"
  end

  defp print({:named_arg, name}, _options) do
    [?{, name, ?}]
  end

  defp print({:pos_arg, index}, _options) do
    [?{, Integer.to_string(index), ?}]
  end

  defp print({:simple_format, argument, type}, _options) do
    [?{, argument_name(argument), ", ", Atom.to_string(type), ?}]
  end

  defp print({:simple_format, argument, type, style}, _options) do
    [?{, argument_name(argument), ", ", Atom.to_string(type), ", ", style(style), ?}]
  end

  defp print({:select, argument, clauses}, options) do
    selector(argument, "select", [], clauses, options)
  end

  defp print({:plural, argument, plural_options, clauses}, options) do
    selector(argument, "plural", plural_options, clauses, options)
  end

  defp print({:select_ordinal, argument, plural_options, clauses}, options) do
    selector(argument, "selectordinal", plural_options, clauses, options)
  end

  # The spacing differs between selectors and between levels; it is kept
  # as `ex_cldr_messages` printed it, since printed messages are msgids.
  defp selector(argument, keyword, [], clauses, %{pretty: true, level: 0} = options) do
    [
      ?{,
      argument_name(argument),
      ", ",
      keyword,
      ?,,
      clauses(clauses, keyword, nested(options)),
      ?}
    ]
  end

  defp selector(argument, "select", [], clauses, %{pretty: true} = options) do
    [
      ?\n,
      pad(options.level),
      ?{,
      argument_name(argument),
      ", select, ",
      clauses(clauses, "select", nested(options)),
      ?}
    ]
  end

  defp selector(argument, keyword, [], clauses, %{pretty: true} = options) do
    [
      ?\n,
      pad(options.level),
      ?{,
      argument_name(argument),
      ", ",
      keyword,
      ?,,
      clauses(clauses, keyword, nested(options)),
      ?}
    ]
  end

  defp selector(argument, keyword, [], clauses, options) do
    [?{, argument_name(argument), ", ", keyword, ", ", clauses(clauses, keyword, options), ?}]
  end

  defp selector(argument, keyword, plural_options, clauses, %{pretty: true} = options) do
    [
      line_start(options),
      ?{,
      argument_name(argument),
      ", ",
      keyword,
      ", ",
      plural_options(plural_options),
      clauses(clauses, keyword, nested(options)),
      ?}
    ]
  end

  defp selector(argument, keyword, plural_options, clauses, options) do
    [
      ?{,
      argument_name(argument),
      ", ",
      keyword,
      ", ",
      plural_options(plural_options),
      ?\s,
      clauses(clauses, keyword, options),
      ?}
    ]
  end

  defp line_start(%{level: 0}) do
    []
  end

  defp line_start(%{level: level}) do
    [?\n, pad(level)]
  end

  defp clauses(clauses, keyword, %{pretty: true} = options) do
    clause_options = %{nested(options) | plural: keyword != "select"}

    clauses
    |> Enum.sort(&clause_sorter/2)
    |> Enum.map(fn {selector, message} ->
      [?\n, pad(options.level), selector_text(selector), " {", print(message, clause_options), ?}]
    end)
  end

  defp clauses(clauses, keyword, options) do
    clause_options = %{options | plural: keyword != "select"}

    clauses
    |> Enum.sort(&clause_sorter/2)
    |> Enum.map(fn {selector, message} ->
      [selector_text(selector), " {", print(message, clause_options), ?}]
    end)
    |> Enum.intersperse(?\s)
  end

  defp selector_text(selector) when is_integer(selector) do
    [?=, Integer.to_string(selector)]
  end

  defp selector_text(selector) do
    Kernel.to_string(selector)
  end

  defp plural_options(plural_options) do
    Enum.map(plural_options, fn {:offset, offset} -> ["offset: ", Integer.to_string(offset)] end)
  end

  defp argument_name({:named_arg, name}) do
    name
  end

  defp argument_name({:pos_arg, index}) do
    Integer.to_string(index)
  end

  defp style({:named_format, name}) do
    [?:, name]
  end

  defp style({:skeleton, skeleton}) do
    ["::", skeleton]
  end

  defp style(style) do
    Kernel.to_string(style)
  end

  # Text from the first syntax character on is quoted, so a literal that
  # starts with `{` is quoted whole, as `ex_cldr_messages` did. `#` is a
  # syntax character only in a plural or selectordinal clause; elsewhere
  # `'#` would not start a quote, and the apostrophes would be text.
  defp quote_syntax(literal, options) do
    case :binary.match(literal, syntax_characters(options)) do
      {position, _length} ->
        text = binary_part(literal, 0, position)
        quoted = binary_part(literal, position, byte_size(literal) - position)
        [text, ?', quoted, ?']

      :nomatch ->
        literal
    end
  end

  defp syntax_characters(%{plural: true}) do
    @plural_syntax_characters
  end

  defp syntax_characters(_options) do
    @syntax_characters
  end

  defp nested(options) do
    %{options | level: options.level + 1}
  end

  defp pad(level) do
    String.duplicate("  ", level)
  end

  # The clause order of `ex_cldr_messages`: explicit values first, then
  # `one`, `two`, `few`, `many`, the rest in term order, and `other` last.
  defp clause_sorter({:one, _}, {b, _}) when is_atom(b) do
    true
  end

  defp clause_sorter({a, _}, {:one, _}) when is_atom(a) do
    false
  end

  defp clause_sorter({a, _}, {:few, _}) when a in [:one, :two] do
    true
  end

  defp clause_sorter({:few, _}, {b, _}) when b in [:one, :two] do
    false
  end

  defp clause_sorter({a, _}, {:many, _}) when a in [:one, :two, :few] do
    true
  end

  defp clause_sorter({:many, _}, {b, _}) when b in [:one, :two, :few] do
    false
  end

  defp clause_sorter({:other, _}, {_b, _}) do
    false
  end

  defp clause_sorter({a, _}, {b, _}) do
    a <= b
  end
end
