defmodule Localize.Message.MF1.Parser do
  @moduledoc """
  Parses an ICU MessageFormat 1 message into the list of parts that
  `Localize.Message.MF1` formats.

  A parsed message is a list whose elements are:

  * `{:literal, string}` — text, with quoting resolved.

  * `{:named_arg, name}` or `{:pos_arg, index}` — an argument, by name
    (a string) or by position.

  * `{:simple_format, argument, type}` and `{:simple_format, argument, type,
    style}` — a formatted argument such as `{count, number, integer}`. The type
    is one of `:number`, `:date`, `:time`, `:datetime`, `:spellout`,
    `:ordinal`, `:unit`, `:list` or `:money`. The style is a keyword atom,
    `{:named_format, name}` for a `:name` style, `{:skeleton, text}` for a
    `::skeleton` style, or pattern text.

  * `{:plural, argument, options, clauses}` and `{:select_ordinal, argument,
    options, clauses}` — the options are `[offset: n]` when an offset is given,
    and the clauses map `:zero`, `:one`, `:two`, `:few`, `:many`, `:other` or
    an explicit integer value to a message.

  * `{:select, argument, clauses}` — the clauses map each selector string to a
    message.

  * `:value` — `#` in a `plural` or `selectordinal` clause, the number being
    selected on.

  """

  import NimbleParsec
  import Localize.Message.MF1.Parser.Combinators

  alias Localize.Message.MF1.ParseError
  alias Localize.Message.MF1.PositionalArgumentError

  @typedoc "A parsed MessageFormat 1 message."
  @type t :: [term()]

  defparsecp(:message, message())
  defparsecp(:plural_message, plural_message())

  @doc """
  Parses a MessageFormat 1 message.

  ### Arguments

  * `message` is a MessageFormat 1 message string.

  * `options` is a keyword list of options.

  ### Options

  * `:allow_positional_args` is `true` (the default) to accept positional
    arguments such as `{0}`, or `false` to return an error for them.

  ### Returns

  * `{:ok, parsed_message}`, or

  * `{:error, %Localize.Message.MF1.ParseError{}}` when the message cannot
    be parsed, or is not a string, or

  * `{:error, %Localize.Message.MF1.PositionalArgumentError{}}` when it uses
    positional arguments and they are not allowed.

  ### Examples

      iex> Localize.Message.MF1.Parser.parse("Hello {name}!")
      {:ok, [literal: "Hello ", named_arg: "name", literal: "!"]}

      iex> Localize.Message.MF1.Parser.parse("{count, plural, one {# item} other {# items}}")
      {:ok,
       [
         {:plural, {:named_arg, "count"}, [],
          %{one: [:value, {:literal, " item"}], other: [:value, {:literal, " items"}]}}
       ]}

  """
  @spec parse(term(), Keyword.t()) ::
          {:ok, t()} | {:error, ParseError.t() | PositionalArgumentError.t()}
  def parse(message, options \\ [])

  def parse(message, options) when is_binary(message) and is_list(options) do
    with {:ok, parsed} <- run(message) do
      parsed
      |> normalize_whitespace()
      |> check_positional_args(Keyword.get(options, :allow_positional_args, true))
    end
  end

  def parse(message, _options) do
    {:error, ParseError.exception(reason: "a message is a string, got #{inspect(message)}")}
  end

  defp run(message) do
    case message(message) do
      {:ok, parsed, "", _context, _line, _offset} ->
        {:ok, parsed}

      {:ok, _parsed, rest, _context, _line, offset} ->
        {:error, ParseError.exception(reason: unparsed(rest), position: offset + 1)}

      {:error, reason, _rest, _context, _line, offset} ->
        {:error, ParseError.exception(reason: reason, position: offset + 1)}
    end
  end

  defp unparsed(rest) do
    "unexpected #{inspect(String.slice(rest, 0, 20))}"
  end

  # White space alone before a nested plural, select or selectordinal in a
  # clause is layout, as in `{a, select, x { {b, plural, …} } …}`, and is
  # dropped, at every depth.
  defp normalize_whitespace(parts) when is_list(parts) do
    Enum.map(parts, &normalize_part/1)
  end

  defp normalize_part({:select, argument, clauses}) do
    {:select, argument, normalize_clauses(clauses)}
  end

  defp normalize_part({complex, argument, options, clauses})
       when complex in [:plural, :select_ordinal] do
    {complex, argument, options, normalize_clauses(clauses)}
  end

  defp normalize_part(part) do
    part
  end

  defp normalize_clauses(clauses) do
    Map.new(clauses, fn {selector, message} -> {selector, normalize_clause(message)} end)
  end

  defp normalize_clause([{:literal, text}, complex | rest] = message) do
    if complex?(complex) and String.trim(text) == "" do
      normalize_whitespace([complex | rest])
    else
      normalize_whitespace(message)
    end
  end

  defp normalize_clause(message) do
    normalize_whitespace(message)
  end

  defp complex?(part) do
    match?({:select, _, _}, part) or match?({:plural, _, _, _}, part) or
      match?({:select_ordinal, _, _, _}, part)
  end

  defp check_positional_args(parsed, false) do
    case positional_args(parsed) do
      [] -> {:ok, parsed}
      arguments -> {:error, PositionalArgumentError.exception(arguments: arguments)}
    end
  end

  defp check_positional_args(parsed, _allow?) do
    {:ok, parsed}
  end

  # Every positional argument in a parsed message, at any depth.
  defp positional_args(parsed) do
    parsed
    |> collect_positional_args([])
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp collect_positional_args({:pos_arg, index}, acc) do
    [index | acc]
  end

  defp collect_positional_args(tuple, acc) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> collect_positional_args(acc)
  end

  defp collect_positional_args(%{} = map, acc) do
    map
    |> Map.values()
    |> collect_positional_args(acc)
  end

  defp collect_positional_args(list, acc) when is_list(list) do
    Enum.reduce(list, acc, &collect_positional_args/2)
  end

  defp collect_positional_args(_other, acc) do
    acc
  end
end
