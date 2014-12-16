module CircuitBreakage
  # Similar to Breaker, but accepts a Redis connection and an arbitrary key,
  # and will share state among an arbitrary number of RedisBackedBreakers via
  # Redis. Relies on the SETNX redis command.
  #
  class RedisBackedBreaker < Breaker

    # How long before we decide a lock-holder has crashed, in seconds.
    DEFAULT_LOCK_TIMEOUT = DEFAULT_TIMEOUT + 10

    attr_reader :connection, :key, :lock_timeout

    def initialize(connection, key, block)
      @connection = connection
      @key = key
      @lock_timeout = DEFAULT_LOCK_TIMEOUT
      super(block)
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

    private

    def do_retry(*args)
      try_with_mutex('half_open_retry') do
        super
      end
    end

    def try_with_mutex(lock, &block)
      mutex_key = "#{@key}/locks/#{lock}"
      lock_timestamp = Time.now.to_i

      # See http://redis.io/commands/setnx for a walkthrough of this logic.
      acquired = @connection.setnx(mutex_key, lock_timestamp)
      if !acquired
        locked_at = @connection.get(mutex_key).to_i
        raise CircuitBreakage::CircuitOpen if !lock_expired(locked_at)
        locked_at_second_check = @connection.getset(mutex_key, Time.now.to_i).to_i
        raise CircuitBreakage::CircuitOpen if locked_at_second_check != locked_at
      end

      begin
        block.call
      ensure
        if !lock_expired(lock_timestamp)
          # There's a tiny unavoidable race condition here.
          @connection.del(mutex_key)
        end
      end
    end

    def lock_expired(timestamp)
      timestamp + @lock_timeout < Time.now.to_i
    end

  end
end
