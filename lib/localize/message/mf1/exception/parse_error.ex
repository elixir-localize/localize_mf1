defmodule Localize.Message.MF1.ParseError do
  @moduledoc """
  Returned when a MessageFormat 1 message cannot be parsed: a syntax error,
  or a `plural`, `select` or `selectordinal` argument with no `other`
  clause.

  """

  defexception [:reason, :position]

  @type t :: %__MODULE__{reason: String.t(), position: non_neg_integer() | nil}

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{reason: reason, position: nil}) do
    Localize.Exception.safe_message("mf1", "The message could not be parsed: {$reason}",
      reason: reason
    )
  end

  def message(%__MODULE__{reason: reason, position: position}) do
    Localize.Exception.safe_message(
      "mf1",
      "The message could not be parsed at position {$position}: {$reason}",
      reason: reason,
      position: position
    )
  end
end
