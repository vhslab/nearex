defmodule NearexTest do
  @moduledoc false

  use ExUnit.Case

  import Mock

  @near_url "https://rpc.testnet.near.org"

  # The private key does not matter. Its a testnet key and can be regenerated
  @tx_opts [
    account_id: "aguxez.testnet",
    private_key:
      "9A6NcQPXaAFxnVG3aBZTketSxAtX4NvmqgEvPYtH33GRhFL5efNAy2T5cYAfpquBwQ2wFBcAvfackXSawKsHb5S",
    near_url: @near_url,
    receiver_id: "token.aguxez.testnet",
    method_name: "transfer"
  ]

  setup_with_mocks([
    {Nearex.HTTP, [],
     [
       view_function: fn _, _, _, _ ->
         {:ok, %{"result" => %{"nonce" => 47}}}
       end
     ]},
    {Nearex.HTTP, [],
     [
       get_chain_status: fn _ ->
         {:ok,
          %{
            "result" => %{
              "sync_info" => %{
                "latest_block_hash" => "GNpghcYtiixPg5XQRSp1CzVf2swieoVGnz9DjTam8vaZ"
              }
            }
          }}
       end
     ]}
  ]) do
    :ok
  end

  describe "sign_transaction" do
    test "returns encoded piece of data based on args" do
      # We're going to perform a 'transfer' transaction
      args = %{
        receiver_id: "aguxez.testnet",
        amount: "100"
      }

      # We're going to return the same data for the priv key request
      signed_tx = Nearex.sign_transaction(args, @tx_opts)

      assert signed_tx == signed_transaction()
    end
  end

  describe "send_transaction" do
    test "returns logs if transaction was sent correctly" do
      with_mock(Nearex.HTTP,
        send_transaction: fn _, _ ->
          # TODO: Implement
          {:ok,
           %{
             "result" => %{
               "receipts_outcome" => [
                 %{"outcome" => %{"logs" => ["Transferred 1 Zest from m.zest to r.zest"]}}
               ],
               "status" => %{"SuccessValue" => ""}
             }
           }}
        end
      ) do
        assert {:ok, ["Transferred 1 Zest from m.zest to r.zest"]} =
                 Nearex.send_transaction(signed_transaction(),
                   near_url: @near_url,
                   req_id: 1
                 )
      end
    end

    test "returns panic msg if transaction reverted" do
      with_mock(Nearex.HTTP,
        send_transaction: fn _, _ ->
          {:ok, %{"result" => error_return("failed to deserialize json")}}
        end
      ) do
        {:error, "failed to deserialize json"} =
          Nearex.send_transaction(signed_transaction(), near_url: @near_url, req_id: 1)
      end
    end
  end

  defp signed_transaction do
    "DgAAAGFndXhlei50ZXN0bmV0ABkwW4Jt7v+OLZd0h1WLfNi9N2iNZRJ6PsoccZ4ik2Z4MAAAAAAAAAAUAAAAdG9rZW4uYWd1eGV6LnRlc3RuZXTkdmr779qh/wBh/ds6bdUZ4ju6fR338ZnAGG6XtOBzBgEAAAACCAAAAHRyYW5zZmVyLwAAAHsiYW1vdW50IjoiMTAwIiwicmVjZWl2ZXJfaWQiOiJhZ3V4ZXoudGVzdG5ldCJ9AEB6EPNaAAAAAAAAAAAAAAAAAAAAAAAAAEJjS/lPAgFvUbLO7gICIKO61kXDeB5pRtWbF4GwnptKhWbFGu99AQ9vOnuTo2UJz4nxduhJD8dcadsjNI3sGgg="
  end

  defp error_return(msg) do
    %{
      "status" => %{
        "Failure" => %{
          "ActionError" => %{
            "kind" => %{
              "FunctionCallError" => %{"HostError" => %{"GuestPanic" => %{"panic_msg" => msg}}}
            }
          }
        }
      }
    }
  end
end
