fu! esearch#out#win#update#init(es) abort
  cal extend(a:es, {
        \ 'contexts':           [],
        \ 'files_count':        0,
        \ 'separators_count':   0,
        \ 'line_numbers_map':   [],
        \ 'ctx_by_name':        {},
        \ 'ctx_ids_map':        [],
        \ 'render':             function('esearch#out#win#render#'.a:es.win_render_strategy.'#do'),
        \})
  aug esearch_win_updates " init blank to prevent errors on cleanup
  aug END
  setl undolevels=-1 noswapfile nonumber norelativenumber nospell nowrap synmaxcol=400
  setl nolist nomodeline foldcolumn=0 buftype=nofile bufhidden=hide foldmethod=marker
  cal s:init_header_ctx(a:es)

  if a:es.request.async
    cal s:init_async_updates(a:es)
  en
endfu

fu! s:init_async_updates(es) abort
  cal extend(a:es, {
        \ 'last_update_at':     reltime(),
        \ 'updates_timer':      -1,
        \ 'early_update_limit': &lines,
        \})

  aug esearch_win_updates
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
  let a:es.request.cb.schedule_finish = function('s:early_update_cb', [a:es])
  let a:es.updates_timer = timer_start(
        \ a:es.win_update_throttle_wait,
        \ function('s:update_timer_cb', [a:es, bufnr('%')]),
        \ {'repeat': -1})
endfu

fu! s:init_header_ctx(es) abort
  cal esearch#out#win#update#add_context(a:es.contexts, '', 1) " add blank header context
  let header_ctx = a:es.contexts[0]
  let header_ctx.end = 2
  let a:es.ctx_ids_map += [header_ctx.id, header_ctx.id]
  let a:es.line_numbers_map += [0, 0]
  setl modifiable
  silent 1,$delete_
  cal esearch#util#setline(bufnr('%'), 1, b:esearch.header_text())
  setl nomodifiable
endfu

" rely only on stdout events
fu! s:init_instant_updates(es) abort
  let a:es.request.cb.update = function('esearch#out#win#update#update', [bufnr('%')])
  let a:es.request.cb.schedule_finish = function('esearch#out#win#update#schedule_finish', [bufnr('%')])
endfu

fu! esearch#out#win#update#uninit(es) abort
  if has_key(a:es, 'updates_timer')
    cal timer_stop(a:es.updates_timer)
  en
  exe printf('au! esearch_win_updates * <buffer=%s>', string(a:es.bufnr))
endfu

" NOTE is_consumed waits early_finish_wait ms while early_update_cb is
" working.
fu! esearch#out#win#update#can_finish_early(es) abort
  if !a:es.request.async | retu 1 | en

  let original_early_update_limit = a:es.early_update_limit
  let a:es.early_update_limit *= 1000
  try
    retu a:es.request.is_consumed(a:es.early_finish_wait)
          \ && (len(a:es.request.data) - a:es.request.cursor) <= a:es.final_batch_size
  finally
    let a:es.early_update_limit = original_early_update_limit
  endtry
endfu

fu! s:early_update_cb(es) abort
  if a:es.bufnr != bufnr('%') | retu | en
  let es = a:es

  cal esearch#out#win#update#update(es.bufnr)
  if es.live_update
    cal esearch#out#win#appearance#matches#hl_viewport(es)
    cal esearch#out#win#appearance#ctx_syntax#hl_viewport(es)
  en

  if es.request.cursor >= es.early_update_limit
    let es.request.cb.update = 0
    let es.request.cb.schedule_finish = 0
    retu
  en
  if es.request.finished && len(es.request.data) == es.request.cursor
    cal esearch#out#win#update#schedule_finish(es.bufnr)
  en
endfu

fu! s:update_timer_cb(es, bufnr, timer) abort
  let elapsed = reltimefloat(reltime(a:es.last_update_at)) * 1000
  if elapsed < a:es.win_update_throttle_wait | retu | en

  cal esearch#out#win#update#update(a:es.bufnr)

  let request = a:es.request
  if request.finished && len(request.data) == request.cursor
    let a:es.updates_timer = -1
    cal esearch#out#win#update#schedule_finish(a:es.bufnr)
    cal timer_stop(a:timer)
  en
endfu

fu! esearch#out#win#update#add_context(contexts, filename, begin) abort
  cal add(a:contexts, {
        \ 'id': len(a:contexts),
        \ 'begin': a:begin,
        \ 'end': 0,
        \ 'filename': a:filename,
        \ 'filetype': '',
        \ 'loaded_syntax': 0,
        \ 'lines': {},
        \ })
endfu

fu! esearch#out#win#update#update(bufnr, ...) abort
  if a:bufnr != bufnr('%') | retu | en

  let es = getbufvar(a:bufnr, 'esearch')
  let batched = get(a:, 1, 0)
  let r = es.request
  let data = r.data
  let len = len(data)

  cal setbufvar(a:bufnr, '&modifiable', 1)
  if len > r.cursor
    if !batched
          \ || len - r.cursor - 1 <= es.batch_size
          \ || (r.finished && len - r.cursor - 1 <= es.final_batch_size)
      let [from, to] = [r.cursor, len - 1]
      let r.cursor = len
    el
      let [from, to] = [r.cursor, r.cursor + es.batch_size - 1]
      let r.cursor += es.batch_size
    en

    cal es.render(a:bufnr, data, from, to, es)
  en
  cal esearch#util#setline(a:bufnr, 1, es.header_text())
  cal setbufvar(a:bufnr, '&modifiable', 0)

  let es.last_update_at = reltime()
endfu

fu! esearch#out#win#update#schedule_finish(bufnr) abort
  if a:bufnr == bufnr('%')
    retu esearch#out#win#update#finish(a:bufnr)
  en

  " Bind event to finish the search as soon as the buffer is entered
  aug esearch_win_updates
    exe printf('au BufEnter <buffer=%d> cal esearch#out#win#update#finish(%d)', a:bufnr, a:bufnr)
  aug END
endfu

fu! esearch#out#win#update#finish(bufnr) abort
  if a:bufnr != bufnr('%') | retu | en

  cal esearch#util#doautocmd('User esearch_win_finish_pre')
  let es = getbufvar(a:bufnr, 'esearch')

  cal esearch#out#win#update#update(a:bufnr, 0)
  " TODO
  let es.contexts[-1].end = line('$')
  if es.win_context_len_annotations
    cal luaeval('esearch.appearance.set_context_len_annotation(_A[1], _A[2])',
          \ [es.contexts[-1].begin, len(es.contexts[-1].lines)])
  en
  cal esearch#out#win#update#uninit(es)
  cal setbufvar(a:bufnr, '&modifiable', 1)

  if !es.current_adapter.is_success(es.request)
    cal esearch#stderr#finish(es)
  en
  let es.header_text = function('esearch#out#win#header#finished_render')
  cal esearch#util#setline(a:bufnr, 1, es.header_text())

  cal setbufvar(a:bufnr, '&modified', 0)
  cal esearch#out#win#modifiable#init()

  if es.win_ui_nvim_syntax
    cal luaeval('esearch.appearance.buf_attach_ui()')
  en
  cal esearch#out#win#appearance#annotations#init(es)
  if g:esearch#has#nvim && es.live_update | redraw | en
endfu
