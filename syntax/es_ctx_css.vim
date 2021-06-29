if exists('b:current_syntax')
  finish
endif

syn keyword es_cssTagName abbr address area a b base bdo blockquote body br button caption cite code col colgroup dd del dfn div dl dt em fieldset form h1 h2 h3 h4 h5 h6 head hr html img i iframe input ins isindex kbd label legend li link map menu meta noscript ol optgroup option p param pre q s samp script small span strong sub sup tbody td textarea tfoot th thead title tr ul u var object svg article aside audio bdi canvas command data datalist details dialog embed figcaption figure footer header hgroup keygen main mark menuitem meter nav output progress rt rp ruby section source summary time track video wbr
syn match  es_cssTagName           /\<select\>\|\<style\>\|\<table\>/
syn match  es_cssTagName           "\*"
syn match  es_cssProp              /[^-[:alnum:]][-[:alnum:]]\+\ze\s*:/
syn region es_cssAttributeSelector start="\[" end="]"
syn region es_cssString            start=+"+  skip=+\\\\\|\\"+ end=+"\|^+
syn region es_cssString            start=+'+  skip=+\\\\\|\\'+ end=+'\|^+
syn region  es_cssComment      start="//"  end="$"
syn region  es_cCssomment      start="/\*" end="\*/\|^"
" According to syntax/css.vim id cannot start with -, but this matches are
" merged for performance reasons
syn match es_cssClassOrId "[.#]-\=[A-Za-z_@][A-Za-z0-9_@-]*"
syn match es_sassVariable "$[[:alnum:]_-]\+"
" @include is highlighted as Include in the original syntax. Also a collision
" with vars in less
syn match es_sassPreProc  /@\l\+\>/

hi def link es_cssTagName           Statement
hi def link es_cssProp              StorageClass
hi def link es_cssAttributeSelector String
hi def link es_cssString            String
hi def link es_cssComment           Comment
hi def link es_cssClassOrId         Function
hi def link es_sassVariable         Identifier
hi def link es_sassPreProc          PreProc

let b:current_syntax = 'es_ctx_css'
