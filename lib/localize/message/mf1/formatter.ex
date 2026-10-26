defmodule Localize.Message.MF1.Formatter do
  @moduledoc false

  # Formats one argument value by its MF1 type and style with Localize's
  # formatters, keeping the behaviour of `ex_cldr_messages` 2.0.1
  # (`Cldr.Message.V1.Interpreter`) so that messages migrate unchanged. Every
  # function returns `{:ok, string}` or `{:error, exception}`; none raises.

  @date_modules %{date: Localize.Date, time: Localize.Time, datetime: Localize.DateTime}
  @date_styles [:short, :medium, :long, :full]
  @unit_styles [:short, :long]
  @money_styles [:short, :long]
  @list_styles Localize.List.known_list_styles()
  @integer_pattern "#"
  @permille_pattern "#,##0‰"
  @spellout_rules %{
    nil => "spellout_numbering",
    verbose: "spellout_numbering_verbose",
    year: "spellout_numbering_year",
    ordinal: "spellout_ordinal"
  }

  defguardp is_numeric(value) when is_number(value) or is_struct(value, Decimal)

  @doc """
  Formats a value as an argument of an MF1 type (`nil` for a plain argument)
  and style.

  """
  @spec format(term(), atom() | nil, term(), map()) :: {:ok, String.t()} | {:error, Exception.t()}
  def format(value, type, style, context)

  def format({number, options}, nil, nil, context) when is_numeric(number) and is_list(options) do
    number(number, options, context)
  end

  def format(value, nil, nil, context) do
    Localize.Chars.to_string(value, base_options(context))
  end

  def format(value, :number, style, context) do
    with {:ok, number, value_options} <- number_value(value, :number) do
      number_with_style(number, style, value_options, context)
    end
  end

  def format(value, type, style, context) when type in [:spellout, :ordinal] do
    with {:ok, number, _value_options} <- number_value(value, type),
         {:ok, rule} <- rule_name(type, style) do
      Localize.Number.Rbnf.to_string(number, rule, base_options(context))
    end
  end

  def format(value, type, style, context) when is_map_key(@date_modules, type) do
    with {:ok, options} <- date_options(style, context) do
      Map.fetch!(@date_modules, type).to_string(value, options)
    end
  end

  def format(value, :unit, style, context) do
    with {:ok, options} <- unit_options(style, context) do
      Localize.Unit.to_string(value, options)
    end
  end

  def format(value, :list, style, context) do
    with {:ok, options} <- list_options(style, context) do
      Localize.List.to_string(value, options)
    end
  end

  def format(value, :money, style, context) do
    money(value, style, context)
  end

  def format(value, type, _style, _context) do
    {:error, format_error(value, type, "is not a MessageFormat 1 argument type")}
  end

  @doc """
  Returns the number of a number argument, which is a number, a `Decimal` or
  a `{number, options}` tuple whose options are passed to the formatter.

  """
  @spec number_value(term(), atom()) ::
          {:ok, number() | Decimal.t(), Keyword.t()} | {:error, Exception.t()}
  def number_value(number, _type) when is_numeric(number) do
    {:ok, number, []}
  end

  def number_value({number, options}, _type) when is_numeric(number) and is_list(options) do
    {:ok, number, options}
  end

  def number_value(value, type) do
    {:error, format_error(value, type, "a number or a Decimal is required")}
  end

  @doc """
  Formats a number with the context's options and `extra_options` merged
  over them.

  """
  @spec number(number() | Decimal.t(), Keyword.t(), map()) ::
          {:ok, String.t()} | {:error, Exception.t()}
  def number(number, extra_options, context) do
    options =
      context.options
      |> Keyword.merge(extra_options)
      |> Keyword.put(:locale, context.locale)

    Localize.Number.to_string(number, options)
  end

  defp number_with_style(number, nil, value_options, context) do
    number(number, value_options, context)
  end

  defp number_with_style(number, :integer, value_options, context) do
    number(number, Keyword.put(value_options, :format, @integer_pattern), context)
  end

  defp number_with_style(number, :permille, value_options, context) do
    number(number, Keyword.put(value_options, :format, @permille_pattern), context)
  end

  defp number_with_style(number, :ordinal, value_options, context) do
    number(number, Keyword.put(value_options, :format, :digits_ordinal), context)
  end

  # Any other keyword style is a fixed atom from the grammar, given to
  # `Localize.Number` as the format, as `ex_cldr_messages` did.
  defp number_with_style(number, style, value_options, context)
       when is_atom(style) or is_binary(style) do
    number(number, Keyword.put(value_options, :format, style), context)
  end

  defp number_with_style(number, {:named_format, name}, value_options, context) do
    case configured_format(name, context) do
      {:ok, format_options} ->
        number(number, Keyword.merge(value_options, format_options), context)

      :error ->
        named_number_format(number, name, value_options, context)
    end
  end

  defp number_with_style(number, {:skeleton, skeleton}, _value_options, _context) do
    {:error, format_error(number, :number, "number skeletons (::#{skeleton}) are not supported")}
  end

  # A `:name` style that is not a configured format names an RBNF rule
  # (`:spellout_ordinal`) or a number format (`:currency_long`) of the
  # locale. Names are compared as strings, so no atom is made.
  defp named_number_format(number, name, value_options, context) do
    with {:ok, rule_names} <- Localize.Number.Rbnf.rule_names_for_locale(context.locale),
         {:ok, styles} <- Localize.Number.Format.format_styles_for(context.locale) do
      cond do
        name in rule_names ->
          Localize.Number.Rbnf.to_string(number, name, base_options(context))

        style = Enum.find(styles, &(Atom.to_string(&1) == name)) ->
          number(number, Keyword.put(value_options, :format, style), context)

        true ->
          {:error, format_error(number, :number, "there is no number format named #{name}")}
      end
    end
  end

  defp rule_name(:ordinal, nil) do
    {:ok, "digits_ordinal"}
  end

  defp rule_name(:spellout, style) when is_map_key(@spellout_rules, style) do
    {:ok, Map.fetch!(@spellout_rules, style)}
  end

  defp rule_name(_type, style) when is_binary(style) do
    {:ok, String.trim_leading(style, "%")}
  end

  defp rule_name(_type, {:named_format, name}) do
    {:ok, name}
  end

  defp rule_name(type, style) do
    {:error, format_error(style, type, "is not a style of #{type} arguments")}
  end

  defp date_options(nil, context) do
    {:ok, base_options(context)}
  end

  defp date_options(style, context) when style in @date_styles or is_binary(style) do
    {:ok, Keyword.put(base_options(context), :format, style)}
  end

  defp date_options({:skeleton, skeleton}, _context) do
    {:error,
     format_error(skeleton, :date, "date and time skeletons (::#{skeleton}) are not supported")}
  end

  defp date_options(style, context) do
    named_options(style, context)
  end

  defp unit_options(nil, context) do
    {:ok, base_options(context)}
  end

  defp unit_options(style, context) when style in @unit_styles do
    {:ok, Keyword.put(base_options(context), :format, style)}
  end

  defp unit_options("narrow", context) do
    {:ok, Keyword.put(base_options(context), :format, :narrow)}
  end

  defp unit_options(style, context) do
    named_options(style, context)
  end

  defp list_options(nil, context) do
    {:ok, base_options(context)}
  end

  defp list_options(style, context) when style in @list_styles do
    {:ok, Keyword.put(base_options(context), :list_style, style)}
  end

  defp list_options(style, context) do
    named_options(style, context)
  end

  # A `:name` style is a format configured with the `:formats` option or the
  # `:localize_mf1, :formats` application setting; an unconfigured name, or
  # another keyword style, formats with the defaults, as `ex_cldr_messages`
  # did. Pattern text that the type does not take is an error.
  defp named_options({:named_format, name}, context) do
    case configured_format(name, context) do
      {:ok, format_options} -> {:ok, Keyword.merge(base_options(context), format_options)}
      :error -> {:ok, base_options(context)}
    end
  end

  defp named_options(style, context) when is_atom(style) do
    {:ok, base_options(context)}
  end

  defp named_options(style, _context) do
    {:error, format_error(style, :style, "is not a style this argument type takes")}
  end

  if Code.ensure_loaded?(Money) do
    defp money(%Money{} = money, style, context) do
      with {:ok, options} <- money_options(style, context) do
        Money.to_string(money, options)
      end
    end

    defp money(value, _style, _context) do
      {:error, format_error(value, :money, "a Money struct is required")}
    end

    defp money_options(nil, context) do
      {:ok, base_options(context)}
    end

    defp money_options(style, context) when style in @money_styles or is_binary(style) do
      {:ok, Keyword.put(base_options(context), :format, style)}
    end

    defp money_options(style, context) do
      named_options(style, context)
    end
  else
    defp money(value, _style, _context) do
      {:error, format_error(value, :money, "money arguments need the ex_money package")}
    end
  end

  defp configured_format(name, context) do
    with :error <- find_format(context.formats, name) do
      find_format(Application.get_env(:localize_mf1, :formats, %{}), name)
    end
  end

  defp find_format(formats, name) when is_map(formats) or is_list(formats) do
    Enum.find_value(formats, :error, &format_named(&1, name))
  end

  defp find_format(_formats, _name) do
    :error
  end

  defp format_named({key, options}, name) when is_list(options) do
    if key == name or (is_atom(key) and Atom.to_string(key) == name) do
      {:ok, options}
    else
      nil
    end
  end

  defp format_named(_entry, _name) do
    nil
  end

  defp base_options(context) do
    Keyword.put(context.options, :locale, context.locale)
  end

  defp format_error(value, function, detail) do
    Localize.FormatError.exception(value: value, function: function, detail: detail)
  end
end
