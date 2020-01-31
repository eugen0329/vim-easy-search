if exists('b:current_syntax')
  finish
endif

syn match   es_shDerefSimple "\$\%(\h\w*\|\d\)"
syn keyword es_shKeyword     case esac do done for in if fi until while
syn region  es_shSingleQuote start=+'+ end=+'\|$+
syn region  es_shDoubleQuote start=+\%(\%(\\\\\)*\\\)\@<!"+ skip=+\\"+ end=+"\|$+

hi def link es_shDerefSimple PreProc
hi def link es_shSingleQuote String
hi def link es_shDoubleQuote String
hi def link es_shKeyword     Keyword

let b:current_syntax = 'win_context_sh'
