defmodule Nearex do
  @moduledoc false

  alias Nearex.{HTTP, Serializer, Utils}
  alias Nearex.Types.{Transaction, Signature}

  @spec sign_transaction(map(), Keyword.t()) :: String.t()
  def sign_transaction(params, extra) do
    # We're only calling this fetch! function here so we can make sure the key exists. If we wait until it goes through
    # to the HTTP module it will stay pending until it times out
    Keyword.fetch!(extra, :near_url)

    private_key = Keyword.fetch!(extra, :private_key)
    account_id = Keyword.fetch!(extra, :account_id)
    block_hash = Utils.get_last_block_hash(extra)

    # Even if we're sending them as options, some keys are required, say account_id, gas, amount, etc...
    keypair = Utils.get_keypair(private_key)
    account_nonce = Utils.get_account_nonce(keypair.public, account_id, extra)

    serializer_state =
      keypair.public
      |> Transaction.build_transaction_payload(account_nonce, block_hash, params, extra)
      |> Transaction.sign_args(Serializer.init_buffer())

    # Gets the buffer for the length it has
    message = Enum.take(serializer_state.buff, serializer_state.length)

    second_ser_state =
      :sha256
      |> :crypto.hash(message)
      |> :enacl.sign_detached(keypair.secret)
      |> Signature.create_signature(keypair.public, account_nonce, block_hash, params, extra)
      |> Transaction.sign_args(Serializer.init_buffer())

    second_ser_state.buff
    |> Enum.take(second_ser_state.length)
    |> :binary.list_to_bin()
    |> Base.encode64()
  end

  def send_transaction(params, extra) do
    Keyword.fetch!(extra, :near_url)

    [params]
    |> HTTP.send_transaction(extra)
    |> Transaction.parse_if_error()
  end

  def view(contract, method, arguments, extra \\ []) do
    # Same comment as above
    Keyword.fetch!(extra, :near_url)

    # This function returns a charlist & we need to base58 encode it
    parsed_args =
      arguments
      |> Utils.serialize_args()
      |> to_string()
      |> Base58.encode()

    HTTP.view_function(
      "query",
      "call/#{contract}/#{method}",
      parsed_args,
      extra
    )
  end
end
