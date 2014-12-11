module CircuitBreakage
  # Similar to Breaker, but accepts a redis connection and an arbitrary key,
  # and will share state among an arbitrary number of RedisBackedBreakers via
  # redis. Relies on the SETNX redis command.
  #
  class RedisBackedBreaker < Breaker
    attr_reader :connection, :key

    def initialize(connection, key, block)
      raise NotImplementedError.new("Still working on it!")

      @connection = connection
      @key = key
      super(block)
    end

    def state
      @connection.get("#{@key}/state")
    end

    def state=(state)
      @connection.set("#{@key}/state", state)
    end

    def last_failed
      @connection.get("#{@key}/last_failed")
    end

    # TODO: Appropriate locking and such. See http://redis.io/commands/setnx
  end
end
