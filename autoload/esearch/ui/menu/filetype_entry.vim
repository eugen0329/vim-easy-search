let s:String     = vital#esearch#import('Data.String')
let s:List       = vital#esearch#import('Data.List')
let s:FiletypeEntry  = esearch#ui#component()

fu! s:FiletypeEntry.render() abort dict
  let icon = empty(self.props.filetypes) ? ['Comment', '[ft]'] : ['Typedef', '[ft]']
  let result = [['None', s:String.pad_right(self.props.keys[0], 7, ' ')], icon, ['NONE', ' search only in filetypes']]

  if empty(self.props.filetypes)
    let result += [['Comment', ' (none)']]
  else
    let result += [['Comment', ' ('.self.props._adapter.filetypes2args(self.props.filetypes).')']]
  endif

  return result
endfu

fu! s:FiletypeEntry.keypress(event) abort dict
  if s:List.has(self.props.keys, a:event.key) || a:event.key ==# "\<enter>"
    call self.props.dispatch({'type': 'SET_LOCATION', 'location': 'filetype_input'})
    let stop_propagation = 1
    return stop_propagation
  end
endfu

let s:map_state_to_props = esearch#util#slice_factory(['filetypes', '_adapter'])

fu! esearch#ui#menu#filetype_entry#import() abort
  return esearch#ui#connect(s:FiletypeEntry, s:map_state_to_props)
endfu
