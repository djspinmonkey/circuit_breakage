module CircuitBreakage
  # Similar to Breaker, but accepts a Redis connection and an arbitrary key,
  # and will share state among an arbitrary number of RedisBackedBreakers via
  # Redis. Relies on the SETNX redis command.
  #
  class RedisBackedBreaker < Breaker

    # How long before we decide a lock-holder has crashed, in seconds.
    LOCK_TIMEOUT = DEFAULT_TIMEOUT + 10

    attr_reader :connection, :key

    def initialize(connection, key, block)
      raise NotImplementedError.new("Still working on it!")

      @connection = connection
      @key = key
      super(block)
    end

    private

    def do_retry(*args)
      try_with_mutex('half_open_retry') do
        super
      end
    end

    def try_with_mutex(lock, &block)
      mutex_key = "#{@key}/locks/#{lock}"

      acquired = @connection.setnx(mutex_key, Time.now.to_i)
      if acquired = 0   # mutex is already acquired
        locked_at = @connection.get(mutex_key)
        return if locked_at + LOCK_TIMEOUT < Time.now.to_i  # unexpired lock
        locked_at_second_check = @connection.getset(mutex_key, Time.now.to_i)
        return if locked_at_second_check != locked_at       # expired lock, but somebody beat us to it
      end
      # If we get this far, we have successfully acquired the mutex.

      begin
        block.call
      ensure
        @connection.del(mutex_key)
      end
    end

    [:state, :failure_count, :last_failed].each do |attr|
      attr_key = "#{@key}/attrs/#{attr}"

      define_method(attr) do
        @connection.get(attr_key)
      end

      define_method("#{attr}=") do |value|
        @connection.set(attr_key, value)
      end
    end

  end
end
