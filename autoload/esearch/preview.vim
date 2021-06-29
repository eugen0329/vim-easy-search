let s:is_cmdwin = vital#esearch#import('Vim.Buffer').is_cmdwin
let s:Log    = esearch#log#import()
let s:Shape  = esearch#preview#shape#import()
let s:Buf = esearch#preview#buf#import()
let [s:true, s:false, s:null, s:t_dict, s:t_float, s:t_func,
     \ s:t_list, s:t_number, s:t_string] = esearch#polyfill#definitions()

if g:esearch#has#nvim
  let s:Preview = esearch#preview#nvim#opener#import()
  let s:default_vars = {
        \ '&foldenable': 0,
        \ '&wrap': 0,
        \ '&winhighlight': join([
        \   'Normal:esearchNormalFloat',
        \   'SignColumn:esearchSignColumnFloat',
        \   'LineNr:esearchLineNrFloat',
        \   'CursorLineNr:esearchCursorLineNrFloat',
        \   'CursorLine:esearchCursorLineFloat',
        \   'Conceal:esearchConcealFloat',
        \ ], ',')
        \ }
else
  let s:Preview = esearch#preview#vim#opener#import()
  let s:default_vars = {'&foldenable': 0, '&number': 1, '&wrap': 0}
endif
let g:esearch#preview#close_on_move = ['CursorMoved', 'CursorMovedI', 'InsertEnter']
let g:esearch#preview#close_on = ['QuitPre', 'BufEnter', 'BufWinEnter', 'TabLeave']
let g:esearch#preview#reset_on = 'BufWinLeave,BufLeave'
" The constant is used to ignore events used by :edit and :view commands to
" reduce the execution of unwanted autocommands like updating lightline,
" powerline etc.
" From docs: BufDelte - ...also used just before a buffer in the buffer list is
" renamed.
let g:esearch#preview#silent_open_eventignore = 'BufLeave,BufWinLeave,BufEnter,BufWinEnter,WinEnter,BufDelete'
let g:esearch#preview#buffers = {}
let g:esearch#preview#win     = {}
let g:esearch#preview#buffer  = {}
let g:esearch#preview#last    = {}

fu! esearch#preview#shell(command, ...) abort
  let opts = get(a:, 1, {})
  let backend = get(opts, 'backend', g:esearch.backend)
  call extend(opts, {'emphasis': []}, 'keep')
  call extend(opts, {'close_on': []}, 'keep')
  call extend(opts, {'method': 'shell'}, 'keep')
  call extend(opts, {'align': 'custom'}, 'keep')
  call extend(opts, {'line': 1}, 'keep')
  call extend(opts, {'on_finish': function('esearch#util#noop')}, 'keep')
  call extend(opts, {'cwd': getcwd()}, 'keep')
  call extend(opts, {'command': a:command})
  let expire = get(opts, 'expire', 2000)
  if expire && esearch#preview#is_open()
        \ && get(g:esearch#preview#win, 'cache_key', []) ==# [opts, opts.align]
        \ && reltimefloat(reltime(g:esearch#preview#win.upd_at)) * 1000 < expire
    return
  endif
  let request = esearch#backend#{backend}#init(opts.cwd, '', a:command)
  let request.cb.finish = function('<SID>on_finish', [bufnr(''), request, opts])
  call esearch#backend#{backend}#exec(request)
  if !request.async | call request.cb.finish() | endif
endfu

fu! s:on_finish(bufnr, request, opts) abort
  if esearch#preview#is_open()
        \ && get(g:esearch#preview#last.opts, 'method') isnot# 'shell'
        \ || bufnr('') !=# a:bufnr
    " Close only shell previews to prevent E814
    return
  endif
  noau noswap let bufnr = bufadd('[esearch-preview-shell]')
  noau call bufload(bufnr)
  call setbufvar(bufnr, '&buftype', 'nofile')
  call deletebufline(bufnr, 1, '$')
  call setbufline(bufnr, 1, a:request.data)
  call appendbufline(bufnr, '$', a:request.errors)
  call a:opts.on_finish(bufnr, a:request, a:opts)
  call esearch#preview#open('[esearch-preview-shell]', a:opts.line, a:opts)
endfu

fu! esearch#preview#open(filename, line, ...) abort
  let opts = get(a:, 1, {})

  let shape = s:Shape.new({
        \ 'width':  get(opts, 'width',  s:null),
        \ 'height': get(opts, 'height', s:null),
        \ 'row':    get(opts, 'row',    -1),
        \ 'col':    get(opts, 'col',    -1),
        \ 'align':  get(opts, 'align',  'cursor'),
        \ })

  let close_on  = g:esearch#preview#close_on + get(opts, 'close_on',  [])
  let close_on  = uniq(copy(close_on))

  let location = {'filename': a:filename, 'line': a:line}
  let vars = extend(copy(get(opts, 'let', {})), s:default_vars, 'keep')
  let emphasis = get(opts, 'emphasis', g:esearch#emphasis#default)

  let g:esearch#preview#last = s:Preview
        \.new(location, shape, emphasis, vars, opts, close_on)

  return g:esearch#preview#last[get(opts, 'method', 'open')]()
endfu

fu! esearch#preview#is_current() abort
  return !empty(g:esearch#preview#win)
        \ && g:esearch#preview#win.id == win_getid()
endfu

fu! esearch#preview#is_open() abort
  " window id becomes invalid on bwipeout
  return !empty(g:esearch#preview#win)
        \ && esearch#win#exists(g:esearch#preview#win.id)
endfu

fu! esearch#preview#reset() abort
  if has_key(g:esearch#preview#last, 'win')
    call g:esearch#preview#last.win.unplace_emphasis()
  endif
  if esearch#preview#is_open()
    let guard = g:esearch#preview#win.guard
    if !empty(guard) | call guard.restore() | endif
  endif
endfu

fu! esearch#preview#close(...) abort
  if esearch#preview#is_open() && !s:is_cmdwin()
    call esearch#preview#reset()
    call g:esearch#preview#win.close()
    let g:esearch#preview#buffer = g:esearch#preview#win.buf
    let g:esearch#preview#win = 0
    return 1
  endif
  return 0
endfu

fu! esearch#preview#wipeout(...) abort
  call esearch#preview#close()
  let buffer = g:esearch#preview#buffer
  if !empty(buffer) && get(buffer, 'viewed') && bufexists(buffer.id) && getbufvar(buffer.id, '&readonly')
    exe buffer.id 'bwipeout'
  endif
endfu

" Shape specified on create is only to prevent blinks.
" Actual shape settings are set there
fu! esearch#preview#default_height() abort
  return min([19, &lines / 2])
endfu
