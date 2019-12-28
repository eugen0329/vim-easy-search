# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'

class API::ESearch::QuickFix
  include API::Mixins::BecomeTruthyWithinTimeout

  class_attribute :search_event_timeout, default: Configuration.search_event_timeout
  class_attribute :search_freeze_timeout, default: Configuration.search_freeze_timeout
  attr_reader :editor

  def initialize(editor)
    @editor = editor
  end

  def has_search_started?(timeout: 10.seconds)
    became_truthy_within?(timeout) do
      editor.press!('lh') # press jk to close "Press ENTER or type command to continue" prompt
      inside_quickfix_search_window?
    end
  end

  def has_search_finished?
    raise 'TODO'
  end

  def has_reported_a_single_result?
    raise 'TODO'
  end

  def has_outputted_result_from_file_in_line?
    raise 'TODO'
  end

  def has_outputted_result_with_right_position_inside_file?
    raise 'TODO'
  end

  def has_not_reported_errors?
    has_reported_errors_in_title?
  end

  def has_reported_errors_in_title?
    raise 'TODO'
  end

  def has_search_freezed?(timeout: search_freeze_timeout)
    !became_truthy_within?(timeout) do
      editor.with_ignore_cache { has_reported_finish_in_title? }
    end
  end

  def has_reported_finish_in_title?
    editor.quickfix_window_name.include?('Finished')
  end

  def close_search!
    if inside_quickfix_search_window?
      editor.delete_current_buffer!
    end
  end

  private

  def inside_quickfix_search_window?
    quickfix_window_name, filetype = editor.quickfix_window_name_with_filetype
    quickfix_window_name.match?(/\A:Search/) && filetype == 'qf'

    #   Fails in rubocop 0.78
    #   editor.current_buffer_name_with_filetype in [/Search/, 'qf']
    #   true
    # rescue NoMatchingPatternError
    #   false
  end
end
