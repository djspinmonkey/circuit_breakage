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

breaker.call(*some_args)      # args are passed through to block
```

## "Shared" Circuit Breakers

The unique feature of this particular Circuit Breaker gem is that it also
supports shared state via memcache (or some other backing data store).  This
allows a number of circuit breakers running in separate processes to trip and
un-trip in unison.

```ruby
cache = Rails.cache    # Anything that provides similar `write` and `fetch` works
key = 'my_app/some_operation'

breaker = CircuitBreakage::CachingBreaker.new(cache, key, block)
# Everything else is the same as above.
```

So, if you have the same piece of code running on 27 instances across 3
different servers, as soon as one trips, they all trip, and as soon as one
resets, they all reset.
