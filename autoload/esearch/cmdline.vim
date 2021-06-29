let s:Context = esearch#ui#context()
let s:App  = esearch#ui#app#import()

if !exists('g:esearch#cmdline#dir_icon')
  if g:esearch#has#unicode
    let g:esearch#cmdline#dir_icon = g:esearch#unicode#dir_icon
  else
    let g:esearch#cmdline#dir_icon = 'D '
  endif
endif

if !exists('g:esearch#cmdline#clear_selection_chars')
  let g:esearch#cmdline#clear_selection_chars = []
endif
let g:esearch#cmdline#clear_selection_chars += [
      \ "\<del>",
      \ "\<bs>",
      \ "\<c-w>",
      \ "\<c-h>",
      \ "\<c-u>",
      \]
if g:esearch#has#meta_key
  let g:esearch#cmdline#clear_selection_chars += [
        \ "\<m-d>",
        \ "\<m-bs>",
        \ "\<m-c-h>",
        \]
endif
if !exists('g:esearch#cmdline#start_search_chars')
  let g:esearch#cmdline#start_search_chars = [
        \ "\<enter>",
        \]
endif
if !exists('g:esearch#cmdline#cancel_selection_and_retype_chars')
  let g:esearch#cmdline#cancel_selection_and_retype_chars = [
        \ "\<left>",
        \ "\<right>",
        \ "\<up>",
        \ "\<down>",
        \]
endif
if !exists('g:esearch#cmdline#cancel_selection_chars')
  let g:esearch#cmdline#cancel_selection_chars = [
        \ "\<esc>",
        \ "\<c-c>",
        \]
endif
if !exists('g:esearch#cmdline#insert_register_content_chars')
  let g:esearch#cmdline#insert_register_content_chars = [
        \ "\<c-r>",
        \]
endif

fu! esearch#cmdline#read(esearch) abort
  return s:app(a:esearch)
endfu

fu! esearch#cmdline#map(lhs, rhs) abort
  " TODO deprecate
endfu

fu! s:app(esearch) abort
  let initial_state = s:initial_state(a:esearch)
  let store = esearch#ui#create_store(function('<SID>reducer'), initial_state)
  let context = s:Context.new().provide({'store': store})
  let app = s:App.new(store)

  try
    while app.render()
    endwhile
  catch /Vim:Interrupt/
    " noop
  finally
    call app.component_will_unmount()
    call context.restore()
  endtry

  return store.state
endfu

fu! s:initial_state(esearch) abort
  let initial_state = a:esearch
  let initial_state.location = 'search_input'
  let initial_state.did_select_prefilled = 0
  let initial_state.cursor = 0
  let initial_state.cmdpos = strchars(initial_state.pattern.peek().str) + 1
  return initial_state
endfu

fu! s:reducer(state, action) abort
  if a:action.type ==# 'FORCE_EXEC'
    let state = copy(a:state)
    if has_key(a:action, 'cmdline')
      let state.pattern = deepcopy(state.pattern)
      call state.pattern.replace(a:action.cmdline)
    endif
    if empty(state.pattern.peek().str) | return a:state | endif

    if has_key(a:action, 'glob')
      let state.globs = deepcopy(state.globs)
      call state.globs.replace(copy(a:action.glob))
    endif
    let esearch = esearch#init(extend(state, {'remember': [], 'force_exec': 1, 'name': '[esearch]' }))
    if empty(esearch) | return a:state | endif

    return extend(copy(a:state), {'live_update_bufnr': esearch.bufnr})
  elseif a:action.type ==# 'NEXT_CASE'
    return extend(copy(a:state), {'case': s:cycle_mode(a:state, 'case')})
  elseif a:action.type ==# 'NEXT_REGEX'
    return extend(copy(a:state), {'regex': s:cycle_mode(a:state, 'regex')})
  elseif a:action.type ==# 'NEXT_TEXTOBJ'
    return extend(copy(a:state), {'textobj': s:cycle_mode(a:state, 'textobj')})
  elseif a:action.type ==# 'PUSH_PATTERN'
    return extend(copy(a:state), {'pattern': s:push_pattern(a:state)})
  elseif a:action.type ==# 'TRY_POP_PATTERN'
    return extend(copy(a:state), {'pattern': s:try_pop_pattern(a:state)})
  elseif a:action.type ==# 'SET_GLOB'
    return extend(copy(a:state), {'globs': s:set_glob(a:state, a:action.glob)})
  elseif a:action.type ==# 'PUSH_GLOB'
    return extend(copy(a:state), {'globs': s:push_glob(a:state)})
  elseif a:action.type ==# 'TRY_POP_GLOB'
    return extend(copy(a:state), {'globs': s:try_pop_globs(a:state)})
  elseif a:action.type ==# 'SET_CURSOR'
    return extend(copy(a:state), {'cursor': a:action.cursor})
  elseif a:action.type ==# 'SET_VALUE'
    let settable = {}
    let settable[a:action.name] = a:action.value
    return extend(copy(a:state), settable)
  elseif a:action.type ==# 'SET_CMDPOS'
    return extend(copy(a:state), {'cmdpos': a:action.cmdpos})
  elseif a:action.type ==# 'SET_PATHS'
    return extend(copy(a:state), {'paths': a:action.paths})
  elseif a:action.type ==# 'SET_FILETYPES'
    return extend(copy(a:state), {'filetypes': a:action.filetypes})
  elseif a:action.type ==# 'SET_DID_SELECT_PREFILLED'
    return extend(copy(a:state), {'did_select_prefilled': 1})
  elseif a:action.type ==# 'SET_CMDLINE'
    let pattern = copy(a:state.pattern)
    call pattern.replace(a:action.cmdline)
    return extend(copy(a:state), {'pattern': pattern})
  elseif a:action.type ==# 'SET_LOCATION'
    return extend(copy(a:state), {'location': a:action.location})
  elseif a:action.type ==# 'PREVIEW_GLOB'
    let state = copy(a:state)
    let state.globs = deepcopy(a:state.globs)
    call state.globs.replace(a:action.glob)
    call esearch#preview#shell(state._adapter.glob(state), {
    \  'relative': 'editor',
    \  'align':    'bottom',
    \  'height':    0.3,
    \  'cwd':       state.cwd,
    \  'let':      {'&number': 0, '&filetype': 'esearch_glob'},
    \  'on_finish':  {bufnr, request, _ ->
    \    appendbufline(bufnr, 0, len(request.data).' matched file'.(len(request.data) == 1 ? '' : 's'))
    \  }
    \})
    return a:state
  else
    throw 'Unknown action ' . string(a:action)
  endif
endfu

fu! s:try_pop_pattern(state) abort
  let pattern = a:state.pattern
  call pattern.try_pop()
  return pattern
endfu

fu! s:push_pattern(state) abort
  if !a:state._adapter.multi_pattern | return a:state.pattern | endif

  let pattern = a:state.pattern
  if empty(pattern.peek().str)
    call pattern.next()
  else
    call pattern.push()
  endif

  return pattern
endfu

fu! s:try_pop_globs(state) abort
  let globs = a:state.globs
  call globs.try_pop()
  return globs
endfu

fu! s:set_glob(state, glob) abort
  let globs = a:state.globs
  call globs.replace(a:glob)
  return globs
endfu

fu! s:push_glob(state) abort
  if !a:state._adapter.multi_glob | return a:state.globs | endif

  let globs = a:state.globs
  if empty(globs.peek().str)
    call globs.next()
  else
    call globs.push('')
  endif

  return globs
endfu

fu! s:cycle_mode(state, mode_name) abort
  let kinds = keys(a:state._adapter[a:mode_name])
  let i = index(kinds, a:state[a:mode_name])

  if i >= len(kinds) - 1
    let i = 0
  else
    let i += 1
  endif

  return kinds[i]
endfu
