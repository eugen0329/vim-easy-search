let s:Log = esearch#log#import()
let [s:true, s:false, s:null, s:t_dict, s:t_float, s:t_func,
     \ s:t_list, s:t_number, s:t_string] = esearch#polyfill#definitions()
let s:relative = 'win'

fu! esearch#preview#vim#popup#import() abort
  return s:VimPopup
endfu

let s:VimPopup = esearch#preview#popup_base#import()

fu! s:VimPopup.reshape() abort dict
  if !self.buf.is_valid()
    call s:Log.error('Preview buf was deleted')
    return esearch#preview#close()
  endif

  if g:esearch#has#getbufinfo_linecount
    call self.shape.clip_height(getbufinfo(self.buf.id)[0].linecount)
  endif
  let height = self.shape.height
  let line   = self.location.line

  call popup_setoptions(self.id, {
        \ 'firstline': max([1, line - height/2]),
        \ })
  call popup_move(self.id, {
        \ 'maxheight': height,
        \ 'minheight': height,
        \ 'maxwidth':  self.shape.width,
        \ 'minwidth':  self.shape.width,
        \ 'line': self.shape.row,
        \ })
endfu

fu! s:VimPopup.open() abort dict
  try
    noau let self.id = popup_create(self.buf.id, {
        \ 'maxwidth':  self.shape.width,
        \ 'minwidth':  self.shape.width,
        \ 'maxheight': self.shape.height,
        \ 'minheight': self.shape.height,
        \ 'line':      self.shape.row,
        \ 'col':       self.shape.col,
        \ 'pos':       self.shape.anchor,
        \ 'highlight': 'esearchNormalFloat',
        \ 'scrollbar': 0,
        \})
  catch /^Vim(let):E325:/
    call popup_clear() " as SwapExists doesn't work
    exe self.buf.id . 'bdelete'
    throw "Can't open the preview: swap exists"
  endtry
  if empty(esearch#win#get(self.id, '&filtype'))
    call win_execute(self.id, 'filetype detect')
  endif
  return self
endfu

fu! s:VimPopup.close() abort dict
  call self.unplace_emphasis()
  call popup_close(self.id)
endfu
