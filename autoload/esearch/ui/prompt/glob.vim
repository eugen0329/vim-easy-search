let s:Log        = esearch#log#import()
let s:PathPrompt = esearch#ui#prompt#path#import()
let s:GlobPrompt = esearch#ui#component()

fu! s:GlobPrompt.render() abort dict
  if empty(self.props.globs) || empty(self.props.globs.list) | return [] | endif

  let result = []
  let globs = self.props.globs.list
  let end = len(globs) - 1
  for i in range(0, end)
    let result += [['Special', '<'.substitute(globs[i].opt, '^-*', '', '')]]
    let result += s:PathPrompt.new({'paths': esearch#shell#argv([globs[i].str]), 'escape': 0}).render()
    let result += [['Special', '>']]
    if i != end && !empty(self.props.separator)
      let result += [[self.props.normal_hl, self.props.separator]]
    endif
  endfor

  return result
endfu

let s:GlobPrompt.default_props = {'normal_hl': 'NONE', 'separator': ' '}
let s:map_state_to_props = esearch#util#slice_factory(['cwd', 'globs'])

fu! esearch#ui#prompt#glob#import() abort
  return esearch#ui#connect(s:GlobPrompt, s:map_state_to_props)
endfu
