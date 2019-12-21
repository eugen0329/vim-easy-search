# frozen_string_literal: true

require 'spec_helper'
require 'plugin/shared_examples/backend.rb'
require 'plugin/shared_examples/abortable_backend.rb'
require 'plugin/shared_contexts/dumpable.rb'

context 'esearch#backend', :backend do
  describe '#system', :system do
    it_behaves_like 'a backend', 'system'
  end

  describe '#vimproc', :vimproc do
    before(:all) do
      press ':let g:esearch#backend#vimproc#updatetime = 30'
      press ':let g:esearch#backend#vimproc#read_timeout = 30'
    end

    it_behaves_like 'a backend', 'vimproc'
    it_behaves_like 'an abortable backend', 'vimproc'
  end

  describe '#nvim', :nvim do
    around { |e| use_neovim(&e) }

    it do
      result = press(':version<Enter>')
      expect(result).to be_present
    end

    it do
      result = expr('esearch#util#flatten([])')
      expect(result).to be_present
    end

    # before do
    #   cmd 'enew'
    # end

    # it_behaves_like 'a backend', 'nvim'
    # it_behaves_like 'an abortable backend', 'nvim'
  end

  describe '#vim8', :vim8 do
    before { press ':let g:esearch#backend#vim8#timer = 100<Enter>' }

    it_behaves_like 'a backend', 'vim8'
    it_behaves_like 'an abortable backend', 'vim8'
  end
end
