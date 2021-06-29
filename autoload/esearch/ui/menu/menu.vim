let s:List             = vital#esearch#import('Data.List')
let s:PathEntry        = esearch#ui#menu#path_entry#import()
let s:CaseEntry        = esearch#ui#menu#case_entry#import()
let s:RegexEntry       = esearch#ui#menu#regex_entry#import()
let s:TextobjEntry     = esearch#ui#menu#textobj_entry#import()
let s:UnsignedIntEntry = esearch#ui#menu#unsigned_int_entry#import()
let s:SearchPrompt     = esearch#ui#prompt#search#import()
let s:ContextEntry     = esearch#ui#menu#context_entry#import()
let s:BeforeEntry      = esearch#ui#menu#before_entry#import()
let s:AfterEntry       = esearch#ui#menu#after_entry#import()
let s:GlobEntry        = esearch#ui#menu#glob_entry#import()
let s:FiletypeEntry    = esearch#ui#menu#filetype_entry#import()

let s:Menu = esearch#ui#component()

" TODO sharing
let s:case_keys          = ['s', "\<c-s>"]
let s:regex_keys         = ['r', "\<c-r>"]
let s:textobj_keys       = ['t', "\<c-t>"]
let s:path_keys          = ['p', "\<c-p>"]
let s:filetype_keys      = ['f', "\<c-f>"]
let s:glob_keys          = ['g', "\<c-g>"]
let s:after_keys         = ['a', 'A']
let s:before_keys        = ['b', 'B']
let s:context_keys       = ['c', 'C']
let s:unsigned_int_keys = ["\<c-a>", "\<c-x>", "\<enter>", "\<left>", "\<right>", "\<c-h>"]

let s:keys = s:case_keys + s:regex_keys + s:textobj_keys + s:path_keys + s:filetype_keys + s:glob_keys
      \ + s:after_keys + s:before_keys + s:context_keys + ["\<enter>", "\<del>", "\<bs>", '+', '-'] + s:unsigned_int_keys
      \ + map(range(0, 9), 'string(v:val)')

fu! s:Menu.new(props) abort dict
  let new = extend(copy(self), {'props': a:props})
  let adapter = a:props._adapter

  let i = esearch#util#counter()
  let new.items = []
  if !empty(adapter.case)      | let new.items += [s:CaseEntry.new({'i':     i.next(), 'keys': s:case_keys})]     | endif
  if !empty(adapter.regex)     | let new.items += [s:RegexEntry.new({'i':    i.next(), 'keys': s:regex_keys})]    | endif
  if !empty(adapter.textobj)   | let new.items += [s:TextobjEntry.new({'i':  i.next(), 'keys': s:textobj_keys})]  | endif
  if !empty(adapter.filetypes) | let new.items += [s:FiletypeEntry.new({'i': i.next(), 'keys': s:filetype_keys})] | endif
  let new.items += [s:PathEntry.new({'i': i.next(), 'keys': s:path_keys})]
  if !empty(adapter.globs)    | let new.items += [s:GlobEntry.new({'i':  i.next(), 'keys': s:glob_keys})] | endif
  if !empty(adapter.before)   | let new.items += [s:BeforeEntry.new({'i':  i.next()})] | endif
  if !empty(adapter.after)    | let new.items += [s:AfterEntry.new({'i':   i.next()})] | endif
  if !empty(adapter.context)  | let new.items += [s:ContextEntry.new({'i': i.next()})] | endif

  let new.prompt = s:SearchPrompt.new()
  let text_height = esearch#ui#height(new.prompt.render() + [['', a:props.cmdline]])
  let new.height = len(new.items) + text_height

  return new
endfu

fu! s:Menu.render() abort dict
  let result = []
  for i in range(0, len(self.items)-1)
    let result += (self.props.cursor ==# i ? [['Function', '> ']] : [['NONE', '  ']])
    let result += self.items[i].render()
    let result += [['NONE', "\n"]]
  endfor
  let result += self.prompt.render()
  let result += [['NONE', self.props.cmdline]]

  return result
endfu

fu! s:Menu.keypress(event) abort dict
  let stop_propagation = 0
  let key = a:event.key

  if !s:List.has(s:keys, key)
    " TODO show an error
    return stop_propagation
  endif

  if key ==# "\<enter>"
    return self.items[self.props.cursor].keypress(a:event)
  end

  for item in self.items
    let stop_propagation = item.keypress(a:event)

    if stop_propagation
      call self.props.dispatch({'type': 'SET_CURSOR', 'cursor': item.props.i})
      break
    endif
  endfor

  return stop_propagation
endfu

let s:map_state_to_props = esearch#util#slice_factory(['cmdline', 'after', 'before', 'context', '_adapter'])

fu! esearch#ui#menu#menu#import() abort
  return esearch#ui#connect(s:Menu, s:map_state_to_props)
endfu
