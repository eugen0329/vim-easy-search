fu! esearch#adapter#rg#new() abort
  return copy(s:Rg)
endfu

let s:Rg = esearch#adapter#base#import()
if exists('g:esearch#adapter#rg#bin')
  call esearch#util#deprecate('g:esearch#adapter#rg#options. Please, use g:esearch.adapters.rg.bin')
  let s:Rg.bin = g:esearch#adapter#rg#bin
else
  let s:Rg.bin = 'rg'
endif
if exists('g:esearch#adapter#rg#options')
  call esearch#util#deprecate('g:esearch#adapter#rg#options. Please, use g:esearch.adapters.rg.options')
  let s:Rg.options = g:esearch#adapter#rg#options
else
  " --text: Search binary files as if they were text
  let s:Rg.options = '--follow'
endif
let s:Rg.mandatory_options = '--no-heading --color=never --line-number --with-filename'
" https://docs.rs/regex/1.3.6/regex/#syntax

let s:glob = {'icon': '--glob',  'opt': '--glob '}
let s:iglob = {'icon': '--iglob', 'opt': '--iglob '}
call extend(s:Rg, {
      \ 'bool2regex': ['literal', 'default'],
      \ 'regex': {
      \   'literal':   {'icon': '',  'option': '--fixed-strings'},
      \   'default':   {'icon': 'r', 'option': ''},
      \   'auto':      {'icon': 'A', 'option': '--engine auto'},
      \   'pcre':      {'icon': 'P', 'option': '--pcre2'},
      \ },
      \ 'bool2textobj': ['none', 'word'],
      \ 'textobj': {
      \   'none':     {'icon': '',  'option': ''},
      \   'word':     {'icon': 'w', 'option': '--word-regexp'},
      \   'line':     {'icon': 'l', 'option': '--line-regexp'},
      \ },
      \ 'bool2case': ['ignore', 'sensitive'],
      \ 'multi_pattern': 1,
      \ 'pattern_kinds': [{'icon': '', 'opt': '-e ', 'regex': 1}],
      \ 'case': {
      \   'ignore':    {'icon':  '', 'option': '--ignore-case'},
      \   'sensitive': {'icon': 's', 'option': '--case-sensitive'},
      \   'smart':     {'icon': 'S', 'option': '--smart-case'},
      \ },
      \ 'multi_glob': 1,
      \ 'glob_options': '--files --sort path',
      \ 'globs': [s:glob, s:iglob],
      \ 'str2glob': {'-g': s:glob, '--glob': s:glob, '--iglob': s:iglob},
      \})

" rg --type-list | cut -d: -f1 | tr '\n' ' '
let s:Rg.filetypes = split('agda aidl amake asciidoc asm asp ats avro awk bazel bitbake brotli buildstream bzip2 c cabal cbor ceylon clojure cmake coffeescript config coq cpp creole crystal cs csharp cshtml css csv cython d dart dhall diff docker ebuild edn elisp elixir elm erb erlang fidl fish fortran fsharp gap gn go gradle groovy gzip h haml haskell hbs hs html idris java jinja jl js json jsonl julia jupyter k kotlin less license lisp lock log lua lz4 lzma m4 make mako man markdown matlab md mk ml msbuild nim nix objc objcpp ocaml org pascal pdf perl php pod postscript protobuf ps puppet purs py qmake qml r rdoc readme robot rst ruby rust sass scala sh slim smarty sml soy spark spec sql stylus sv svg swift swig systemd taskpaper tcl tex textile tf thrift toml ts twig txt typoscript vala vb verilog vhdl vim vimscript webidl wiki xml xz yacc yaml zig zsh zstd')

fu! s:Rg._command(esearch, glob_or_pattern) abort dict
  let regex = self.regex[a:esearch.regex].option
  let case = self.textobj[a:esearch.textobj].option
  let textobj = self.case[a:esearch.case].option

  if empty(a:esearch.paths)
    let paths = self.pwd()
  else
    let paths = esearch#shell#join(a:esearch.paths)
  endif

  let context = ''
  if a:esearch.after > 0   | let context .= ' -A ' . a:esearch.after   | endif
  if a:esearch.before > 0  | let context .= ' -B ' . a:esearch.before  | endif
  if a:esearch.context > 0 | let context .= ' -C ' . a:esearch.context | endif

  return join([
        \ self.bin,
        \ regex, case, textobj,
        \ self.mandatory_options,  self.options,
        \ context,
        \ self.filetypes2args(a:esearch.filetypes),
        \ a:esearch.globs.arg(),
        \ a:glob_or_pattern,
        \ '--',
        \ paths,
        \], ' ')
endfu

fu! s:Rg.command(esearch) abort dict
  return self._command(a:esearch, a:esearch.pattern.arg)
endfu

fu! s:Rg.glob(esearch) abort dict
  return self._command(a:esearch, self.glob_options)
endfu

fu! s:Rg.filetypes2args(filetypes) abort dict
  return substitute(a:filetypes, '\<', '--type ', 'g')
endfu

fu! s:Rg.is_success(request) abort
  " https://github.com/BurntSushi/ripgrep/issues/948
  return a:request.status == 0
        \ || (a:request.status == 1 && empty(a:request.errors) && empty(a:request.data))
endfu
