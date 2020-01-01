if !exists('g:esearch#adapter#grep#options')
  let g:esearch#adapter#grep#options = ''
endif
if !exists('g:esearch#adapter#grep#bin')
  let g:esearch#adapter#grep#bin = 'grep'
endif

let s:format = '^\(.\{-}\)\:\(\d\{-}\)\:\(.\{-}\)$'

fu! esearch#adapter#grep#_options() abort
  if !exists('s:options')

    let available_options = esearch#util#parse_help_options(g:esearch#adapter#grep#bin.' -h')
    if v:shell_error != 0
      let available_options = esearch#util#parse_help_options(g:esearch#adapter#grep#bin.' --help')
    endif

    if has('macunix')
      let regex = '-E'
      let literal_match = '--fixed-strings'
      let show_line_numbers = '--line-number'
      let exclude_dirs = '--exclude-dir=.{git,svn,hg}'
    else
      if has_key(available_options, '--perl-regexp')
        let regex = '--perl-regexp'
      elseif has_key(available_options, '-E')
        let regex = '-E'
      else
        throw 'TODO58'
      endif

      if has_key(available_options, '--fixed-strings')
        let literal_match = '--fixed-strings'
      elseif has_key(available_options, '-F')
        let literal_match = '-F'
      else
        throw 'TODO58'
      endif

      if has_key(available_options, '--line-number')
        let show_line_numbers = '--line-number'
      elseif has_key(available_options, '-n')
        let show_line_numbers = '-n'
      else
        throw 'TODO58'
      endif

      if has_key(available_options, '--exclude-dir')
        let exclude_dirs = '--exclude-dir=.{git,svn,hg}'
      else
        let exclude_dirs = ''
      endif
    endif


    let s:options = {
    \ 'regex': { 'p': [literal_match, regex], 's': ['>', 'r'] },
    \ 'case':  { 'p': ['-i',   ''             ], 's': ['>', 'c'] },
    \ 'word':  { 'p': ['',                '--word-regexp'], 's': ['>', 'w'] },
    \ 'show_line_numbers': show_line_numbers,
    \ 'exclude_dirs': exclude_dirs,
    \ 'stringify':   function('esearch#util#stringify'),
    \ 'parametrize': function('esearch#util#parametrize'),
    \}
  endif
  return s:options
endfu

fu! esearch#adapter#grep#cmd(pattern, dir, escape, ...) abort
  let options = a:0 ? a:1 : esearch#adapter#grep#_options()
  let r = options.parametrize('regex')
  let c = options.parametrize('case')
  let w = options.parametrize('word')
  " -r: recursive, no follow symbolic links
  " -I: Process a binary file as if it did not contain matching data

  " return g:esearch#adapter#grep#bin.' '.r.' '.c.' '.w.' -r --line-number --exclude-dir=.{git,svn,hg} ' .
  return g:esearch#adapter#grep#bin.' '.r.' '.c.' '.w.' -r -n '.options.show_line_numbers.' '.options.exclude_dirs.' '.
        \ g:esearch#adapter#grep#options . ' -- ' .
        \ a:escape(a:pattern)  . ' ' . fnameescape(a:dir)
endfu

fu! esearch#adapter#grep#is_broken_result(line) abort
  return empty(matchlist(a:line, s:format)[1:3])
endfu

fu! esearch#adapter#grep#parse_results(raw, from, to, broken_results, pattern) abort
  if empty(a:raw) | return [] | endif
  let format = s:format
  let results = []
  let pattern = a:pattern

  let i = a:from
  let limit = a:to + 1

  while i < limit
    let el = matchlist(a:raw[i], format)[1:3]
    if empty(el)
      if index(a:broken_results, a:raw[i]) < 0
        call add(a:broken_results, a:raw[i])
      endif
    else
      let col = match(el[2], pattern) + 1
      if !col | let col = 1 | endif
      call add(results, {'filename': el[0], 'lnum': el[1], 'col': col, 'text': el[2]})
    endif
    let i += 1
  endwhile
  return results
endfu

fu! esearch#adapter#grep#requires_pty() abort
  return 0
endfu

" Used to build the query
fu! s:parametrize(key, ...) dict abort
  let option_index = g:esearch[a:key]
  return self[a:key]['p'][option_index]
endfu
