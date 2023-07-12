local M = {}

local ns = vim.api.nvim_create_namespace('sneak')

local matches

function M.before()
  matches = {}
end

function M.placematch(c, row, col)
  matches[#matches+1] = { c, row, col }
end

function M.after()
  matches = nil
end

function M.init()
  vim.api.nvim_set_decoration_provider(ns, {
    on_start = function(_, _)
      if not matches then
        return false
      end
    end,
    on_win = function(_, win, _, _, _)
      if win ~= vim.api.nvim_get_current_win() then
        return false
      end
      for _, m in ipairs(matches) do
        local c, row, col = unpack(m)
        vim.api.nvim_buf_set_extmark(0, ns, row, col, {
          priority = 1000,
          virt_text = { {c, 'SneakLabel'} },
          virt_text_pos = 'overlay',
          ephemeral = true,
        })
      end
    end
  })
end

return M
