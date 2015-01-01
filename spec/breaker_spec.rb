module CircuitBreakage
  describe Breaker do
    let(:breaker) { Breaker.new(block) }
    let(:block) { ->(x) { return x } }

    it 'initializes with a block' do
      block = ->() { "This is a block!" }
      breaker = Breaker.new(block)
      expect(breaker).to be_a(Breaker)
    end

    describe '#call' do
      subject { -> { breaker.call(arg) rescue nil} }
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
          it { is_expected.to change { breaker.last_exception }.from(nil) }

          it 'raises the exception that caused the failure' do
            expect { breaker.call(arg) }.to raise_exception('some error')
          end

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

          it 'raises CircuitBreakage::CircuitTimeout' do
            expect { breaker.call(arg) }.to raise_exception(CircuitBreakage::CircuitTimeout)
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
          before { breaker.last_failed = Time.now - breaker.duration - 30 }

          it 'calls the block' do
            expect(breaker.call(arg)).to eq arg
          end
        end
      end
    end
  end
end
