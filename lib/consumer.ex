defmodule Consumer do
  @moduledoc """
  Documentation for `Consumer`.
  """

  use GenServer
  @queue "test_queue"
  @limit 10

  @spec start_link() :: {:ok, pid()}
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl GenServer
  def init(nil) do
    Process.flag(:trap_exit, true)
    send(self(), :init)
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:init, _state) do
    {:ok, conn} = AMQP.Connection.open()
    {:ok, chan} = AMQP.Channel.open(conn)

    {:ok, tag} = AMQP.Basic.consume(chan, @queue)
    {:noreply, %{ tag: tag, chan: chan, count: 0 }}
  end
  def handle_info({:basic_consume_ok, %{ consumer_tag: tag }}, state=%{ tag: tag }) do
    IO.puts("Tag: #{tag}")
    {:noreply, state}
  end
  def handle_info({:basic_deliver, _payload, headers}, state) when state.count < @limit do
    IO.puts("Headers's keys: #{inspect(Map.keys(headers))}")
    AMQP.Basic.ack(state.chan, headers.delivery_tag)
    {:noreply, Map.update(state, :count, 0, &(&1+1))}
  end
  def handle_info({:basic_deliver, _payload, headers}, state) do
    AMQP.Basic.ack(state.chan, headers.delivery_tag)
    AMQP.Basic.cancel(state.chan, state.tag)
    {:noreply, state}
  end
  def handle_info(info, state) do
    IO.puts("#{inspect(info)}")
    {:noreply, state}
  end
end
