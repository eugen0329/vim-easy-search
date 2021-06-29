fu! esearch#glob#new(adapter, ...) abort
  return s:GlobSet.new(a:adapter.globs, a:adapter.str2glob, get(a:, 1, []))
endfu

let s:GlobSet = {}

fu! s:GlobSet.new(kinds, str2glob, globs) abort dict
  let new = copy(self)
  let new.kinds = esearch#util#cycle(a:kinds)
  let new.globs = esearch#util#stack([])
  for [kind, str] in a:globs
    call new.globs.push(s:Glob.from_kind(kind, str))
  endfor
  let new.list = new.globs.list
  return new
endfu

" TODO
fu! s:GlobSet.arg(...) abort
  let list = filter(copy(self.list), '!empty(v:val.str)')
  let dict = get(a:, 1, {})
  return join(map(copy(list), 'get(dict, v:val.opt, v:val.opt) . shellescape(v:val.str)'), ' ')
endfu

fu! s:GlobSet.replace(str) abort dict
  if empty(self.list) | return self.push(a:str) |  endif
  return self.globs.replace(extend(copy(self.globs.top()), {'str': a:str}))
endfu

fu! s:GlobSet.push(str) abort dict
  return self.globs.push(s:Glob.from_kind(self.kinds.next(), a:str))
endfu

fu! s:GlobSet.try_pop() abort dict
  if self.globs.len() == 0 | return | endif
  return self.globs.pop()
endfu

fu! s:GlobSet.next() abort dict
  if empty(self.list) | return s:Glob.from_kind(self.kinds.next(), self.peek().str) |  endif

  return self.globs.replace(s:Glob.from_kind(self.kinds.next(), self.peek().str))
endfu

fu! s:GlobSet.peek() abort dict
  return empty(self.list) ? s:Glob.from_kind(self.kinds.peek(), '') : self.globs.top()
endfu

let s:Glob = {}

fu! s:Glob.new(icon, opt, str) abort dict
  return extend(copy(self), {'icon': a:icon, 'opt': a:opt, 'str': a:str})
endfu

fu! s:Glob.from_kind(kind, str) abort
  return s:Glob.new(a:kind.icon, a:kind.opt, a:str)
endfu

fu! s:Glob.convert(_esearch) abort dict
  let self.arg = shellescape(self.str)
  return self
endfu
