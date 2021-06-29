# frozen_string_literal: true

require 'spec_helper'

describe 'esearch#shell' do
  include VimlValue::SerializationHelpers
  include Helpers::FileSystem
  include Helpers::Shell

  describe '#split' do
    describe 'special' do
      shared_examples 'it tokenizes inside an arg as a metastring' do |c|
        it { expect(tokens_of("#{c}ab d")).to   eq([[[1, c], [0, 'ab']], [[0, 'd']]])          }
        it { expect(tokens_of("a#{c}b d")).to   eq([[[0, 'a'], [1, c], [0, 'b']], [[0, 'd']]]) }
        it { expect(tokens_of("ab#{c} d")).to   eq([[[0, 'ab'], [1, c]], [[0, 'd']]])          }
        it { expect(tokens_of(" #{c}ab")).to    eq([[[1, c], [0, 'ab']]])                      }
        it { expect(tokens_of(" ab#{c} ")).to   eq([[[0, 'ab'], [1, c]]])                      }
        it { expect(tokens_of("#{c}ab#{c}")).to eq([[[1, c], [0, 'ab'], [1, c]]])              }
        it { expect(tokens_of("#{c}#{c}ab")).to eq([[[1, c], [1, c], [0, 'ab']]])              }
      end

      it { expect(tokens_of('ab cd')).to eq([[[0, 'ab']], [[0, 'cd']]]) }

      describe 'wildcards' do
        include_examples 'it tokenizes inside an arg as a metastring', '?'
        include_examples 'it tokenizes inside an arg as a metastring', '*'
        include_examples 'it tokenizes inside an arg as a metastring', '+'
        include_examples 'it tokenizes inside an arg as a metastring', '@'
        include_examples 'it tokenizes inside an arg as a metastring', '!'
        include_examples 'it tokenizes inside an arg as a metastring', '('
        include_examples 'it tokenizes inside an arg as a metastring', ')'
        include_examples 'it tokenizes inside an arg as a metastring', '|'
        include_examples 'it tokenizes inside an arg as a metastring', '{'
        include_examples 'it tokenizes inside an arg as a metastring', '}'
        include_examples 'it tokenizes inside an arg as a metastring', '['
        include_examples 'it tokenizes inside an arg as a metastring', ']'
        include_examples 'it tokenizes inside an arg as a metastring', '^'
        include_examples 'it tokenizes inside an arg as a metastring', '$'
      end

      describe 'backticks' do
        context 'when trailing' do
          it { expect(tokens_of('`')).to   eq(:error) }
          it { expect(tokens_of('```')).to eq(:error) }
        end

        context 'when toplevel' do
          it { expect(tokens_of('``')).to    eq([[[1, '``']]])  }
          it { expect(tokens_of('`a`')).to   eq([[[1, '`a`']]]) }
        end

        context 'when in a string' do
          it { expect(tokens_of('"``"')).to       eq([[[1, '``']]])                      }
          it { expect(tokens_of('"`a`"')).to      eq([[[1, '`a`']]])                     }
          it { expect(tokens_of("'`a`'")).to      eq([[[0, '`a`']]])                     }
          it { expect(tokens_of('"z`a`b"')).to    eq([[[0, 'z'], [1, '`a`'], [0, 'b']]]) }
          it { expect(tokens_of('"`\\`\\``"')).to eq([[[1, '`\\`\\``']]])                }

          context 'when unmatched' do
            it { expect(tokens_of('"`"')).to        eq(:error) }
            it { expect(tokens_of('"```"')).to      eq(:error) }
          end
        end

        context 'when a part of an arg' do
          include_examples 'it tokenizes inside an arg as a metastring', '`zz`'
        end
      end
    end

    describe 'empty args' do
      it { expect(split('a "" b')).to eq(['a', '', 'b']) }
      it { expect(split("a '' b")).to eq(['a', '', 'b']) }
    end

    describe 'single word' do
      it { expect(split('ab')).to  eq(['ab']) }
      it { expect(split('ab ')).to eq(['ab']) }
      it { expect(split(' ab')).to eq(['ab']) }
    end

    describe 'multiple words' do
      it { expect(split('a b')).to  eq(%w[a b])  }
      it { expect(split('a bc')).to eq(%w[a bc]) }
    end

    describe 'multibyte' do
      it { expect(split("'Σ'")).to   eq(%w[Σ])   }
      it { expect(split("Δ 'Σ'")).to eq(%w[Δ Σ]) }
    end

    describe 'double quote' do
      it { expect(split('"a b"')).to    eq(['a b'])  }
      it { expect(split(' "a b"')).to   eq(['a b'])  }
      it { expect(split('"a b" ')).to   eq(['a b'])  }
      it { expect(split('"a\\b"')).to   eq(['ab'])   }
      it { expect(split('"a\\"b"')).to  eq(['a"b'])  }
      it { expect(split('"a\\\\b"')).to eq(['a\\b']) }
      it { expect(split('a"b"')).to     eq(['ab'])   }
      it { expect(split('"a"b')).to     eq(['ab'])   }
      it { expect(split('"')).to        eq(:error)   }
      it { expect(split('a"')).to       eq(:error)   }
      it { expect(split('"a')).to       eq(:error)   }

      describe 'unescaping everything' do
        it { expect(split('"\\a"')).to  eq(['a']) }
        it { expect(split('"\\&"')).to  eq(['&']) }
        it { expect(split('"\\."')).to  eq(['.']) }
      end
    end

    describe 'single quote' do
      it { expect(split("'a b'")).to    eq(['a b'])    }
      it { expect(split("'a b' ")).to   eq(['a b'])    }
      it { expect(split(" 'a b'")).to   eq(['a b'])    }
      it { expect(split("'a\\b'")).to   eq(['a\\b'])   }
      it { expect(split("'a\\'b'")).to  eq(:error)     }
      it { expect(split("'a\\\\b'")).to eq(['a\\\\b']) }
      it { expect(split("a'b'")).to     eq(['ab'])     }
      it { expect(split("'a'b")).to     eq(['ab'])     }
      it { expect(split("'")).to        eq(:error)     }
      it { expect(split("'a")).to       eq(:error)     }
      it { expect(split("a'")).to       eq(:error)     }
    end

    describe 'mixing args' do
      it { expect(split("''a'b'\"c\"\\ d ''")).to eq(['abc d', '']) }
    end

    describe 'backslashes' do
      it { expect(split('\\')).to      eq(:error)  }
      it { expect(split('a\\ b')).to   eq(['a b']) }
      it { expect(split('\\ a ')).to   eq([' a'])  }
      it { expect(split('a\\ ')).to    eq(['a '])  }
      it { expect(split('a\\  ')).to   eq(['a '])  }
      it { expect(split('\\\\')).to    eq(['\\'])  }
      it { expect(split('\\`')).to     eq(['`'])   }

      describe 'unescaping everything' do
        it { expect(split('a\\b')).to eq(['ab']) }
        it { expect(split('ab\\')).to eq(:error) }
        it { expect(split('\\ab')).to eq(['ab']) }
        it { expect(split('\\&')).to  eq(['&'])  }
        it { expect(split('\\.')).to  eq(['.'])  }
        it { expect(split("\\'")).to  eq(["'"])  }
        it { expect(split('\\"')).to  eq(['"'])  }
      end
    end
  end
end
