defmodule Consumer do
  @moduledoc """
  Documentation for `Consumer`.
  """

  use GenServer
  require Logger
  alias :jsx, as: JSX
  @queue "test_queue"

  # APIs
  @spec start_link() :: {:ok, pid()}
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec stop() :: no_return()
  def stop() do
    GenServer.stop(__MODULE__, :normal)
  end

  # Callback functions
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

    # The current process becomes the de facto consumer
    # Of all incoming messages from the queue.
    {:ok, tag} = AMQP.Basic.consume(chan, @queue, self())
    {:noreply, %{tag: tag, chan: chan, count: 0, conn: conn}}
  end

  def handle_info(
        {:basic_consume_ok, %{consumer_tag: tag}},
        state = %{tag: tag}
      ) do
    IO.puts("Tag: #{tag}")
    {:noreply, state}
  end

  def handle_info({:basic_deliver, payload, headers}, state) do
    Logger.info("Payload consumer: #{inspect(JSX.decode(payload))}")
    AMQP.Basic.ack(state.chan, headers.delivery_tag)
    {:noreply, state}
  end

  def handle_info(info, state) do
    Logger.info("Unknown info: #{inspect(info)}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    AMQP.Channel.close(state.chan)
    AMQP.Connection.close(state.conn)
  end
end
