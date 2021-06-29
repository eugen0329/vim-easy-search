# frozen_string_literal: true

require 'spec_helper'

describe 'esearch#shell' do
  include VimlValue::SerializationHelpers
  include Helpers::FileSystem
  include Helpers::Shell

  describe '#escape' do
    # It Doesn't make a lot of sense to test it separately from #split due to
    # possible false positives and much more complicated setup.
    shared_examples 'handles char' do |c, as:|
      describe "handling char #{c.dump} as #{as.dump}" do
        it { expect(split_and_escape("#{c}b")).to          eq(["#{as}b"])            }
        it { expect(split_and_escape(c)).to                eq([as])                  }
        it { expect(split_and_escape("#{c}a#{c}")).to      eq(["#{as}a#{as}"])       }
        it { expect(split_and_escape("d#{c}b#{c}a")).to    eq(["d#{as}b#{as}a"])     }
        it { expect(split_and_escape("#{c}b#{c}a#{c}")).to eq(["#{as}b#{as}a#{as}"]) }
      end
    end

    shared_examples "doesn't escape char" do |c|
      include_examples 'handles char', c,        as: c
      include_examples 'handles char', "\\#{c}", as: "\\#{c}"
    end

    shared_examples 'escapes char' do |c|
      include_examples 'handles char', c,        as: "\\#{c}"
      include_examples 'handles char', "\\#{c}", as: "\\#{c}"
    end

    describe 'metachars' do
      include_examples "doesn't escape char", '?'
      include_examples "doesn't escape char", '*'
      include_examples "doesn't escape char", '!'
      include_examples "doesn't escape char", '|'
      include_examples "doesn't escape char", '^'
      include_examples "doesn't escape char", '$'
      include_examples "doesn't escape char", '['
      include_examples "doesn't escape char", ']'
      include_examples "doesn't escape char", '@'
      include_examples "doesn't escape char", '('
      include_examples "doesn't escape char", ')'
      include_examples "doesn't escape char", '{'
      include_examples "doesn't escape char", '}'

      describe 'preventing double escaping' do
        include_examples 'handles char', '\\+', as: '\\+'
      end
    end

    describe 'shell special' do
      include_examples 'escapes char', '&'
      include_examples 'escapes char', '%'
      include_examples 'escapes char', ';'
      include_examples 'escapes char', '#'
      include_examples 'escapes char', '>'
      include_examples 'escapes char', '<'
      include_examples 'escapes char', "\n"

      describe 'handling \s' do
        it { expect(split_and_escape("'a b'")).to   eq(['a\\ b'])     }
        it { expect(split_and_escape("'a\\ b'")).to eq(['a\\\\\\ b']) }
        it { expect(split_and_escape('a b')).to     eq(%w[a b])       }
        it { expect(split_and_escape('a\\ b')).to   eq(['a\\ b'])     }
      end

      describe 'handling \t' do
        it { expect(split_and_escape("'a\tb'")).to   eq(["a\\\tb"])     }
        it { expect(split_and_escape("'a\\\tb'")).to eq(["a\\\\\\\tb"]) }
        it { expect(split_and_escape("a\tb")).to     eq(%w[a b])        }
        it { expect(split_and_escape("a\\\tb")).to   eq(["a\\\tb"])     }
      end
    end

    describe 'backticks' do
      it { expect(split_and_escape("'a`b`c'")).to eq(['a\`b\`c']) }
      it { expect(split_and_escape('a\`b\`c')).to eq(['a\`b\`c']) }
      it { expect(split_and_escape('"a`b`c"')).to eq(['a`b`c'])   }
      it { expect(split_and_escape('a`b`c')).to   eq(['a`b`c'])   }
    end

    describe 'specials only at the leading position' do
      context 'when not escaped yet' do
        it { expect(split_and_escape('-')).to   eq(['\-'])  }
        it { expect(split_and_escape('-a')).to  eq(['-a'])  }
        it { expect(split_and_escape('a-')).to  eq(['a-'])  }
        it { expect(split_and_escape('+')).to   eq(['\+'])  }
        it { expect(split_and_escape('+a')).to  eq(['\+a']) }
        it { expect(split_and_escape('a+')).to  eq(['a+'])  }
      end

      context 'when already escaped' do
        it { expect(split_and_escape('\-')).to  eq(['\-'])  }
        it { expect(split_and_escape('\-a')).to eq(['-a'])  }
        it { expect(split_and_escape('a\-')).to eq(['a-'])  }
        it { expect(split_and_escape('\+')).to  eq(['\+'])  }
        it { expect(split_and_escape('\+a')).to eq(['\+a']) }
        it { expect(split_and_escape('a\+')).to eq(['a\+']) }
      end
    end
  end
end
