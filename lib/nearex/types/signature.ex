defmodule Nearex.Types.Signature do
  @moduledoc """
  Holds a signature struct. This is used for serialization of the transaction and signature.
  `args` must be a kw list of `:transaction, :signature]
  """

  alias Nearex.Types.Transaction

  @enforce_keys [:args]
  defstruct [:args]

  @type t :: %__MODULE__{
          args: Keyword.t()
        }

  @spec create_signature(list(), binary(), integer(), String.t(), map(), Keyword.t()) ::
          %__MODULE__{}
  def create_signature(signature, public_key, account_nonce, block_hash, params, extra) do
    # We need to create a signature from the result of the first serialization then serialize everything again
    transaction =
      Transaction.build_transaction_payload(
        public_key,
        account_nonce,
        block_hash,
        params,
        extra
      )

    %__MODULE__{
      args: [
        transaction: transaction,
        signature: [
          key_type: %{type: "u8", value: 0},
          data: %{type: [64], value: signature}
        ]
      ]
    }
  end
end
