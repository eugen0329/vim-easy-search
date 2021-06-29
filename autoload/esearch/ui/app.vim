let s:OptionsMenu             = esearch#ui#menu#menu#import()
let s:MenuController          = esearch#ui#controllers#menu#import()
let s:GlobInputController     = esearch#ui#controllers#glob_input#import()
let s:PathInputController     = esearch#ui#controllers#path_input#import()
let s:FiletypeInputController = esearch#ui#controllers#filetype_input#import()
let s:SearchInputController   = esearch#ui#controllers#search_input#import()

let s:App = esearch#ui#component()

fu! s:App.new(store) abort dict
  let instance = extend(copy(self), {'store': a:store})
  let instance.current_route = 0
  let instance.location = a:store.state.location
  return instance
endfu

fu! s:App.render() abort dict
  if self.store.state.location ==# 'menu'
    call self.route('menu', s:MenuController.new({'menu_class': s:OptionsMenu}))
  elseif self.store.state.location ==# 'path_input'
    call self.route('path_input', s:PathInputController.new())
  elseif self.store.state.location ==# 'glob_input'
    call self.route('glob_input', s:GlobInputController.new())
  elseif self.store.state.location ==# 'filetype_input'
    call self.route('filetype_input', s:FiletypeInputController.new())
  elseif self.store.state.location ==# 'search_input'
    call self.route('search_input', s:SearchInputController.new())
  elseif self.store.state.location ==# 'exit'
    call esearch#ui#soft_clear()
    return 0
  else
    throw 'Unknown location'
  endif

  call self.current_route.render()

  return 1
endfu

fu! s:App.route(location, component) abort dict
  if self.location !=# a:location || empty(self.current_route)
    let self.location = a:location

    if !empty(self.current_route)
      call self.current_route.component_will_unmount()
    endif
    call a:component.component_will_mount()
  endif
  let self.current_route = a:component
endfu

fu! s:App.component_will_unmount() abort dict
  if !empty(self.current_route)
    call self.current_route.component_will_unmount()
  endif
endfu

let s:map_state_to_props = esearch#util#slice_factory(['location'])

fu! esearch#ui#app#import() abort
  return s:App
endfu
