# frozen_string_literal: true

RSpec.shared_context 'setup syntax testing' do
  include Helpers::FileSystem
  include Helpers::WindowSyntaxContext

  let!(:test_directory) { directory([source_file], 'window/syntax/').persist! }

  before do
    esearch.configure!(regex: 1, backend: 'system', adapter: 'ag', 'out': 'win')
    editor.press! ':let g:esearch_win_context_syntax_async = 0<Enter>'
    esearch.search! '^', paths: [source_file.path.to_s]
    expect(esearch).to have_search_finished
  end
  after { editor.press! ':let g:esearch_win_context_syntax_async = 1<Enter>' }

  it 'keeps line numbers highligh untouched' do
    expect(source_file.content).to have_line_numbers_highlight(%w[esearchLineNr LineNr])
  end

  it 'keeps header highligh untouched' do
    is_expected.to have_highligh_aliases(
      '\%1l.*' => %w[esearchHeader Title]
    )
  end
end
