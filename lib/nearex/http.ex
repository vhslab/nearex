defmodule Nearex.HTTP do
  @moduledoc """
  HTTP interface
  """

  require Logger

  @type request_return() :: {:ok, String.t()} | {:error, String.t()}

  @spec view_function(String.t(), String.t(), String.t(), Keyword.t()) :: request_return()
  def view_function(method, path, params, opts \\ []) do
    request = %{
      method: method,
      params: [path, params],
      id: opts[:req_id],
      jsonrpc: "2.0"
    }

    opts[:near_url]
    |> client()
    |> Tesla.post("/", request)
    |> convert_response()
  end

  @spec get_chain_status(Keyword.t()) :: request_return()
  def get_chain_status(opts) do
    request = %{
      method: "status",
      params: [],
      id: opts[:req_id],
      jsonrpc: "2.0"
    }

    opts[:near_url]
    |> client()
    |> Tesla.post("/", request)
    |> convert_response()
  end

  @spec send_transaction(String.t(), Keyword.t()) :: request_return()
  def send_transaction(params, opts) do
    request = %{
      method: "broadcast_tx_commit",
      params: params,
      id: opts[:req_id],
      jsonrpc: "2.0"
    }

    opts[:near_url]
    |> client()
    |> Tesla.post("/", request)
    |> convert_response()
  end

  defp client(url) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, url},
      {Tesla.Middleware.JSON, engine: Jason},
      {Tesla.Middleware.Retry, delay: 500, max_retries: 10}
    ])
  end

  defp convert_response({:error, :timeout}) do
    {:error, "timeout"}
  end

  defp convert_response({:ok, %Tesla.Env{body: body, status: 200}}) do
    {:ok, body}
  end

  defp convert_response({:ok, %Tesla.Env{body: body, status: 202}}) do
    {:ok, body}
  end

  # These are the ranges of errors, 400 to 511.
  defp convert_response({:ok, %Tesla.Env{body: body, status: status}})
       when status in 400..511 do
    Logger.error(fn ->
      event = %{error: %{name: "HTTPError", data: %{body: body}}}
      message = "[HTTP] #{inspect(body)}"

      {message, event: event}
    end)

    {:error, "there was an error processing your request"}
  end
end
