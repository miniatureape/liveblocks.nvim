local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  return
end

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local function liveblocks_picker(opts)
  opts = opts or {}
  local blocks = require('liveblocks').scan_all_blocks()

  if #blocks == 0 then
    vim.notify('No liveblocks found in configured root_dirs', vim.log.levels.INFO)
    return
  end

  local entries = {}
  for _, block in ipairs(blocks) do
    local rel_path = vim.fn.fnamemodify(block.source_file, ':~:.')
    local display = table.concat(block.args, ' ') .. '  ' .. rel_path .. ':' .. block.start_line

    table.insert(entries, {
      display = display,
      ordinal = table.concat(block.args, ' ') .. ' ' .. rel_path,
      filename = block.source_file,
      lnum = block.start_line,
      block = block,
    })
  end

  pickers.new(opts, {
    prompt_title = 'Liveblocks',
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.ordinal,
          filename = entry.filename,
          lnum = entry.lnum,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.grep_previewer(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          vim.cmd('edit ' .. vim.fn.fnameescape(selection.filename))
          vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
        end
      end)
      return true
    end,
  }):find()
end

return telescope.register_extension({
  exports = {
    liveblocks = liveblocks_picker,
  },
})
