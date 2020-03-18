let g:esearch#adapter#parse#viml#controls = {
      \  'a':  "\<C-G>",
      \  'b':  "\b",
      \  't':  "\t",
      \  'n':  "\n",
      \  'v':  "\<C-k>",
      \  'f':  "\f",
      \  'r':  "\r",
      \  '\':  '\',
      \  '"':  '"',
      \  '033':"\e",
      \ }

fu! esearch#adapter#parse#viml#getqflines_funcref() abort
  return function('esearch#adapter#parse#viml#getqflines')
endfu
fu! esearch#adapter#parse#viml#legacy_funcref() abort
  return function('esearch#adapter#parse#viml#legacy')
endfu

" NOTE some code is reused by copypasting (wrappend into SHARED CODE
" {START,END}) as parsing is a bottleneck and should be as fast as possible
fu! esearch#adapter#parse#viml#legacy(data, from, to) abort dict
  if empty(a:data) | return [] | endif
  let results = []
  let pattern = self.exp.vim

  let i = a:from
  let limit = a:to + 1

  while i < limit
    let line = a:data[i]

    if line[0] ==# '"'
      let res = matchlist(line, '^"\(\%(\\\\\|\\"\|.\)\{-}\)"\:\(\d\{-}\)[-:]\(.*\)$')[1:3]
      if len(res) != 3
        let i += 1
        continue
      endif

      let [filename, lnum, text] = res

      " SHARED CODE START
      let filename = substitute(filename, '\\\([abtnvfr"\\]\|033\)',
            \ '\=g:esearch#adapter#parse#viml#controls[submatch(1)]', 'g')
      " SHARED CODE END
      call add(results, {
            \ 'filename': substitute(filename, b:esearch.cwd_prefix, '', ''),
            \ 'lnum':     lnum,
            \ 'text':     text})

    else
      let offset = 0
      while 1
        let idx = stridx(line, ':', offset)

        if idx < 0
          break
        endif

        let filename = line[0 : idx - 1]
        let offset = idx + 1

        if filereadable(filename)
          break
        end
      endwhile

      if idx > 0
        let matches = matchlist(line, '\(\d\+\)[-:]\(.*\)', offset)[1:2]
        if !empty(matches)
          call add(results, {
                \ 'filename': substitute(filename, b:esearch.cwd_prefix, '', ''),
                \ 'lnum':     matches[0],
                \ 'text':     matches[1]})
        endif
      endif
    endif

    let i += 1
  endwhile

  return results
endfu

fu! esearch#adapter#parse#viml#getqflines(data, from, to) abort dict
  if empty(a:data) | return [] | endif

  let items = getqflist({'lines': a:data[a:from : a:to], 'efm': '%f:%l:%m'}).items
  try
    " changing cwd is required as bufname() has side effects
    let saved_cwd = getcwd()
    if !empty(b:esearch.cwd)
      exe 'lcd' b:esearch.cwd
    endif
    for item in filter(items, 'v:val.valid')

      let filename = bufname(item['bufnr'])
      if filename[0] ==# '"' && strlen(filename) > 1
        " SHARED CODE START
        let filename = substitute(filename[1 : strchars(filename) - 2], '\\\([abtnvfr"\\]\|033\)',
              \ '\=g:esearch#adapter#parse#viml#controls[submatch(1)]', 'g')
        " SHARED CODE END
      endif

      let item['filename'] = filename
    endfor
  finally
    if !empty(saved_cwd)
      exe 'lcd' saved_cwd
    endif
  endtry
  return items
endfu