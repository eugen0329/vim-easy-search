let s:Dict     = vital#esearch#import('Data.Dict')
let s:List     = vital#esearch#import('Data.List')
let s:Filepath = vital#esearch#import('System.Filepath')

let s:metachars = '()[]{}?*+@!$^|'
if g:esearch#has#windows " From src/vim.h
  let g:esearch#shell#esc_chars = join(uniq(split(s:metachars." \t\n*?[{`%#'\"|!<", '\zs')))
else
  let g:esearch#shell#esc_chars = join(uniq(split(s:metachars." \t\n*?[{`$\\%#'\"|!<>();&", '\zs')))
endif
let s:is_metachar = s:Dict.make_index(split(s:metachars, '\zs'))
let g:esearch#shell#metachar_re = '['.escape(s:metachars, ']').']'
let s:matachar_re = g:esearch#shell#metachar_re
let s:eval_re = '`\%(\\`\|[^`]\)*`'
let s:regular = '\%(\\.\|[^''" \t`\\'.escape(s:metachars, ']').']\)\+'
let s:sq_re   = '''\%([^'']\+\|''''\)*'''
let s:dq_re   = '"\%(\\"\|[^"]\)*"'
let s:err_re  = '[''"`]\|\\$'
" inspired by rb 3 shellwords implementation
let s:word_re = '\('.join([s:matachar_re, s:eval_re, s:regular, s:sq_re, s:dq_re, s:err_re], '\|').'\)\(\s*\)'
let s:split_dq_by_eval_re = '\('.s:eval_re.'\|[^`]*\)\zs'
let s:unmatched_backtick_re = '^`\%(\\`\|[^`]\)*$'
let s:errors = {
      \ '\': 'trailing slash',
      \ '"': 'unmatched double quote',
      \ "'": 'unmatched single quote',
      \ '`': 'unmatched backtick',
      \}

fu! esearch#shell#split(str) abort
  return g:esearch#has#posix_shell ? s:split_posix_shell(a:str) : [a:str, 0]
endfu

" @return ([{str: String, meta: Bool, tokens: [(Bool, String)]}], Error)
fu! s:split_posix_shell(str) abort
  let [argv, tokens, offset] = [[], [], matchend(a:str, '^\s*')]
  let meta = 0

  while 1
    let matches = matchlist(a:str, s:word_re, offset)[0:2]
    if empty(matches) | break | endif
    let [match, text, sep] = matches

    let err = get(s:errors, text)
    if !empty(err) | return [argv, err.' at byte '.offset] | endif

    if get(s:is_metachar, text) || text[0] ==# '`'
      call add(tokens, [1, text])
      let meta = 1
    elseif text[0] ==# '"'
      if text ==# '""'
        call add(tokens, [0, ''])
      else
        let sub = split(text[1:-2], s:split_dq_by_eval_re)
        let meta = meta || len(sub) > 1 || text[0] ==# '`'
        if sub[-1] =~# s:unmatched_backtick_re | return [argv, s:errors['`']] | endif

        let tokens += map(sub, 'v:val[0] ==# "`" ? [1, v:val] : [0, s:unescape(v:val)]')
      endif
    elseif text[0] ==# "'"
      call add(tokens, [0, substitute(text[1:-2], "''", '', 'g')])
    else
      call add(tokens, [0, s:unescape(text)])
    endif

    if !empty(sep) || offset + len(match) ==# len(a:str)
      call add(argv, s:arg(join(map(copy(tokens), 'v:val[1]'), ''), tokens, meta))
      let [tokens, meta] = [[], 0]
    endif

    let offset += len(match)
  endwhile

  return [argv, 0]
endfu

" Git grep recognizes args as <tree-or-path> -- <path>. We put everything before
" '--' except paths that look like options and can't be before '--'.
fu! esearch#shell#join_pathspec(argv) abort
  if !g:esearch#has#posix_shell " temporarty workaround for windows shell
    return  a:argv =~# ' [''"\\]\=-' ?  ' -- ' . a:argv : a:argv . ' -- '
  endif

  let [trees, pathspecs] = s:List.partition(function('s:not_option'), a:argv)
  return esearch#shell#join(trees)
        \.(empty(pathspecs) ? '' : ' -- '.esearch#shell#join(pathspecs))
endfu

fu! esearch#shell#join(argv) abort
  if !g:esearch#has#posix_shell | return a:argv | endif
  return join(map(copy(a:argv), 'esearch#shell#escape(v:val)'), ' ')
endfu

fu! esearch#shell#escape(path) abort
  if a:path.meta
    let str = join(map(copy(a:path.tokens),
          \ 'v:val[0] ? v:val[1] : escape(v:val[1], g:esearch#shell#esc_chars)'), '')
  else
    let str = escape(a:path.str, g:esearch#shell#esc_chars)
  endif
  return str =~# '^[+>]\|^-$' ? '\'.str : str
endfu

fu! esearch#shell#argv(strs) abort
  if g:esearch#has#posix_shell | return map(copy(a:strs), 's:minimized_arg(v:val)') | endif
  return join(map(copy(a:strs), 'shellescape(v:val)'))
endfu

fu! s:minimized_arg(path) abort
  if s:Filepath.is_relative(a:path) | return s:arg(a:path, [], 0) | endif
  return s:arg(fnamemodify(a:path, ':.'), [], 0)
endfu

fu! s:arg(str, tokens, meta) abort
  return {'str': a:str, 'tokens': a:tokens, 'meta': a:meta}
endfu

fu! s:not_option(p) abort
  return a:p.str[0] !=# '-'
endfu
let s:by_not_option = function('s:not_option')

fu! s:unescape(str) abort
  return substitute(a:str, '\\\(.\)', '\1', 'g')
endfu
