defmodule Nearex.Serializer do
  @moduledoc false

  require Logger

  def init_buffer do
    %{buff: [], length: 0}
  end

  def write_u8(value, state) do
    state
    |> put_in([:buff], List.insert_at(state.buff, state.length, value))
    |> put_in([:length], state.length + 1)
  end

  def write_u32(value, state) do
    do_write_u32(state, value)
  end

  def write_u64(value, state) do
    bin_to_send = <<value::64-little>>

    write_buffer(state, bin_to_send)
  end

  def write_u128(value, state) do
    bin_to_send = <<value::128-little>>

    write_buffer(state, bin_to_send)
  end

  def write_string(value, state) do
    bin_value = :binary.bin_to_list(value)

    state
    |> do_write_u32(length(bin_value))
    |> write_buffer(value)
  end

  def write_array(values, state) do
    do_write_u32(state, length(values))
  end

  def write_fixed_array(value, state) do
    write_buffer(state, value)
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
end
