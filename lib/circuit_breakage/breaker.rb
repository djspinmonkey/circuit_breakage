require 'timeout'

module CircuitBreakage
  class CircuitOpen < RuntimeError; end
  class CircuitTimeout < RuntimeError; end

  # A simple circuit breaker implementation.  See the main README for usage
  # details.
  #
  class Breaker
    attr_accessor :failure_count, :last_failed, :state, :block
    attr_accessor :failure_threshold, :duration, :timeout, :last_exception

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
      Timeout.timeout(self.timeout) do
        ret_value = @block.call(*args)
      end
      handle_success

      return ret_value
    rescue Exception => e
      handle_failure(e)
    end

    def time_to_retry?
      Time.now >= self.last_failed + self.duration
    end

    def handle_success
      self.failure_count = 0
      self.state = 'closed'
    end

    def handle_failure(error)
      self.last_failed = Time.now
      self.failure_count += 1
      if self.failure_count >= self.failure_threshold
        self.state = 'open'
      end

      self.last_exception = error

      if error.instance_of?(Timeout::Error)
        # Raising an instance of Interrupt seems pretty rude, and there's no
        # useful information in Timeout::Error anyway, so re-raise timeout
        # errors as our own error class.
        raise CircuitTimeout, "Circuit breaker timed out."
      else
        raise(error)
      end
    end
  end
end
