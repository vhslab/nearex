defmodule Nearex.Utils do
  @moduledoc false

  alias Nearex.HTTP

  @spec get_keypair(String.t()) :: map()
  def get_keypair(private_key) do
    private_key
    |> Base58.decode()
    |> :enacl.sign_seed_keypair()
  end

  @spec get_account_nonce(String.t(), String.t(), Keyword.t()) :: pos_integer()
  def get_account_nonce(public_key, account_id, opts \\ []) do
    {:ok, response} =
      HTTP.view_function(
        "query",
        "access_key/#{account_id}/ed25519:#{Base58.encode(public_key)}",
        "",
        opts
      )

    response["result"]["nonce"] + 1
  end

  @spec get_last_block_hash() :: String.t()
  def get_last_block_hash(opts \\ []) do
    {:ok, response} = HTTP.get_chain_status(opts)

    response["result"]["sync_info"]["latest_block_hash"]
  end

  @spec serialize_args(map()) :: charlist()
  def serialize_args(arguments) do
    arguments
    |> Jason.encode!()
    |> :binary.bin_to_list()
  end
end
