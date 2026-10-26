defmodule Localize.Message.MF1.Sigils do
  @moduledoc """
  The `~M` sigil, which returns a message in canonical form at compile time.

  A message may be laid out with white space for readability, but Gettext
  uses the message string as its key, so a change of layout would make a new
  message. `~M` returns the canonical form of the message
  (`Localize.Message.MF1.canonical_message/2`) instead, and a message that
  cannot be parsed is a compile error.

  This is the `~M` of `Cldr.Message.Sigil` from `ex_cldr_messages`, with the
  same output. A MessageFormat 2 message is canonicalized by
  `Localize.Message.canonical_message/2`. `Localize.Message.Sigils` defines
  its own `~M` for MF2 messages, so import one or the other.

  """

  @doc ~S"""
  Returns an MF1 message in canonical form.

  The message is pretty printed by default, with each selector clause on a
  line of its own, which translators find easier to read.

  ### Arguments

  * `message` is the sigil's text, without interpolation or escapes.

  * `modifiers` are the sigil's modifiers.

  ### Modifiers

  * `p` pretty prints the message (the default).

  * `u` returns the message on one line.

  ### Returns

  * The canonical message, as a string literal.

  ### Examples

      iex> import Localize.Message.MF1.Sigils
      iex> ~M(An ICU message)
      "An ICU message"
      iex> ~M"{n, plural, other {# items} one {# item}}"u
      "{n, plural, one {# item} other {# items}}"

  """
  defmacro sigil_M({:<<>>, _meta, [message]}, modifiers) when is_binary(message) do
    Localize.Message.MF1.canonical_message!(message, options(modifiers))
  end

  # `~m` canonicalizes at compile time a message with escapes and
  # interpolation, or at runtime when it interpolates. It was private in
  # `ex_cldr_messages` and stays so.
  @doc false
  defmacro sigil_m({:<<>>, _meta, [message]}, modifiers) when is_binary(message) do
    message
    |> Macro.unescape_string()
    |> Localize.Message.MF1.canonical_message!(options(modifiers))
  end

  defmacro sigil_m({:<<>>, meta, pieces}, modifiers) do
    message = {:<<>>, meta, Enum.map(pieces, &unescape/1)}
    options = options(modifiers)

    quote do
      Localize.Message.MF1.canonical_message!(unquote(message), unquote(options))
    end
  end

  @doc false
  def options([modifier]) when modifier in [?u, ?U] do
    [pretty: false]
  end

  def options(_modifiers) do
    [pretty: true]
  end

  defp unescape(piece) when is_binary(piece) do
    Macro.unescape_string(piece)
  end

  defp unescape(piece) do
    piece
  end
end
