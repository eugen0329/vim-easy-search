# frozen_string_literal: true

require 'fileutils'
require 'pathname'

class Fixtures::LazyFile
  attr_reader :given_relative_path, :raw_content, :kwargs
  attr_accessor :working_directory

  def initialize(raw_content, given_relative_path = nil, **kwargs)
    @given_relative_path = Pathname.new(given_relative_path).cleanpath.to_s if given_relative_path
    @raw_content = raw_content
    @kwargs = kwargs
  end

  def persist!
    absolute_path = path
    FileUtils.mkdir_p(absolute_path.dirname) unless absolute_path.dirname.directory?
    File.open(absolute_path, open_mode) { |f| f.puts(content) } unless absolute_path.file?
    self
  end

  def path
    working_directory.join(relative_path)
  end

  def relative_path
    given_relative_path || digest_name
  end

  def to_s
    path.to_s
  end

  def digest_key
    [relative_path, content].map(&:to_s).to_s
  end

  private

  def content
    @content ||=
      if raw_content.is_a? String
        raw_content
      elsif raw_content.is_a? Array
        raw_content.join("\n")
      else
        raise RuntimeError
      end
  end

  def digest_name
    Digest::MD5.hexdigest([content, kwargs.to_a.sort].map(&:to_s).to_s)
  end

  def open_mode
    return 'wb' if kwargs[:binary]

    'w'
  end
end
