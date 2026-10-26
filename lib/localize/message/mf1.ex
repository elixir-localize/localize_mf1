defmodule Localize.Message.MF1 do
  @moduledoc """
  Formats ICU MessageFormat 1 messages with Localize.

  ICU MessageFormat 1 (MF1) is the message syntax of ICU4J and ICU4C, of
  translation management systems such as Crowdin, and of `ex_cldr_messages`
  1.x: arguments (`{name}`), formatted arguments (`{count, number}`) and the
  `plural`, `select` and `selectordinal` selectors. Localize itself formats
  MessageFormat 2 (`Localize.Message`); this library formats MF1 messages with
  Localize's locales, plural rules and formatters, so that applications can
  keep existing MF1 translations.

  The API follows `Cldr.Message` from `ex_cldr_messages`:

  * `format/3`, `format!/3` and `format_to_iolist/3` format a message with
    its bindings. An MF2 message given to `format/3` or `format!/3` is
    formatted by `Localize.Message`, as `Cldr.Message` did.

  * `format_list/3` formats a message already parsed by
    `Localize.Message.MF1.Parser.parse/2`.

  * `bindings/1` lists the arguments a message uses.

  ### Arguments and bindings

  Bindings are a keyword list or map, keyed by atom or string, for named
  arguments such as `{name}`, or a list of values for positional arguments
  such as `{0}`. A number binding may be a `{number, options}` tuple whose
  options are given to `Localize.Number.to_string/2`.

  ### Formatted arguments

  | Argument | Formatted with |
  |---|---|
  | `{n}` | `Localize.Chars.to_string/2` |
  | `{n, number}`, `{n, number, integer}` (and `currency`, `percent`, `permille`, `short`, `long`) | `Localize.Number.to_string/2` |
  | `{n, number, ordinal}` | the `digits_ordinal` rule ("1st") |
  | `{n, spellout}` (and `verbose`, `year`, `ordinal`) | `Localize.Number.Rbnf.to_string/3` |
  | `{d, date}`, `{t, time}`, `{dt, datetime}` (and `short` to `full`, or a pattern) | `Localize.Date`, `Localize.Time` and `Localize.DateTime` |
  | `{u, unit}` (and `short`, `long`, `narrow`) | `Localize.Unit.to_string/2` |
  | `{l, list}` (and `or`, `unit` and the other list styles) | `Localize.List.to_string/2` |
  | `{m, money}` (and `short`, `long`) | `Money.to_string/2`, when `ex_money` is a dependency |

  A `:name` style, as in `{n, number, :spellout_ordinal}`, is a format
  configured with the `:formats` option or the `:formats` key of the
  `:localize_mf1` application environment, or else an RBNF rule or a number
  format of that name. Number and date skeletons (`::…`) are not supported.

  """

  alias Localize.Message.MF1.Interpreter
  alias Localize.Message.MF1.Parser

  @own_options [:locale, :trim, :allow_positional_args, :formats]

  @typedoc "Bindings for a message's arguments."
  @type bindings :: Keyword.t() | map() | list()

  @doc """
  Formats a MessageFormat 1 message.

  ### Arguments

  * `message` is a MessageFormat 1 message string. A MessageFormat 2
    message (see `mf2?/1`) is formatted by `Localize.Message.format/3`.

  * `bindings` is a keyword list or map of named arguments, or a list of
    positional arguments. The default is `[]`.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` is a locale identifier or a `t:Localize.LanguageTag.t/0`. The
    default is `Localize.get_locale/0`.

  * `:trim` is `true` to trim white space from the message before it is
    formatted. The default is `false`.

  * `:allow_positional_args` is `false` to return an error for a message
    with positional arguments. The default is `true`.

  * `:formats` is a map or keyword list of named formats, each a keyword
    list of formatter options, used by `:name` styles.

  * Any other option is given to every formatter, as in `ex_cldr_messages`;
    for example `currency: :EUR` for `{price, number, currency}`.

  ### Returns

  * `{:ok, formatted_message}`, or

  * `{:error, %Localize.BindError{}}` when an argument has no binding, or

  * `{:error, exception}` when the message cannot be parsed or a value
    cannot be formatted.

  ### Examples

      iex> Localize.Message.MF1.format("{greeting} to you!", greeting: "Good morning")
      {:ok, "Good morning to you!"}

      iex> Localize.Message.MF1.format("{count, plural, one {# item} other {# items}}", count: 3)
      {:ok, "3 items"}

  """
  @spec format(String.t(), bindings(), Keyword.t()) :: {:ok, String.t()} | {:error, Exception.t()}
  def format(message, bindings \\ [], options \\ [])

  def format(message, bindings, options) when is_binary(message) do
    if mf2?(message) do
      Localize.Message.format(message, bindings, options)
    else
      message
      |> format_to_iolist(bindings, options)
      |> to_binary()
    end
  end

  def format(message, _bindings, _options) do
    {:error, invalid_message(message)}
  end

  defp to_binary({:ok, iolist, _bound, _unbound}) do
    {:ok, IO.iodata_to_binary(iolist)}
  end

  defp to_binary({:error, _iolist, _bound, unbound}) do
    {:error, Localize.BindError.exception(unbound: unbound)}
  end

  defp to_binary({:error, _exception} = error) do
    error
  end

  @doc """
  Formats a MessageFormat 1 message, raising on error.

  ### Arguments

  * `message` is a message string, as for `format/3`.

  * `bindings` is a keyword list, map or list of bindings.

  * `options` is a keyword list of options.

  ### Options

  * See `format/3`.

  ### Returns

  * The formatted message. An exception is raised when the message cannot
    be formatted.

  ### Examples

      iex> Localize.Message.MF1.format!("{greeting} to you!", greeting: "Good morning")
      "Good morning to you!"

      iex> Localize.Message.MF1.format!("{{Hello, world!}}")
      "Hello, world!"

  """
  @spec format!(String.t(), bindings(), Keyword.t()) :: String.t() | no_return()
  def format!(message, bindings \\ [], options \\ []) do
    case format(message, bindings, options) do
      {:ok, formatted} -> formatted
      {:error, exception} -> raise exception
    end
  end

  @doc """
  Formats a MessageFormat 1 message to an iolist, with the arguments that
  were and were not bound.

  ### Arguments

  * `message` is a MessageFormat 1 message string.

  * `bindings` is a keyword list, map or list of bindings.

  * `options` is a keyword list of options.

  ### Options

  * See `format/3`.

  ### Returns

  * `{:ok, iolist, bound, []}` where `bound` lists the arguments used, or

  * `{:error, iolist, bound, unbound}` when arguments in `unbound` have no
    binding; each is written into `iolist` as its source text, such as
    `{name}`, or

  * `{:error, exception}` when the message cannot be parsed or a value
    cannot be formatted.

  ### Examples

      iex> Localize.Message.MF1.format_to_iolist("{greeting} to you!", greeting: "Good morning")
      {:ok, ["Good morning", " to you!"], ["greeting"], []}

  """
  @spec format_to_iolist(String.t(), bindings(), Keyword.t()) ::
          {:ok, list(), list(), list()}
          | {:error, list(), list(), list()}
          | {:error, Exception.t()}
  def format_to_iolist(message, bindings \\ [], options \\ [])

  def format_to_iolist(message, bindings, options) when is_binary(message) do
    with {:ok, options} <- validate_options(options),
         {:ok, parsed} <- Parser.parse(maybe_trim(message, options[:trim]), options) do
      format_list(parsed, bindings, options)
    end
  end

  def format_to_iolist(message, _bindings, _options) do
    {:error, invalid_message(message)}
  end

  @doc """
  Formats a message parsed by `Localize.Message.MF1.Parser.parse/2` to an
  iolist.

  ### Arguments

  * `parsed` is a parsed message.

  * `bindings` is a keyword list, map or list of bindings.

  * `options` is a keyword list of options.

  ### Options

  * See `format/3`. `:trim` and `:allow_positional_args` apply only when
    parsing, so they have no effect here.

  ### Returns

  * As for `format_to_iolist/3`.

  ### Examples

      iex> {:ok, parsed} = Localize.Message.MF1.Parser.parse("{count, number} jelly beans")
      iex> Localize.Message.MF1.format_list(parsed, [count: 1234], locale: :de)
      {:ok, ["1.234", " jelly beans"], ["count"], []}

  """
  @spec format_list(Parser.t(), bindings(), Keyword.t()) ::
          {:ok, list(), list(), list()}
          | {:error, list(), list(), list()}
          | {:error, Exception.t()}
  def format_list(parsed, bindings \\ [], options \\ [])

  def format_list(parsed, bindings, options) when is_list(parsed) do
    with {:ok, options} <- validate_options(options),
         {:ok, bindings} <- validate_bindings(bindings),
         {:ok, locale} <-
           Localize.validate_locale(Keyword.get_lazy(options, :locale, &Localize.get_locale/0)) do
      Interpreter.format_list(parsed, %{
        bindings: bindings,
        locale: locale,
        formats: Keyword.get(options, :formats, %{}),
        options: Keyword.drop(options, @own_options)
      })
    end
  end

  def format_list(parsed, _bindings, _options) do
    {:error,
     Localize.InvalidValueError.exception(
       value: parsed,
       expected: "a parsed MessageFormat 1 message"
     )}
  end

  @doc """
  Returns the names (and positions) of the arguments a message uses.

  ### Arguments

  * `message` is a MessageFormat 1 message string, or a message parsed by
    `Localize.Message.MF1.Parser.parse/2`.

  ### Returns

  * A list of argument names (strings) and positions (integers), in the
    order `Cldr.Message.bindings/1` gave them, or

  * `{:error, exception}` when the message cannot be parsed.

  ### Examples

      iex> Localize.Message.MF1.bindings("This {variable} is in the message")
      ["variable"]

  """
  @spec bindings(String.t() | Parser.t()) ::
          [String.t() | non_neg_integer()] | {:error, Exception.t()}
  def bindings(message) when is_binary(message) do
    with {:ok, parsed} <- Parser.parse(message) do
      bindings(parsed)
    end
  end

  def bindings(parsed) when is_list(parsed) do
    parsed
    |> collect_bindings()
    |> List.flatten()
    |> Enum.uniq()
  end

  def bindings(message) do
    {:error, invalid_message(message)}
  end

  # Collected as `Cldr.Message.bindings/1` did, so that the order is the same.
  defp collect_bindings(parsed) when is_list(parsed) do
    Enum.reduce(parsed, [], &collect_binding/2)
  end

  defp collect_bindings(clauses) when is_map(clauses) do
    Enum.map(clauses, fn {_selector, clause} -> collect_bindings(clause) end)
  end

  defp collect_binding({type, name}, acc) when type in [:named_arg, :pos_arg] do
    [name | acc]
  end

  defp collect_binding({:simple_format, {_type, name}, _format}, acc) do
    [name | acc]
  end

  defp collect_binding({:simple_format, {_type, name}, _format, _style}, acc) do
    [name | acc]
  end

  defp collect_binding({:select, {_type, name}, clauses}, acc) do
    [name, collect_bindings(clauses) | acc]
  end

  defp collect_binding({kind, {_type, name}, _options, clauses}, acc)
       when kind in [:plural, :select_ordinal] do
    [name, collect_bindings(clauses) | acc]
  end

  defp collect_binding(_part, acc) do
    acc
  end

  defp maybe_trim(message, true) do
    String.trim(message)
  end

  defp maybe_trim(message, _trim) do
    message
  end

  defp validate_options(options) do
    if Keyword.keyword?(options) do
      {:ok, options}
    else
      {:error,
       Localize.InvalidValueError.exception(value: options, expected: "a keyword list of options")}
    end
  end

  defp validate_bindings(bindings) when is_map(bindings) or is_list(bindings) do
    {:ok, bindings}
  end

  defp validate_bindings(bindings) do
    {:error,
     Localize.InvalidValueError.exception(
       value: bindings,
       expected: "a keyword list, map or list of bindings"
     )}
  end

  defp invalid_message(message) do
    Localize.InvalidValueError.exception(
      value: message,
      expected: "a MessageFormat 1 message string"
    )
  end

  @doc """
  Returns whether a message is written in MessageFormat 2 rather than
  MessageFormat 1.

  An MF2 message starts with a declaration or matcher (`.input`, `.local`,
  `.match`) or a quoted pattern (`{{`); any other message is read as MF1.

  ### Arguments

  * `message` is a message string.

  ### Returns

  * `true` when `message` is an MF2 message, or

  * `false` otherwise, including when `message` is not a string.

  ### Examples

      iex> Localize.Message.MF1.mf2?("Hello {name}")
      false

      iex> Localize.Message.MF1.mf2?("{{Hello {$name}}}")
      true

  """
  @spec mf2?(term()) :: boolean()
  def mf2?(message) when is_binary(message) do
    trimmed = String.trim_leading(message)
    String.starts_with?(trimmed, ".") or String.starts_with?(trimmed, "{{")
  end

  def mf2?(_message) do
    false
  end
end
