" lines_delta is used to update statistics in the header. It can be more or less
" than zero depending on outputted separators ('' or '--') or multiple results
" within a single line (happens only for semgrep at the moment). Lines list
" isn't stored for performance reasons.
fu! esearch#out#win#update#init(es) abort
  cal extend(a:es, {
        \ 'contexts':    [],
        \ 'files_count': 0,
        \ 'lines_delta': 0,
        \ 'ctx_by_name': {},
        \ 'state':       [],
        \ 'render':      function('esearch#out#win#render#'.a:es.win_render_strategy.'#do'),
        \})
  aug __esearch_win_updates__ " init blank to prevent errors on cleanup
  aug END
  setl undolevels=-1 noswapfile nonumber norelativenumber nospell nowrap synmaxcol=400
  setl nolist nomodeline foldcolumn=0 buftype=nofile bufhidden=hide foldmethod=manual foldminlines=0 foldtext=esearch#out#win#fold#text()
  cal s:init_header_ctx(a:es)

  if a:es.request.async
    cal s:init_async_updates(a:es)
  en
endfu

fu! s:init_async_updates(es) abort
  cal extend(a:es, {
        \ 'upd_at': reltime(),
        \ 'upd_timer':  -1,
        \ 'early_upd_max': a:es.live_update && a:es.force_exec ? &lines : a:es.batch_size
        \})

  aug __esearch_win_updates__
    au! * <buffer>
    exe 'au BufUnload <buffer> cal esearch#backend#'.a:es.backend."#abort(str2nr(expand('<abuf>')))"
  aug END
  if g:esearch#has#throttle && a:es.win_update_throttle_wait > 0
    cal s:init_throttled_updates(a:es)
  el
    cal s:init_instant_updates(a:es)
  en
endfu

fu! s:init_throttled_updates(es) abort
  let a:es.request.cb.update = function('s:early_update_cb', [a:es])
  let a:es.request.cb.finish = function('s:early_update_cb', [a:es])
  let a:es.upd_timer = timer_start(
        \ a:es.win_update_throttle_wait,
        \ function('s:update_timer_cb', [a:es, bufnr('%')]),
        \ {'repeat': -1})
endfu

fu! s:init_header_ctx(es) abort
  cal esearch#out#win#update#add_context(a:es.contexts, '', 1, 0) " add blank header context
  let header_ctx = a:es.contexts[0]
  let header_ctx.end = 2
  let a:es.state += [header_ctx.id, header_ctx.id]
  setl modifiable
  keepjumps silent %delete_
  cal esearch#util#setline(bufnr('%'), 1, b:esearch.header_text())
  setl nomodifiable
endfu

" rely only on stdout events
fu! s:init_instant_updates(es) abort
  let a:es.request.cb.update = function('esearch#out#win#update#update', [bufnr('%')])
  let a:es.request.cb.finish = function('esearch#out#win#update#schedule_finish', [bufnr('%')])
endfu

fu! esearch#out#win#update#uninit(es) abort
  if has_key(a:es, 'upd_timer')
    cal timer_stop(a:es.upd_timer)
  en
  exe printf('au! __esearch_win_updates__ * <buffer=%s>', string(a:es.bufnr))
endfu

" NOTE is_consumed waits early_finish_wait ms while early_update_cb is
" working.
fu! esearch#out#win#update#can_finish_early(es) abort
  if !a:es.request.async | retu 1 | en

  retu a:es.request.is_consumed(a:es.early_finish_wait)
        \ && (len(a:es.request.data) - a:es.request.cursor) <= a:es.final_batch_size
endfu

fu! s:early_update_cb(es) abort
  if a:es.bufnr != bufnr('%') | retu | en
  let es = a:es

  cal esearch#out#win#update#update(es.bufnr)
  if es.live_update
    cal esearch#out#win#appearance#matches#hl_viewport(es)
    cal esearch#out#win#appearance#ctx_syntax#hl_viewport(es)
  en

  if es.request.cursor >= es.early_upd_max
    let es.request.cb.update = 0
    let es.request.cb.finish = 0
    retu
  en
  if es.request.finished && len(es.request.data) == es.request.cursor
    cal esearch#out#win#update#schedule_finish(es.bufnr)
  en
endfu

fu! s:update_timer_cb(es, bufnr, timer) abort
  let dt = reltimefloat(reltime(a:es.upd_at)) * 1000
  if dt < a:es.win_update_throttle_wait | retu | en

  cal esearch#out#win#update#update(a:es.bufnr)

  let request = a:es.request
  if request.finished && len(request.data) == request.cursor
    let a:es.upd_timer = -1
    cal esearch#out#win#update#schedule_finish(a:es.bufnr)
    cal timer_stop(a:timer)
  en
endfu

fu! esearch#out#win#update#add_context(contexts, filename, begin, rev) abort
  cal add(a:contexts, {
        \ 'id': len(a:contexts),
        \ 'begin': a:begin,
        \ 'end': 0,
        \ 'filename': a:filename,
        \ 'filetype': '',
        \ 'loaded_syntax': 0,
        \ 'rev': a:rev,
        \ 'lines': {},
        \ })
endfu

fu! esearch#out#win#update#update(bufnr, ...) abort
  if a:bufnr != bufnr('%') | retu | en

  let es = getbufvar(a:bufnr, 'esearch')
  let r = es.request
  let len = len(r.data)

  cal setbufvar(a:bufnr, '&modifiable', 1)
  if len > r.cursor
    if get(a:, 1) || len - r.cursor - 1 <= es.batch_size
          \ || (r.finished && len - r.cursor - 1 <= es.final_batch_size)
      let [from, to] = [r.cursor, len - 1]
      let r.cursor = len
    el
      let [from, to] = [r.cursor, r.cursor + es.batch_size - 1]
      let r.cursor += es.batch_size
    en
    cal es.render(a:bufnr, r.data, from, to, es)
  en
  cal esearch#util#setline(a:bufnr, 1, es.header_text())
  if es.win_ui_nvim_syntax | call luaeval('esearch.highlight_header(nil, true)') | endif
  cal setbufvar(a:bufnr, '&modifiable', 0)

  let es.upd_at = reltime()
endfu

fu! esearch#out#win#update#schedule_finish(n) abort
  if a:n == bufnr('%') || !bufexists(a:n)
    retu esearch#out#win#update#finish(a:n)
  en
  if !bufexists(a:n) | retu | en

  " Bind event to finish the search as soon as the buffer is entered
  aug __esearch_win_updates__
    exe printf('au BufEnter <buffer=%d> cal esearch#out#win#update#finish(%d)', a:n, a:n)
  aug END
endfu

fu! esearch#out#win#update#finish(bufnr) abort
  if a:bufnr != bufnr('%') | retu | en

  cal esearch#util#doautocmd('User esearch_win_finish_pre')
  let es = getbufvar(a:bufnr, 'esearch')

  cal esearch#out#win#update#update(a:bufnr, 1)
  " TODO
  let es.contexts[-1].end = line('$')
  cal esearch#out#win#appearance#annotations#init(es)
  cal esearch#out#win#update#uninit(es)
  cal setbufvar(a:bufnr, '&modifiable', 1)

  if !es._adapter.is_success(es.request)
    cal esearch#stderr#finish(es)
  en
  let es.header_text = function('esearch#out#win#header#finished_render')
  cal esearch#util#setline(a:bufnr, 1, es.header_text())

  cal setbufvar(a:bufnr, '&modified', 0)
  cal esearch#out#win#modifiable#init()
  if es.win_ui_nvim_syntax | cal luaeval('esearch.buf_attach_ui()') | en
endfu
