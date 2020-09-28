local M = {
  ATTACHED_UI            = {},
  UI_NS                  = vim.api.nvim_create_namespace('esearch_highlights'),
  LAST_PATH_SEPARATOR_RE = "/[^/]*$",
  ABOVE_OR_BELOW_ICON_RE = '^%s+[+^_]',
  LINENR_RE              = '^%s+[+^_]?%s*%d+%s',
}


local function highlight_header(bufnr, text)
  vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchHeader', 0, 0, -1)
  local pos1, pos2 =  text:find('%d+')
  if (pos1 or 0) < 2 then return end
  -- 2 is subtracted to capture less-than-or-equl-to sign
  vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchStatistics', 0, pos1 - 2, pos2)
  pos1, pos2 =  text:find('%d+', pos2 + 1)
  if (pos1 or 0) < 1 then return end
  vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchStatistics', 0, pos1 - 1, pos2)
end

function M.highlight_ui(bufnr, from, to)
  if vim.api.nvim_call_function('bufexists', {bufnr}) == 0 then return end
  vim.api.nvim_buf_clear_namespace(bufnr, M.UI_NS, from, to)

  -- for some reason when clearing a namespace {from} acts like it's 1-indexed,
  -- so rehighlighting the previous line is needed.
  from = from - 1
  if from  < 0 then from = 0 end
  local lines = vim.api.nvim_buf_get_lines(bufnr, from, to, false)

  for i, text in ipairs(lines) do
    if i == 1 and from < 1 then
      highlight_header(bufnr, text)
    elseif text:len() == 0 then -- luacheck: ignore
      -- separators are not highlighted
    elseif text:sub(1,1) == ' ' then
      local _, pos2 =  text:find(M.LINENR_RE)
      if pos2 then
        vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchLineNr', from + i - 1 , 0, pos2)
        local _, pos1 = text:find(M.ABOVE_OR_BELOW_ICON_RE)
        if pos1 then
          vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchDiffAdd', from + i - 1 , pos1 - 1, pos1)
        end
      end
    else
      vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchFilename', from + i - 1, 0, -1)
      local col = string.find(text, M.LAST_PATH_SEPARATOR_RE) or 0
      vim.api.nvim_buf_add_highlight(bufnr, M.UI_NS, 'esearchBasename', from + i - 1, col, -1)
    end
  end
end

local function ui_cb(_event_name, bufnr, _changedtick, from, _old_to, to, _old_byte_size)
  vim.schedule(function()
    M.highlight_ui(bufnr, from, to)
  end)
end

local function detach_ui_cb(bufnr)
  M.ATTACHED_UI[bufnr] = nil
end

function M.buf_attach_ui()
  local bufnr = vim.api.nvim_get_current_buf()

  M.highlight_header(true) -- tmp measure to prevent missing highlights on live updates

  if not M.ATTACHED_UI[bufnr] then
    M.ATTACHED_UI[bufnr] = true
    vim.api.nvim_buf_attach(0, false, {on_lines=ui_cb, on_detach=detach_ui_cb})
  end
end

function M.highlight_header(instant)
  if instant then return M.highlight_ui(0, 0, 1) end -- to prevent blinking on reload

  local bufnr = vim.api.nvim_get_current_buf()
  vim.schedule(function()
    M.highlight_ui(bufnr, 0, 1)
  end)
end

return M
