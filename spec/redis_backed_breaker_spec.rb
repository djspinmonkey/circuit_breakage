# TODO: Extract the common tests (ie, most of them) in to a shared example
# group for this and the vanilla Breaker spec.

module CircuitBreakage
  describe RedisBackedBreaker do
    let(:breaker)    { RedisBackedBreaker.new(connection, key, block) }
    let(:connection) { MockCache.new }
    let(:key)        { 'test/data' }
    let(:block)      { ->(x) { return x } }

    describe '#call' do
      subject { -> { breaker.call(arg) } }
      let(:arg) { 'This is an argument.' }

      context 'when the circuit is closed' do
        before { breaker.closed! }

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
          let(:block) { -> { raise 'some error' } }

          it { is_expected.to change { breaker.failure_count }.by(1) }
          it { is_expected.to change { breaker.last_failed } }

          context 'and the failure count exceeds the failure threshold' do
            before { breaker.failure_count = breaker.failure_threshold }

            it { is_expected.to change { breaker.open? }.to(true) }
          end
        end

        context 'and the call times out' do
          let(:block) { ->(_) { sleep 2 } }
          before { breaker.timeout = 0.1 }

          it 'counts as a failure' do
            expect { breaker.call(arg) }.to change { breaker.failure_count }.by(1)
          end
        end
      end

      context 'when the circuit is open' do
        before { breaker.open! }

        context 'before the retry_time' do
          before { breaker.last_failed = Time.now - breaker.duration + 30 }

          it { is_expected.to raise_error(CircuitOpen) }
        end

        context 'after the retry time' do
          before { breaker.last_failed = Time.now - breaker.duration - 30 }

          it 'calls the block' do
            # This is the same as being half open, see below for further tests.
            expect(breaker.call(arg)).to eq arg
          end
        end
      end

      context 'when the circuit is half open' do
        before do
          # For the circuit to be tripped in the first place, the failure count
          # must have reached the failure threshold.
          breaker.failure_count = breaker.failure_threshold
          breaker.half_open!
        end

        it 'calls the block' do
          expect(breaker.call(arg)).to eq arg
        end

        context 'and the call succeeds' do
          before { breaker.failure_count = 3 }

          it { is_expected.to change { breaker.closed? }.to(true) }
          it { is_expected.to change { breaker.failure_count }.to(0) }
        end

        context 'and the call fails' do
          let(:block) { -> { raise 'some error' } }

          it { is_expected.to change { breaker.open? }.to(true) }
          it { is_expected.to change { breaker.last_failed } }
        end
      end
    end

    # #half_open?, #half_open!, #closed?, and #closed! are all exactly the same
    # as #open? and #open!, so we're just going to test the open methods.

    describe '#open!' do
      it 'opens the circuit' do
        breaker.open!
        expect(breaker).to be_open
      end
    end

    describe '#open?' do
      subject { breaker.open? }

      context 'when open' do
        before { breaker.open! }
        it { is_expected.to be_truthy }
      end

      context 'when not open' do
        before { breaker.closed! }
        it { is_expected.to be_falsey }
      end
    end
  end
end

class MockCache
  attr_accessor :stored_data

  def initialize
    @stored_data = {}
  end

  def write(key, val)
    @stored_data[key] = val
  end

  def fetch(key)
    @stored_data[key]
  end
end
