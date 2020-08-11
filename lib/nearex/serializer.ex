defmodule Nearex.Serializer do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{buff: [], length: 0}, name: :buffer)
  end

  def get_buffer do
    GenServer.call(:buffer, :get_buffer)
  end

  def split_buff_save do
    GenServer.call(:buffer, :split_buff_save)
  end

  def write_u8(value) do
    GenServer.call(:buffer, {:write_u8, value})
  end

  def write_u32(value) do
    GenServer.call(:buffer, {:write_u32, value})
  end

  def write_u64(value) do
    GenServer.call(:buffer, {:write_u64, value})
  end

  def write_u128(value) do
    GenServer.call(:buffer, {:write_u128, value})
  end

  def write_string(string) do
    GenServer.call(:buffer, {:write_string, string})
  end

  def write_array(values) do
    GenServer.call(:buffer, {:write_array, values})
  end

  def write_fixed_array(value) do
    GenServer.call(:buffer, {:write_fixed_array, value})
  end

  def clean_state do
    GenServer.cast(:buffer, :clean_state)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:get_buffer, _from, %{buff: buffer} = state) do
    {:reply, buffer, state}
  end

  @impl true
  def handle_call(:split_buff_save, _from, state) do
    new_buff = Enum.take(state.buff, state.length)

    {:reply, new_buff, %{state | buff: new_buff}}
  end

  @impl true
  def handle_call({:write_u8, value}, _from, %{length: proc_length} = state) do
    new_state =
      state
      |> put_in([:buff], List.insert_at(state.buff, proc_length, value))
      |> put_in([:length], proc_length + 1)

    {:reply, new_state.buff, new_state}
  end

  @impl true
  def handle_call({:write_u32, value}, _from, state) do
    new_state = do_write_u32(state, value)

    {:reply, new_state.buff, new_state}
  end

  @impl true
  def handle_call({:write_u64, value}, _from, state) do
    bin_to_send = <<value::64-little>>
    new_state = write_buffer(state, bin_to_send)

    {:reply, new_state.buff, new_state}
  end

  @impl true
  def handle_call({:write_u128, value}, _from, state) do
    bin_to_send = <<value::128-little>>

    new_state =
      state
      |> write_buffer(bin_to_send)

    {:reply, new_state.buff, new_state}
  end

  @impl true
  def handle_call({:write_string, value}, _from, state) do
    bin_value = :binary.bin_to_list(value)

    new_state =
      state
      |> do_write_u32(length(bin_value))
      |> write_buffer(value)

    {:reply, new_state.buff, new_state}
  end

  @impl true
  def handle_call({:write_array, values}, _from, state) do
    new_state =
      state
      |> do_write_u32(length(values))

    {:reply, new_state.buff, new_state}
  end

  @impl true
  def handle_call({:write_fixed_array, value}, _from, state) do
    new_state = write_buffer(state, value)
    {:reply, new_state.buff, new_state}
  end

  defp write_buffer(state, buffer) do
    state
    |> update_in([:buff], fn buff ->
      Enum.concat([
        Enum.take(buff, state.length),
        :binary.bin_to_list(buffer)
      ])
    end)
    |> update_in([:length], fn state_length ->
      buff_length =
        buffer
        |> :binary.bin_to_list()
        |> length()

      state_length + buff_length
    end)
  end

  defp do_write_u32(state, value) do
    bin_value = :binary.bin_to_list(<<value::32-little>>)

    state
    |> update_in([:buff], fn list ->
      list
      |> List.insert_at(state.length, bin_value)
      |> List.flatten()
    end)
    |> put_in([:length], state.length + 4)
  end

  @impl true
  def handle_cast(:clean_state, _) do
    {:noreply, %{buff: [], length: 0}}
  end
end
