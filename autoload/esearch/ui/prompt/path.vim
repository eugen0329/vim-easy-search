let s:Log        = esearch#log#import()
let s:PathPrompt = esearch#ui#component()

fu! s:PathPrompt.render() abort dict
  if empty(self.props.paths)
    return []
  elseif type(self.props.paths) ==# type({})
    return [['Special', self.props.paths.repr()]]
  elseif !g:esearch#has#posix_shell
    return [[self.props.normal_hl, esearch#shell#join(self.props.paths)]]
  endif

  let l:Escape = self.props.escape ? function('esearch#shell#escape') : {path -> path.str}
  let cwd = self.props.cwd
  let paths = self.props.paths
  let result = []
  let dir_icon = g:esearch#cmdline#dir_icon
  let end = len(paths) - 1
  for i in range(0, end)
    let path = paths[i]
    if path.meta
      let result += self.highlight_metachars(path)
    elseif isdirectory(esearch#util#abspath(cwd, path.str))
      let result += [['Directory', dir_icon . l:Escape(path)]]
    else
      let result += [[self.props.normal_hl, l:Escape(path)]]
    endif

    if i != end && !empty(self.props.separator)
      let result += [[self.props.normal_hl, self.props.separator]]
    endif
  endfor

  return result
endfu

fu! s:PathPrompt.highlight_metachars(path) abort dict
  let chunks = []

  for [meta, text] in a:path.tokens
    if meta
      call add(chunks, [text[0] ==# '`' ? 'Special' : 'Identifier', text])
    else
      call add(chunks, ['None', fnameescape(text)])
    endif
  endfor

  return chunks
endfu

let s:PathPrompt.default_props = {'normal_hl': 'NONE', 'separator': ' ', 'escape': 1}

let s:map_state_to_props = esearch#util#slice_factory(['cwd', 'paths'])

fu! esearch#ui#prompt#path#import() abort
  return esearch#ui#connect(s:PathPrompt, s:map_state_to_props)
endfu
