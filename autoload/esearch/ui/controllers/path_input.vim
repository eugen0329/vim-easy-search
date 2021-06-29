let s:Log = esearch#log#import()
let s:PathInputController = esearch#ui#component()

" TODO Live update
fu! s:PathInputController.render() abort dict
  let s:self = self
  if type(self.props.paths) == type({})
    let user_input_in_shell_format = ''
  else
    let user_input_in_shell_format = esearch#shell#join(self.props.paths)
  endif

  redraw!
  while 1
    try
      let user_input_in_shell_format = input('[paths] > ',
            \ user_input_in_shell_format,
            \'customlist,esearch#ui#controllers#path_input#complete')
    catch /Vim:Interrupt/
      return self.props.dispatch({'type': 'SET_LOCATION', 'location': 'menu'})
    endtry

    let [paths, error] = esearch#shell#split(user_input_in_shell_format)
    if empty(error) | break | endif

    call s:Log.echon('ErrorMsg', " can't parse paths: " . error)
    call getchar()
    redraw!
  endwhile

  call self.props.dispatch({'type': 'SET_PATHS',    'paths': paths})
  call self.props.dispatch({'type': 'SET_LOCATION', 'location': 'menu'})
endfu

fu! esearch#ui#controllers#path_input#complete(arglead, cmdline, curpos) abort
  return esearch#ui#complete#paths#do(s:self.props.cwd, a:arglead, a:cmdline, a:curpos)
endfu

fu! s:map_state_to_props(state) abort dict
  return {
        \ 'paths': get(a:state, 'paths', esearch#shell#argv([])),
        \ 'cwd':   a:state.cwd,
        \}
endfu

fu! esearch#ui#controllers#path_input#import() abort
  return esearch#ui#connect(s:PathInputController, function('<SID>map_state_to_props'))
endfu
