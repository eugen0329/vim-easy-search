let s:Buffer = vital#esearch#import('Vim.Buffer')
let s:Log = esearch#log#import()
let s:Filepath = vital#esearch#import('System.Filepath')
let s:UNDEFINED = esearch#polyfill#undefined()

if g:esearch#has#bufadd
  fu! esearch#buf#find(filename) abort
    if !bufexists(a:filename) | return -1 | endif
    return bufadd(a:filename)
  endfu
else
  fu! esearch#buf#find(filename) abort
    return bufnr(esearch#buf#pattern(a:filename))
  endfu
endif

" :h file-pattern
fu! esearch#buf#pattern(filename) abort
  let filename = s:Filepath.to_slash(resolve(a:filename))
  " Special file-pattern characters must be escaped: [ escapes to [[], not \[.
  let filename = escape(filename, '?*[],\')
  " replacing with \{ and \} or [{] and [}] doesn't work
  let filename = substitute(filename, '[{}]', '?', 'g')
  return '^' . filename . '$'
endfu

fu! esearch#buf#tabwin(bufnr) abort
  for tabnr in range(1, tabpagenr('$'))
    let buflist = tabpagebuflist(tabnr)
    if index(buflist, a:bufnr) >= 0
      for winnr in range(1, tabpagewinnr(tabnr, '$'))
        if buflist[winnr - 1] == a:bufnr | return [tabnr, winnr] | endif
      endfor
    endif
  endfor

  return [0, 0]
endf

fu! esearch#buf#get(bufnr, name) abort
  return getbufvar(a:bufnr, a:name[(a:name =~# '^b:' ? 2 : 0):], s:UNDEFINED)
endfu

fu! esearch#buf#let(bufnr, name, val) abort
  call setbufvar(a:bufnr, a:name[(a:name =~# '^b:' ? 2 : 0):], a:val)
endfu

fu! esearch#buf#bulk_let(bufnr, variables) abort
  for [name, l:Val] in items(a:variables)
    if Val is s:UNDEFINED | continue | endif
    call setbufvar(a:bufnr, name[(name =~# '^b:' ? 2 : 0):], Val)
  endfor
endfu

fu! esearch#buf#goto_or_open(buffer, opener, ...) abort
  let options = extend(copy(get(a:, 1, {})), {'opener': a:opener})
  let bufnr = esearch#buf#find(a:buffer)

  " Noop if the buffer is current
  if bufnr == bufnr('%') | return 1 | endif
  " Open if doesn't exist
  if bufnr == -1
    return s:Buffer.open(a:buffer, options)
  endif
  let [tabnr, winnr] = esearch#buf#tabwin(bufnr)
  " Open if closed
  if empty(winnr)
    return s:Buffer.open(a:buffer, options)
  endif
  " Locate if opened
  exe 'tabnext ' . tabnr
  exe winnr . 'wincmd w'
  return 1
endfu

fu! esearch#buf#open(buffer, opener, ...) abort
  let options = extend(copy(get(a:, 1, {})), {'opener': a:opener})
  return s:Buffer.open(a:buffer, options)
endfu

" borrowed from the airline
fu! esearch#buf#qfbufnr() abort
  redir => buffers
  silent ls
  redir END

  for buf in split(buffers, '\n')
    if match(buf, '\cQuickfix') > -1
      return str2nr(matchlist(buf, '\s\(\d\+\)')[1])
    endif
  endfor
  return -1
endfu

fu! esearch#buf#qftype(bufnr) abort
  let buffers = s:Log.capture('silent ls')

  let nr = a:bufnr
  for buf in split(buffers, '\n')
    if match(buf, '\v^\s*'.nr) > -1
      if match(buf, '\cQuickfix') > -1
        return 'qf'
      elseif match(buf, '\cLocation') > -1
        return 'loc'
      else
        return 'reg'
      endif
    endif
  endfor
endfu

fu! esearch#buf#rename(name) abort
  silent exe 'file' fnameescape(a:name)
endfu

fu! esearch#buf#rename_qf(name) abort
  let w:quickfix_title = a:name
endfu

fu! s:bufdo(bufnr, cmd, bang) abort
  let cur_buffer = esearch#buf#stay()
  try
    exe (bufnr('%') == a:bufnr ? '' : a:bufnr.'bufdo ') . a:cmd . (a:bang ? '!' : '')
    return 1
  catch   | call esearch#util#warn(v:exception) | return 0
  finally | call cur_buffer.restore()
  endtry
endfu

fu! esearch#buf#import() abort
  return copy(s:Buf)
endfu

let s:Buf = {}

fu! s:Buf.for(bufnr) abort dict
  call setbufvar(a:bufnr, '&buflisted', 1) " required for bufdo
  return extend(copy(self), {'bufnr': a:bufnr, 'filename': bufname(a:bufnr), 'existed': 1})
endfu

if g:esearch#has#bufadd && g:esearch#has#bufload
  fu! s:Buf.new(filename) abort dict
    let existed = bufexists(a:filename)
    let bufnr = bufadd(a:filename)
    call bufload(bufnr)
    call setbufvar(bufnr, '&buflisted', 1) " required for bufdo
    return extend(copy(self), {'bufnr': bufnr, 'filename': a:filename, 'existed': existed})
  endfu
else
  fu! s:Buf.new(filename) abort dict
    let existed = bufexists(a:filename)
    exe (existed ? 'buffer!' : 'edit!') fnameescape(a:filename)
    call setbufvar(bufnr('%'), '&buflisted', 1) " required for bufdo
    return extend(copy(self), {'bufnr': bufnr('%'), 'filename': a:filename, 'existed': existed})
  endfu
endif

if exists('*nvim_buf_line_count')
  fu! s:Buf.oneliner() abort dict
    return nvim_buf_line_count(self.bufnr) == 1
  endfu
elseif g:esearch#has#getbufinfo_linecount
  fu! s:Buf.oneliner() abort dict
    return getbufinfo(self.bufnr)[0].linecount == 1
  endfu
else
  fu! s:Buf.oneliner() abort dict
    return getbufline(self.bufnr, 2) == []
  endfu
endif

fu! s:Buf.goto() abort dict
  exe 'buffer!' self.bufnr 
endfu

fu! s:Buf.getline(lnum) abort dict
  return get(getbufline(self.bufnr, a:lnum), 0)
endfu

" (set|append|delete)bufline are supported only in latest versions, that aren't
" available in Debian repo, so old APIs are used.
fu! s:Buf.setline(lnum, replacement) abort dict
  if bufnr('%') !=# self.bufnr | throw 'Wrong bufnr' | endif
  call setline(a:lnum, a:replacement)
endfu

fu! s:Buf.appendline(lnum, texts) abort
  if bufnr('%') !=# self.bufnr | throw 'Wrong bufnr' | endif
  call append(a:lnum, a:texts)
endfu

fu! s:Buf.deleteline(lnum) abort dict
  if bufnr('%') !=# self.bufnr | throw 'Wrong bufnr' | endif
  exe a:lnum 'delete _'
endfu

fu! s:Buf.write(bang) dict abort
  return s:bufdo(self.bufnr, 'write', a:bang)
endfu

fu! s:Buf.open(opener, ...) dict abort
  let options = extend(copy(get(a:, 1, {})), {'opener': a:opener})
  return s:Buffer.open(self.bufnr, options)
endfu

fu! s:Buf.bdelete(...) dict abort
  return s:bufdo(self.bufnr, 'bdelete', get(a:, 1))
endfu

fu! s:Buf.bwipeout(...) dict abort
  return s:bufdo(self.bufnr, 'bwipeout', get(a:, 1))
endfu

fu! esearch#buf#stay() abort
  return s:CurrentBufferGuard.new()
endfu

let s:CurrentBufferGuard = {}

fu! s:CurrentBufferGuard.new() abort dict
  return extend(copy(self), {'bufnr': bufnr('')})
endfu

fu! s:CurrentBufferGuard.restore() abort dict
  if self.bufnr != bufnr('') | exe self.bufnr 'buffer!' | endif
endfu
