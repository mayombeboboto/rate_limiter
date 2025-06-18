defmodule RateLimiterTest do
  use ExUnit.Case

  alias RateLimiter.DynamicSupervisor, as: DynamicSup
  alias RateLimiter.{LeakyBucket, TokenBucket}

  @name :server
  describe "leaky bucket" do
    setup do
      opts = [algorithm: :leaky_bucket, capacity: 1, interval: 1]

      {:ok, pid} = RateLimiter.spawn_rate_limiter(@name, opts)
      on_exit(fn -> DynamicSupervisor.terminate_child(DynamicSup, pid) end)

      :ok
    end

    test "success: wait_for_turn/1" do
      queue = :queue.new()
      assert :ok = RateLimiter.wait_for_turn(@name)

      # Simulate a delay to allow the bucket to refill
      Process.sleep(1000)

      assert %LeakyBucket{length: 0, queue: ^queue} =
               RateLimiter.bucket_stats(@name)
    end

    test "error: wait_for_turn/1 bucket full" do
      :ok = execute_tasks(5)

      assert_receive {:error, :bucket_full}
    end
  end

  describe "token bucket" do
    setup do
      opts = [algorithm: :token_bucket, capacity: 5, rate: 1, interval: 1]

      {:ok, pid} = RateLimiter.spawn_rate_limiter(@name, opts)
      on_exit(fn -> DynamicSupervisor.terminate_child(DynamicSup, pid) end)

      :ok
    end

    test "success: wait_for_turn/1" do
      assert :ok = RateLimiter.wait_for_turn(@name)

      # Simulate a delay to allow the bucket to refill
      Process.sleep(1_500)

      assert %TokenBucket{tokens: 5} =
               RateLimiter.bucket_stats(@name)
    end

    test "error: wait_for_turn/1 no token" do
      :ok = execute_tasks(6)

      assert_receive {:error, :no_token}
    end
  end

  test "error: unregistered bucket" do
    assert {:error, :process_not_found} = RateLimiter.wait_for_turn(:unregistered_bucket)
  end

  defp execute_tasks(process_number) do
    pid = self()

    1..process_number
    |> Task.async_stream(
      fn _ ->
        resp = RateLimiter.wait_for_turn(@name)
        send(pid, resp)
      end,
      timeout: :infinity,
      max_concurrency: process_number
    )
    |> Stream.run()
  end
end
