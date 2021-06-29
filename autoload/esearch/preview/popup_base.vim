fu! esearch#preview#popup_base#import() abort
  return copy(s:PopupBase)
endfu

let s:PopupBase = {'guard': 0, 'id': 0, 'emphasis': 0, 'variables': 0}

fu! s:PopupBase.new(buf, location, shape, close_on) abort dict
  let new = copy(self)

  let new.buf      = a:buf
  let new.location = a:location
  let new.shape    = a:shape
  let new.close_on = a:close_on
  let new.emphasis = []

  return new
endfu

fu! s:PopupBase.let(variables) abort dict
  let self.variables = a:variables
  let self.guard = esearch#let#bufwin_restorable(self.buf.id, self.id, a:variables)
endfu

fu! s:PopupBase.init_autoclose_events() abort dict
  let autocommands = join(self.close_on, ',')

  aug __esearch_preview_autoclose__
    au!
    exe 'au ' . autocommands . ' * ++once call esearch#preview#close()'
    exe 'au ' . g:esearch#preview#reset_on . ' * ++once call esearch#preview#reset()'
    au User esearch_open_pre ++once call esearch#preview#close()
    if exists('##TabNewEntered')
      " Prevent options inheritance
      au TabNewEntered * ++once call g:esearch#preview#last.win.guard.new(g:esearch#preview#last.buf.id, win_getid()).restore()
    endif

    " We cannot close the preview when entering cmdwin, so the only option is to
    " reinitialize the events.
    au CmdwinLeave * ++once call g:esearch#preview#win.init_autoclose_events()
  aug END
endfu

fu! s:PopupBase.place_emphasis(emphasis) abort dict
  let self.emphasis = []

  for e in a:emphasis
    call add(self.emphasis, e.new(self.id, self.buf.id, self.location.line).place())
  endfor
endfu

fu! s:PopupBase.unplace_emphasis() abort dict
  if !empty(self.emphasis)
    call map(self.emphasis, 'v:val.unplace()')
    let self.emphasis = []
  endif
endfu
