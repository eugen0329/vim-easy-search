let s:List = vital#esearch#import('Data.List')
let [s:true, s:false, s:null, s:t_dict, s:t_float, s:t_func,
      \ s:t_list, s:t_number, s:t_string] = esearch#polyfill#definitions()

let s:down_keys   = ["\<c-j>", 'j', "\<down>"]
let s:up_keys     = ["\<c-k>", 'k', "\<up>"]
let s:cancel_keys = ["\<esc>", "\<c-c>", 'q']

let s:MenuController = esearch#ui#component()

fu! s:MenuController.new(props) abort dict
  let instance      = extend(copy(self), {'props': a:props})
  let instance.menu = a:props.menu_class.new({'cursor': a:props.cursor})
  return instance
endfu

" inspired by nerdree menu
fu! s:MenuController.render() abort dict
  call self.force_update()

  let key = esearch#util#getchar()
  if s:List.has(s:down_keys, key)
    call self.cursor_down()
  elseif s:List.has(s:up_keys, key)
    call self.cursor_up()
  elseif s:List.has(s:cancel_keys, key)
    return self.props.dispatch({'type': 'SET_LOCATION', 'location': 'search_input'})
  else
    if self.menu.keypress({'key': key, 'target': self.menu.items[self.props.cursor]})
      return
    endif
  endif
endfu

fu! s:MenuController.force_update() abort dict
  let self.menu = self.props.menu_class.new({'cursor': self.props.cursor})
  echo '' | redraw!
  call esearch#ui#render(self.menu)
endfu

fu! s:MenuController.component_will_mount() abort dict
  let s:saved_winheight = winheight(0)
  let s:saved_options = esearch#let#restorable({
        \ '&cmdheight': self.menu.height,
        \ '&lazyredraw': 0,
        \ '&more': 0,
        \ '&t_ve': ''})
  call esearch#ui#soft_clear()
endfu

fu! s:MenuController.component_will_unmount() abort dict
  call s:saved_options.restore()
  exe 'resize ' . s:saved_winheight
  redraw!
endfu

fu! s:MenuController.cursor_down() abort dict
  if self.props.cursor < len(self.menu.items) - 1
    call self.props.dispatch({'type': 'SET_CURSOR', 'cursor': self.props.cursor + 1})
  else
    call self.props.dispatch({'type': 'SET_CURSOR', 'cursor': 0})
  endif
endfu

fu! s:MenuController.cursor_up() abort dict
  if self.props.cursor > 0
    call self.props.dispatch({'type': 'SET_CURSOR', 'cursor': self.props.cursor - 1})
  else
    call self.props.dispatch({'type': 'SET_CURSOR', 'cursor': len(self.menu.items) - 1})
  endif
endfu

let s:map_state_to_props = esearch#util#slice_factory(['cursor'])

fu! esearch#ui#controllers#menu#import() abort
  return esearch#ui#connect(s:MenuController, s:map_state_to_props)
endfu
