scriptencoding utf-8

if exists('g:WebDevIconsUnicodeDecorateFolderNodesDefaultSymbol')
  let g:esearch#unicode#dir_icon = g:WebDevIconsUnicodeDecorateFolderNodesDefaultSymbol
elseif has('osx')
  let g:esearch#unicode#dir_icon = '📂 '
else
  let g:esearch#unicode#dir_icon = '🗀 '
endif
let g:esearch#unicode#spinner = [' ◜ ', '  ◝', '  ◞', ' ◟ ']
let g:esearch#unicode#less_or_equal = '≤'
let g:esearch#unicode#slash = '∕'
let g:esearch#unicode#quote_right = '›'
let g:esearch#unicode#quote_left = '‹'
let g:esearch#unicode#ellipsis = '…'
if has('osx')
  let g:esearch#unicode#up     = '∧'
  let g:esearch#unicode#down   = '∨'
  let g:esearch#unicode#updown = '∧∨'
else
  let g:esearch#unicode#up     = '🡑'
  let g:esearch#unicode#down   = '🡓'
  let g:esearch#unicode#updown = '🡑🡓'
endif
let g:esearch#unicode#arrow_right = ' ➔'
