# frozen_string_literal: true

module Helpers::Shell
  def split(str)
    paths, error = editor.echo(func('esearch#shell#split', str))
    return :error if error != 0

    paths.map { |path| path['str'] }
  end

  def tokens_of(str)
    paths, error = editor.echo(func('esearch#shell#split', str))
    return :error if error != 0

    paths.map { |word| word['tokens'] }
  end

  def split_and_escape(str)
    paths, error = editor.echo(func('esearch#shell#split', str))
    return :error if error != 0

    paths.map do |path|
      editor.echo(func('esearch#shell#escape', path))
    end
  end
end
