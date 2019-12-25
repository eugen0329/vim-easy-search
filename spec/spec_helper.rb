# frozen_string_literal: true

require 'rbconfig'
require 'pathname'
require 'vimrunner'
require 'vimrunner/rspec'
require 'active_support/core_ext/numeric/time'
Dir[File.expand_path('spec/support/**/*.rb')].sort.each { |f| require f unless f.include?('brew_formula') }

def ci?
  ENV['TRAVIS_BUILD_ID'].present?
end

KnownIssues.allow_tests_to_fail_matching_by_tags do
  pending! '[[:digit:]]', /position_inside_file/, adapter: :grep, matching: :regexp
  pending! '\d{2}',       /position_inside_file/, adapter: :grep, matching: :regexp
  pending! 'a{2}',        /position_inside_file/, adapter: :grep, matching: :regexp
  pending! '/(?:',        /position_inside_file/, adapter: :grep, matching: :regexp
  pending! "/(?<=",       /position_inside_file/, adapter: :grep, matching: :regexp
  pending! '(?<name>',    /position_inside_file/, adapter: :grep, matching: :regexp
  pending! '(?P<name>',   /position_inside_file/, adapter: :grep, matching: :regexp

  pending! '[[:digit:]]{2}', /position_inside_file/, adapter: :git, matching: :regexp
  pending! '\d{2}',          /position_inside_file/, adapter: :git, matching: :regexp
  pending! 'a{2}',           /position_inside_file/, adapter: :git, matching: :regexp
  pending! '/(?:',           /position_inside_file/, adapter: :git, matching: :regexp
  pending! "/(?<=",          /position_inside_file/, adapter: :git, matching: :regexp
  pending! '/(?<name>',      /position_inside_file/, adapter: :git, matching: :regexp
  pending! '(?P<name>',      /position_inside_file/, adapter: :git, matching: :regexp

  # https://github.com/google/re2/wiki/Syntax
  pending! "/(?<=",     /reported_errors/, adapter: :pt, matching: :regexp
  pending! "/(?<name>", /reported_errors/, adapter: :pt, matching: :regexp
end


SEARCH_UTIL_ADAPTERS = %w[ack ag git grep pt rg].freeze
RSpec.configure do |config|
  config.include Support::DSL::Vim
  config.include Support::DSL::ESearch

  config.color_mode = true
  config.order = :rand
  config.formatter = :documentation
  config.fail_fast = 3

  config.example_status_persistence_file_path = "failed_specs.txt"
  config.filter_run_excluding :compatibility_regexp if ci?
end

Vimrunner::RSpec.configure do |config|
  config.reuse_server = true

  config.start_vim do
    load_plugins!(vim_gui? ? Vimrunner.start_gvim : Vimrunner.start)
  end
end

VimrunnerNeovim::RSpec.configure do |config|
  config.reuse_server = true

  config.start_nvim do
    load_plugins!(VimrunnerNeovim::Server.new(
      nvim: nvim_path,
      gui: nvim_gui?,
      timeout: 10,
      verbose_level: 0
    ).start)
  end
end

def working_directory
  @working_directory ||= Pathname.new(File.expand_path('..', __dir__))
end

BIN_DIR = working_directory.join('spec', 'support', 'bin')

RSpec::Matchers.define_negated_matcher :not_include, :include
RSpec::Matchers.define_negated_matcher :havent_reported_errors, :have_reported_errors

def load_plugins!(vim)
  vimproc_path = working_directory.join('spec', 'support', 'vim_plugins', 'vimproc.vim')
  pp_path      = working_directory.join('spec', 'support', 'vim_plugins', 'vim-prettyprint')

  vim.add_plugin(working_directory, 'plugin/esearch.vim')
  vim.add_plugin(vimproc_path,      'plugin/vimproc.vim')
  vim.add_plugin(pp_path,           'plugin/prettyprint.vim')
  vim
end

def nvim_path
  if linux?
    # working_directory.join('spec', 'support', 'bin', "nvim.linux.appimage").to_s
    working_directory.join('spec', 'support', 'bin', 'squashfs-root', 'usr', 'bin', 'nvim').to_s
  else
    working_directory.join('spec', 'support', 'bin', 'nvim-osx64', 'bin', 'nvim').to_s
  end
end

def vim_gui?
  # NOTE: for some reason non-gui deadlocks on travis
  ENV.fetch('VIM_GUI', '1') == '1' && gui?
end

def nvim_gui?
  # NOTE use non-gui neovim on travis to not mess with opening xterm or iterm
  ENV.fetch('NVIM_GUI', '1') == '1' && gui?
end

def osx?
  !(RbConfig::CONFIG['host_os'] =~ /darwin/).nil?
end

def linux?
  !(RbConfig::CONFIG['host_os'] =~ /linux/).nil?
end

def gui?
  ENV.fetch('GUI', '1') == '1'
end

# TODO: move out of here
def wait_for_search_start
  expect {
    press('lh') # press jk to close "Press ENTER or type command to continue" prompt
    bufname('%') =~ /Search/
  }.to become_true_within(20.second)
end

def wait_for_search_freezed(timeout = 3.seconds)
  expect { line(1) =~ /Finish/i }.not_to become_true_within(timeout)
end

def wait_for_qickfix_enter
  expect {
    expr('&filetype') == 'qf'
  }.to become_true_within(5.second)
end

def ps_commands
  `ps -A -o command | sed 1d`
end

def esearch
  @esearch ||= API::Esearch::Facade.new(self)
end

def ps_commands_without_sh
  ps_commands
    .split("\n")
    .reject { |l| %r{\A\s*(?:/bin/)?sh}.match?(l) }
    .join("\n")
end

def working_directory
  @working_directory ||= Pathname.new(File.expand_path('..', __dir__))
end

def delete_current_buffer
  # From :help bdelete
  #   Unload buffer [N] (default: current buffer) and delete it from the buffer list.
  press ':bdelete<Enter>'
end

Fixtures::LazyDirectory.fixtures_directory = working_directory.join('spec', 'fixtures')
Fixtures::LazyDirectory.fixtures_directory = working_directory.join('spec', 'fixtures')

def file(relative_path, content)
  Fixtures::LazyFile.new(relative_path, content)
end

def directory(files)
  Fixtures::LazyDirectory.new(files)
end

def search_string_dump(search_string)
  if search_string.is_a? Regexp
    search_string.inspect
  elsif search_string.is_a? String
    search_string.dump
  else
    search_string.to_s
  end
end

def search_string_to_s(search_string)
  return search_string.inspect[1..-2] if search_string.is_a? Regexp

  search_string.to_s
end
