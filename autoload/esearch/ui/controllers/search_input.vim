let s:SelectionController = esearch#ui#controllers#selection#import()
let s:SearchPrompt = esearch#ui#prompt#search#import()
let s:ConfigurationsPrompt = esearch#ui#prompt#configurations#import()
let s:INF = 88888888

cnoremap <plug>(esearch-cycle-regex)   <c-r>=<SID>interrupt('<SID>dispatch', 'NEXT_REGEX')<cr><cr>
cnoremap <plug>(esearch-cycle-case)    <c-r>=<SID>interrupt('<SID>dispatch', 'NEXT_CASE')<cr><cr>
cnoremap <plug>(esearch-cycle-textobj) <c-r>=<SID>interrupt('<SID>dispatch', 'NEXT_TEXTOBJ')<cr><cr>
cnoremap <plug>(esearch-open-menu)     <c-r>=<SID>interrupt('<SID>open_menu')<cr><cr>

cnoremap <plug>(esearch-push-pattern) <c-r>=<SID>interrupt('<SID>dispatch', 'PUSH_PATTERN')<cr><cr>
cnoremap <expr> <plug>(esearch-bs)    <SID>try_pop_pattern("\<bs>")
cnoremap <expr> <plug>(esearch-c-w)   <SID>try_pop_pattern("\<c-w>")
cnoremap <expr> <plug>(esearch-c-h)   <SID>try_pop_pattern("\<c-h>")

let s:keymaps = [
      \ ['c', '<c-o>',      '<plug>(esearch-open-menu)'         ],
      \ ['c', '<c-r><c-r>', '<plug>(esearch-cycle-regex)'       ],
      \ ['c', '<c-s><c-s>', '<plug>(esearch-cycle-case)'        ],
      \ ['c', '<c-t><c-t>', '<plug>(esearch-cycle-textobj)'     ],
      \ ['c', '<c-p>',      '<plug>(esearch-push-pattern)'      ],
      \ ['c', '<bs>',       '<plug>(esearch-bs)',  {'nowait': 1}],
      \ ['c', '<c-w>',      '<plug>(esearch-c-w)', {'nowait': 1}],
      \ ['c', '<c-h>',      '<plug>(esearch-c-h)', {'nowait': 1}],
      \]

let s:self = {}
let s:SearchInputController = esearch#ui#component()

fu! s:SearchInputController.render() abort dict
  let s:self = self
  let original_mappings = esearch#keymap#restorable(s:keymaps)
  let [global_options, local_options] = self.set_options()
  try
    if self.props.live_update | call self.init_live_update() | endif
    return self.render_initial_selection() && self.render_input()
  catch /Vim:Interrupt/
    call self.props.dispatch({'type': 'SET_CMDLINE', 'cmdline': ''})
    call self.props.dispatch({'type': 'SET_LOCATION', 'location': 'exit'})
  finally
    if self.props.live_update | call self.uninit_live_update() | endif
    call local_options.restore()
    call global_options.restore()
    call original_mappings.restore()
  endtry
endfu

fu! s:SearchInputController.set_options() dict abort
  let global_options = {'&laststatus': 2} " show statusline no matter the windows count
  let local_options = {}

  let prompt = s:ConfigurationsPrompt.new().render()
  if !empty(prompt)
    let self.statusline = esearch#ui#to_statusline(prompt)
    " Set both to prevent inheritance when only global &stl is configured by the user
    let global_options['&g:statusline'] = ''
    let local_options['&statusline'] = self.statusline
  endif

  let global_restorable = esearch#let#restorable(global_options)
  let local_restorable = esearch#let#bufwin_restorable(bufnr(''), win_getid(), local_options)
  if !empty(prompt) | redrawstatus! | endif

  return [global_restorable, local_restorable]
endfu

fu! s:SearchInputController.init_live_update() dict abort
  let self.executed_cmdline = ''

  aug __esearch_live_update__
    au!
    au CmdlineChanged * call s:live_update.apply()
    " Overrule statusline plugins when live_update buffer is opened
    au BufEnter * if has_key(s:self, 'statusline') | let &statusline = s:self.statusline | endif
  aug END
  let s:live_update = esearch#async#debounce(function('s:live_update'),
        \ self.props.live_update_debounce_wait)

  call s:live_update.apply(self.props.pattern.peek().str)

  if self.props.win_update_throttle_wait > 0
    let timeout = self.props.win_update_throttle_wait
  else
    let timeout = self.props.live_update_debounce_wait
  endif
  let self.redraw_timer = timer_start(timeout, function('s:redraw'), {'repeat': -1})
endfu

fu! s:SearchInputController.final_live_update() dict abort
  " if changes were made and live_update_debounce_wait wasn't exceeded
  let cmdline = self.cmdline
  if s:self.executed_cmdline ==# cmdline || empty(cmdline) | return | endif
  call s:self.props.dispatch({'type': 'FORCE_EXEC', 'cmdline': cmdline})
endfu

fu! s:live_update(...) abort
  let cmdline = a:0 ? a:1 : getcmdline()
  if s:self.executed_cmdline ==# cmdline || empty(cmdline) || len(cmdline) < s:self.props.live_update_min_len
    return
  endif
  let s:self.executed_cmdline = cmdline
  call s:self.props.dispatch({'type': 'FORCE_EXEC', 'cmdline': cmdline})
endfu

fu! s:redraw(_) abort
  redraw
endfu

fu! s:SearchInputController.uninit_live_update() dict abort
  silent! au! __esearch_live_update__ *
  silent! call timer_stop(self.redraw_timer)
  call s:live_update.cancel()
endfu

fu! s:SearchInputController.render_initial_selection() abort dict
  if self.props.did_select_prefilled
    let self.cmdline = self.props.pattern.peek().str
  elseif !self.props.select_prefilled
    let self.cmdline = self.props.pattern.peek().str
    call self.props.dispatch({'type': 'SET_DID_SELECT_PREFILLED'})
  else
    if empty(self.props.pattern.peek().str)
      let self.cmdline = ''
    else
      " required if switched to esearch#init from another input()
      call esearch#ui#soft_clear()
      let [self.cmdline, finish, retype] = s:SelectionController.new().render()
      if finish
        if self.props.live_update | call self.final_live_update() | endif
        call self.props.dispatch({'type': 'SET_CMDLINE', 'cmdline': self.cmdline})
        call self.props.dispatch({'type': 'SET_LOCATION', 'location': 'exit'})
        return 0
      elseif !empty(retype)
        call feedkeys(retype)
      endif
    endif

    call self.props.dispatch({'type': 'SET_DID_SELECT_PREFILLED'})
  endif

  return 1
endfu

" redraw before is required here to clear possible output leftovers from multiline calls
fu! s:SearchInputController.render_input() abort
  call esearch#ui#soft_clear()

  let self.cmdline .= self.restore_cmdpos_chars()
  let self.pressed_mapped_key = 0
  let self.cmdline = self.input()

  if !empty(self.pressed_mapped_key)
    return call(self.pressed_mapped_key.handler, self.pressed_mapped_key.args)
  endif

  if self.props.live_update | call self.final_live_update() | endif
  call self.props.dispatch({'type': 'SET_CMDLINE', 'cmdline': self.cmdline})
  call self.props.dispatch({'type': 'SET_LOCATION', 'location': 'exit'})
endfu

fu! s:SearchInputController.input() abort dict
  " NOTE that it's impossible to properly retype keys (see SelectionController
  " for details) when inputsave() and inputrestore() are used.
  return input(esearch#ui#to_string(s:SearchPrompt.new()),
        \ substitute(self.cmdline, '\n', '\\n', 'g'), 'customlist,esearch#ui#complete#search#do')
endfu

fu! s:SearchInputController.restore_cmdpos_chars() abort
  if self.props.cmdpos == s:INF | return "\<End>" | endif
  return repeat("\<left>", strchars(self.cmdline) + 1 - self.props.cmdpos)
endfu

fu! s:try_pop_pattern(fallback) abort
  if empty(getcmdline()) && len(s:self.props.pattern.list) > 1
    let s:self.pressed_mapped_key = {'handler': function('<SID>dispatch_try_pop_pattern'), 'args': a:000}
    call s:self.props.dispatch({'type': 'SET_CMDPOS', 'cmdpos': s:INF})
    return "\<cr>"
  endif

  return a:fallback
endfu

fu! s:dispatch_try_pop_pattern(...) abort
  call s:self.props.dispatch({'type': 'TRY_POP_PATTERN'})
endfu

fu! s:interrupt(func, ...) abort
  let s:self.pressed_mapped_key = {'handler': function(a:func), 'args': a:000}
  call s:self.props.dispatch({'type': 'SET_CMDPOS', 'cmdpos': getcmdpos()})
  return ''
endfu

fu! s:open_menu(...) abort dict
  call s:self.props.dispatch({'type': 'SET_CMDLINE', 'cmdline': s:self.cmdline})
  call s:self.props.dispatch({'type': 'SET_LOCATION', 'location': 'menu'})
endfu

fu! s:dispatch(event_type) abort dict
  call s:self.props.dispatch({'type': 'SET_CMDLINE', 'cmdline': s:self.cmdline})
  call s:self.props.dispatch({'type': a:event_type})
endfu

let s:map_state_to_props = esearch#util#slice_factory(['pattern', 'cmdpos',
      \ 'did_select_prefilled', 'select_prefilled', 'win_update_throttle_wait',
      \ 'live_update_debounce_wait', 'live_update', 'live_update_min_len'])

fu! esearch#ui#controllers#search_input#import() abort
  return esearch#ui#connect(s:SearchInputController, s:map_state_to_props)
endfu
