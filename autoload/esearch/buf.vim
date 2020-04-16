let s:Filepath = vital#esearch#import('System.Filepath')

fu! esearch#buf#find(filename) abort
  return bufnr(esearch#buf#pattern(a:filename))
endfu

" :h file-pattern
fu! esearch#buf#pattern(filename) abort
  " Normalize the path (remove redundant path components like in foo/./bar) and
  " resolve links
  let filename = resolve(a:filename)

  " From :h file-pattern
  " Note that for all systems the '/' character is used for path separator (even
  " Windows). This was done because the backslash is difficult to use in a pattern
  " and to make the autocommands portable across different systems.
  let filename = s:Filepath.to_slash(filename)

  " From :h file-pattern:
  "   *          matches any sequence of characters; Unusual: includes path separators
  "   ?          matches any single character
  "   \?         matches a '?'
  "   .          matches a '.'
  "   ~          matches a '~'
  "   ,          separates patterns
  "   \,         matches a ','
  "   { }        like \( \) in a |pattern|
  "   ,          inside { }: like \| in a |pattern|
  "   \}         literal }
  "   \{         literal {
  "   \\\{n,m\}  like \{n,m} in a |pattern|
  "   \          special meaning like in a |pattern|
  "   [ch]       matches 'c' or 'h'
  "   [^ch]      match any character but 'c' and 'h'
  " Special file-pattern characters must be escaped: [ escapes to [[], not \[.
  let filename = escape(filename, '?*[],\')
  " replacing with \{ and \} or [{] and [}] doesn't work
  let filename = substitute(filename, '[{}]', '?', 'g')
  return '^' . filename . '$'
endfu

fu! esearch#buf#location(bufnr) abort
  for tabnr in range(1, tabpagenr('$'))
    let buflist = tabpagebuflist(tabnr)
    if index(buflist, a:bufnr) >= 0
      for winnr in range(1, tabpagewinnr(tabnr, '$'))
        if buflist[winnr - 1] == a:bufnr | return [tabnr, winnr] | endif
      endfor
    endif
  endfor

  return [0, 0]
endf
