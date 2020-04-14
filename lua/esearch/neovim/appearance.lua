local M = {
    UI_NS                = vim.api.nvim_create_namespace('esearch_highlights'),
    ANNOTATIONS_NS       = vim.api.nvim_create_namespace('esearch_annotations'),
    MATCHES_NS           = vim.api.nvim_create_namespace('esearch_matches'),
    CURSOR_LINENR_NS     = vim.api.nvim_create_namespace('esearch_cursor_linenr'),
    ATTACHED_UI          = {},
    ATTACHED_MATCHES     = {},
    ATTACHED_ANNOTATIONS = {},
}

local function matches_cb(event_name, bufnr, changedtick, from, old_to, to, old_byte_size)
  if to == old_to then
    vim.api.nvim_buf_clear_namespace(0, M.MATCHES_NS, from, to)
  end
end

local function detach_matches_cb(bufnr)
  M.ATTACHED_MATCHES[bufnr] = nil
end

function M.buf_attach_matches()
  local bufnr = vim.api.nvim_get_current_buf()
  if not M.ATTACHED_MATCHES[bufnr] then
    M.ATTACHED_MATCHES[bufnr] = true
    vim.api.nvim_buf_attach(0, false, {on_lines=matches_cb, on_detach=detach_matches_cb})
  end
end

local function ui_cb(event_name, bufnr, changedtick, from, old_to, to, old_byte_size)
  local start = from - 1
  if from == 0 then start = 0 end

  vim.schedule(function()
    vim.api.nvim_buf_clear_namespace(bufnr, M.UI_NS, from, to)
    M.highlight_ui(bufnr, start, to)
  end)
end

local function detach_ui_cb(bufnr)
  M.ATTACHED_UI[bufnr] = nil
end

function M.buf_attach_ui()
  local bufnr = vim.api.nvim_get_current_buf()
  if not M.ATTACHED_UI[bufnr] then
    M.ATTACHED_UI[bufnr] = true
    vim.api.nvim_buf_attach(0, false, {on_lines=ui_cb, on_detach=detach_ui_cb})
  end
end

local function annotations_cb(event_name, bufnr, changedtick, from, old_to, to, old_byte_size)
  if to < old_to then -- if lines are removed
    vim.api.nvim_buf_clear_namespace(0, M.ANNOTATIONS_NS, from, to + 1)
  end
end

local function detach_annotations_cb(bufnr)
  M.ATTACHED_ANNOTATIONS[bufnr] = nil
end

function M.buf_attach_annotations()
  local bufnr = vim.api.nvim_get_current_buf()
  if not M.ATTACHED_ANNOTATIONS[bufnr] then
    M.ATTACHED_ANNOTATIONS[bufnr] = true
    vim.api.nvim_buf_attach(0, false, {on_lines=annotations_cb, on_detach=detach_annotations_cb})
  end
end

function M.highlight_ui(bufnr, from, to)
  local lines = vim.api.nvim_buf_get_lines(bufnr, from, to, false)
  for i, text in ipairs(lines) do
    if i == 1 and from < 1 then
      vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchHeader', 0, 0, -1)
      local pos1, pos2 =  text:find('%d+')
      vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchStatistics', 0, pos1 - 1, pos2)
      pos1, pos2 =  text:find('%d+', pos2 + 1)
      vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchStatistics', 0, pos1 - 1, pos2)
    elseif text:len() == 0 then
      -- separators are not highlighted
    elseif text:sub(1,1) == ' ' then
      pos1, pos2 =  text:find('^%s+%d+%s')
      if pos2 ~= nil then
        vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchLineNr', from + i - 1 , 0, pos2)
      end
    else
      vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchFilename', from + i - 1, 0, -1)
    end
  end
end

function M.annotate(contexts)
  for i, ctx in pairs(contexts) do
    if ctx['id'] > 0 then
      M.set_context_len_annotation(ctx['begin'], ctx['end'] - ctx['begin'] - 1)
    end
  end
end

function M.set_context_len_annotation(line, size)
  if size == 1 then
    vim.api.nvim_buf_set_virtual_text(0, M.ANNOTATIONS_NS, line, {{'(' .. size .. ' line)', 'Comment'}}, {})
  else
    vim.api.nvim_buf_set_virtual_text(0, M.ANNOTATIONS_NS, line, {{'(' .. size .. ' lines)', 'Comment'}}, {})
  end
end

function M.highlight_header()
  local bufnr = vim.api.nvim_get_current_buf()

  vim.schedule(function()
    vim.api.nvim_buf_clear_namespace(bufnr, M.UI_NS, 0, 1)
    M.highlight_ui(bufnr, 0, 1)
  end)
end

function M.highlight_cursor_linenr()
  local current_line = vim.api.nvim_get_current_line()
  local _, last_column = current_line:find('^%s+%d+%s')
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local ns = M.CURSOR_LINENR_NS
  local bufnr = vim.api.nvim_get_current_buf()

  vim.schedule(function()
    -- the condition below is needed to prevent adding highlights to buffer when leaving them
    if bufnr == vim.api.nvim_get_current_buf() then
      vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
      if last_column ~= nil then
        vim.api.nvim_buf_add_highlight(0, ns, 'esearchCursorLineNr', line, 0, last_column)
      end
    end
  end)
end

return M
