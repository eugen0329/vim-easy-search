let s:String     = vital#esearch#import('Data.String')
let s:List       = vital#esearch#import('Data.List')
let s:GlobEntry  = esearch#ui#component()

fu! s:GlobEntry.render() abort dict
  let icon = empty(self.props.globs.list) ? ['Comment', '[!/]'] : ['Special', '[!/]']
  let result = [['None', s:String.pad_right(self.props.keys[0], 7, ' ')], icon, ['NONE', ' filter paths']]

  if empty(self.props.globs.list)
    let result += [['Comment', ' (none)']]
  else
    let result += [['Comment', ' (']]
    for glob in self.props.globs.list[:-2]
      let result += [['Comment', glob.opt . shellescape(glob.str) . ' ']]
    endfor
    let last = self.props.globs.list[-1]
    let result += [['Comment', last.opt . shellescape(last.str)]]
    let result += [['Comment', ')']]
  endif

  return result
endfu

fu! s:GlobEntry.keypress(event) abort dict
  if s:List.has(self.props.keys, a:event.key) || a:event.key ==# "\<enter>"
    call self.props.dispatch({'type': 'SET_LOCATION', 'location': 'glob_input'})
    let stop_propagation = 1
    return stop_propagation
  end
endfu

fu! s:map_state_to_props(state) abort dict
  return {'globs': get(a:state, 'globs')}
endfu

fu! esearch#ui#menu#glob_entry#import() abort
  return esearch#ui#connect(s:GlobEntry, function('<SID>map_state_to_props'))
endfu
