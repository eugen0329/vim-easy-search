let s:Log = esearch#log#import()
let [s:true, s:false, s:null, s:t_dict, s:t_float, s:t_func,
     \ s:t_list, s:t_number, s:t_string] = esearch#polyfill#definitions()
let s:relative = 'win'

fu! esearch#preview#nvim#popup#import() abort
  return s:NvimPopup
endfu

let s:NvimPopup = esearch#preview#popup_base#import()

fu! s:NvimPopup.view() abort dict
  let eventignore = esearch#let#restorable({'&eventignore': g:esearch#preview#silent_open_eventignore})
  try
    exe 'keepj view ' . fnameescape(self.buf.filename)
    let self.buf.viewed = 1
  finally
    call eventignore.restore()
  endtry
endfu

fu! s:NvimPopup.edit() abort dict
  if exists('#esearch_preview_autoclose')
    au! __esearch_preview_autoclose__
  endif

  " NOTE The conditions below are needed to reuse already existing buffers where
  " possible. It's important as existing and displayed buffers may contain
  " information valuable for navigation like signs, highlights etc. as well as
  " actual changes made by user in case the buf is displayed and modified.
  "
  " Fallbacks are required as it's impossible to handle the swap prompt using
  " regular buf and autocommand hooks to toggle it. The swap prompt should be
  " suppressed on displaying and appeared on entering.

  " If the buf has a filename equal to the previewed filename
  if expand('%:p') ==# simplify(self.buf.filename)
    let win_ids = win_findbuf(self.buf.id)
    let is_hidden = empty(win_ids) || win_ids ==# [g:esearch#preview#win.id]

    if !is_hidden " if there're opened windows with this buf attached
      return s:true " Reuse the buf
    elseif filereadable(self.buf.swapname) " OR if there's existing swap
      return s:false " Use the fallback
    endif
  endif
  " Otherwise - use :edit to verify that there's no swapfiles appeared and
  " also preload the highlights and other stuff

  let s:swapname = ''
  let eventignore = esearch#let#restorable({'&eventignore': g:esearch#preview#silent_open_eventignore})
  aug __esearch_preview_swap_probe__
    au!
    au SwapExists * ++once let s:swapname = v:swapname | let v:swapchoice = 'q'
  aug END
  try
    exe 'keepj edit ' . fnameescape(self.buf.filename)
  finally
    call eventignore.restore()
    au! __esearch_preview_swap_probe__
  endtry
  let self.buf.swapname = s:swapname

  if !empty(s:swapname)
    return s:false
  endif

  " if the buf is already created, vim switches to it leaving an empty
  " buf we have to cleanup
  let current_buffer_id = bufnr('%')
  if current_buffer_id != self.buf.id && empty(bufname(self.buf.id))
    exe self.buf.id . 'bwipeout'
  endif
  let self.buf.id = current_buffer_id

  aug esearch_prevew_make_regular
    au!
    au BufWinEnter,BufEnter <buf> ++once call esearch#preview#reset()
  aug END

  return s:true
endfu

fu! s:NvimPopup.enter() abort dict
  noau keepj call win_gotoid(self.id)
endfu

fu! s:NvimPopup.open() abort
  try
    let original_options = esearch#util#silence_swap_prompt()
    let self.id = nvim_open_win(self.buf.id, 0, {
          \ 'width':     self.shape.width,
          \ 'height':    self.shape.height,
          \ 'focusable': s:false,
          \ 'anchor':    self.shape.anchor,
          \ 'row':       self.shape.row,
          \ 'col':       self.shape.col,
          \ 'relative':  s:relative,
          \})
  finally
    call original_options.restore()
  endtry

  return self
endfu

fu! s:NvimPopup.close() abort dict
  call self.unplace_emphasis()
  call nvim_win_close(self.id, 1)
endfu

fu! s:NvimPopup.reshape() abort dict
  if !self.buf.is_valid()
    call s:Log.error('Preview buf was deleted')
    return esearch#preview#close()
  endif

  if win_getid() !=# self.id
    let current_win = esearch#win#stay()
    call self.enter()
  endif

  " Prevent showing more lines than the buf has
  call self.shape.clip_height(nvim_buf_line_count(self.buf.id))
  let height = self.shape.height
  let line   = self.location.line

  " allow the window be smaller than winheight
  let winminheight = esearch#let#restorable({'&winminheight': 1})

  try
    call nvim_win_set_config(self.id, {
          \ 'width':     self.shape.width,
          \ 'height':    self.shape.height,
          \ 'anchor':    self.shape.anchor,
          \ 'relative':  s:relative,
          \ 'row':       self.shape.row,
          \ 'col':       self.shape.col,
          \ })

    " Prevent showing EndOfBuffer
    if line('$') < height
      noau keepj call winrestview({'topline': 1, 'lnum': line})
    elseif line('$') - line < height / 2
      " EMphasized line will be shown below the center as EndOfBuffer is near.
      let topline = line('$') - height + 1
      noau keepj call winrestview({'topline': topline, 'lnum': line})
    else
      " The only way to perfectly center is to use zz as we cannot calculate the
      " correct topline position due to wraps that occupy more than one screen
      " line
      noau keepj call winrestview({'lnum': line})
      norm! zz
    endif
  finally
    call winminheight.restore()
    if exists('current_win') | noau keepj call current_win.restore() | endif
  endtry
endfu

fu! s:NvimPopup.init_entered_autoclose_events() abort dict
  aug __esearch_preview_autoclose__
    " Before leaving a window
    au WinLeave * ++once call g:esearch#preview#last.win.guard.new(g:esearch#preview#last.buf.id, win_getid()).restore() | call esearch#preview#close()
    " After entering another window
    au WinEnter * ++once au! __esearch_preview_autoclose__
    " From :h local-options
    " When splitting a window, the local options are copied to the new window. Thus
    " right after the split the contents of the two windows look the same.
    au WinNew * ++once call g:esearch#preview#last.win.guard.new(g:esearch#preview#last.buf.id, win_getid()).restore() | au! __esearch_preview_autoclose__

    " NOTE dc09e176. Prevents options inheritance when trying to delete the
    " buf. Grep note id to locate the test case.
    au BufDelete * ++once call esearch#preview#close()

    au CmdwinEnter * call g:esearch#preview#last.win.guard.new(g:esearch#preview#last.buf.id, win_getid()).restore()
  aug END
endfu

" Helps to prevent blinks
fu! s:NvimPopup.update(buf, location, shape, close_on) abort dict
  let self.buf      = a:buf
  let self.location = a:location
  let self.shape    = a:shape
  let self.close_on = a:close_on
  call self.guard.restore()
  call nvim_win_set_buf(self.id, a:buf.id)
  " Emphasis must be removed as it doesn't correspond to a:location anymore
  call self.unplace_emphasis()

  return self
endfu

fu! s:NvimPopup.is_entered() abort dict
  return win_getid() ==# self.id
endfu

fu! s:NvimPopup.open() abort dict
  try
    let original_options = esearch#util#silence_swap_prompt()
    let self.id = nvim_open_win(self.buf.id, 0, {
          \ 'width':     self.shape.width,
          \ 'height':    self.shape.height,
          \ 'focusable': s:false,
          \ 'anchor':    self.shape.anchor,
          \ 'row':       self.shape.row,
          \ 'col':       self.shape.col,
          \ 'relative':  s:relative,
          \})
  finally
    call original_options.restore()
  endtry

  return self
endfu
