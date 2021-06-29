let s:CurrentGlob = esearch#ui#component()

fu! s:CurrentGlob.render() abort dict
  if empty(self.props._adapter.globs) | return [] | endif

  let opt = self.props.globs.peek().icon
  let args = self.get_args()
  return [['NONE', args.(len(args) ? ' ' : '').opt." '"]]
endfu

fu! s:CurrentGlob.get_args() abort
  let state = self.__context__().store.state
  let converted = map(copy(self.props.globs.list[:-2]), 'v:val.convert(state)')
  return join(map(converted, 'v:val.opt . v:val.arg'))
endfu

let s:map_state_to_props = esearch#util#slice_factory(['globs', '_adapter'])

fu! esearch#ui#prompt#current_glob#import() abort
  return esearch#ui#connect(s:CurrentGlob, s:map_state_to_props)
endfu
