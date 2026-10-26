defmodule Localize.Message.MF1.PositionalArgumentError do
  @moduledoc """
  Returned when a MessageFormat 1 message uses positional arguments such as
  `{0}` and the caller has not permitted them.

  """

  defexception [:arguments]

  @type t :: %__MODULE__{arguments: [non_neg_integer()]}

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{arguments: arguments}) do
    Localize.Exception.safe_message(
      "mf1",
      "Positional arguments are not permitted, found {$arguments}",
      arguments: Enum.map_join(arguments, ", ", &Kernel.to_string/1)
    )
  end
end
