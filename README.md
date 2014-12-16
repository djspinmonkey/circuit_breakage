# CircuitBreakage

A simple Circuit Breaker implementation in Ruby with a timeout.  A Circuit
Breaker wraps potentially troublesome logic and will "trip" the circuit (ie,
stop trying to run the logic) if it sees too many failures.  After a while, it
will retry.

## Usage

### Normal Boring Circuit Breakers

```ruby
block = ->(*args) do
  # Some dangerous thing.
end

breaker = CircuitBreakage::Breaker.new(block)
breaker.failure_threshold = 3 # only 3 failures before tripping circuit
breaker.duration = 10         # 10 seconds before retry
breaker.timeout = 0.5         # 500 milliseconds allowed before auto-fail

begin
  breaker.call(*some_args)    # args are passed through to block
rescue CircuitBreaker::CircuitOpen
  puts "Too many recent failures!"
rescue CircuitBreaker::CircuitTimeout
  puts "Operation timed out!"
end
```

### Redis-backed "Shared" Circuit Breakers

The unique feature of this particular Circuit Breaker gem is that it also
supports shared state via Redis, using the SETNX and GETSET commands.  This
allows a number of circuit breakers running in separate processes to trip and
un-trip in unison. To be specific, when the circuit is closed, all processes
proceed as normal. When the circuit is open, all processes will raise
`CircuitBreakage::CircuitOpen`. When the circuit is open, but the retry
duration has expired (this is sometimes referred to as a "half open" state),
exactly *one* process will retry, and then either close the circuit or reset
the retry timer as appropriate.

```ruby
connection = some_redis_connection
key = 'my_app/some_operation'

breaker = CircuitBreakage::RedisBackedBreaker.new(connection, key, block)
# Everything else is the same as above.
```
