fu! esearch#adapter#grep#new() abort
  return copy(s:Grep)
endfu

let s:Grep = {}

if exists('g:esearch#adapter#grep#bin')
  " TODO warn deprecated
  let s:Grep.bin = g:esearch#adapter#grep#bin
else
  let s:Grep.bin = 'grep'
endif
if exists('g:esearch#adapter#grep#options')
  " TODO warn deprecated
  let s:Grep.options = g:esearch#adapter#grep#options
else
  " -I: don't match binary files
  let s:Grep.options = '-I '
endif

" Short options are used as they are supported more often than long ones

" -n: output line numbers
" -R: recursive, follow symbolic links
" -H: Print the file name for each match.
" -x: Line regexp
let s:Grep.mandatory_options = '-H -R -n'
let s:Grep.spec = {
      \   '_regex': ['literal', 'basic'],
      \   'regex': {
      \     'literal':  {'icon': '',  'option': '-F'},
      \     'basic':    {'icon': 'G', 'option': '-G'},
      \     'extended': {'icon': 'E', 'option': '-E'},
      \     'pcre':     {'icon': 'P', 'option': '-P'},
      \   },
      \   '_full': ['none', 'word'],
      \   'full': {
      \     'none':     {'icon': '',  'option': ''},
      \     'word':     {'icon': 'w', 'option': '-w'},
      \     'line':     {'icon': 'l', 'option': '-x'},
      \   },
      \   '_case': ['ignore', 'sensitive'],
      \   'case': {
      \     'ignore':    {'icon':  '', 'option': '-i'},
      \     'sensitive': {'icon': 's', 'option': ''},
      \   }
      \ }

fu! s:Grep.command(esearch, pattern, escape) abort dict
  let r = self.spec.regex[a:esearch.regex].option
  let c = self.spec.full[a:esearch.full].option
  let w = self.spec.case[a:esearch.case].option

  let joined_paths = esearch#adapter#ag_like#joined_paths(a:esearch)
  let context = printf('-A %d -B %d -C %d', a:esearch.after, a:esearch.before, a:esearch.context)

  return join([self.bin, r, c, w, self.mandatory_options, self.options, context], ' ')
        \ . ' -- ' .  a:escape(a:pattern) . ' ' . (empty(joined_paths) ? '.' : joined_paths)
endfu

fu! s:Grep.is_success(request) abort
  " 0 if a line is match, 1 if no lines matched, > 1 are for errors
  return a:request.status == 0 || a:request.status == 1
endfu
