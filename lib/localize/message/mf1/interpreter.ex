defmodule Localize.Message.MF1.Interpreter do
  @moduledoc false

  # Formats a parsed MessageFormat 1 message (see `Localize.Message.MF1.Parser`)
  # with Localize's formatters. Nothing here raises on a message, a binding or
  # an option: a value that cannot be formatted returns a
  # `Localize.FormatError`, and an argument with no binding is written as its
  # source text (`{name}`, as ICU does) and reported as unbound.

  alias Localize.Message.MF1.Formatter

  @typedoc "The interpreter's running output and the arguments seen so far."
  @type state :: %{output: list(), bound: list(), unbound: list()}

  @doc """
  Formats a parsed message.

  The context is a map of `:bindings`, `:locale` (a `t:Localize.LanguageTag.t/0`),
  `:options` (given to every formatter) and `:formats`.

  """
  @spec format_list(list(), map()) ::
          {:ok, list(), list(), list()}
          | {:error, list(), list(), list()}
          | {:error, Exception.t()}
  def format_list(parsed, context) do
    initial = %{output: [], bound: [], unbound: []}
    context = Map.put(context, :value, nil)

    with {:ok, state} <- interpret(parsed, context, initial) do
      result(state)
    end
  end

  defp result(%{output: output, bound: bound, unbound: unbound}) do
    iolist = Enum.reverse(output)
    bound = arguments(bound)

    case arguments(unbound) do
      [] -> {:ok, iolist, bound, []}
      unbound -> {:error, iolist, bound, unbound}
    end
  end

  defp arguments(reversed) do
    reversed
    |> Enum.reverse()
    |> Enum.uniq()
  end

  defp interpret([], _context, state) do
    {:ok, state}
  end

  defp interpret([part | rest], context, state) do
    with {:ok, state} <- interpret_part(part, context, state) do
      interpret(rest, context, state)
    end
  end

  defp interpret_part({:literal, text}, _context, state) do
    {:ok, emit(state, text)}
  end

  defp interpret_part(:value, %{value: nil}, state) do
    {:ok, emit(state, "#")}
  end

  defp interpret_part(:value, %{value: value}, state) do
    {:ok, emit(state, value)}
  end

  defp interpret_part({argument_type, _name} = argument, context, state)
       when argument_type in [:named_arg, :pos_arg] do
    with_argument(argument, context, state, fn value, state ->
      format_value(Formatter.format(value, nil, nil, context), state)
    end)
  end

  defp interpret_part({:simple_format, argument, type}, context, state) do
    interpret_part({:simple_format, argument, type, nil}, context, state)
  end

  defp interpret_part({:simple_format, argument, type, style}, context, state) do
    with_argument(argument, context, state, fn value, state ->
      format_value(Formatter.format(value, type, style, context), state)
    end)
  end

  defp interpret_part({:select, argument, clauses}, context, state) do
    with_argument(argument, context, state, fn value, state ->
      clause = Map.get(clauses, selector(value)) || Map.get(clauses, "other", [])
      interpret(clause, context, state)
    end)
  end

  defp interpret_part({kind, argument, plural_options, clauses}, context, state)
       when kind in [:plural, :select_ordinal] do
    with_argument(argument, context, state, fn value, state ->
      offset = Keyword.get(plural_options, :offset, 0)

      with {:ok, clause, formatted} <- plural_clause(kind, value, offset, clauses, context) do
        interpret(clause, %{context | value: formatted}, state)
      end
    end)
  end

  defp interpret_part(part, _context, _state) do
    {:error,
     Localize.FormatError.exception(
       value: part,
       function: :mf1,
       detail: "not part of a parsed MessageFormat 1 message"
     )}
  end

  # Calls `fun` with the argument's value, or writes the argument's source
  # text and records it as unbound when no binding has it.
  defp with_argument({_type, name} = argument, context, state, fun) do
    case fetch_argument(argument, context.bindings) do
      {:ok, value} ->
        fun.(value, %{state | bound: [name | state.bound]})

      :error ->
        {:ok, %{emit(state, "{#{name}}") | unbound: [name | state.unbound]}}
    end
  end

  defp format_value({:ok, formatted}, state) do
    {:ok, emit(state, formatted)}
  end

  defp format_value({:error, _exception} = error, _state) do
    error
  end

  defp emit(state, iodata) do
    %{state | output: [iodata | state.output]}
  end

  # A named argument is found by a string key or an atom key of the same
  # name, compared as strings so that no atom is made from the message.
  defp fetch_argument({:named_arg, name}, bindings) do
    find_binding(bindings, fn key -> key == name or atom_named?(key, name) end)
  end

  # A positional argument is the element at its index of a list of values,
  # or the value of an integer or string key of a map.
  defp fetch_argument({:pos_arg, index}, bindings) when is_list(bindings) do
    Enum.fetch(bindings, index)
  end

  defp fetch_argument({:pos_arg, index}, bindings) do
    string_index = Integer.to_string(index)
    find_binding(bindings, fn key -> key == index or key == string_index end)
  end

  defp find_binding(bindings, match?) when is_map(bindings) do
    find_binding(Map.to_list(bindings), match?)
  end

  defp find_binding(bindings, match?) when is_list(bindings) do
    Enum.find_value(bindings, :error, &matching_binding(&1, match?))
  end

  defp matching_binding({key, value}, match?) do
    if match?.(key) do
      {:ok, value}
    else
      nil
    end
  end

  defp matching_binding(_element, _match?) do
    nil
  end

  defp atom_named?(key, name) when is_atom(key) do
    Atom.to_string(key) == name
  end

  defp atom_named?(_key, _name) do
    false
  end

  # The select key a value chooses: a string as itself, an atom or an
  # integer as its text. Anything else chooses `other`.
  defp selector(value) when is_binary(value) do
    value
  end

  defp selector(value) when is_atom(value) or is_integer(value) do
    to_string(value)
  end

  defp selector(_value) do
    "other"
  end

  # The clause a plural or selectordinal chooses, and `#` formatted. An
  # explicit `=n` clause is matched against the value before the offset is
  # applied; a plural category against the value after it, as in ICU.
  defp plural_clause(kind, value, offset, clauses, context) do
    with {:ok, number, number_options} <- Formatter.number_value(value, kind),
         {:ok, offset_number} <- subtract(number, offset),
         {:ok, category} <- plural_category(kind, offset_number, context),
         {:ok, formatted} <- Formatter.number(offset_number, number_options, context) do
      clause =
        explicit_clause(clauses, number) || Map.get(clauses, category) ||
          Map.get(clauses, :other, [])

      {:ok, clause, formatted}
    end
  end

  defp subtract(number, 0) do
    {:ok, number}
  end

  defp subtract(%Decimal{} = number, offset) do
    {:ok, Decimal.sub(number, offset)}
  end

  defp subtract(number, offset) do
    {:ok, number - offset}
  end

  defp plural_category(kind, number, context) do
    options = [locale: context.locale, type: plural_type(kind)]

    case Localize.Number.PluralRule.plural_type(number, options) do
      category when is_atom(category) -> {:ok, category}
      {:error, _exception} = error -> error
    end
  end

  defp plural_type(:plural) do
    :cardinal
  end

  defp plural_type(:select_ordinal) do
    :ordinal
  end

  defp explicit_clause(clauses, number) do
    case exact_integer(number) do
      {:ok, integer} -> Map.get(clauses, integer)
      :error -> nil
    end
  end

  defp exact_integer(number) when is_integer(number) do
    {:ok, number}
  end

  defp exact_integer(number) when is_float(number) and number == trunc(number) do
    {:ok, trunc(number)}
  end

  defp exact_integer(%Decimal{} = number) do
    if Decimal.integer?(number) do
      {:ok, Decimal.to_integer(number)}
    else
      :error
    end
  end

  defp exact_integer(_number) do
    :error
  end
end
