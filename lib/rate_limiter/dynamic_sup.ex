defmodule RateLimiter.DynamicSupervisor do
  @moduledoc false
  use DynamicSupervisor

  alias RateLimiter.{LeakyBucket, TokenBucket}

  @type name() :: atom()

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec spawn_rate_limiter(name(), keyword()) :: {:ok, pid()}
  def spawn_rate_limiter(name, opts) do
    mod =
      Keyword.fetch!(opts, :algorithm)
      |> get_module()

    child_spec = %{
      id: mod,
      restart: :transient,
      start: {mod, :start_link, [name, opts]}
    }

    {:ok, _pid} = DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Private helper to select the rate limiter module based on the algorithm option.
  defp get_module(:leaky_bucket), do: LeakyBucket
  defp get_module(:token_bucket), do: TokenBucket
end
