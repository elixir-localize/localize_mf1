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

  """

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
