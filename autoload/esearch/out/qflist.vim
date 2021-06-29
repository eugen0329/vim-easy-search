fu! esearch#out#qflist#init(es) abort
  if a:es.live_update && !a:es.force_exec | return s:init_live_updated(a:es) | endif

  if has_key(g:, 'esearch_qf')
    call esearch#backend#{g:esearch_qf.backend}#abort(bufnr('%'))
  end
  call setqflist([])
  copen
  if a:es.request.async
    call esearch#out#qflist#setup_autocmds(a:es)
  endif
  let g:esearch_qf = extend(a:es, {'name': ':'.a:es.name})
  call esearch#buf#rename_qf(g:esearch_qf.name)
  if !g:esearch_qf.request.async
    call esearch#out#qflist#finish()
  endif
  return g:esearch_qf
endfu

fu! esearch#out#qflist#setup_autocmds(es) abort
  aug __esearch_out_qflist__
    au! * <buffer>
    let a:es.request.cb.update = function('esearch#out#qflist#update')
    let a:es.request.cb.finish = function('esearch#out#qflist#schedule_finish')

    " Keep only User cmds(reponsible for results updating) and qf initialization
    au BufUnload <buffer> exe "au! __esearch_out_qflist__ * <abuf> "
    exe 'au BufUnload <buffer> call esearch#backend#'.a:es.backend."#abort(str2nr(expand('<abuf>')))"

    " We need to handle quickfix bufhidden=wipe behavior
    if !exists('#__esearch_out_qflist__#FileType')
      au FileType qf
            \ if exists('g:esearch_qf') && !g:esearch_qf.request.finished && esearch#buf#qftype(bufnr('%')) ==# 'qf' |
            \   call esearch#out#qflist#setup_autocmds(g:esearch_qf) |
            \ endif
    endif
  aug END
endfu

fu! esearch#out#qflist#update(...) abort
  let es = g:esearch_qf
  let batched = get(a:, 1, 0)

  let request = es.request
  let data = es.request.data
  let data_size = len(data)
  if data_size > request.cursor
    if batched || data_size - request.cursor - 1 <= es.batch_size
      let [from,to] = [request.cursor, data_size - 1]
      let request.cursor = data_size
    else
      let [from, to] = [request.cursor, request.cursor + es.batch_size - 1]
      let request.cursor += es.batch_size
    endif

    let cwd = esearch#win#lcd(es.cwd)
    try
      let [entries, _, errors] = es.parse(data, from, to)
      if !empty(errors) | call esearch#stderr#append(es, errors) | endif

      if es.adapter ==# 'git'
        if !has_key(es, '_git_dir') | let es._git_dir = es.git_dir(es.cwd) | endif
        call s:set_git_urls(es, es._git_dir, entries)
      endif

      if esearch#buf#qftype(bufnr('%')) ==# 'qf'
        let curpos = getcurpos()[1:]
        noau call setqflist(entries, 'a')
        call cursor(curpos)
      else
        noau call setqflist(entries, 'a')
      endif
    finally
      call cwd.restore()
    endtry
  endif
endfu

fu! s:set_git_urls(es, dir, entries) abort
  for e in a:entries
    if get(e, 'rev') | let e.module = e.filename | let e.filename = a:es.git_url(e.filename, a:dir) | en
  endfor
endfu

fu! esearch#out#qflist#schedule_finish() abort
  call esearch#out#qflist#finish()
endfu

fu! esearch#out#qflist#finish() abort
  let es = g:esearch_qf

  if es.request.async
    au! __esearch_out_qflist__ * <buffer>
  endif

  " Update using all remaining request.data
  call esearch#out#qflist#update(0)

  let es.name = es.name . '. Finished.'

  if esearch#buf#qftype(bufnr('%')) ==# 'qf'
    call esearch#buf#rename_qf(es.name)
  else
    let bufnr = esearch#buf#qfbufnr()
    if bufnr !=# -1
      for tabnr in range(1, tabpagenr('$'))
        let buflist = tabpagebuflist(tabnr)
        if index(buflist, bufnr) >= 0
          for winnr in range(1, tabpagewinnr(tabnr, '$'))
            if buflist[winnr - 1] == bufnr
              call settabwinvar(tabnr, winnr, 'quickfix_title', es.name)
            endif
          endfor
        endif
      endfor
    endif
  endif
endfu

fu! s:init_live_updated(es) abort
  let g:esearch_qf.name = ':'.a:es.name
  if g:esearch_qf.request.finished
    let g:esearch_qf.name .= '. Finished.'
  endif
  call esearch#buf#rename_qf(g:esearch_qf.name)
  return g:esearch_qf
endfu
