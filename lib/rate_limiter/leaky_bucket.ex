defmodule RateLimiter.LeakyBucket do
  @moduledoc """
  Implements a Leaky Bucket rate limiter as a GenServer.
  """

  use GenServer

  @type t() :: %__MODULE__{
          capacity: pos_integer(),
          interval: pos_integer(),
          queue: :queue.queue(),
          length: non_neg_integer()
        }

  defstruct [:capacity, :interval, :queue, :length]

  # Public API

  @doc false
  @spec start_link(atom(), keyword()) :: GenServer.on_start()
  def start_link(name, opts) do
    GenServer.start_link(__MODULE__, opts, name: via(name))
  end

  @doc false
  @spec wait_for_turn(atom()) :: :ok | {:error, :bucket_full}
  def wait_for_turn(name) do
    GenServer.call(via(name), :wait_for_turn, :infinity)
  end

  @doc false
  @spec bucket_stats(atom()) :: t()
  def bucket_stats(name) do
    GenServer.call(via(name), :bucket_stats)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, 1)
    capacity = Keyword.get(opts, :capacity, 1)

    interval_per_req =
      div(interval, capacity)
      |> :timer.seconds()

    {:ok, _ref} = :timer.send_interval(interval_per_req, :trigger)

    {:ok,
     %__MODULE__{
       interval: interval,
       capacity: capacity,
       queue: :queue.new(),
       length: 0
     }}
  end

  @impl true
  def handle_call(:wait_for_turn, from, %__MODULE__{length: length} = state) do
    if length < state.capacity do
      queue = :queue.in(from, state.queue)
      new_state = %__MODULE__{state | queue: queue, length: length + 1}

      {:noreply, new_state}
    else
      {:reply, {:error, :bucket_full}, state}
    end
  end

  def handle_call(:bucket_stats, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:trigger, %__MODULE__{length: 0} = state) do
    {:noreply, state}
  end

  def handle_info(:trigger, %__MODULE__{length: length} = state) do
    {{:value, from}, queue} = :queue.out(state.queue)

    GenServer.reply(from, :ok)
    {:noreply, %__MODULE__{state | queue: queue, length: length - 1}}
  end

  defp via(name) do
    {:via, Registry, {RateLimiter.Registry, name, __MODULE__}}
  end
end
