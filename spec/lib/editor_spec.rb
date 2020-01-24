# frozen_string_literal: true

require 'spec_helper'

describe Editor, :editor do
  include Helpers::FileSystem
  include VimlValue::SerializationHelpers

  let(:cache_enabled) { true }
  let(:editor) { Editor.new(method(:vim), cache_enabled: cache_enabled) }

  describe '#lines' do
    let(:filename) { 'file.txt' }
    let(:test_lines) { %w[a b c d] }
    let!(:test_directory) { directory([file(test_lines, filename)]).persist! }

    before do
      editor.cd!   test_directory
      editor.edit! filename
    end

    context 'return value' do
      it { expect(editor.lines).to be_a(Enumerator) }
      it { expect(editor.lines {}).to be_nil        }
      it do
        expect { |yield_probe| editor.lines(&yield_probe) }
          .to yield_successive_args(*test_lines)
      end
    end

    context 'range' do
      it { expect(editor.lines(1..).to_a).to                     eq(test_lines)         }
      it { expect(editor.lines(1..1).to_a).to                    eq([test_lines.first]) }
      it { expect(editor.lines(1..test_lines.count).to_a).to     eq(test_lines)         }
      it { expect(editor.lines(2..test_lines.count).to_a).to     eq(test_lines[1..])    }
      it { expect(editor.lines(2..test_lines.count - 1).to_a).to eq(test_lines[1..-2])  }
      it { expect(editor.lines(test_lines.count + 1..).to_a).to  eq([])                 }
      it { expect(editor.lines(test_lines.count..).to_a).to      eq([test_lines.last])  }

      it { expect { editor.lines(0..0).to_a   }.to raise_error(ArgumentError) }
      it { expect { editor.lines(0..1).to_a   }.to raise_error(ArgumentError) }
      it { expect { editor.lines(1..0).to_a   }.to raise_error(ArgumentError) }
      it { expect { editor.lines(2..1).to_a   }.to raise_error(ArgumentError) }
      it { expect { editor.lines(-1..2).to_a  }.to raise_error(ArgumentError) }
      it { expect { editor.lines(-2..-1).to_a }.to raise_error(ArgumentError) }
    end

    context 'prefetch_count' do
      context 'when is set to 1' do
        let(:prefetch_count) { 1 }

        it do
          expect(vim).to receive(:echo).exactly(test_lines.count).and_call_original
          expect(editor.lines(prefetch_count: prefetch_count).to_a).to eq(test_lines)
        end
      end

      # TODO: better name
      context 'lines_count % prefetch_count != 0' do
        let(:divisor) { 2 }
        let(:prefetch_count) { test_lines.count / divisor + 1 }
        before { expect(test_lines.count / prefetch_count).not_to eq(0) } # verify the setup

        it do
          expect(vim).to receive(:echo).exactly(test_lines.count / divisor).and_call_original
          expect(editor.lines(prefetch_count: prefetch_count).to_a).to eq(test_lines)
        end
      end

      it { expect { editor.lines(prefetch_count: -1) }.to raise_error(ArgumentError) }
      it { expect { editor.lines(prefetch_count: 0) }.to  raise_error(ArgumentError) }
    end

    shared_examples 'yields each line using prefetching' do
      let(:prefetch_count) { 2 }
      subject { editor.lines(prefetch_count: prefetch_count) }

      # verify the setup
      before { expect(test_lines.count).to eq(prefetch_count * 2) }

      it 'yields each line using prefetching' do
        expect(vim).to receive(:echo).once.and_call_original
        expect(subject.next).to eq(test_lines[0])
        expect(subject.next).to eq(test_lines[1])

        expect(vim).to receive(:echo).once.and_call_original
        expect(subject.next).to eq(test_lines[2])
        expect(subject.next).to eq(test_lines[3])

        expect { subject.next }.to raise_error(StopIteration)
      end
    end

    context 'when cache_enabled: true' do
      let(:cache_enabled) { true }

      include_examples 'yields each line using prefetching'
    end

    context 'when cache_enabled: false' do
      let(:cache_enabled) { false }

      include_examples 'yields each line using prefetching'
    end
  end
end
