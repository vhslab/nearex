# Nearex

Rudimentary RPC client for Near on Elixir

This RPC client is very basic at its current stage as well as its usage.

## What's implemented

- [x] View functions
- [x] Function calls

## The library

The code is as documented as it can right now as we're working on a 3rd party platform.

Talking structures, not logic, the serialization method needs the transaction and signature to be on the same order. A signature is a hashed transaction (that was previously serialized) that needs to be serialized as well, so we need to make 2 serializations per request.

This is the order on how we need the parameters when creating the transaction object (note that they don't need to be on this order as they are under a keyword list on the arguments that `Nearex.sign_transaction/2` expects)

- `signer_id` (The account that's sending the message)
- `public_key`
- `nonce`
- `receiver_id` (The contract where the request is being sent to)
- `block_hash` (Latest block hash)
- `actions`

## Actions

Actions are merely a name that we have to the _action_ that's being performed. Since right now the only action available is `function_call`, that's the only action. A transaction accepts a list of actions.

What's under an `function_call` on an `Action`?

- `method_name`
- `args` (Serialized arguments sent to the contract)
- `gas`
- `amount` (If we're sending Near on the transaction)

## What do we need to send when signing a transaction?

This library does not include environment configuration. We, instead, let the parent application specify the configuration that's needed under options for functions.

There are a few that are required even if they're called _options_. Made it that way for simplicity (And called them `extra` internally :) )

- `private_key` (Signer's private key)
- `near_url` (Url of the RPC client)
- `account_id` (ID of the account that's sending the tx)
- `receiver_id` (ID of the account that's receiving the tx)
- `method_name` (Name of the function to call)

`gas` and `deposit_amount` are optional

## View functions

View functions are very similar, only thing is that you do not need to send private keys and none of that stuff as they're basically anonymous calls to peek at contracts' state. These are the options we're expecting on the view function

- `near_url` (Url of the RPC client)
- `req_id` (ID of the JSONRPC request, this is so we can identify each request)

```elixir
Nearex.view("picks.aguxez.testnet", "get_stake_amount_for_user", %{race_id: "race_id", horse_id: "123", account_id: "m.zest"}, near_url: "https://rpc.testnet.near.org", req_id: "some id")
```

## Pending

- [ ] Use a normal module with an accumulator instead of a GenServer for serialization. With a GenServer we're tied to a long running process which is prone to race conditions.
- [ ] Support more methods
