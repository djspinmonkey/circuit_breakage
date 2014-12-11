require 'timeout'

module CircuitBreakage
  class CircuitOpen < RuntimeError; end
  class CircuitTimeout < RuntimeError; end

  # A simple circuit breaker implementation.  See the main README for usage
  # details.
  #
  class Breaker
    attr_accessor :failure_count, :last_failed, :state, :block
    attr_accessor :failure_threshold, :duration, :timeout

    DEFAULT_FAILURE_THRESHOLD = 5     # Number of failures required to trip circuit
    DEFAULT_DURATION          = 300   # Number of seconds the circuit stays tripped
    DEFAULT_TIMEOUT           = 10    # Number of seconds before the call times out

    def initialize(block)
      self.block              = block
      self.failure_threshold  = DEFAULT_FAILURE_THRESHOLD
      self.duration           = DEFAULT_DURATION
      self.timeout            = DEFAULT_TIMEOUT
      self.failure_count      ||= 0
      self.last_failed        ||= Time.at(0)
      self.state              ||= 'closed'
    end

    def call(*args)
      case(state)
      when 'open'
        if time_to_retry?
          do_retry(*args)
        else
          raise CircuitOpen
        end
      when 'closed'
        do_call(*args)
      end
    end

    private

    # Defined independently so that it can be overridden.
    def do_retry(*args)
      do_call(*args)
    end

    def do_call(*args)
      ret_value = nil
      Timeout.timeout(self.timeout, CircuitTimeout) do
        ret_value = @block.call(*args)
      end
      handle_success

      return ret_value
    rescue Exception => e
      handle_failure
    end

    def time_to_retry?
      Time.now >= self.last_failed + self.duration
    end

    def handle_success
      self.failure_count = 0
      self.state = 'closed'
    end

    def handle_failure
      self.last_failed = Time.now
      self.failure_count += 1
      if self.failure_count >= self.failure_threshold
        self.state = 'open'
      end
    end
  end
end
