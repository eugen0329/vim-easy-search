# frozen_string_literal: true

require 'spec_helper'

describe 'esearch#cmdline menu', :commandline do
  include Helpers::Commandline

  shared_examples 'commandline menu testing examples' do
    before { esearch.configure(out: 'stubbed', backend: 'system', prefill: ['last'], root_markers: []) }
    after do
      esearch.cleanup!
      esearch.output.reset_calls_history!
    end

    # NOTE: editor#send_keys after #open_menu_keys must be called separately due to
    # +clientserver implimentation particularities

    describe 'change options using hotkeys' do
      shared_examples 'it sets options using hotkey' do |hotkeys, options|
        it "sets #{options} using hotkey(s) #{hotkeys}" do
          expect do
            editor.send_keys(*open_input_keys, *open_menu_keys)
            editor.send_keys_separately(*hotkeys, close_menu_key, 'search str', :enter)
          end.to set_global_options(options)
            .and start_stubbed_search_with_options(options)
            .and finish_stubbed_search_for('search str')
        end
      end

      context 'default mappings' do
        context 'when enabling options' do
          before { esearch.configure!(adapter: 'ag', textobj: 0, case: 'ignore', regex: 'literal') }

          # > s      toggle case match
          #   r      toggle regexp match
          #   t      toggle textobj match
          #   p      edit [path]
          #   aA     adjust after (0)
          #   bB     adjust before (0)
          #   cC     adjust context (1)

          context 'when using own keys' do
            include_examples 'it sets options using hotkey', '\\<c-s>', 'case'  => 'sensitive'
            include_examples 'it sets options using hotkey', 's',       'case'  => 'sensitive'

            include_examples 'it sets options using hotkey', '\\<c-t>', 'textobj'  => 'word'
            include_examples 'it sets options using hotkey', 't',       'textobj'  => 'word'

            include_examples 'it sets options using hotkey', '\\<c-r>', 'regex' => 'pcre'
            include_examples 'it sets options using hotkey', 'r',       'regex' => 'pcre'
          end

          context 'when using <cr>' do
            CR = '\\<cr>'
            C_J = '\\<c-j>'
            C_K = '\\<c-k>'

            include_examples 'it sets options using hotkey', [CR],             'case'    => 'sensitive'
            include_examples 'it sets options using hotkey', ['j'] * 1 + [CR], 'regex'   => 'pcre'
            include_examples 'it sets options using hotkey', ['j'] * 2 + [CR], 'textobj' => 'word'
            include_examples 'it sets options using hotkey', [C_J] * 1 + [CR], 'regex'   => 'pcre'
            include_examples 'it sets options using hotkey', [C_J] * 2 + [CR], 'textobj' => 'word'

            context 'when wrapping around the end' do
              include_examples 'it sets options using hotkey', [C_J] * 9 + [CR], 'case'    => 'sensitive'
              include_examples 'it sets options using hotkey', ['k'] * 9 + [CR], 'case'    => 'sensitive'
              include_examples 'it sets options using hotkey', ['k'] * 8 + [CR], 'regex'   => 'pcre'
              include_examples 'it sets options using hotkey', ['k'] * 7 + [CR], 'textobj' => 'word'
              include_examples 'it sets options using hotkey', [C_K] * 9 + [CR], 'case'    => 'sensitive'
              include_examples 'it sets options using hotkey', [C_K] * 8 + [CR], 'regex'   => 'pcre'
              include_examples 'it sets options using hotkey', [C_K] * 7 + [CR], 'textobj' => 'word'
            end
          end
        end

        context 'when disabling options' do
          before { esearch.configure!(adapter: 'ag', textobj: 'word', regex: 'pcre') }

          context 'when using own keys' do
            include_examples 'it sets options using hotkey', '\\<c-t>', 'textobj'  => 'none'
            include_examples 'it sets options using hotkey', 't',       'textobj'  => 'none'

            include_examples 'it sets options using hotkey', '\\<c-r>', 'regex' => 'literal'
            include_examples 'it sets options using hotkey', 'r',       'regex' => 'literal'
          end
        end

        context 'when cycling options' do
          before { esearch.configure!(adapter: 'ag', case: 'sensitive') }

          context 'when using own keys' do
            include_examples 'it sets options using hotkey', '\\<c-s>', 'case' => 'smart'
            include_examples 'it sets options using hotkey', 's',       'case' => 'smart'
          end
        end

        context 'when incrementing' do
          before { esearch.configure!(adapter: 'ag', after: 0, before: 0, context: 0) }

          context 'when using own key' do
            include_examples 'it sets options using hotkey', 'a'.chars,  'after'   => 1
            include_examples 'it sets options using hotkey', 'b'.chars,  'before'  => 1
            include_examples 'it sets options using hotkey', 'c'.chars,  'context' => 1
            include_examples 'it sets options using hotkey', 'aa'.chars, 'after'   => 2
            include_examples 'it sets options using hotkey', 'bb'.chars, 'before'  => 2
            include_examples 'it sets options using hotkey', 'cc'.chars, 'context' => 2
          end

          context 'when using +' do
            include_examples 'it sets options using hotkey', 'kk+'.chars, 'after' => 1
            include_examples 'it sets options using hotkey', 'kkk+'.chars, 'before' => 1
            include_examples 'it sets options using hotkey', 'k+'.chars, 'context' => 1
            include_examples 'it sets options using hotkey', 'kk++'.chars, 'after' => 2
            include_examples 'it sets options using hotkey', 'kkk++'.chars, 'before' => 2
            include_examples 'it sets options using hotkey', 'k++'.chars, 'context' => 2
          end

          context 'when usgin <c-a>' do
            C_A = '\\<c-a>'
            include_examples 'it sets options using hotkey', 'kk'.chars + [C_A] * 1, 'after' => 1
            include_examples 'it sets options using hotkey', 'kkk'.chars + [C_A] * 1, 'before' => 1
            include_examples 'it sets options using hotkey', 'k'.chars + [C_A] * 1, 'context' => 1
            include_examples 'it sets options using hotkey', 'kk'.chars + [C_A] * 2, 'after' => 2
            include_examples 'it sets options using hotkey', 'kkk'.chars + [C_A] * 2, 'before' => 2
            include_examples 'it sets options using hotkey', 'k'.chars + [C_A] * 2, 'context' => 2
          end
        end

        context 'when decrementing' do
          before { esearch.configure!(adapter: 'ag', after: 2, before: 2, context: 2) }

          context 'when using own key' do
            include_examples 'it sets options using hotkey', 'A'.chars,  'after'   => 1
            include_examples 'it sets options using hotkey', 'B'.chars,  'before'  => 1
            include_examples 'it sets options using hotkey', 'C'.chars,  'context' => 1
            include_examples 'it sets options using hotkey', 'AA'.chars, 'after'   => 0
            include_examples 'it sets options using hotkey', 'BB'.chars, 'before'  => 0
            include_examples 'it sets options using hotkey', 'CC'.chars, 'context' => 0
          end

          context 'when using -' do
            include_examples 'it sets options using hotkey', 'kk-'.chars, 'after' => 1
            include_examples 'it sets options using hotkey', 'kkk-'.chars, 'before' => 1
            include_examples 'it sets options using hotkey', 'k-'.chars, 'context' => 1
            include_examples 'it sets options using hotkey', 'kk--'.chars, 'after' => 0
            include_examples 'it sets options using hotkey', 'kkk--'.chars, 'before' => 0
            include_examples 'it sets options using hotkey', 'k--'.chars, 'context' => 0
          end

          context 'when usgin <c-x>' do
            C_X = '\\<c-x>'
            include_examples 'it sets options using hotkey', 'kk'.chars + [C_X] * 1, 'after' => 1
            include_examples 'it sets options using hotkey', 'kkk'.chars + [C_X] * 1, 'before' => 1
            include_examples 'it sets options using hotkey', 'k'.chars + [C_X] * 1, 'context' => 1
            include_examples 'it sets options using hotkey', 'kk'.chars + [C_X] * 2, 'after' => 0
            include_examples 'it sets options using hotkey', 'kkk'.chars + [C_X] * 2, 'before' => 0
            include_examples 'it sets options using hotkey', 'k'.chars + [C_X] * 2, 'context' => 0
          end
        end

        context 'when setting numeric' do
          before { esearch.configure!(adapter: 'ag', after: 0, before: 0, context: 0) }

          include_examples 'it sets options using hotkey', 'kk7'.chars, 'after' => 7
          include_examples 'it sets options using hotkey', 'kkk8'.chars, 'before' => 8
          include_examples 'it sets options using hotkey', 'k9'.chars,   'context' => 9
          include_examples 'it sets options using hotkey', 'kk71'.chars, 'after'   => 71
          include_examples 'it sets options using hotkey', 'kkk82'.chars, 'before' => 82
          include_examples 'it sets options using hotkey', 'k93'.chars, 'context' => 93
        end

        context 'when deleting numeric' do
          BS = '\\<bs>'
          DEL = '\\<del>'

          before { esearch.configure!(adapter: 'ag', after: 71, before: 82, context: 93) }

          context 'when against non-zero' do
            context 'when deleting the rightmost char' do
              include_examples 'it sets options using hotkey', 'kk'.chars + [BS] * 1, 'after' => 7
              include_examples 'it sets options using hotkey', 'kkk'.chars + [BS] * 1, 'before' => 8
              include_examples 'it sets options using hotkey', 'k'.chars + [BS] * 1, 'context' => 9
              include_examples 'it sets options using hotkey', 'kk'.chars + [BS] * 2, 'after' => 0
              include_examples 'it sets options using hotkey', 'kkk'.chars + [BS] * 2, 'before' => 0
              include_examples 'it sets options using hotkey', 'k'.chars + [BS] * 2, 'context' => 0
            end

            context 'when nullifying the value' do
              include_examples 'it sets options using hotkey', 'kk'.chars + [DEL] * 1, 'after' => 0
              include_examples 'it sets options using hotkey', 'kkk'.chars + [DEL] * 1, 'before' => 0
              include_examples 'it sets options using hotkey', 'k'.chars + [DEL] * 1, 'context' => 0
            end
          end

          context 'when against zero' do
            include_examples 'it sets options using hotkey', 'kk'.chars + [BS] * 3, 'after' => 0
            include_examples 'it sets options using hotkey', 'kkk'.chars + [BS] * 3, 'before' => 0
            include_examples 'it sets options using hotkey', 'k'.chars + [BS] * 3, 'context' => 0

            include_examples 'it sets options using hotkey', 'kk'.chars + [DEL] * 2, 'after' => 0
            include_examples 'it sets options using hotkey', 'kkk'.chars + [DEL] * 2, 'before' => 0
            include_examples 'it sets options using hotkey', 'k'.chars + [DEL] * 2, 'context' => 0
          end
        end

        context 'when jumping to menu entries by pressing their own keys' do
          before { esearch.configure!(adapter: 'ag', after: 0, before: 0, context: 0) }

          # Only context width options are tested as the feature is only
          # useful for them.
          include_examples 'it sets options using hotkey', 'A7'.chars, 'after'   => 7
          include_examples 'it sets options using hotkey', 'B8'.chars, 'before'  => 8
          include_examples 'it sets options using hotkey', 'C9'.chars, 'context' => 9
        end
      end
    end

    describe 'dismissing menu' do
      before { esearch.configuration.submit!(overwrite: true) } # TODO: will be removed

      context 'default hotkeys' do
        before { editor.send_keys(*open_input_keys, *open_menu_keys) }

        it { expect { editor.send_keys(close_menu_key) }.to change { editor.mode }.to(:commandline) }
      end

      context 'cursor position' do
        context 'within input provided by user' do
          shared_examples 'it preserves cursor location after' do |expected_location:, dismiss_with:|
            context "when dismissing with #{dismiss_with} keys" do
              let(:test_string) { expected_location.tr('|', '') }
              it "preserves location in #{expected_location} at '|'" do
                editor.send_keys(*open_input_keys,
                  test_string,
                  *locate_cursor_with_arrows(expected_location),
                  *open_menu_keys)
                editor.send_keys(*dismiss_with)

                expect(editor).to have_commandline_cursor_location(expected_location)
              end
            end
          end

          context 'when ascii input' do
            include_examples 'it preserves cursor location after',
              dismiss_with:      [:escape],
              expected_location: 'st|rn'

            include_examples 'it preserves cursor location after',
              dismiss_with:      [:escape],
              expected_location: 'st|n'

            include_examples 'it preserves cursor location after',
              dismiss_with:      [:escape],
              expected_location: 'strn|'

            include_examples 'it preserves cursor location after',
              dismiss_with:      [:escape],
              expected_location: '|strn'
          end

          context 'when multibyte input' do
            include_examples 'it preserves cursor location after',
              dismiss_with:      [:escape],
              expected_location: 'st|Σn'
          end
        end

        context 'within prefilled input' do
          shared_examples 'it restores cursor location' do |dismiss_with:, expected_location:|
            context do
              include_context 'run preparatory search to enable prefilling', expected_location.tr('|', '')

              it "preserves location #{expected_location} after cancelling" do
                editor.send_keys(*open_input_keys, *open_menu_keys)
                editor.send_keys(*dismiss_with)

                expect(editor).to have_commandline_cursor_location(expected_location)
              end
            end
          end

          include_examples 'it restores cursor location',
            dismiss_with:      [:escape],
            expected_location: 'str|'
        end
      end
    end
  end

  include_examples 'commandline menu testing examples'
end
