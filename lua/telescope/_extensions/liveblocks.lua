local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  return
end

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

-- Browse liveblocks used in markdown files. Default action opens the source
-- file; <C-i> inserts a fence reference at the cursor in the calling buffer.
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

  -- Remember the calling window/buf/cursor so <C-i> can insert there
  local caller_win = vim.api.nvim_get_current_win()
  local caller_buf = vim.api.nvim_get_current_buf()
  local caller_cursor = vim.api.nvim_win_get_cursor(caller_win)

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
    attach_mappings = function(prompt_bufnr, map)
      -- Default <CR>: open source file at block location
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          vim.cmd('edit ' .. vim.fn.fnameescape(selection.filename))
          vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
        end
      end)

      -- <C-i>: insert the selected block's fence at the calling cursor
      map({ 'i', 'n' }, '<C-i>', function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          local name = table.concat(selection.value.block.args, ' ')
          vim.schedule(function()
            vim.api.nvim_set_current_win(caller_win)
            local liveblocks = require('liveblocks')
            local f_start = '[//]: #' .. liveblocks.config.fence_str .. ' ' .. name
            local f_end = '[//]: #/' .. liveblocks.config.fence_str
            local r = caller_cursor[1]
            vim.api.nvim_buf_set_lines(caller_buf, r - 1, r - 1, false, { f_start, f_end })
            liveblocks.refresh_liveblocks()
          end)
        end
      end)

      return true
    end,
  }):find()
end

-- Pick from available block files in blocks_dir and insert a fence at cursor.
local function liveblocks_insert_picker(opts)
  opts = opts or {}
  local liveblocks = require('liveblocks')

  local all_names = {}
  for _, root_dir in ipairs(liveblocks.config.root_dirs) do
    local blocks_path = vim.fn.expand(root_dir) .. '/' .. liveblocks.config.blocks_dir
    local files = vim.fn.globpath(blocks_path, '**/*', false, true)
    for _, file in ipairs(files) do
      if vim.fn.isdirectory(file) == 0 then
        local rel = file:sub(#blocks_path + 2)
        table.insert(all_names, { name = rel, path = file })
      end
    end
  end

  if #all_names == 0 then
    vim.notify('No liveblocks found in configured root_dirs', vim.log.levels.INFO)
    return
  end

  local caller_win = vim.api.nvim_get_current_win()
  local caller_buf = vim.api.nvim_get_current_buf()
  local caller_cursor = vim.api.nvim_win_get_cursor(caller_win)

  pickers.new(opts, {
    prompt_title = 'Insert Liveblock',
    finder = finders.new_table({
      results = all_names,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name,
          filename = entry.path,
          lnum = 1,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.file_previewer(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          vim.schedule(function()
            vim.api.nvim_set_current_win(caller_win)
            local f_start = '[//]: #' .. liveblocks.config.fence_str .. ' ' .. selection.value.name
            local f_end = '[//]: #/' .. liveblocks.config.fence_str
            local r = caller_cursor[1]
            vim.api.nvim_buf_set_lines(caller_buf, r - 1, r - 1, false, { f_start, f_end })
            liveblocks.refresh_liveblocks()
          end)
        end
      end)
      return true
    end,
  }):find()
end

return telescope.register_extension({
  exports = {
    liveblocks = liveblocks_picker,
    insert = liveblocks_insert_picker,
  },
})
