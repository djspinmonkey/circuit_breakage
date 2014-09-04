# CircuitBreakage

A simple Circuit Breaker implementation in Ruby with a timeout.  A Circuit
Breaker wraps potentially troublesome logic and will "trip" the circuit (and
stop trying to run the logic) if it sees too many failures.  After a while, it
will retry.

## Usage

```ruby
block = ->(*args) do
  # Some dangerous thing.
end

breaker = CircuitBreakage.new(block)
breaker.failure_threshold = 3 # only 3 failures before tripping circuit
breaker.duration = 10         # 10 seconds before retry
breaker.timeout = 0.5         # 500 milliseconds allowed before auto-fail

breaker.call(*some_args)      # args are passed through to block
