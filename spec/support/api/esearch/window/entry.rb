# frozen_string_literal: true

require 'active_support/core_ext/object/instance_variables'

class API::ESearch::Window::Entry
  include API::Mixins::RollbackState

  class OpenEntryError < RuntimeError; end

  class_attribute :rollback_inside_buffer_on_open, default: true

  attr_reader :editor, :context, :line_in_window, :relative_path

  def initialize(editor, relative_path, context, line_in_window)
    @editor = editor
    @relative_path = relative_path
    @context = context
    @line_in_window = line_in_window
  end

  def line_number
    context.to_i # takes leading int
  end

  def open
    old_buffer_name = editor.current_buffer_name

    rollback_open do
      editor.locate_line! line_in_window + 1
      editor.press_with_user_mappings! '\<Enter>'

      opened_buffer_name = editor.current_buffer_name
      yield

      # Checking after the block execution to let opened_buffer_name become
      # preloaded in batch with other data during block execution to prevent N+1.
      raise OpenEntryError, "Entry was opened incorrectly #{inspect}" if old_buffer_name == opened_buffer_name
    end
  end

  private

  def inspect
    "<Entry:#{object_id} #{instance_values.except('editor').map { |k, v| "#{k}=#{v.inspect}" }.join(', ')}>"
  end

  def rollback_open(&block)
    if rollback_inside_buffer_on_open?
      rollback_cursor_location(editor, &block)
    else
      rollback_current_buffer(editor, &block)
    end
  end
end
