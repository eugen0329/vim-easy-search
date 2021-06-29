fu! esearch#middleware#globs#apply(esearch) abort
  if empty(get(a:esearch, 'globs'))
    let a:esearch.globs = esearch#glob#new(a:esearch._adapter, [])
    return a:esearch
  endif

  if g:esearch#has#posix_shell
    if type(a:esearch.globs) ==# type('')
      let a:esearch.globs = s:from_shell_string(a:esearch)
    endif
  else
    " TODO
    let g:esearch.pending_warnings += ['esearch: globs are for non posix shells']
    let a:esearch.globs = esearch#glob#new(a:esearch._adapter, [])
  endif

  return a:esearch
endfu

fu! s:from_shell_string(esearch) abort
  let [tokens, error] = esearch#shell#split(a:esearch.globs)
  if !empty(error) | throw "Can't parse globs: " . error | endif
  if empty(tokens) | return esearch#glob#new(a:esearch._adapter, []) | endif

  let [globs, str2glob] = [[], a:esearch._adapter.str2glob]
  for i in range(0, len(tokens) / 2 - 1)
    let [kind, str] = [get(str2glob, tokens[i * 2].str), tokens[i*2 + 1].str]

    if empty(kind)
      let g:esearch.pending_warnings += ['esearch: unknown glob ' . tokens[i * 2].str . ' is specified']
      continue
    endif

    let globs += [[kind, str]]
  endfor

  return esearch#glob#new(a:esearch._adapter, globs)
endfu
