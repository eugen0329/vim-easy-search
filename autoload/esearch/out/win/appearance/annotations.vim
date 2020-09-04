fu! esearch#out#win#appearance#annotations#init(es) abort
  if a:es.win_context_len_annotations && a:es.win_render_strategy ==# 'lua'
    cal luaeval('esearch.appearance.set_context_len_annotation(_A[1], _A[2])',
          \ [a:es.contexts[-1].begin, len(a:es.contexts[-1].lines)])
    cal luaeval('esearch.appearance.buf_attach_annotations()')
  en
endfu

fu! esearch#out#win#appearance#annotations#uninit(es) abort
  if a:es.win_context_len_annotations
    cal luaeval('esearch.appearance.buf_clear_annotations()')
  en
endfu
