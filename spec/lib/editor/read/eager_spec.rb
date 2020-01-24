# frozen_string_literal: true

require 'spec_helper'
require_relative 'inherited_from_reader_base_shared_examples'

describe Editor, :editor do
  include VimlValue::SerializationHelpers

  let(:cache_enabled) { false }
  let(:subject) { Editor::Read::Eager.new(method(:vim), cache_enabled) }

  describe '#echo' do
    # arbitrary expression which is easy to use for inspection of the method
    def abs(numeric)
      subject.echo func('abs', numeric)
    end

    context 'when cache_enabled: true' do
      let(:cache_enabled) { true }

      context 'when batches are identical' do
        it 'fetches each value once separately' do
          expect(vim).to receive(:echo).once.with('[abs(-1)]').and_call_original
          expect(vim).to receive(:echo).once.with('[abs(-2)]').and_call_original

          expect([abs(-1), abs(-2)]).to eq([1, 2])
          expect([abs(-1), abs(-2)]).to eq([1, 2])
        end
      end

      context 'when the second batch is smaller' do
        it 'fetches each value once separately' do
          expect(vim).to receive(:echo).once.with('[abs(-1)]').and_call_original
          expect(vim).to receive(:echo).once.with('[abs(-2)]').and_call_original

          expect([abs(-1), abs(-2)]).to eq([1, 2])
          expect(abs(-2)).to eq(2)
        end
      end

      context 'when the first batch is smaller' do
        it 'fetches each value once separately' do
          expect(vim).to receive(:echo).once.with('[abs(-1)]').and_call_original
          expect(abs(-1)).to eq(1)

          expect(vim).to receive(:echo).once.with('[abs(-2)]').and_call_original
          expect([abs(-1), abs(-2)]).to eq([1, 2])
        end
      end
    end

    context 'when cache_enabled: false' do
      let(:cache_enabled) { false }

      context 'when batches are identical' do
        it 'fetches separately ignoring caching' do
          expect(vim).to receive(:echo).twice.with('[abs(-1)]').and_call_original
          expect(vim).to receive(:echo).twice.with('[abs(-2)]').and_call_original

          expect([abs(-1), abs(-2)]).to eq([1, 2])
          expect([abs(-1), abs(-2)]).to eq([1, 2])
        end
      end

      context 'when the second batch is smaller' do
        it 'fetches separately ignoring caching' do
          expect(vim).to receive(:echo).once.with('[abs(-1)]').and_call_original
          expect(vim).to receive(:echo).twice.with('[abs(-2)]').and_call_original

          expect([abs(-1), abs(-2)]).to eq([1, 2])
          expect(abs(-2)).to eq(2)
        end
      end

      context 'when the first batch is smaller' do
        it 'fetches separately ignoring caching' do
          expect(vim).to receive(:echo).twice.with('[abs(-1)]').and_call_original
          expect(abs(-1)).to eq(1)

          expect(vim).to receive(:echo).once.with('[abs(-2)]').and_call_original
          expect([abs(-1), abs(-2)]).to eq([1, 2])
        end
      end
    end

    describe 'errors handling' do
      it { expect { subject.echo(func('undefined')).to_s }.to raise_error(Editor::Read::Base::ReadError) }
      it { expect { subject.echo(func('Undefined')).to_s }.to raise_error(Editor::Read::Base::ReadError) }
      it { expect { subject.echo(var('undefined')).to_s }.to  raise_error(Editor::Read::Base::ReadError) }
    end
  end

  include_context 'inherited from Editor::Read::Base'
  describe '#with_ignore_cache' do
    include_examples '#with_ignore_cache'
  end

  describe '#handle_state_change!' do
    include_examples '#handle_state_change!'
  end
end
