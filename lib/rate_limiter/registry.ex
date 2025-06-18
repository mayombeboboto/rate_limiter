defmodule RateLimiter.Registry do
  @moduledoc false

  @type name() :: atom()

  @doc false
  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(_opts) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__
    )
  end

  @doc false
  @spec lookup(name()) :: {:ok, module()} | {:error, :process_not_found}
  def lookup(name) do
    case Registry.lookup(__MODULE__, name) do
      [{_pid, module}] -> {:ok, module}
      [] -> {:error, :process_not_found}
    end
  end
end
