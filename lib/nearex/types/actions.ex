defmodule Nearex.Types.Actions do
  @moduledoc """
  Holds a struct of actions (functionCall, for example) that will be performed with a transaction
  """

  # Very generic right now. Note that even if this action struct has two fields we need to construct a list like this
  # to comply with the serialization methods
  # Example: actions: [args: [functional_call: more_Args]] (Args need to be a list on the order we're expecting, no maps)

  @enforce_keys [:args]
  defstruct [
    :args
  ]

  @type t :: %__MODULE__{args: Keyword.t()}
end
