module CircuitBreakage
  # Similar to Breaker, but accepts a cache object, and will call #write and
  # #fetch on that object to store and retrieve all state, instead of keeping
  # it in memory.
  #
  # This implementation is currently somewhat naive as relates to race
  # conditions, making sure only a single process actually retries, etc.  It
  # shouldn't cause any serious problems, but it's not realizing the full
  # benefits of using a shared data store yet.
  #
  class CachingBreaker < Breaker
    attr_reader :cache, :key

    def initialize(cache, key, block)
      @cache = cache
      @key = key
      super(block)
    end

    def self.cached_attr(*attrs)
      attrs.each do |attr|
        define_method attr do
          raise "You must define the cache and key on a CachingBreaker!" unless cache && key
          cache.fetch "#{key}/#{attr}"
        end

        define_method "#{attr}=" do |value|
          raise "You must define the cache and key on a CachingBreaker!" unless cache && key
          cache.write "#{key}/#{attr}", value
        end
      end
    end

    cached_attr :failure_count, :last_failed, :state
  end
end
