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
      @block = block
      self.failure_threshold  = DEFAULT_FAILURE_THRESHOLD
      self.duration           = DEFAULT_DURATION
      self.timeout            = DEFAULT_TIMEOUT

      self.failure_count ||= 0
      self.last_failed   ||= Time.at(0)
      closed!
    end

    def call(*args)
      if open?
        if time_to_retry?
          half_open!
        else
          raise CircuitOpen
        end
      end

      begin
        ret_value = nil
        Timeout.timeout(self.timeout, CircuitTimeout) do
          ret_value = @block.call(*args)
        end
        handle_success

        return ret_value
      rescue Exception => e
        handle_failure
      end
    end

    [:open, :closed, :half_open].each do |state|
      define_method("#{state}?") {
        self.state == state
      }

      define_method("#{state}!") {
        self.state = state
      }
    end

    private

    def time_to_retry?
      Time.now >= self.last_failed + self.duration
    end

    def handle_success
      closed!
      self.failure_count = 0
    end

    def handle_failure
      self.last_failed = Time.now
      self.failure_count += 1
      open! if self.failure_count >= self.failure_threshold
    end
  end
end
