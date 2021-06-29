let s:Log = esearch#log#import()
let s:Buf = esearch#preview#buf#import()
let [s:true, s:false, s:null, s:t_dict, s:t_float, s:t_func,
     \ s:t_list, s:t_number, s:t_string] = esearch#polyfill#definitions()

fu! esearch#preview#nvim#opener#import() abort
  return copy(s:NvimOpener)
endfu

let s:NvimOpener = esearch#preview#opener_base#import()
let s:NvimOpener.popup = esearch#preview#nvim#popup#import()

fu! s:NvimOpener.open() abort dict
  let current_win = esearch#win#stay()
  let self.buf = s:Buf.fetch_or_create(
        \ self.location.filename, g:esearch#preview#buffers)

  try
    let g:esearch#preview#win = s:NvimOpener.open_or_update(
          \ self.buf, self.location, self.shape, self.close_on)
    let self.win = g:esearch#preview#win

    call self.win.enter()
    if !self.win.edit()
      call self.win.view()
    endif
    " it's better to let variables after editing the buf to prevent
    " inheriting some options by buffers (for example, &winhl local to window
    " becoms local to buf).
    call self.win.let(self.vars)
    call self.win.place_emphasis(self.emphasis)
    call self.win.reshape()
    call self.win.init_autoclose_events()
  catch
    call s:Log.error(v:exception . (g:esearch#env is 0 ? '' : v:throwpoint))
    call esearch#preview#close()
    return s:false
  finally
    noau keepj call current_win.restore()
  endtry

  return s:true
endfu

fu! s:NvimOpener.shell() abort dict
  let current_win = esearch#win#stay()
  let self.buf = s:Buf.fetch_or_create(
        \ self.location.filename, g:esearch#preview#buffers)

  try
    let g:esearch#preview#win = s:NvimOpener.open_or_update(
          \ self.buf, self.location, self.shape, self.close_on)
    let self.win = g:esearch#preview#win
    let self.win.upd_at = reltime()
    let self.win.cache_key = [self.opts, self.shape.align]
    call self.win.let(self.vars)
    call self.win.place_emphasis(self.emphasis)
    call self.win.reshape()
    call self.win.init_autoclose_events()
  catch
    call esearch#preview#close()
    call s:Log.error(v:exception . (g:esearch#env is 0 ? '' : v:throwpoint))
    return s:false
  finally
    noau keepj call current_win.restore()
  endtry

  return s:true
endfu

" Maintain the window as a singleton.
fu! s:NvimOpener.open_or_update(buf, location, shape, close_on) abort dict
  if esearch#preview#is_open()
    return g:esearch#preview#win
          \.update(a:buf, a:location, a:shape, a:close_on)
  else
    call esearch#preview#close()
    return self.popup
          \.new(a:buf, a:location, a:shape, a:close_on)
          \.open()
  endif
endfu

fu! s:NvimOpener.open_and_enter() abort dict
  let current_win = esearch#win#stay()
  let reuse_existing = 0
  let self.buf = s:Buf.new(self.location.filename, reuse_existing)

  try
    if esearch#preview#is_open()
          \ && g:esearch#preview#win.location.filename ==# self.location.filename
          \ && empty(g:esearch#preview#win.buf.swapname)
      call esearch#preview#reset()
      silent! au! __esearch_preview_autoclose__
      let g:esearch#preview#win.shape = self.shape
      let g:esearch#preview#win.close_on = self.close_on
      let was_opened = 1
    else
      call esearch#preview#close()
      let g:esearch#preview#win = self.popup
            \.new(self.buf, self.location, self.shape, self.close_on)
            \.open()
      let was_opened = 0
    endif
    let self.win = g:esearch#preview#win
    call self.win.enter()
    if !was_opened && !self.buf.edit_allowing_swap_prompt()
      call esearch#preview#close()
      return s:false
    endif

    " it's better to let variables after editing the buf to prevent
    " inheriting some options by buffers (for example, &winhl local to window
    " becoms local to buf).
    call self.win.let(self.vars)
    call self.win.place_emphasis(self.emphasis)
    call self.win.reshape()
    call self.win.init_entered_autoclose_events()
  catch
    call esearch#preview#close()
    call s:Log.error(v:exception)
    return s:false
  endtry

  return s:true
endfu
