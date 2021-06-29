let s:List    = vital#esearch#import('Data.List')
let s:Prelude = vital#esearch#import('Prelude')

fu! esearch#preview#shape#import() abort
  return s:Shape
endfu

if has('nvim')
  let [s:topright, s:topleft, s:botleft] = ['NE', 'NW', 'SW']
else
  let [s:topright, s:topleft, s:botleft] = ['topright', 'topleft', 'botleft']
endif

let s:Shape = {}

fu! s:Shape.new(measures) abort dict
  let new = copy(self)
  let new.winline = winline()
  let new.wincol  = wincol()
  let new.align = a:measures.align
  let new.screenpos = g:esearch#has#nvim ? nvim_win_get_position(0) : win_screenpos(0)

  if &showtabline ==# 2 || &showtabline == 1 && tabpagenr('$') > 1
    let new.tabline_height = 1
  else
    let new.tabline_height = 0
  endif
  if &laststatus ==# 2 || &laststatus == 1 && winnr('$') > 1
    let new.statusline_height = 0
  else
    let new.statusline_height = 1
  endif
  let new.winheight = winheight(0)
  let new.winwidth = winwidth(0)
  let new.top = new.screenpos[0]
  let new.bottom = new.winheight + new.screenpos[0]
  let new.editor_top = new.tabline_height
  let new.editor_bottom = &lines - new.statusline_height - 2

  if new.align ==# 'cursor'
    call extend(new, {'width': 120, 'height': esearch#preview#default_height()})
    let new.relative = 0
  elseif s:List.has(['top', 'bottom'], new.align)
    call extend(new, {'width': 1.0, 'height': esearch#preview#default_height()})
    let new.relative = 1
  elseif s:List.has(['left', 'right'], new.align)
    call extend(new, {'width': 0.5, 'height': 1.0})
    let new.relative = 1
  endif

  let width = a:measures.width
  if s:Prelude.is_numeric(width) && width > 0
    let new.width = width
  endif
  let height = a:measures.height
  if s:Prelude.is_numeric(height) && height > 0
    let new.height = height
  endif

  let new.height = s:absolute_value(new.height, new.winheight)
  let new.width = s:absolute_value(new.width, new.winwidth)

  if new.align ==# 'custom'
    if get(a:measures, 'row', 0) > new.screenpos[0] + (!has('nvim')) && get(a:measures, 'col', 0) > new.screenpos[1]
      let new.row = a:measures.row - has('nvim')
      let new.col = a:measures.col - has('nvim')
      let new.anchor = s:topleft
      let new.custom = 1
    else
      let new.align = 'cursor'
      let new.custom = 0
    endif
  else
    let new.custom = 0
  endif
  call new.realign()

  return new
endfu

fu! s:absolute_value(value, interval) abort
  if type(a:value) ==# type(1.0)
    return float2nr(ceil(a:value * a:interval))
  elseif type(a:value) ==# type(1) && a:value > 0
    return a:value
  else
    throw 'Wrong type of value ' . a:value
  endif
endfu

fu! s:Shape.realign() abort dict
  if self.align ==# 'cursor'
    call self.align_to_cursor()
  elseif self.align ==# 'top'
    return self.align_to_top()
  elseif self.align ==# 'bottom'
    return self.align_to_bottom()
  elseif self.align ==# 'left'
    return self.align_to_left()
  elseif self.align ==# 'right'
    return self.align_to_right()
  endif
endfu

fu! s:Shape.align_to_top() abort dict
  let self.col    = self.screenpos[1]
  let self.row    = self.top
  let self.anchor = s:topleft
endfu

fu! s:Shape.align_to_right() abort dict
  let self.col    = self.screenpos[1] + self.winwidth + 1
  let self.row    = self.top
  let self.anchor = s:topright
endfu

fu! s:Shape.align_to_left() abort dict
  let self.col    = self.screenpos[1]
  let self.row    = self.top
  let self.anchor = s:topleft
endfu

fu! s:Shape.align_to_bottom() abort dict
  let self.row    = self.bottom - !has('nvim')
  let self.col    = self.screenpos[1]
  let self.anchor = s:botleft
endfu

fu! s:Shape.align_to_cursor() abort dict
  let winline = self.winline
  if winline  + self.screenpos[0] + self.height > self.editor_bottom
    let self.row = winline - self.height - 1 + self.screenpos[0] " if there's no room - show above
  else
    let self.row = winline + self.screenpos[0]
  endif
  let self.col = self.wincol - 1 + self.screenpos[1]

  let self.anchor = s:topleft
endfu

fu! s:Shape.clip_height(lines_count) abort dict
  " Left and right aligned previews are stretched
  if s:List.has(['left', 'right'], self.align) | return | endif

  let self.height = min([
        \ a:lines_count,
        \ self.height,
        \ self.editor_bottom - self.editor_top])
  if !self.custom | call self.realign() | endif
endfu
