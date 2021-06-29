let s:Log             = esearch#log#import()
let s:FiletypeInputController = esearch#ui#component()

" TODO Live update
fu! s:FiletypeInputController.render() abort dict
  let s:_adapter = self.props._adapter
  redraw!

  try
    let filetypes = input('[filetypes] > ',
          \ self.props.filetypes,
          \ 'customlist,esearch#ui#controllers#filetype_input#complete')
  catch /Vim:Interrupt/
    return self.props.dispatch({'type': 'SET_LOCATION', 'location': 'menu'})
  endtry

  call self.props.dispatch({'type': 'SET_FILETYPES', 'filetypes': filetypes})
  call self.props.dispatch({'type': 'SET_LOCATION', 'location': 'menu'})
endfu

fu! esearch#ui#controllers#filetype_input#complete(arglead, cmdline, curpos) abort
  return esearch#ui#complete#filetypes#do(s:_adapter.filetypes, a:arglead, a:cmdline, a:curpos)
endfu

let s:map_state_to_props = esearch#util#slice_factory(['filetypes', '_adapter'])

fu! esearch#ui#controllers#filetype_input#import() abort
  return esearch#ui#connect(s:FiletypeInputController, s:map_state_to_props)
endfu
