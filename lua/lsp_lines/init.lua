local M = {}

local render = require("lsp_lines.render")

local function render_current_line(diagnostics, ns, bufnr, opts)
  local current_line_diag = {}
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1

  for _, diagnostic in pairs(diagnostics) do
    local show = diagnostic.end_lnum and (lnum >= diagnostic.lnum and lnum <= diagnostic.end_lnum)
      or (lnum == diagnostic.lnum)
    if show then
      table.insert(current_line_diag, diagnostic)
    end
  end

  render.show(ns, bufnr, current_line_diag, opts)
end

---@class SetupOpts
---@field only_current_line SetupOptsOnlyCurrentLine Options for lsp_lines only_current_line mode

---@class SetupOptsOnlyCurrentLine
---@field events string | string[] Event or event list for |nvim_create_autocmd()|

---@class Opts
---@field virtual_lines OptsVirtualLines Options for lsp_lines plugin

---@class OptsVirtualLines
---@field only_current_line boolean Only render for current line
---@field highlight_whole_line boolean Highlight empty space to the left of a diagnostic

-- Registers a wrapper-handler to render lsp lines.
-- This should usually only be called once, during initialisation.
---@param setup_opts SetupOpts
M.setup = function(setup_opts)
  setup_opts = vim.tbl_deep_extend("force", {
    only_current_line = {
      events = "CursorMoved",
    },
  }, setup_opts or {})

  -- TODO: On LSP restart (e.g.: diagnostics cleared), errors don't go away.
  vim.diagnostic.handlers.virtual_lines = {
    ---@param namespace number
    ---@param bufnr number
    ---@param diagnostics table
    ---@param opts boolean|Opts
    show = function(namespace, bufnr, diagnostics, opts)
      local ns = vim.diagnostic.get_namespace(namespace)
      if not ns.user_data.virt_lines_ns then
        ns.user_data.virt_lines_ns = vim.api.nvim_create_namespace("")
        ns.user_data.virt_lines_augroup =
          vim.api.nvim_create_augroup("LspLines_" .. ns.user_data.virt_lines_ns, { clear = true })
      end

      vim.api.nvim_clear_autocmds({ group = ns.user_data.virt_lines_augroup, buffer = bufnr })
      if opts.virtual_lines.only_current_line then
        local events = setup_opts.only_current_line.events
        vim.api.nvim_create_autocmd(events, {
          buffer = bufnr,
          callback = function()
            render_current_line(
              vim.diagnostic.get(bufnr, { namespace = namespace }),
              ns.user_data.virt_lines_ns,
              bufnr,
              opts
            )
          end,
          group = ns.user_data.virt_lines_augroup,
        })
        -- Also show diagnostics for the current line before the first CursorMoved event
        render_current_line(diagnostics, ns.user_data.virt_lines_ns, bufnr, opts)
      else
        render.show(ns.user_data.virt_lines_ns, bufnr, diagnostics, opts)
      end
    end,
    ---@param namespace number
    ---@param bufnr number
    hide = function(namespace, bufnr)
      local ns = vim.diagnostic.get_namespace(namespace)
      if ns.user_data.virt_lines_ns then
        render.hide(ns.user_data.virt_lines_ns, bufnr)
        vim.api.nvim_clear_autocmds({ group = ns.user_data.virt_lines_augroup, buffer = bufnr })
      end
    end,
  }
end

---@return boolean
M.toggle = function()
  local new_value = not vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = new_value })
  return new_value
end

return M
