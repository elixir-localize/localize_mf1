if Code.ensure_loaded?(Gettext.Interpolation) do
  defmodule Localize.Message.MF1.Gettext.Interpolation do
    @moduledoc """
    A Gettext interpolation module for ICU MessageFormat 1 messages.

    A Gettext backend that names this module as its `:interpolation` formats
    its messages, the msgids and msgstrs of its `.po` files, as MF1 with
    `Localize.Message.MF1`, in the locale of `Localize.get_locale/0`:

    ```elixir
    defmodule MyApp.Gettext do
      use Gettext.Backend,
        otp_app: :my_app,
        interpolation: Localize.Message.MF1.Gettext.Interpolation
    end
    ```

    Gettext is then used as usual:

    ```elixir
    use Gettext, backend: MyApp.Gettext

    gettext("You have {count, plural, one {# message} other {# messages}}", count: 3)
    #=> "You have 3 messages"
    ```

    This replaces a module defined with `use Cldr.Gettext.Interpolation,
    cldr_backend: MyApp.Cldr` in `ex_cldr_messages`; Localize has no backend
    modules, so there is nothing to configure. Messages written in
    MessageFormat 2 use `Localize.Gettext.Interpolation` instead.

    A translation in the backend's `.po` files that is not valid MF1 is a
    compile error of the backend. Any other message that cannot be parsed or
    formatted is logged and returned unchanged, and a missing binding is reported to Gettext with the argument written back
    in its source form, as in `{count, number}`.

    """

    @behaviour Gettext.Interpolation

    require Logger

    alias Localize.Message.MF1

    @impl Gettext.Interpolation
    def runtime_interpolate(message, bindings) when is_binary(message) do
      message
      |> MF1.format_to_iolist(bindings)
      |> interpolation_result(message)
    end

    @impl Gettext.Interpolation
    defmacro compile_interpolate(_translation_type, message, bindings) do
      message = expand_to_binary!(message, __CALLER__)
      parsed = parse!(message)

      quote do
        Localize.Message.MF1.Gettext.Interpolation.interpolate_parsed(
          unquote(Macro.escape(parsed)),
          unquote(message),
          unquote(bindings)
        )
      end
    end

    @impl Gettext.Interpolation
    def message_format do
      "icu-format"
    end

    @doc false
    @spec interpolate_parsed(MF1.Parser.t(), String.t(), Gettext.Interpolation.bindings()) ::
            {:ok, String.t()} | {:missing_bindings, String.t(), [String.t() | non_neg_integer()]}
    def interpolate_parsed(parsed, message, bindings) do
      parsed
      |> MF1.format_list(bindings)
      |> interpolation_result(message)
    end

    # Missing bindings are reported by name, as `ex_cldr_messages` did,
    # rather than as atoms made from message text.
    defp interpolation_result({:ok, iolist, _bound, _unbound}, _message) do
      {:ok, IO.iodata_to_binary(iolist)}
    end

    defp interpolation_result({:error, iolist, _bound, unbound}, _message) do
      {:missing_bindings, IO.iodata_to_binary(iolist), unbound}
    end

    defp interpolation_result({:error, exception}, message) do
      Logger.warning(
        "Localize.Message.MF1.Gettext.Interpolation: returning #{inspect(message)} " <>
          "unchanged: #{Exception.message(exception)}"
      )

      {:ok, message}
    end

    defp parse!(message) do
      case MF1.Parser.parse(message) do
        {:ok, parsed} ->
          parsed

        {:error, exception} ->
          raise ArgumentError,
                "could not parse the MessageFormat 1 message #{inspect(message)}: " <>
                  Exception.message(exception)
      end
    end

    defp expand_to_binary!(term, env) do
      case Macro.expand(term, env) do
        binary when is_binary(binary) ->
          binary

        {:<<>>, _meta, pieces} = expanded ->
          join_literal!(pieces, expanded)

        other ->
          raise_not_binary!(other)
      end
    end

    defp join_literal!(pieces, expanded) do
      if Enum.all?(pieces, &is_binary/1) do
        Enum.join(pieces)
      else
        raise_not_binary!(expanded)
      end
    end

    @dialyzer {:nowarn_function, raise_not_binary!: 1}
    defp raise_not_binary!(term) do
      raise ArgumentError, """
      Gettext macros expect a message that is a string at compile time, but \
      received:

        #{inspect(term)}

      To format a message built at runtime, use Localize.Message.MF1.format/3.
      """
    end
  end
end
