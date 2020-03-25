let s:Guard    = vital#esearch#import('Vim.Guard')
let s:Message  = vital#esearch#import('Vim.Message')
let s:Prelude  = vital#esearch#import('Prelude')
let s:List     = vital#esearch#import('Data.List')
call esearch#polyfill#extend(s:)

let s:autoclose_events = join([
      \ 'CursorMoved',
      \ 'CursorMovedI',
      \ 'InsertEnter',
      \ 'QuitPre',
      \ 'ExitPre',
      \ 'BufEnter',
      \ 'BufWinEnter',
      \ 'WinLeave',
      \ ], ',')

let g:esearch#preview#buffers = {}
let g:esearch#preview#win = s:null
let g:esearch#preview#cache = esearch#cache#lru#new(20)
let g:esearch#preview#scratches = esearch#cache#lru#new(5)
let g:esearch#preview#emphasis = s:null

" TODO
" - separate strategies when it's clear how vim's floats are implemented

fu! esearch#preview#start(filename, line, ...) abort
  if !filereadable(a:filename)
    return s:false
  endif

  let opts = get(a:000, 0, {})
  let max_edit_size = get(opts, 'max_edit_size', 100 * 1024) " size in bytes
  let shape = s:Shape.new({
        \ 'width':     get(opts, 'width',  s:null),
        \ 'height':    get(opts, 'height', s:null),
        \ 'alignment': get(opts, 'align',  'cursor'),
        \ })
  let location = {
        \ 'filename': a:filename,
        \ 'line':     a:line,
        \ }
  " let strategy = get(opts, 'align',  'cursor')

  let win_vars = {'&winhighlight': 'Normal:NormalFloat', '&foldenable': s:false}
  call extend(win_vars, get(opts, 'let!', {})) " TOOO coverage

  if getfsize(a:filename) > max_edit_size
    return s:PreviewInScratchBuffer
          \.new(location, shape, win_vars).open()
  else
    return s:PreviewInRegularBuffer
          \.new(location, shape, win_vars).open()
  endif
endfu

fu! esearch#preview#is_open() abort
  " window id becomes invalid on bwipeout
  return g:esearch#preview#win isnot# s:null
        \ && esearch#win#exists(g:esearch#preview#win.id)
endfu

fu! esearch#preview#reset() abort
  " If #close() is used on every listed event, it can cause a bug where previewed
  " buffer loose it's content on open, so this method is defined to handle this
  if esearch#preview#is_open()
    let guard = g:esearch#preview#win.guard
    if !empty(guard) | call guard.restore() | endif
  endif
endfu

fu! esearch#preview#close() abort
  if esearch#preview#is_open()
    call esearch#preview#reset()
    call g:esearch#preview#win.close()
    let g:esearch#preview#win = s:null
  endif

  if g:esearch#preview#emphasis isnot# s:null
    call g:esearch#preview#emphasis.clear()
  endif
endfu

let s:PreviewInScratchBuffer = {}

fu! s:PreviewInScratchBuffer.new(location, shape, win_vars) abort dict
  let instance = copy(self)
  let instance.location = a:location
  let instance.shape    = a:shape
  let instance.win_vars = a:win_vars
  return instance
endfu

fu! s:PreviewInScratchBuffer.open() abort dict
  let lines_text = esearch#util#readfile(self.location.filename, g:esearch#preview#cache)
  let current_win = esearch#win#stay()
  let self.buffer = s:ScratchBuffer
        \.fetch_or_create(self.location, g:esearch#preview#scratches)
  try
    call esearch#preview#close()
    let g:esearch#preview#win = s:FloatingWindow.new(self.buffer, self.shape).open()
    call g:esearch#preview#win.let(self.win_vars)
    call g:esearch#preview#win.focus()
    call self.set_filetype()
    call self.set_context_lines(lines_text)
    let g:esearch#preview#emphasis =
          \ esearch#emphasize#sign(g:esearch#preview#win.id, self.location.line, '->')
          \.draw()
    call g:esearch#preview#win.reshape()
    call g:esearch#preview#win.init_autoclose_autocommands()
  catch
    call esearch#preview#close()
    echoerr v:exception
    return s:false
  finally
    noau keepj call current_win.restore()
  endtry

  return s:true
endfu

fu! s:PreviewInScratchBuffer.set_filetype() abort dict
  let filetype = esearch#ftdetect#complete(self.location.filename)
  if filetype isnot# s:null
    call nvim_buf_set_option(self.buffer.id, 'filetype', filetype)
  endif
endfu

" Setup context lines prepended by blank lines outside the viewport.
" syntax_sync_lines offset is added to make syntaxes highlight correct
fu! s:PreviewInScratchBuffer.set_context_lines(lines_text) abort dict
  let syntax_sync_lines = 100
  let line = self.location.line
  let height = self.shape.height
  let begin = max([line - height - syntax_sync_lines, 0])
  let end = min([line + height + syntax_sync_lines, len(a:lines_text)])

  let blank_lines = repeat([''], begin)
  let context_lines = a:lines_text[ begin : end]
  call nvim_buf_set_lines(self.buffer.id, 0, -1, 0,
        \ blank_lines + context_lines)

  " Prevents slowdowns on big syntax syncing ranges (according to the doc,
  " 'fromstart' option is equivalent to 'syncing starts ...', but with a large
  " number).
  if match(s:Message.capture('syn sync'), 'syncing starts \d\{3,}') >= 0
    syntax sync clear
    exe printf('syntax sync minlines=%d maxlines=%d',
          \ syntax_sync_lines,
          \ syntax_sync_lines + 1)
  endif
endfu

"""""""""""""""""""""""""""""""""""""""

let s:PreviewInRegularBuffer = {}

fu! s:PreviewInRegularBuffer.new(location, shape, win_vars) abort dict
  let instance = copy(self)
  let instance.location = a:location
  let instance.shape = a:shape
  let instance.win_vars = a:win_vars
  return instance
endfu

fu! s:PreviewInRegularBuffer.open() abort dict
  let current_win = esearch#win#stay()
  let self.buffer = s:Buffer.fetch_or_create(self.location, g:esearch#preview#buffers)

  try
    call esearch#preview#close()
    let g:esearch#preview#win = s:FloatingWindow.new(self.buffer, self.shape).open()
    call g:esearch#preview#win.let(self.win_vars)
    call g:esearch#preview#win.focus()
    call self.edit()
    let g:esearch#preview#emphasis =
          \ esearch#emphasize#sign(g:esearch#preview#win.id, self.location.line, '->')
          \.draw()
    call g:esearch#preview#win.reshape()
    call self.init_on_open_autocommands()
    call g:esearch#preview#win.init_autoclose_autocommands()
  catch
    call esearch#preview#close()
    echoerr v:exception
    return s:false
  finally
    noau keepj call current_win.restore()
  endtry

  return s:true
endfu

fu! s:PreviewInRegularBuffer.edit() abort dict
  if expand('%:p') !=# self.location.filename
    let original_options = esearch#util#silence_swap_prompt()
    try
      exe 'keepj noau edit ' . fnameescape(self.location.filename)
    finally
      call original_options.restore()
    endtry

    " if the buffer is already created, vim switches to it leaving an empty
    " buffer we have to cleanup
    let current_buffer_id = bufnr('%')
    if current_buffer_id != self.buffer.id && bufexists(self.buffer.id)
      exe self.buffer.id . 'bwipeout'
    endif
    let self.buffer.id = current_buffer_id
  endif

  keepj doau BufReadPre,BufRead
endfu

fu! s:PreviewInRegularBuffer.init_on_open_autocommands() abort
  augroup esearch#preview
    au!
    au BufWinEnter,BufEnter <buffer> ++once call s:make_preview_buffer_regular()
  augroup END
endfu

fu! s:make_preview_buffer_regular() abort
  let current_filename = expand('%:p')
  if !has_key(g:esearch#preview#buffers, current_filename)
    " execute once
    return
  endif

  call remove(g:esearch#preview#buffers, current_filename)
  call esearch#preview#reset()
  au! esearch#preview *
endfu

"""""""""""""""""""""""""""""""""""""""

let s:Buffer = {}

fu! s:Buffer.new(location) abort dict
  let instance = copy(self)
  let instance.filename = a:location.filename
  let instance.line = a:location.line

  if bufexists(instance.filename)
    let instance.id = bufnr('^'.instance.filename.'$')
  else
    let instance.id = nvim_create_buf(1, 0)
  endif

  return instance
endfu

fu! s:Buffer.fetch_or_create(location, cache) abort dict
  let filename = a:location.filename
  if has_key(a:cache, filename)
    let instance = a:cache[filename]
    if instance.is_valid()
      return instance
    endif
    call remove(a:cache, filename)
  endif

  let instance = self.new(a:location)
  let a:cache[filename] = instance

  return instance
endfu

fu! s:Buffer.is_valid() abort dict
  return nvim_buf_is_valid(self.id)
endfu

"""""""""""""""""""""""""""""""""""""""

let s:ScratchBuffer = {}

fu! s:ScratchBuffer.new(location) abort dict
  let instance          = copy(self)
  let instance.line     = a:location.line
  let instance.filename = a:location.filename
  let instance.kind     = 'scratch'
  let instance.id       = nvim_create_buf(0, 1)
  return instance
endfu

fu! s:ScratchBuffer.fetch_or_create(location, cache) abort
  let filename = a:location.filename

  if a:cache.has(filename)
    let instance = a:cache.get(filename)
    if instance.is_valid()
      return instance
    endif

    call a:cache.remove(filename)
  endif

  let instance = self.new(a:location)
  call a:cache.set(filename, instance)

  return instance
endfu

fu! s:ScratchBuffer.remove() abort dict
  if !bufexists(self.id) | return | endif
  silent exe self.id 'bwipeout'
endfu

fu! s:ScratchBuffer.is_valid() abort dict
  return nvim_buf_is_valid(self.id)
endfu

"""""""""""""""""""""""""""""""""""""""

let s:FloatingWindow = {'guard': s:null, 'id': -1}

fu! s:FloatingWindow.new(buffer, shape) abort dict
  let instance        = copy(self)
  let instance.buffer = a:buffer
  let instance.shape  = a:shape
  return instance
endfu

fu! s:FloatingWindow.let(variables) abort dict
  let self.guard = esearch#win#let_restorable(self.id, a:variables)
endfu

fu! s:FloatingWindow.open() abort dict
  try
    let original_options = esearch#util#silence_swap_prompt()
    let self.id = nvim_open_win(self.buffer.id, 0, {
          \ 'width':     self.shape.width,
          \ 'height':    self.shape.height,
          \ 'focusable': s:false,
          \ 'anchor':    self.shape.anchor,
          \ 'row':       self.shape.row,
          \ 'col':       self.shape.col,
          \ 'relative':  self.shape.relative,
          \})
  finally
    call original_options.restore()
  endtry

  return self
endfu

fu! s:FloatingWindow.close() abort dict
  call nvim_win_close(self.id, 1)
endfu

" Shape on create is only to prevent blinks. Actual shape setting is set there
" NOTE: Builtin winrestview() has a lot of side effects so reshape()
" should be invoken as later as possible
fu! s:FloatingWindow.reshape() abort dict
  " Prevent showing more lines than the buffer has
  call self.shape.clip_height(nvim_buf_line_count(self.buffer.id))

  let height = self.shape.height
  let line = self.buffer.line

  " Allow the window be smallar than winminheight
  try
    let winminheight = esearch#let#restorable({'&winminheight': 1})
    call nvim_win_set_config(g:esearch#preview#win.id, {
          \ 'height':    height,
          \ 'anchor':    self.shape.anchor,
          \ 'row':       self.shape.row,
          \ 'col':       self.shape.col,
          \ 'relative':  self.shape.relative,
          \ })

    " literally what :help 'scrolloff' option does, but without dealing with
    " options
    if line('$') < height
      let topline = 1
    elseif line('$') - line < height
      let topline = line('$') - height
    else
      let topline = line - (height / 2)
    endif
    noau keepj call winrestview({
          \ 'lnum':    line,
          \ 'col':     1,
          \ 'topline': topline,
          \ })
  finally
    call winminheight.restore()
  endtry
endfu

fu! s:FloatingWindow.init_autoclose_autocommands() abort dict
  augroup esearch#preview#autoclose
    au!
    exe 'au ' . s:autoclose_events . ' * ++once call esearch#preview#close()'
    exe 'au ' . s:autoclose_events . ',BufWinLeave,BufLeave * ++once call esearch#preview#reset()'
  augroup END
endfu

fu! s:FloatingWindow.focus() abort dict
  noau keepj call esearch#win#focus(self.id)
endfu

"""""""""""""""""""""""""""""""""""""""

let s:Shape = {'relative': 'win'}

fu! s:Shape.new(definitions) abort dict
  let instance = copy(self)
  let instance.winline = winline()
  let instance.wincol  = wincol()
  let instance.alignment = a:definitions.alignment

  if &showtabline ==# 2 || &showtabline == 1 && tabpagenr('$') > 1
    let tabline_room = 1
  else
    let tabline_room = 0
  endif

  if &laststatus ==# 2 || &laststatus == 1 && winnr('$') > 1
    let statusline_room = 0
  else
    let statusline_room = 1
  endif

  let instance.top = tabline_room
  let instance.bottom = winheight(0) + tabline_room + statusline_room

  if instance.alignment ==# 'cursor'
    call extend(instance, {'width': 120, 'height': 15})
  elseif s:List.has(['top', 'bottom'], instance.alignment)
    call extend(instance, {'width': winwidth(0), 'height': 15})
  elseif s:List.has(['left', 'right'], instance.alignment)
    call extend(instance, {'width': winwidth(0) / 2, 'height': winheight(0) - 0})
  else
    throw 'Unknown preview align'
  endif

  let width = a:definitions.width
  if s:Prelude.is_numeric(width) && width > 0
    let instance.width = s:measure(width, winwidth(0))
  endif

  let height = a:definitions.height
  if s:Prelude.is_numeric(height) && height > 0
    let instance.height = s:measure(height, winheight(0))
  endif

  call instance.align()

  return instance
endfu

fu! s:measure(value, interval) abort
  if type(a:value) ==# type(1.0)
    return float2nr(a:value * a:interval)
  elseif type(a:value) ==# type(1) && a:value > 0
    return a:value
  else
    throw 'Wrong type of value ' . a:value
  endif
endfu

fu! s:Shape.align() abort dict
  if self.alignment ==# 'cursor'
    call self.align_to_cursor()
  elseif self.alignment ==# 'top'
    return self.align_to_top()
  elseif self.alignment ==# 'bottom'
    return self.align_to_bottom()
  elseif self.alignment ==# 'left'
    return self.align_to_left()
  elseif self.alignment ==# 'right'
    return self.align_to_right()
  else
    throw 'Unknown preview align'
  endif
endfu

fu! s:Shape.align_to_top() abort dict
  let self.col    = 0
  let self.row    = self.top
  let self.anchor = 'NE'
endfu

fu! s:Shape.align_to_right() abort dict
  let self.col    = winwidth(0) + 1
  let self.row    = self.top
  let self.anchor = 'NE'
endfu

fu! s:Shape.align_to_left() abort dict
  let self.col    = 0
  let self.row    = self.top
  let self.anchor = 'NE'
endfu

fu! s:Shape.align_to_bottom() abort dict
  let self.row    = self.bottom
  let self.col    = 0
  let self.anchor = 'SE'
endfu

fu! s:Shape.align_to_cursor() abort dict
  if &lines - self.height - 1 < self.winline
    " if there's no room - show above
    let self.row = self.winline - self.height
  else
    let self.row = self.winline + 1
  endif
  let self.col = max([5, self.wincol - 1])

  let self.anchor = 'NW'
endfu

fu! s:Shape.clip_height(max_height) abort dict
  if s:List.has(['left', 'right'], self.alignment) | return | endif

  let self.height = min([
        \ a:max_height,
        \ self.height,
        \ &lines - 1])

  call self.align()
endfu
