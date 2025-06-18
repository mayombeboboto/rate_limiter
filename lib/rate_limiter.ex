defmodule RateLimiter do
  @moduledoc """
  Provides a unified API for rate limiting using either the Leaky Bucket or Token Bucket algorithms.

  This module allows you to start, interact with, and reset rate limiter processes by name.
  The specific algorithm and its configuration are determined by the options provided at startup.

  ## Supported Algorithms

    * `:leaky_bucket` - Processes requests at a fixed interval, rejecting new requests when full.
    * `:token_bucket` - Allows bursts up to a capacity, refilling tokens at a fixed rate.

  ## Example

      # Start a leaky bucket limiter
      {:ok, _pid} = RateLimiter.start_link(:my_leaky, algorithm: :leaky_bucket, capacity: 5, interval: 1)
      RateLimiter.wait_for_turn(:my_leaky)

      # Start a token bucket limiter
      {:ok, _pid} = RateLimiter.start_link(:my_token, algorithm: :token_bucket, capacity: 10, rate: 2, interval: 1)
      RateLimiter.wait_for_turn(:my_token)
  """

  alias RateLimiter.DynamicSupervisor, as: DynamicSup
  alias RateLimiter.{LeakyBucket, TokenBucket}

  @type name() :: atom()
  @type t() :: LeakyBucket.t() | TokenBucket.t()

  @typedoc """
  Options for starting a Leaky Bucket rate limiter.

    * `:algorithm` - must be `:leaky_bucket`
    * `:capacity` - maximum number of requests in the bucket (required)
    * `:interval` - time interval in seconds (default: 1)
  """
  @type leaky_bucket_opts ::
          [
            algorithm: :leaky_bucket,
            capacity: pos_integer(),
            interval: pos_integer()
          ]

  @typedoc """
  Options for starting a Token Bucket rate limiter.

    * `:algorithm` - must be `:token_bucket`
    * `:capacity` - maximum number of tokens in the bucket (default: 5)
    * `:rate` - number of tokens added per interval (default: 1)
    * `:interval` - time interval in seconds for token refill (default: 1)
  """
  @type token_bucket_opts ::
          [
            algorithm: :token_bucket,
            capacity: pos_integer(),
            rate: pos_integer(),
            interval: pos_integer()
          ]

  @typedoc """
  Options for starting a rate limiter. Must be either `leaky_bucket_opts` or `token_bucket_opts`.
  """
  @type options :: leaky_bucket_opts | token_bucket_opts

  @doc """
  Starts a rate limiter child process registered under the given name.

  ## Options

    * `:algorithm` - The rate limiting algorithm (`:leaky_bucket` or `:token_bucket`). **Required**.
    * Other options are passed to the respective bucket module.

  ## Returns

    * `{:ok, pid}` on success.
    * `{:error, reason}` on failure.
  """
  @spec spawn_rate_limiter(name(), options()) :: DynamicSupervisor.on_start_child()
  defdelegate spawn_rate_limiter(name, opts), to: DynamicSup

  @doc """
  Requests permission to proceed according to the rate limiter's policy.

  Returns `:ok` if allowed, or an error tuple if not.
  """
  @spec wait_for_turn(name()) :: :ok | {:error, term()}
  def wait_for_turn(name), do: execute(name, :wait_for_turn)

  @doc """
  Returns the current state of the rate limiter for the given name.
  """
  @spec bucket_stats(name()) :: t()
  def bucket_stats(name), do: execute(name, :bucket_stats)

  defp execute(name, func) do
    case RateLimiter.Registry.lookup(name) do
      {:error, reason} -> {:error, reason}
      {:ok, mod} -> apply(mod, func, [name])
    end
  end
end
