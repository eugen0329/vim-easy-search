fu! esearch#out#win#unsupported#handle(event) abort
  try
    call esearch#changes#lock()
    call b:esearch.undotree.mark_block_as_corrupted()

    silent undo

    let changenr = esearch#changes#undo_state()
    call b:esearch.undotree.checkout(changenr)
    call esearch#changes#rewrite_last_state({
          \ 'changenr': changenr(),
          \ })
  finally
    call esearch#changes#unlock()
  endtry
endfu