defmodule RateLimiter.TokenBucket do
  @moduledoc """
  Implements a Token Bucket rate limiter as a GenServer.
  """

  use GenServer

  @type t() :: %__MODULE__{
          capacity: pos_integer(),
          rate: pos_integer(),
          tokens: pos_integer(),
          interval: pos_integer()
        }

  defstruct [:capacity, :rate, :tokens, :interval]

  # Public API

  @doc false
  @spec start_link(atom(), keyword()) :: GenServer.on_start()
  def start_link(name, opts) do
    GenServer.start_link(__MODULE__, opts, name: via(name))
  end

  @doc false
  @spec wait_for_turn(term()) :: :ok | {:error, :no_token}
  def wait_for_turn(name) do
    GenServer.call(via(name), :wait_for_turn)
  end

  @doc false
  @spec bucket_stats(atom()) :: t()
  def bucket_stats(name) do
    GenServer.call(via(name), :bucket_stats)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    # tokens/sec
    rate = Keyword.get(opts, :rate, 1)
    capacity = Keyword.get(opts, :capacity, 5)
    interval = Keyword.get(opts, :interval, 1)

    # Start periodic refill
    {:ok, _ref} =
      interval
      |> :timer.seconds()
      |> :timer.send_interval(:refill)

    {
      :ok,
      %__MODULE__{
        rate: rate,
        tokens: capacity,
        capacity: capacity,
        interval: interval
      }
    }
  end

  @impl true
  def handle_call(:wait_for_turn, _from, %__MODULE__{tokens: tokens} = state)
      when tokens > 0 do
    {:reply, :ok, %__MODULE__{state | tokens: tokens - 1}}
  end

  def handle_call(:wait_for_turn, _from, state) do
    {:reply, {:error, :no_token}, state}
  end

  def handle_call(:bucket_stats, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:refill, %__MODULE__{tokens: tokens, rate: rate, capacity: capacity} = state) do
    new_tokens = min(tokens + rate, capacity)
    {:noreply, %__MODULE__{state | tokens: new_tokens}}
  end

  defp via(name) do
    {:via, Registry, {RateLimiter.Registry, name, __MODULE__}}
  end
end
