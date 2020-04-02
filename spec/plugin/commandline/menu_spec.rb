# frozen_string_literal: true

require 'spec_helper'

describe 'esearch#cmdline menu', :commandline do
  include Helpers::Commandline

  shared_examples 'commandline menu testing examples' do
    before { esearch.configure(out: 'stubbed', backend: 'system', use: 'last', root_markers: []) }
    after do
      esearch.cleanup!
      esearch.output.reset_calls_history!
    end

    # NOTE editor#send_keys after #open_menu_keys must be called separately due to
    # +clientserver implimentation particularities

    describe 'change options using hotkeys' do
      shared_examples 'it sets options using hotkey' do |hotkey, options|
        it "sets #{options} using hotkey #{hotkey}" do
          expect {
            editor.send_keys(*open_input_keys, *open_menu_keys)
            editor.send_keys(hotkey, close_menu_key, 'search str', :enter)
          }.to set_global_options(options)
            .and start_search_with_options(options)
            .and finish_search_for('search str')
        end
      end

      context 'default mappings' do
        context 'when enabling options' do
          before { esearch.configure!(adapter: 'ag', bound: 'disabled', case: 'ignore', regex: 'literal') }

          include_examples 'it sets options using hotkey', '\\<C-s>', 'case'  => 'sensitive'
          include_examples 'it sets options using hotkey', 's',       'case'  => 'sensitive'

          include_examples 'it sets options using hotkey', '\\<C-b>', 'bound'  => 'word'
          include_examples 'it sets options using hotkey', 'b',       'bound'  => 'word'

          include_examples 'it sets options using hotkey', '\\<C-r>', 'regex' => 'pcre'
          include_examples 'it sets options using hotkey', 'r',       'regex' => 'pcre'
        end

        context 'when disabling options' do
          before { esearch.configure!(adapter: 'ag', bound: 'word', regex: 'pcre') }

          include_examples 'it sets options using hotkey', '\\<C-b>', 'bound'  => 'disabled'
          include_examples 'it sets options using hotkey', 'b',       'bound'  => 'disabled'

          include_examples 'it sets options using hotkey', '\\<C-r>', 'regex' => 'literal'
          include_examples 'it sets options using hotkey', 'r',       'regex' => 'literal'
        end

        context 'when cycling' do
          before { esearch.configure!(adapter: 'ag', case: 'sensitive') }
          include_examples 'it sets options using hotkey', '\\<C-s>', 'case'  => 'smart'
          include_examples 'it sets options using hotkey', 's',       'case'  => 'smart'
        end
      end
    end

    describe 'change options by moving the menu selection' do
      shared_context 'opened menu testing' do
        before do
          esearch.configuration.submit!(overwrite: true)
          editor.command('call esearch#util_testing#spy_echo()')
          editor.send_keys(*open_input_keys, *open_menu_keys)
        end
        after { editor.command('call esearch#util_testing#unspy_echo()') }
      end

      shared_examples 'it locates "regex" menu items by pressing' do |keys:|
        context "when pressing #{keys}" do
          include_context 'opened menu testing'

          it 'locates "regex" menu entry' do
            expect {
              editor.send_keys_separately(*keys, :enter, close_menu_key, 'search string', :enter)
            }.to change { menu_items }
              .from(match_array([
                start_with('> s '),
                start_with('  r '),
                start_with('  b '),
                start_with('  p ')
              ])).to(match_array([
                start_with('  s '),
                start_with('> r '),
                start_with('  b '),
                start_with('  p ')
              ]))
              .and set_global_options('regex' => 'pcre')
              .and start_search_with_options('regex' => 'pcre')
          end
        end
      end

      shared_examples 'it locates "bound" menu items by pressing' do |keys:|
        context "when pressing #{keys}" do
          include_context 'opened menu testing'

          it 'locates "bound" menu entry' do
            expect { editor.send_keys_separately(*keys, :enter, close_menu_key, 'search string', :enter) }
              .to change { menu_items }
              .from(match_array([
                start_with('> s '),
                start_with('  r '),
                start_with('  b '),
                start_with('  p ')
              ])).to(match_array([
                start_with('  s '),
                start_with('  r '),
                start_with('> b '),
                start_with('  p ')
              ]))
              .and set_global_options('bound' => 'word')
              .and start_search_with_options('bound' => 'word')
          end
        end
      end

      shared_examples 'it locates "case" menu items by pressing' do |keys:|
        context "when pressing #{keys}" do
          include_context 'opened menu testing'

          it 'locates "case" menu entry' do
            expect {
              editor.send_keys(*keys)
              editor.send_keys(:enter, close_menu_key, 'search string', :enter)
            }.to set_global_options('case' => 'sensitive')
              .and start_search_with_options('case' => 'sensitive')
          end
        end
      end

      context 'default hotkeys' do
        ## Menu outlook is:
        # > s       toggle case sensitive match
        #   r       toggle regexp match
        #   b       toggle bound match
        #   p       edit paths

        include_examples 'it locates "regex" menu items by pressing', keys: ['j']
        include_examples 'it locates "regex" menu items by pressing', keys: ['\\<C-j>']

        include_examples 'it locates "bound" menu items by pressing',  keys: ['kk']
        include_examples 'it locates "bound" menu items by pressing',  keys: ['jj']
        include_examples 'it locates "bound" menu items by pressing',  keys: ['\\<C-k>\\<C-k>']
        include_examples 'it locates "bound" menu items by pressing',  keys: ['\\<C-j>\\<C-j>']

        include_examples 'it locates "case" menu items by pressing',  keys: []
        include_examples 'it locates "case" menu items by pressing',  keys: ['jjjj']
        include_examples 'it locates "case" menu items by pressing',  keys: ['kkkk']
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

  context 'neovim', :neovim do
    around(:context) { |e| use_nvim(&e) }

    include_examples 'commandline menu testing examples'
  end

  context 'vim' do
    include_examples 'commandline menu testing examples'
  end
end
