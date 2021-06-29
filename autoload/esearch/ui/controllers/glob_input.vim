let s:INF = 88888888
let s:Log = esearch#log#import()
let s:GlobInputController = esearch#ui#component()
let s:CurrentGlob = esearch#ui#prompt#current_glob#import()

cnoremap <plug>(esearch-push-glob)  <c-r>=<SID>interrupt('<SID>dispatch', 'PUSH_GLOB')<cr><cr>
cnoremap <expr> <plug>(esearch-glob-bs)  <SID>try_pop_glob("\<bs>")
cnoremap <expr> <plug>(esearch-glob-c-w) <SID>try_pop_glob("\<c-w>")
cnoremap <expr> <plug>(esearch-glob-c-h) <SID>try_pop_glob("\<c-h>")

let s:keymaps = [
      \ ['c', '<c-p>',      '<plug>(esearch-push-glob)'      ],
      \ ['c', '<bs>',       '<plug>(esearch-glob-bs)',  {'nowait': 1}],
      \ ['c', '<c-w>',      '<plug>(esearch-glob-c-w)', {'nowait': 1}],
      \ ['c', '<c-h>',      '<plug>(esearch-glob-c-h)', {'nowait': 1}],
      \]

" TODO create reusable input
fu! s:GlobInputController.render() abort dict
  let s:self = self
  let self.cmdline = self.props.globs.peek().str
  let self.pending_keypress = 0

  let ellipsis = g:esearch#has#unicode ? g:esearch#unicode#ellipsis : '...'

  redraw!
  let original_mappings = esearch#keymap#restorable(s:keymaps)
  try
    call self.init_preview()

    let prompt = esearch#ui#to_string([['NONE', self.props.adapter.' '.ellipsis.' ']] + s:CurrentGlob.new().render())
    let glob = input(prompt,
          \ self.props.globs.peek().str,
          \ 'customlist,esearch#ui#controllers#glob_input#complete')
  catch /Vim:Interrupt/
    silent! call esearch#preview#wipeout()
    return self.props.dispatch({'type': 'SET_LOCATION', 'location': 'menu'})
  finally
    call original_mappings.restore()
    call self.uninit_preview()
  endtry
  if empty(glob)
    call self.props.dispatch({'type': 'TRY_POP_GLOB'})
  else
    call self.props.dispatch({'type': 'SET_GLOB', 'glob': glob})
  endif
  if !self.props.live_update
    call self.props.dispatch({'type': 'FORCE_EXEC'}) " exec before leaving the input
  endif

  if !empty(self.pending_keypress)
    return call(self.pending_keypress.handler, self.pending_keypress.args)
  endif
  silent! call esearch#preview#wipeout()
  call self.props.dispatch({'type': 'SET_LOCATION', 'location': 'menu'})
endfu

fu! s:GlobInputController.init_preview() dict abort
  if !g:esearch#has#globs_preview || !self.props.live_update | return | endif

  if self.props.win_update_throttle_wait > 0
    let timeout = self.props.win_update_throttle_wait
  else
    let timeout = self.props.live_update_debounce_wait
  endif
  let self.redraw_timer = timer_start(timeout, function('s:redraw'), {'repeat': -1})
  aug __esearch_globs_preview__
    au!
    au CmdlineChanged * call s:globs_preview.apply()
  aug END
  let s:globs_preview = esearch#async#debounce(function('s:globs_preview'),
        \ self.props.live_update_debounce_wait)
endfu

fu! s:GlobInputController.uninit_preview() dict abort
  if !g:esearch#has#globs_preview || !self.props.live_update | return | endif
  au! __esearch_globs_preview__ *
  silent! call timer_stop(self.redraw_timer)
  call s:globs_preview.cancel()
endfu

fu! s:globs_preview(...) abort
  " if !empty(s:self.props._adapter.globs)
    call s:self.props.dispatch({'type': 'PREVIEW_GLOB', 'glob': getcmdline()})
  " endif
  call s:self.props.dispatch({'type': 'FORCE_EXEC', 'glob': getcmdline()})
endfu

fu! esearch#ui#controllers#glob_input#complete(arglead, cmdline, curpos) abort
  return esearch#ui#complete#paths#do(s:self.props.cwd, a:arglead, a:cmdline, a:curpos)
endfu

fu! s:try_pop_glob(fallback) abort
  if empty(getcmdline()) && len(s:self.props.globs.list) > 1
    let s:self.pending_keypress = {'handler': function('<SID>dispatch_try_pop_glob'), 'args': a:000}
    call s:self.props.dispatch({'type': 'SET_CMDPOS', 'cmdpos': s:INF})
    return "\<cr>"
  endif

  return a:fallback
endfu

fu! s:dispatch_try_pop_glob(...) abort
  call s:self.props.dispatch({'type': 'TRY_POP_GLOB'})
endfu

fu! s:interrupt(func, ...) abort
  let s:self.pending_keypress = {'handler': function(a:func), 'args': a:000}
  call s:self.props.dispatch({'type': 'SET_CMDPOS', 'cmdpos': getcmdpos()})
  return ''
endfu

fu! s:dispatch(event_type) abort dict
  call s:self.props.dispatch({'type': 'SET_CMDLINE', 'cmdline': s:self.cmdline})
  call s:self.props.dispatch({'type': a:event_type})
endfu

fu! s:redraw(_) abort
  redraw
endfu

let s:map_state_to_props = esearch#util#slice_factory(['cwd', 'globs', 'adapter', '_adapter', 'win_update_throttle_wait', 'live_update_debounce_wait', 'live_update'])

fu! esearch#ui#controllers#glob_input#import() abort
  return esearch#ui#connect(s:GlobInputController, s:map_state_to_props)
endfu
