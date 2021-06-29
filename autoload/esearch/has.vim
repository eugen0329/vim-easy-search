" A module to collect one checks in a single place and also make them overridable
let g:esearch#has#nvim = has('nvim')
let g:esearch#has#windows = has('win32')
let g:esearch#has#posix_shell = !has('win32') || has('win32unix')
let g:esearch#has#timers = has('timers')
let g:esearch#has#debounce = has('timers')
let g:esearch#has#reg_recording = exists('*reg_recording')
let g:esearch#has#throttle = has('timers')
let g:esearch#has#bufadd = exists('*bufadd')
let g:esearch#has#bufload = exists('*bufload')
let g:esearch#has#meta_key = has('nvim') || has('gui_running')
let g:esearch#has#gui_colors = has('gui_running') || has('termguicolors') && &termguicolors || has('nvim') && $NVIM_TUI_ENABLE_TRUE_COLOR " from papercolors
let g:esearch#has#nvim_add_highlight = exists('*nvim_buf_clear_namespace') && exists('*nvim_buf_add_highlight')
let g:esearch#has#unicode = has('multi_byte') && (&termencoding ==# 'utf-8' || &encoding ==# 'utf-8')
let g:esearch#has#vim8_preview = exists('*popup_create')
let g:esearch#has#nvim_preview = has('nvim') && exists('*nvim_open_win')
let g:esearch#has#preview = (g:esearch#has#nvim_preview || g:esearch#has#vim8_preview)
let g:esearch#has#nvim_winid = exists('*nvim_set_current_win') && exists('*nvim_get_current_win')
let g:esearch#has#vim8_types = exists('v:true') && exists('v:false') && exists('v:null')
let g:esearch#has#nvim_jobs = has('nvim') && exists('*jobstart')
let g:esearch#has#live_update = has('timers') && exists('##CmdlineChanged')
" 7.4.1787 - fix of: channel close callback is invoked before other callbacks
let g:esearch#has#vim8_calls_close_cb_last = has('patch-7.4.1787')
let g:esearch#has#vim8_jobs = has('job') && g:esearch#has#vim8_calls_close_cb_last
let g:esearch#has#jobs = g:esearch#has#nvim_jobs || g:esearch#has#vim8_jobs
" 7.3.896 memory leaks in Lua interface
let s:fixed_lua = (v:version > 703 || v:version == 703 && has('patch896'))
let g:esearch#has#nvim_lua = has('nvim') && !g:esearch#has#windows && s:fixed_lua
let g:esearch#has#vim_lua = !has('nvim') && has('lua') && !g:esearch#has#windows && s:fixed_lua
unlet s:fixed_lua
let g:esearch#has#lua = g:esearch#has#nvim_lua || g:esearch#has#vim_lua
let g:esearch#has#virtual_cursor_linenr_highlight = !has('nvim') || g:esearch#has#nvim_add_highlight
let g:esearch#has#annotations = exists('*nvim_buf_attach') && exists('*nvim_buf_set_virtual_text') && g:esearch#has#lua
let g:esearch#has#nvim_lua_syntax = exists('*nvim_buf_attach') && g:esearch#has#nvim_add_highlight && g:esearch#has#lua
let g:esearch#has#nvim_lua_regex = g:esearch#has#nvim_lua && luaeval('not not vim.regex')
let g:esearch#has#getbufinfo_linecount = has('patch-8.2.0019')
let g:esearch#has#matchadd_win = has('patch-8.1.1084')
let g:esearch#has#globs_preview = g:esearch#has#preview
let g:esearch#has#complete_changed = exists('##CompleteChanged')
let g:esearch#has#signs_api = exists('*sign_define')
