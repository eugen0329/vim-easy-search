let s:Prelude  = vital#esearch#import('Prelude')
let s:List     = vital#esearch#import('Data.List')
let s:Log      = esearch#log#import()
let s:Filepath = vital#esearch#import('System.Filepath')

let g:esearch#util#even_count_of_escapes_re = '\\\@<!\%(\\\\\)*'

fu! esearch#util#setline(_, lnum, text) abort
  call setline(a:lnum, a:text)
endfu

if has('nvim')
  fu! esearch#util#append_lines(lines) abort
    call nvim_buf_set_lines(0, -1, -1, 0, a:lines)
  endfu
else
  fu! esearch#util#append_lines(lines) abort
    call append(line('$'), a:lines)
  endfu
endif

fu! esearch#util#ellipsize_end(text, max_len, ellipsis) abort
  if strchars(a:text) < a:max_len
    return a:text
  endif

  return strcharpart(a:text, 0, a:max_len - 1 - strchars(a:ellipsis)) . a:ellipsis
endfu

fu! esearch#util#clip(value, from, to) abort
  " is made inclusive to be compliant with vim internal functions
  if a:value >= a:to
    return a:to
  elseif a:value <= a:from
    return a:from
  else
    return a:value
  endif
endfu

fu! esearch#util#is_visual(mode) abort
  return a:mode =~? "^[vs\<c-v>]$"
endfu

fu! esearch#util#slice(dict, keys) abort
  return filter(copy(a:dict), 'index(a:keys, v:key) >= 0')
endfu

fu! esearch#util#compare_len(first, second) abort
  let a = len(a:first)
  let b = len(a:second)
  return a == b ? 0 : a > b ? 1 : -1
endfu

" abolish.vim
fu! esearch#util#buff_words() abort
  let words = []
  let lnum = line('w0')
  while lnum <= line('w$')
    let line = getline(lnum)
    let col = 0
    while match(line,'\<\k\k\+\>',col) != -1
      let words += [matchstr(line,'\<\k\k\+\>',col)]
      let col = matchend(line,'\<\k\k\+\>',col)
    endwhile
    let lnum += 1
  endwhile

  return s:List.uniq(words)
endfu

if has('nvim') || g:esearch#has#windows
  fu! esearch#util#getchar() abort
    return s:to_char(getchar())
  endfu
else
  fu! esearch#util#getchar() abort
    let char = getchar()

    if empty(esearch#keymap#escape_kind(char))
      return s:to_char(char)
    endif

    return char
  endfu
endif

fu! esearch#util#has_upper(text) abort
  let ignorecase = esearch#let#restorable({'&ignorecase': 0})
  try
    return a:text =~# '[[:upper:]]'
  finally
    call ignorecase.restore()
  endtry
endfu

fu! s:to_char(getchar_output) abort
  if type(a:getchar_output) ==# type('')
    return a:getchar_output
  endif
  return nr2char(a:getchar_output)
endfu

fu! esearch#util#insert(list, items, index) abort
  let i = len(a:items) - 1
  let list = a:list

  while i >= 0
    let list = insert(list, a:items[i], a:index)
    let i -= 1
  endwhile

  return list
endfu

fu! esearch#util#safe_undojoin() abort
  try
    undojoin
  catch /E790:/
  endtry
endfu

fu! esearch#util#squash_undo() abort
  let undolevels = esearch#let#restorable({'&l:undolevels': -1})
  keepjumps call setline('.', getline('.'))
  call undolevels.restore()
endfu

fu! esearch#util#safe_matchdelete(id) abort
  if a:id < 1 | return | endif " E802

  try
    call matchdelete(a:id)
  catch /E803:/
  endtry
endfu

fu! esearch#util#is_abspath(path) abort
  return s:Filepath.is_absolute(a:path) || a:path =~# '^\~\%(/\|$\)'
endfu

" Expanding to full path using :p is required to replace ~ character
fu! esearch#util#abspath(cwd, path) abort
  if esearch#util#is_abspath(a:path) | return fnamemodify(a:path, ':p') | endif
  return s:Filepath.join(a:cwd, a:path)
endfu

" Is DANGEROUS as it can cause editing file with an existing swap, required ONLY
" for floating preview windows
fu! esearch#util#silence_swap_prompt() abort
  " A - suppress swap prompt
  " F - don't echo that a:filename is edited
  return esearch#let#restorable({'&shortmess': 'AF'})
endfu

fu! esearch#util#slice_factory(keys) abort
  let private_scope = {}
  exe    " fu! l:private_scope.slice(dict) abort\n"
     \ . '   return esearch#util#slice(a:dict,'.string(a:keys).")\n"
     \ . ' endfu'
  return private_scope.slice
endfu

fu! esearch#util#doautocmd(expr) abort
  exe 'silent doau <nomodeline> ' . a:expr
endfu

fu! esearch#util#escape_for_statusline(str) abort
  let safe_slash = g:esearch#has#unicode ? g:esearch#unicode#slash : '{slash}'
  return substitute(tr(a:str, '/', safe_slash), '%', '%%', 'g')
endfu

fu! esearch#util#counter() abort
  return s:Count.new()
endfu

let s:Count = {'_value': 0}

fu! s:Count.new() abort dict
  return copy(self)
endfu

fu! s:Count.next() abort dict
  let self._value += 1
  return self._value - 1
endfu

fu! esearch#util#cycle(list) abort
  return s:Cycle.new(a:list)
endfu

let s:Cycle = {}

fu! s:Cycle.new(list) abort dict
  return extend(copy(self), {'list': a:list, 'i': 0})
endfu

fu! s:Cycle.peek() abort dict
  return self.list[self.i]
endfu

fu! s:Cycle.next() abort dict
  let next = self.list[self.i]
  let self.i = (self.i + 1) % len(self.list)
  return next
endfu

fu! esearch#util#stack(list) abort
  return s:Stack.new(a:list)
endfu

let s:Stack = {}

fu! s:Stack.new(list) abort dict
  return extend(copy(self), {'list': a:list})
endfu

fu! s:Stack.top() abort dict
  return self.list[-1]
endfu

fu! s:Stack.len() abort dict
  return len(self.list)
endfu

" .top() = val; in cpp
fu! s:Stack.replace(new_top) abort dict
  let self.list[-1] = a:new_top
  return self.list[-1]
endfu

fu! s:Stack.push(val) abort dict
  return add(self.list, a:val)
endfu

fu! s:Stack.pop() abort dict
  return remove(self.list, -1)
endfu

fu! esearch#util#deprecate(message) abort
  let g:esearch.pending_warnings += ['DEPRECATION: ' . a:message]
endfu

fu! esearch#util#warn(message) abort
  if mode() ==# 'c'
    let g:esearch.pending_warnings += [a:message]
  else
    redraw
    call s:Log.info(a:message)
  endif
endfu

fu! esearch#util#find_up(path, markers) abort
  " Partially based on vital's prelude path2project-root internals
  let dir = s:Prelude.path2directory(a:path)
  let depth = 0
  while depth < 50
    for marker in a:markers
      let file = globpath(dir, marker, 1)
      if file !=# '' | return file | endif
    endfor

    let dir_upwards = fnamemodify(dir, ':h')
    " NOTE compare is case insensitive
    if dir_upwards == dir | return '' | endif
    let dir = dir_upwards
    let depth += 1
  endwhile
  return ''
endfu

fu! esearch#util#by_key(pair1, pair2) abort
  return a:pair1[0] == a:pair2[0] ? 0 : +a:pair1[0] > +a:pair2[0] ? 1 : -1
endfu

if g:esearch#has#timers
fu! esearch#util#try_defer(funcref, ...) abort
  call timer_start(0, function('s:defer_cb', [a:funcref, a:000]))
endfu
fu! s:defer_cb(func, argv, _) abort
  return call(a:func, a:argv)
endfu
else
  fu! esearch#util#try_defer(funcref, ...) abort
    call call(a:funcref, a:000)
  endfu
endif

fu! esearch#util#clipboard_reg() abort
  let clipboards = split(&clipboard, ',')
  if index(clipboards, 'unnamedplus') >= 0
    return '+'
  elseif index(clipboards, 'unnamed') >= 0
    return '*'
  endif

  return '"'
endfu

fu! esearch#util#capture_range(target) abort range
  call add(a:target, [a:firstline, a:lastline])
endfu

fu! esearch#util#noop(...) abort
  return 0
endfu
