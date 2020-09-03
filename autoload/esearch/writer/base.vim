fu! esearch#writer#base#import() abort
  return copy(s:Base)
endfu

let s:Base = {}

fu! s:Base.new(diff, esearch) abort
  return extend(copy(self), {'diff': a:diff, 'esearch': a:esearch})
endfu

fu! s:Base.log() abort dict
  if empty(self.conflicts)
    call esearch#util#warn('Done.')
    return setbufvar(self.esearch.bufnr, '&modified', 0)
  end

  let reasons = map(self.conflicts, 'printf("\n\t%s (%s)", v:val.filename, v:val.reason)')
  let message = "Can't write changes to the following files:".join(reasons, '')
  call esearch#util#warn(message)
endfu

fu! s:Base.verify_readable(ctx, path) abort dict
  if filereadable(a:path) | return 1 | endif
  if get(a:ctx.original, 'git')
    call add(self.conflicts, {'filename': a:path, 'reason': 'is a git blob'})
  else
    call add(self.conflicts, {'filename': a:path, 'reason': 'is not readable'})
  endif
  return 0
endfu