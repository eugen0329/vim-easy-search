fu! esearch#adapter#base#import() abort
  return copy(s:Base)
endfu

let s:Base = {
      \ 'bin': 'NotImplemented',
      \ 'options': 'NotImplemented',
      \ 'mandatory_options': 'NotImplemented',
      \ 'parser': 'generic',
      \ 'pattern_kinds': [{'icon': '', 'opt': '', 'regex': 1}],
      \ 'multi_pattern': 0,
      \ 'multi_glob': 0,
      \ 'globs': [],
      \ 'str2glob': {},
      \ 'glob_options': '',
      \ 'after':    {'hint': 'lines after' , 'opt': '-A'},
      \ 'before':   {'hint': 'lines before', 'opt': '-B'},
      \ 'context':  {'hint': 'lines around', 'opt': '-C'},
      \}

fu! s:Base.command(esearch) abort dict
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
        \ regex,
        \ case,
        \ textobj,
        \ self.mandatory_options,
        \ self.options,
        \ context,
        \ self.filetypes2args(a:esearch.filetypes),
        \ '--',
        \ a:esearch.pattern.arg,
        \ paths,
        \], ' ')
endfu

let s:Base.filetypes = []

fu! s:Base.glob(filetypes) abort dict
  throw 'NotAvailable'
endfu

fu! s:Base.filetypes2args(filetypes) abort dict
  return ''
endfu

" Some adapters require pwd to be set explicitly (like grep) using '.'. For
" others it cause unwanted './' prefix. Exact path doesn't need to be
" specified as it's set using :lcd command and outherwise would cause a full
" path to be rendered.
fu! s:Base.pwd() abort dict
  return ''
endfu

" '' and '--' separators are outputted when context height options are given
fu! s:Base.outputs_separators(esearch) abort
  return a:esearch.context != 0 || a:esearch.before != 0 || a:esearch.after != 0
endfu

fu! s:Base.is_success(request) abort
  return a:request.status == 0
endfu
