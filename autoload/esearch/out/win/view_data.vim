let s:results_line_re = '^\%>1l\s\+\d\+.*'
let s:Filepath = vital#esearch#import('System.Filepath')

" Methods to mine information from a rendered window

fu! esearch#out#win#view_data#init(esearch) abort
  call extend(a:esearch, {
        \ 'filename':           function('<SID>filename'),
        \ 'unescaped_filename': function('<SID>unescaped_filename'),
        \ 'filetype':           function('<SID>filetype'),
        \ 'line_in_file':       function('<SID>line_in_file'),
        \ 'ctx_view':           function('<SID>ctx_view'),
        \ 'ctx_at':             function('<SID>ctx_at'),
        \ 'is_filename':        function('<SID>is_filename'),
        \ 'is_entry':           function('<SID>is_entry'),
        \ 'is_current':         function('<SID>is_current'),
        \ 'is_blank':           function('<SID>is_blank'),
        \ })
endfu

fu! esearch#out#win#view_data#filename(es, ctx) abort
  if empty(a:ctx) | return '' | endif

  if get(a:ctx, 'git') ==# 1
    return s:git_url(a:es, a:ctx.filename)
  elseif s:Filepath.is_absolute(a:ctx.filename)
    return a:ctx.filename
  endif
  return s:Filepath.join(a:es.cwd, a:ctx.filename)
endfu

" Returns dict that can be forwarded into builtin winrestview()
fu! s:ctx_view() abort dict
  let line = self.line_in_file()
  let state = esearch#out#win#_state(self)
  let linenr = printf(g:esearch#out#win#linenr_format, state.line_numbers_map[line('.')])
  return { 'lnum': line,  'col': max([0, col('.') - strlen(linenr) - 1]) }
endfu

fu! s:line_in_file() abort dict
  return (matchstr(getline(s:result_line()), '^\s\+\zs\d\+\ze.*'))
endfu

fu! s:filetype(...) abort dict
  if !self.is_current() | return | endif

  let ctx = self.ctx_at(line('.'))
  if empty(ctx) | return '' | endif

  if empty(ctx.filetype)
    let opts = get(a:000)

    if get(opts, 'fast', 0)
      let ctx.filetype = esearch#ftdetect#complete(ctx.filename)
    else
      let ctx.filetype = esearch#ftdetect#fast(ctx.filename)
    endif
  endif

  return ctx.filetype
endfu

fu! s:git_url(es, filename) abort
  if !has_key(a:es, 'git_dir')
    let a:es.git_dir = esearch#git#dir(a:es.cwd)
  endif
  return esearch#git#url(a:es.git_dir, a:filename)
endfu

fu! s:unescaped_filename(...) abort dict
  if !self.is_current() | return | endif
  return esearch#out#win#view_data#filename(self, self.ctx_at(get(a:, 1, line('.'))))
endfu

fu! s:filename(...) abort dict
  if !self.is_current() | return | endif
  return fnameescape(esearch#out#win#view_data#filename(self, self.ctx_at(get(a:, 1, line('.')))))
endfu

fu! s:ctx_at(line) dict abort
  if self.is_blank() | return {} | endif

  let ctx = esearch#out#win#repo#ctx#new(self, esearch#out#win#_state(self))
        \.by_line(a:line)
  if ctx.id == 0
    return self.contexts[1]
  endif

  return ctx
endfu

fu! s:is_entry(...) abort dict
  return getline(get(a:, 1, line('.'))) =~# g:esearch#out#win#entry_re
endfu

fu! s:is_filename(...) abort dict
  return getline(get(a:, 1, line('.'))) =~# g:esearch#out#win#filename_re
endfu

" Is used to prevent problems with asynchronous code
fu! s:is_current() abort dict
  return get(b:, 'esearch', {'id': -1}).id == self.id
endfu

fu! s:is_blank() abort dict
  " if only a header ctx
  if len(self.contexts) < 2 | return 1 | endif
endfu

fu! s:result_line() abort
  let current_line_text = getline('.')
  let current_line = line('.')

  " if the cursor above the header on above a file
  if current_line < 3 || match(current_line_text, '^[^ ].*') >= 0
    return search(s:results_line_re, 'cWn') " search forward
  elseif empty(current_line_text)
    return search(s:results_line_re, 'bcWn')  " search backward
  else
    return current_line
  endif
endfu
