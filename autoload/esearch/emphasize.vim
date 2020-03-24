let s:sign_name  = 'esearchEmphasizeSign'
let s:sign_group = 'esearchEmphasizeSigns'
let s:sign_id    = 502012 " TODO: investigate what is the scope of id's

fu! esearch#emphasize#sign(win_handle, line, text) abort
  return s:SignEmphasis.new(a:win_handle, a:line, a:text)
endfu

let s:SignEmphasis = {}

fu! s:SignEmphasis.new(win_handle, line, text) abort dict
  let instance = copy(self)
  let instance.win_handle = a:win_handle
  let instance.line          = a:line
  let instance.text          = a:text
  let instance.guard         = {}

  return instance
endfu

fu! s:SignEmphasis.draw() abort dict
  if empty(sign_getdefined(s:sign_name))
    call sign_define(s:sign_name, {'text': self.text})
  endif

  let self.guard = esearch#win#let_restorable(
        \ self.win_handle, {'&signcolumn': 'auto'})

  noau call sign_place(s:sign_id,
        \ s:sign_group,
        \ s:sign_name,
        \ esearch#win#bufnr(self.win_handle),
        \ {'lnum': self.line})

  return self
endfu

fu! s:SignEmphasis.clear() abort dict
  call sign_unplace(s:sign_group, {'id': s:sign_id})
  call self.guard.restore()
endfu