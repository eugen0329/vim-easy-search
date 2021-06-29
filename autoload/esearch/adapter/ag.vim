fu! esearch#adapter#ag#new() abort
  return copy(s:Ag)
endfu

let s:Ag = esearch#adapter#base#import()
if exists('g:esearch#adapter#ag#bin')
  call esearch#util#deprecate('g:esearch#adapter#ag#options. Please, use g:esearch.adapters.ag.bin')
  let s:Ag.bin = g:esearch#adapter#ag#bin
else
  let s:Ag.bin = 'ag'
endif
if exists('g:esearch#adapter#ag#options')
  call esearch#util#deprecate('g:esearch#adapter#ag#options. Please, use g:esearch.adapters.ag.options')
  let s:Ag.options = g:esearch#adapter#ag#options
else
  let s:Ag.options = '--follow'
endif
let s:Ag.mandatory_options = '--nogroup --nocolor --noheading --nobreak'
let s:glob = {'icon': '--file-search-regex', 'opt': '--file-search-regex '}
let s:ignore = {'icon': '--ignore', 'opt': '--ignore '}
call extend(s:Ag, {
      \ 'bool2regex': ['literal', 'pcre'],
      \ 'regex': {
      \   'literal':   {'icon': '',  'option': '--fixed-strings'},
      \   'pcre':      {'icon': 'r', 'option': ''},
      \ },
      \ 'bool2textobj': ['none', 'word'],
      \ 'textobj': {
      \   'none':      {'icon': '',  'option': ''},
      \   'word':      {'icon': 'w', 'option': '--word-regexp'},
      \ },
      \ 'bool2case': ['ignore', 'sensitive'],
      \ 'case': {
      \   'ignore':    {'icon':  '', 'option': '--ignore-case'},
      \   'sensitive': {'icon': 's', 'option': '--case-sensitive'},
      \   'smart':     {'icon': 'S', 'option': '--smart-case'},
      \ },
      \ 'multi_glob': 1,
      \ 'glob_options': '--files-with-matches',
      \ 'globs': [s:glob, s:ignore],
      \ 'str2glob': {'-G': s:glob, '--file-search-regex': s:glob, '--ignore': s:ignore},
      \})

" ag --list-file-types
let s:Ag.filetypes = split('actionscript ada asciidoc apl asm batch bitbake bro cc cfmx chpl clojure coffee coq cpp crystal csharp css cython delphi dlang dot dts ebuild elisp elixir elm erlang factor fortran fsharp gettext glsl go groovy haml handlebars haskell haxe hh html idris ini ipython isabelle j jade java jinja2 js json jsp julia kotlin less liquid lisp log lua m4 make mako markdown mason matlab mathematica md mercury naccess nim nix objc objcpp ocaml octave org parrot pdb perl php pike plist plone proto pug puppet python qml racket rake restructuredtext rs r rdoc ruby rust salt sass scala scheme shell smalltalk sml sql stata stylus swift tcl terraform tex thrift tla tt toml ts twig vala vb velocity verilog vhdl vim wix wsdl wadl xml yaml')

fu! s:Ag._command(esearch, pattern_arg, converter) abort dict
  let regex = self.regex[a:esearch.regex].option
  let case = self.textobj[a:esearch.textobj].option
  let textobj = self.case[a:esearch.case].option
  let paths = self.pwd() ? empty(a:esearch.paths) : esearch#shell#join(a:esearch.paths)
  let context = ''
  if a:esearch.after > 0   | let context .= ' -A ' . a:esearch.after   | endif
  if a:esearch.before > 0  | let context .= ' -B ' . a:esearch.before  | endif
  if a:esearch.context > 0 | let context .= ' -C ' . a:esearch.context | endif

  return join([
        \ self.bin,
        \ regex, case, textobj,
        \ self.mandatory_options, self.options,
        \ context,
        \ self.filetypes2args(a:esearch.filetypes),
        \ a:esearch.globs.arg(a:converter),
        \ '--',
        \ a:pattern_arg,
        \ paths,
        \], ' ')
endfu

fu! s:Ag.command(esearch) abort dict
  return self._command(a:esearch, a:esearch.pattern.arg, {})
endfu

fu! s:Ag.glob(esearch) abort dict
  return self._command(a:esearch, '', {'--file-search-regex ': '-g '})
endfu

fu! s:Ag.is_success(request) abort
  " https://github.com/ggreer/the_silver_searcher/issues/1298
  return a:request.status == 0
        \ || (a:request.status == 1 && empty(a:request.errors) && empty(a:request.data))
endfu

fu! s:Ag.filetypes2args(filetypes) abort dict
  return substitute(a:filetypes, '\<', '--', 'g')
endfu
