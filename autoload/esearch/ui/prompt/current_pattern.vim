let s:CurrentPattern = esearch#ui#component()

fu! s:CurrentPattern.render() abort dict
  if !self.props._adapter.multi_pattern | return [] | endif

  let opt = self.props.pattern.peek().icon
  let args = self.get_args()
  return [['NONE', args.(len(args) ? ' ' : '').opt]]
endfu

fu! s:CurrentPattern.get_args() abort
  let state = self.__context__().store.state
  let converted = map(copy(self.props.pattern.list[:-2]), 'v:val.convert(state)')
  return join(map(converted, 'v:val.opt . v:val.arg'))
endfu

let s:map_state_to_props = esearch#util#slice_factory(['pattern', '_adapter'])

fu! esearch#ui#prompt#current_pattern#import() abort
  return esearch#ui#connect(s:CurrentPattern, s:map_state_to_props)
endfu
