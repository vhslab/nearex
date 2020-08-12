defmodule Nearex.Types.Transaction do
  @moduledoc """
  Holds the data structure to serialize the data we need. Note that the data needs to be on a specified order
  to make the serialization work
  """

  alias Nearex.{Serializer, Utils}
  alias Nearex.Types.{Actions, Signature}

  @default_gas 100_000_000_000_000

  @enforce_keys [:args]
  defstruct args: []

  @type t :: %__MODULE__{args: Keyword.t()}

  @spec build_transaction_payload(binary(), integer(), String.t(), map(), Keyword.t()) ::
          %__MODULE__{}
  def build_transaction_payload(public_key, account_nonce, block_hash, params, extra) do
    %__MODULE__{
      args: [
        signer_id: %{type: "string", value: extra[:account_id]},
        public_key: [
          key_type: %{type: "u8", value: 0},
          data: %{type: [32], value: public_key}
        ],
        nonce: %{type: "u64", value: account_nonce},
        receiver_id: %{type: "string", value: Keyword.fetch!(extra, :receiver_id)},
        block_hash: %{
          type: [32],
          value: Base58.decode(block_hash)
        },
        actions: [
          %Actions{
            args: [
              function_call: [
                method_name: %{type: "string", value: Keyword.fetch!(extra, :method_name)},
                args: %{
                  type: ["u8"],
                  value: Utils.serialize_args(params)
                },
                gas: %{type: "u64", value: extra[:gas] || @default_gas},
                amount: %{type: "u128", value: extra[:deposit_amount] || 0}
              ]
            ]
          }
        ]
      ]
    }
  end

  @spec sign_args(%__MODULE__{} | map(), map()) :: no_return()
  def sign_args(given_args, serializer_state) do
    args =
      case given_args do
        struct when is_struct(struct) -> struct.args
        _ -> given_args
      end

    Enum.reduce(args, serializer_state, &match_args/2)
  end

  defp match_args(args, acc) do
    case args do
      %Actions{args: args} ->
        sign_args(args, acc)

      %Signature{args: args} ->
        sign_args(args, acc)

      {:function_call, values} ->
        new_acc = Serializer.write_u8(2, acc)

        sign_args(values, new_acc)

      {name, values} when name in [:transaction, :signature, :public_key] ->
        sign_args(values, acc)

      {_name, %{type: type, value: value}} when is_bitstring(type) or type == "string" ->
        # Get the type of message to send
        write_type = String.to_existing_atom("write_#{type}")

        apply(Serializer, write_type, [value, acc])

      {name, %{type: type, value: values}} when is_list(type) ->
        [internal_type] = type

        if is_number(internal_type) do
          continue_if_bytes_match(values, internal_type)

          Serializer.write_fixed_array(values, acc)
        else
          new_acc = Serializer.write_array(values, acc)

          Enum.reduce(values, new_acc, fn val, new_ser_state ->
            sign_args([{name, %{type: internal_type, value: val}}], new_ser_state)
          end)
        end

      {_name, values} when is_list(values) ->
        new_acc = Serializer.write_array(values, acc)

        sign_args(values, new_acc)
    end
  end

  defp continue_if_bytes_match(values, internal_type) do
    if length(:binary.bin_to_list(values)) != internal_type do
      # Raising is discouraged but its ok in this situation because if this does not match the transaction won't go through anyway
      raise ArgumentError,
            "Mismatch on byte length of number, expected #{internal_type} but got #{
              length(:binary.bin_to_list(values))
            }"
    end
  end

  # Errors are very peculiar here because of the way they're formatted. We need to go many levels down to reach the message
  # Right now we're going to care about GuesPanics and serialization errors
  @spec parse_if_error(tuple) :: {:ok, [String.t()]} | {:error, String.t()}
  def parse_if_error({:ok, return_value}) do
    tx_return = return_value["result"] || return_value

    case is_error(tx_return) do
      {true, :tx_failure} -> {:error, return_error_value(:tx_failure, tx_return)}
      {false, :ignore} -> {:ok, parse_logs_from_tx(tx_return)}
    end
  end

  defp is_error(result) do
    case result do
      %{"status" => %{"SuccessValue" => ""}} -> {false, :ignore}
      %{"status" => %{"Failure" => _}} -> {true, :tx_failure}
    end
  end

  defp return_error_value(:tx_failure, result) do
    get_in(
      result,
      ~w(status Failure ActionError kind FunctionCallError HostError GuestPanic panic_msg)
    )
  end

  defp parse_logs_from_tx(tx) do
    # Go through the receipts outcome and get all logs
    Enum.flat_map(tx["receipts_outcome"], & &1["outcome"]["logs"])
  end
end
