# CircuitBreakage

A simple circuit breaker implementation in Ruby with a timeout.  A circuit
breaker wraps a potentially troublesome block of code and will "trip" the
circuit (ie, stop trying to run the code) if it sees too many failures.  After
a configurable amount of time, the circuit breaker will retry.

See http://martinfowler.com/bliki/CircuitBreaker.html for a more complete
description of the pattern.

## Usage

### Simple Example

```ruby
proc = ->(*args) do
  # Some dangerous thing.
end

breaker = CircuitBreakage::Breaker.new(proc)
breaker.failure_threshold =   3 # only 3 failures before tripping circuit
breaker.duration          =  10 # 10 seconds before retry
breaker.timeout           = 0.5 # 500 milliseconds allowed before auto-fail

begin
  breaker.call(*some_args)    # args are passed through to the proc
rescue CircuitBreakage::CircuitOpen
  puts "Too many recent failures!"
rescue CircuitBreakage::CircuitTimeout
  puts "Operation timed out!"
end
```

A "failure" in this context means that the proc either raised an exception or
timed out.

### Slightly More Complex Example in Rails

This example shows one way you might choose to wrap a remote service call in a
Rails app.

```ruby
# in your controller
class MyController
  def show
    widget_client = WidgetClient.new
    @widgets = widget_client.get_widget(id)
  end
end

# in lib/widget_client.rb
class WidgetClient
  class << self
    def breaker
      if @breaker.nil?
        @breaker = CircuitBreakage::Breaker.new method(:do_get_widget)
        @breaker.failure_threshold =   3
        @breaker.duration          =  10
        @breaker.timeout           = 0.5
      end

      return @breaker
    end

    def do_get_widget(id)
      # Do the remote service call here.
    end
  end

  def get_widget(id)
    class.breaker.call(id)
  end
end
```

This makes it easy to control all calls to the remote service with a single
breaker. This way, they are all tripped and reset together, even if the service
is called by several different parts of your code. Don't forget to handle
errors somewhere -- probably either the controller or the client library,
depending on the needs of your code.

Note that we've actually used a `Method` object rather than a proc to
initialize the circuit breaker. That's fine -- breakers will actually work with
any object that responds to `call`.

### Redis-Backed "Shared" Circuit Breakers

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
key = 'my_app/this_operation'

breaker = CircuitBreakage::RedisBackedBreaker.new(connection, key, proc)
breaker.lock_timeout = 30  # seconds before assuming a locking process has crashed

# Everything else is the same as above.
```

The `lock_timeout` setting is necessary since a process that crashes or is
killed might be holding the retry lock. This sets the amount of time other
processes will wait before deciding a lock has expired.  It should be longer
than the amount of time you expect the proc to take to run.

All circuit breakers using the same key and the same Redis instance will share
their state . It is strongly recommended that their settings
(failure_threshold, duration, etc) all be configured the same!
