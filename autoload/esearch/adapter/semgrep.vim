fu! esearch#adapter#semgrep#new() abort
  return copy(s:Semgrep)
endfu

let s:Semgrep = esearch#adapter#base#import()

let s:Semgrep.bin = 'semgrep'
let s:Semgrep.options = ''
let s:Semgrep.mandatory_options = '--json --quiet'

call extend(s:Semgrep, {
      \ 'regex':   {},
      \ 'textobj': {},
      \ 'case':    {},
      \ 'before':  0,
      \ 'after':   0,
      \ 'context': 0,
      \ 'parser':  'semgrep',
      \ 'multi_pattern': 1,
      \ 'pattern_kinds': [
      \   {'icon': '-e', 'opt': '-e ', 'regex': 0},
      \ ],
      \})

fu! s:Semgrep.command(esearch) abort dict

  if empty(a:esearch.paths)
    let paths = self.pwd()
  else
    let paths = esearch#shell#join(a:esearch.paths)
  endif

  return join([
        \ self.bin,
        \ self.mandatory_options,
        \ self.options,
        \ a:esearch.pattern.arg,
        \ self.filetypes2args(a:esearch.filetypes),
        \ '--',
        \ paths,
        \], ' ')
endfu

let s:Semgrep.filetypes = split('go java js json py python rb ruby c ocaml')

fu! s:Semgrep.filetypes2args(filetypes) abort dict
  return substitute(a:filetypes, '\<', '--lang=', 'g')
endfu
