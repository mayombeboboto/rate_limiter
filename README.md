# RateLimiter

[![CI](https://github.com/elixir-plug/mime/actions/workflows/ci.yml/badge.svg)](https://github.com/mayombeboboto/rate_limiter/actions/workflows/ci.yml)

RateLimiter is an Elixir library that provides robust, concurrent-safe rate limiting using two classic algorithms: **Leaky Bucket** and **Token Bucket**. It is designed for use in distributed systems, APIs, background jobs, or anywhere you need to control the rate of operations.

## Features

- **Leaky Bucket**: Queues requests and processes them at a fixed rate. Excess requests are rejected if the bucket is full.
- **Token Bucket**: Allows bursts up to a set capacity, refilling tokens at a configurable rate.
- **GenServer-based**: Each limiter runs as a supervised process, supporting concurrency and fault-tolerance.
- **Named Limiters**: Start and interact with multiple independent limiters by name.
- **Unified API**: Interact with both algorithms using a single, simple interface.

## Installation

Add `rate_limiter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:rate_limiter, "~> 0.1.0"}
  ]
end
```

## Usage

> ### Warning {: .warning}
>
> Ensure `rate_limiter` application is started.

### Starting a Rate Limiter

You can start a rate limiter process with either algorithm:

#### Leaky Bucket

```elixir
{:ok, _pid} = RateLimiter.spawn_rate_limiter(:my_leaky, algorithm: :leaky_bucket, capacity: 5, interval: 1)
```

- `:capacity` - Maximum number of requests that can be queued (required)
- `:interval` - Time interval in seconds over which the capacity is enforced (default: 1)

#### Token Bucket

```elixir
{:ok, _pid} = RateLimiter.spawn_rate_limiter(:my_token, algorithm: :token_bucket, capacity: 10, rate: 2, interval: 1)
```

- `:capacity` - Maximum number of tokens in the bucket (default: 5)
- `:rate` - Number of tokens added per interval (default: 1)
- `:interval` - Time interval in seconds for token refill (default: 1)

### Requesting Permission

To check if an action is allowed (and update the limiter’s state):

```elixir
case RateLimiter.wait_for_turn(:my_leaky) do
  :ok -> do_the_thing()
  {:error, reason} -> handle_rate_limit(reason)
end
```

### Checking Limiter State

```elixir
RateLimiter.bucket_stats(:my_leaky)
```

## Example

```elixir
{:ok, _pid} = RateLimiter.spawn_rate_limiter(:api_limiter, algorithm: :leaky_bucket, capacity: 10, interval: 1)

for _ <- 1..12 do
  IO.inspect RateLimiter.wait_for_turn(:api_limiter)
end
```

## Algorithms

### Leaky Bucket

- Requests are queued up to `:capacity`.
- Requests are processed at a fixed interval.
- If the bucket is full, new requests are rejected with `{:error, :bucket_full}`.

### Token Bucket

- Each request consumes a token.
- Tokens are refilled at a fixed rate up to `:capacity`.
- If no tokens are available, requests are rejected with `{:error, :no_token}`.

## When to Use

- **Leaky Bucket**: When you want a steady, constant rate of processing (e.g., smoothing out bursts).
- **Token Bucket**: When you want to allow short bursts but enforce an average rate over time.

## Contributing

Before submitting a PR, ensure you run `mix check` and all checks passes
successfully.

## Version Bumps

This project adheres to [Semantic Versioning][semantic-versioning],
which means the version number will follow the format `MAJOR.MINOR.PATCH`.

Also, the [github-tag-action][github-tag-action] is used to automatically
create a new tag when the PR is merged to master.

When open a PR meant to generate a new version:

1. Update the `mix.exs` and `README` with the new version.

2. Update [CHANGELOG](CHANGELOG.md) with the new version tight to
   [semantic versioning][semantic-versioning].

3. Don't forget to include in your commit the tag:

   - `"#patch"` for increment `PATCH` version.
     E.g.: **"Fix failing tests (#patch)"**.
   - `"#minor"` for increment `MINOR` version.
     E.g.: **"Add Telemetry utility to instrument the projects (#minor)"**.
   - `"#major"` for increment `MAJOR` version.
     E.g.: **"Release x.y.z (#major)"**.

[github-tag-action]: https://github.com/anothrNick/github-tag-action
[semantic-versioning]: https://semver.org/spec/v2.0.0.html

If for some reason GH actions are not working (maybe because we ran out of
minutes), then push the tag manually, like so:

```
git tag -a v0.1.0 -m "RateLimiter version 0.1.0"
git push origin v0.1.0
```

## License

Apache License 2.0. See the project’s LICENSE file for details.
