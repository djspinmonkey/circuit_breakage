# TODO: Extract the common tests (ie, most of them) in to a shared example
# group for this and the vanilla Breaker spec.

module CircuitBreakage
  describe RedisBackedBreaker do
    let(:breaker)    { RedisBackedBreaker.new(connection, key, block) }
    let(:connection) { MockRedis.new }
    let(:key)        { 'test/data' }
    let(:block)      { ->(x) { return x } }

    describe '#call' do
      subject { -> { breaker.call(arg) rescue nil } }
      let(:arg) { 'This is an argument.' }

      context 'when the circuit is closed' do
        before { breaker.state = 'closed' }

        it 'calls the block' do
          # The default block just returns the arg.
          expect(breaker.call(arg)).to eq arg
        end

        context 'and the call succeeds' do
          it 'resets the failure count' do
            breaker.failure_count = 3
            expect { breaker.call(arg) }.to change { breaker.failure_count }.to(0)
          end
        end

        context 'and the call fails' do
          let(:block) { ->(_) { raise 'some error' } }

          it { is_expected.to change { breaker.failure_count }.by(1) }
          it { is_expected.to change { breaker.last_failed } }

          context 'and the failure count exceeds the failure threshold' do
            before { breaker.failure_count = breaker.failure_threshold }

            it { is_expected.to change { breaker.state }.to('open') }
          end
        end

        context 'and the call times out' do
          let(:block) { ->(_) { sleep 2 } }
          before { breaker.timeout = 0.1 }

          it 'counts as a failure' do
            expect { breaker.call(arg) rescue nil }.to change { breaker.failure_count }.by(1)
          end
        end
      end

      context 'when the circuit is open' do
        before { breaker.state = 'open' }

        context 'before the retry_time' do
          before { breaker.last_failed = Time.now - breaker.duration + 30 }

          it 'raises CircuitBreakage::CircuitOpen' do
            expect { breaker.call(arg) }.to raise_error(CircuitOpen)
          end
        end

        context 'after the retry time' do
          it 'calls the block' do
            breaker.last_failed = Time.at(0)
            expect(breaker.call(arg)).to eq arg
          end

          # TODO: It would be nice to test some of the concurrency scenarios,
          # but that's pretty tricky to do politely in a test suite.
        end
      end
    end
  end
end

class MockRedis
  attr_accessor :stored_data

  def initialize
    @stored_data = {}
  end

  def get(key)
    @stored_data[key]
  end

  def set(key, val)
    @stored_data[key] = val
  end

  def setnx(key, val)
    if @stored_data[key].nil?
      @stored_data[key] = val
      return 1
    else
      return 0
    end
  end

  def getset(key, val)
    old_val = @stored_data[key]
    @stored_data[key] = val
    return old_val
  end

  def del(key)
    @stored_data.delete(key)
  end
end
