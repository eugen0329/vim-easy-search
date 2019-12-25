# frozen_string_literal: true

class API::ESearch::Window::HeaderParser
  HEADER_REGEXP = /Matches in (?<lines_count>\d+) lines, (?<files_count>\d+) file/.freeze

  attr_reader :editor

  def initialize(editor)
    @editor = editor
  end

  def parse
    return OpenStruct.new({}) if header_line !~ HEADER_REGEXP

    OpenStruct.new(named_captures(header_line.match(HEADER_REGEXP)))
  end

  def finished?
    header_line =~ HEADER_REGEXP && header_line =~ /\. Finished\.\z/
  end

  def errors?
    header_line =~ /\AERRORS from/
  end

  private

  def header_line
    editor.line(1)
  end

  def named_captures(matchdata)
    # TODO: update ruby and use builtin
    matchdata.names.zip(matchdata.captures.map(&:to_i)).to_h
  end
end
