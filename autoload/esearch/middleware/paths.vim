let s:Filepath = vital#esearch#import('System.Filepath')

fu! esearch#middleware#paths#apply(esearch) abort
  if !has_key(a:esearch, 'paths')
    let a:esearch.paths = esearch#shell#argv([])
    return a:esearch
  endif

  if g:esearch#has#posix_shell
    if type(a:esearch.paths) ==# type('')
      
      let [paths, error] = esearch#shell#split(s:Filepath.expand_home(a:esearch.paths))
      if !empty(error) | throw "Can't parse paths: " . error | endif
      let a:esearch.paths = paths
    endif
  endif

  return a:esearch
endfu
