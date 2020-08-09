defmodule Nearex do
  @moduledoc false

  alias Nearex.Buffer

  @config %{
    node_url: "https://rpc.testnet.near.org",
    provider: %{type: "JsonRPCProvider", args: %{url: "https://rpc.testnet.near.org"}},
    priv_key:
      "7Y6NcQPXaAFxnVG3aBZTketSxAtX4NvmqgEvPYtQ3HGRhFL5efNAy2T5cYAfpquBwQ2wFBcAvfackXSawKsHbxG",
    account_id: "aguxez.testnet",
    network_id: "default"
  }

  @default_gas 100_000_000_000_000

  @def_args ~s({"receiver_id":"picks.aguxez.testnet","amount":"1"})

  def send_transaction do
    public_key = get_keypair().public

    public_key
    |> payload(get_account_nonce(public_key), "2HcbhiWaRgm7Zt7GKzEpSeNjVNDjoSysjnA8wHBGEKFT")
    |> Map.get(:transaction)
    |> Enum.into([])
    |> sign_args()

    message = Buffer.split_buff_save()

    Buffer.clean_state()

    :sha256
    |> :crypto.hash(message)
    |> :enacl.sign_detached(get_keypair().secret)
    |> signed_tx()
    |> sign_args()

    message = Buffer.split_buff_save()

    Buffer.clean_state()

    message
    |> :binary.list_to_bin()
    |> Base.encode64()
    |> do_send()
  end

  defp get_account_nonce(public_key) do
    %{body: body} =
      view_function("access_key/#{@config.account_id}/ed25519:#{Base58.encode(public_key)}", "")

    body["result"]["nonce"] + 1
  end

  # defp get_last_block_hash do
  #   get_chain_status().body["result"]["sync_info"]["latest_block_hash"]
  # end

  defp serialize_args(args) do
    :binary.bin_to_list(args)
  end

  defp payload(public_key, account_nonce, block_hash) do
    %{
      transaction: [
        signer_id: %{type: "string", value: "aguxez.testnet"},
        public_key: [
          key_type: %{type: "u8", value: 0},
          data: %{type: [32], value: public_key}
        ],
        nonce: %{type: "u64", value: account_nonce},
        receiver_id: %{type: "string", value: "token.aguxez.testnet"},
        block_hash: %{
          type: [32],
          value: Base58.decode(block_hash)
        },
        actions: [
          function_call: [
            method_name: %{type: "string", value: "transfer"},
            args: %{type: ["u8"], value: serialize_args(@def_args)},
            gas: %{type: "u64", value: @default_gas},
            amount: %{type: "u128", value: 0}
          ]
        ]
      ]
    }
  end

  defp signed_tx(signature) do
    public_key = get_keypair().public

    tx_payload =
      payload(
        public_key,
        get_account_nonce(public_key),
        "2HcbhiWaRgm7Zt7GKzEpSeNjVNDjoSysjnA8wHBGEKFT"
      )

    %{
      signed_msg: [
        transaction: tx_payload,
        signature: [
          key_type: %{type: "u8", value: 0},
          data: %{type: [64], value: signature}
        ]
      ]
    }
  end

  def sign_args(fields) do
    Enum.each(fields, &match_args/1)
  end

  defp match_args(args) do
    case args do
      {_name, %{type: type, value: value}} when is_bitstring(type) or type == "string" ->
        # Get the type of message to send
        write_type = String.to_existing_atom("write_#{type}")

        apply(Buffer, write_type, [value])

      {name, %{type: type, value: values}} when is_list(type) ->
        [internal_type] = type

        if is_number(internal_type) do
          if length(:binary.bin_to_list(values)) != internal_type do
            raise ArgumentError,
                  "Mismatch on byte length of number, expected #{internal_type} but got #{
                    length(:binary.bin_to_list(values))
                  }"
          end

          Buffer.write_fixed_array(values)
        else
          Buffer.write_array(values)

          Enum.map(values, fn val ->
            sign_args([{name, %{type: internal_type, value: val}}])
          end)
        end

      {:function_call, values} ->
        Buffer.write_u8(2)

        sign_args(values)

      {name, values} when name in [:signed_msg, :transaction, :signature, :public_key] ->
        sign_args(values)

      {_, values} when is_map(values) ->
        sign_args(values)

      {_name, values} when is_list(values) ->
        Buffer.write_array(values)

        sign_args(values)
    end
  end

  def get_keypair do
    @config.priv_key
    |> Base58.decode()
    |> :enacl.sign_seed_keypair()
  end

  def view_function(method, params \\ nil) do
    request = %{
      method: "query",
      params: [method, params || serialized_params()],
      id: 1,
      jsonrpc: "2.0"
    }

    Tesla.post!(
      client(),
      "/",
      request,
      headers: [{"content-type", "application/json; charset=utf-8"}]
    )
  end

  def do_send(params) do
    request = %{
      method: "broadcast_tx_commit",
      params: [params],
      id: 3,
      jsonrpc: "2.0"
    }

    Tesla.post!(
      client(),
      "/",
      request,
      headers: [{"content-type", "application/json; charset=utf-8"}]
    )
  end

  def get_chain_status do
    request = %{
      method: "status",
      params: [],
      id: 2,
      jsonrpc: "2.0"
    }

    Tesla.post!(
      client(),
      "/",
      request,
      headers: [{"content-type", "application/json; charset=utf-8"}]
    )
  end

  defp serialized_params do
    %{account_id: "picks.aguxez.testnet"}
    |> Jason.encode!()
    |> Base58.encode()
  end

  defp client do
    Tesla.client([
      {
        Tesla.Middleware.BaseUrl,
        @config.node_url
      },
      {Tesla.Middleware.JSON, engine: Jason}
    ])
  end
end
