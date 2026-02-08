local M = {}

M.config = {
  aliases             = {},
  root_dirs           = {},
  blocks_dir          = 'liveblocks',
  fence_str           = 'lb',
  folding             = true,
}

function M.setup(opts)
  opts = opts or {}
  M.config.aliases = opts.aliases or {}
  M.config.root_dirs = opts.root_dirs or {}
  M.config.blocks_dir = opts.blocks_dir or 'liveblocks'
  M.config.debug = opts.debug or false
  if opts.folding ~= nil then
    M.config.folding = opts.folding
  end
end

local function dprint(s)
    if M.config.debug then
        print(s)
    end
end

local function fence()
  local fence = {}
  fence['start'] = '[//]: #' .. M.config.fence_str
  fence['end'] = '[//]: #/' .. M.config.fence_str
  fence['start_pattern'] = '%[//%]: #' .. M.config.fence_str .. ' (.+)'
  fence['end_pattern'] = '%[//%]: #/' .. M.config.fence_str
  return fence
end

function M.setup_folding()
  if not M.config.folding then
    return
  end
  local f = fence()
  vim.wo.foldmethod = 'marker'
  vim.wo.foldmarker = f['start'] .. ',' .. f['end']
end

-- Insert a blank live block fence
function M.create_liveblock()
    dprint('Created liveblock')
    -- Insert lines below the current cursor line
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] -- 1-indexed line
    local fence = fence()
    vim.api.nvim_buf_set_lines(
        0,
        row - 1, row - 1,
        false,
        { fence['start'], fence['end'] }
    )
end

-- Wrap visual selection with liveblock fences
function M.wrap_selection(start_line, end_line)
    dprint('Wrapping selection with liveblock')
    local fence = fence()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Insert end fence after selection (do this first to preserve line numbers)
    vim.api.nvim_buf_set_lines(bufnr, end_line, end_line, false, { fence['end'] })
    -- Insert start fence before selection with a trailing space for the block name
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, start_line - 1, false, { fence['start'] .. ' ' })

    -- Move cursor to start fence line and enter insert mode at end of line
    vim.api.nvim_win_set_cursor(0, { start_line, 0 })
    vim.cmd('startinsert!')
end

local function is_in_allowed_directory()
  if #M.config.root_dirs == 0 then
    return true
  end

  local bufpath = vim.api.nvim_buf_get_name(0)
  for _, root_dir in ipairs(M.config.root_dirs) do
    local expanded_root = vim.fn.expand(root_dir)
    if vim.startswith(bufpath, expanded_root) then
      return true
    end
  end

  dprint('Not in an allowed directory')
  return false
end

local function find_local_project_dir(bufpath)
  for _, root_dir in ipairs(M.config.root_dirs) do
    local expanded_root = vim.fn.expand(root_dir)
    if vim.startswith(bufpath, expanded_root) then
        dprint('Found local project directory at ' .. expanded_root)
        return expanded_root
    end
  end
  dprint('Did not find local project directory')
  return false
end

local function resolve_path(rel_path)
  if M.config.aliases[rel_path] then
    path = M.config.aliases[rel_path]
  end

  -- If path is actually absolute return path
  if vim.startswith(rel_path, '/') then
      return rel_path
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local curfile = vim.api.nvim_buf_get_name(bufnr)

  -- check that this current file is in a configured project directory
  local project_root = find_local_project_dir(curfile)

  if not project_root then
    vim.notify('Block is not in an allowed project directory. Please add to `root_dirs` config', vim.log.levels.WARN)
    return false
  end

  -- block `foo` is stored at the project_root of the current file
  -- + the configured name for blocks, plus `foo`
  return project_root .. '/' .. M.config.blocks_dir .. '/' .. rel_path
end

local function parse_liveblocks(lines)
  dprint('parsing liveblocks')
  local blocks = {}
  local i = 1
  local fence = fence()

  while i <= #lines do
    local line = lines[i]
    local start_pattern = fence['start_pattern']
    local end_pattern = fence['end_pattern']
    local match = line:match(start_pattern)

    if match then
      dprint('found start of block')
      local block_content = {}
      local start_line = i
      local args = vim.split(vim.trim(match), '%s+')

      local end_line = nil
      for j = i + 1, #lines do
        if lines[j]:match(end_pattern) then
          dprint('found end of block')
          end_line = j
          break
        else
          table.insert(block_content, lines[j])
        end
      end
      local full_path = ''

      dprint('arg ' .. args[1])
      full_path = resolve_path(args[1])

      if end_line then
        table.insert(blocks, {
          start_line = start_line,
          end_line = end_line,
          args = args,
          content = block_content,
          full_path = full_path
        })
        i = end_line + 1
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end

  return blocks
end

local function read_file_content(rel_filepath)
  local full_path = resolve_path(rel_filepath)
  if not full_path then
    vim.notify(
        'Liveblocks: Could not resolve filepath for block ' .. rel_filepath,
        vim.log.levels.WARN
    )
    return false
  end

  local file = io.open(full_path, 'r')
  if not file then
    local content = {}
    return content
  end

  local content = file:read('*all')
  file:close()

  local lines = vim.split(content, '\n', { plain = true })
  if lines[#lines] == '' then
    table.remove(lines, #lines)
  end

  return lines
end

local function is_command_block(args)
  return args[1] == 'cmd' or (args[1] and args[1]:sub(1, 1) == '!')
end

local function get_command_args(args)
  if args[1] == 'cmd' then
    local cmd_args = {}
    for i = 2, #args do
      table.insert(cmd_args, args[i])
    end
    return cmd_args
  elseif args[1] and args[1]:sub(1, 1) == '!' then
    local cmd_args = { args[1]:sub(2) }
    for i = 2, #args do
      table.insert(cmd_args, args[i])
    end
    return cmd_args
  end
  return nil
end

local function escape_arg(arg)
  local expanded = arg:gsub('^~/', vim.fn.expand('~') .. '/')
  expanded = expanded:gsub('^~$', vim.fn.expand('~'))
  return vim.fn.shellescape(expanded)
end

local function execute_command(args)
  -- Split args into pipeline stages on | tokens, escaping args within each stage
  local stages = {{}}
  for _, arg in ipairs(args) do
    if arg == '|' then
      table.insert(stages, {})
    else
      table.insert(stages[#stages], escape_arg(arg))
    end
  end

  local escaped_stages = {}
  for _, stage in ipairs(stages) do
    table.insert(escaped_stages, table.concat(stage, ' '))
  end

  local cmd = table.concat(escaped_stages, ' | ')
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return nil, 'Command failed (exit ' .. vim.v.shell_error .. '): ' .. cmd
  end

  local lines = vim.split(output, '\n', { plain = true })
  if lines[#lines] == '' then
    table.remove(lines, #lines)
  end

  return lines
end

local function get_block_content(args)
  if #args == 0 then
    return nil, 'No arguments provided'
  end

  if is_command_block(args) then
    return execute_command(get_command_args(args))
  else
    local filepath = table.concat(args, ' ')
    return read_file_content(filepath)
  end
end

local function equivalent(t1, t2)
  -- TODO: Account for empty space at beginning and end
  if (table.getn(t1) ~= table.getn(t2)) then
      return false
  end
  for i,v in ipairs(t1) do
      if v ~= t2[i] then
          return false
      end
  end
  return true
end

function M.refresh_liveblocks()
  if not is_in_allowed_directory() then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = parse_liveblocks(lines)

  if #blocks == 0 then
    return
  end
  dprint("refreshing blocks");

  local block_updated = false

  for i = #blocks, 1, -1 do
    dprint("iterating over block");
    local block = blocks[i]
    local content, err = get_block_content(block.args)

    if content then

-- TODO: I'm not sure about this yet.
-- If you have unsaved edits in a block, then move to another buffer with that block
-- and make and save edits there, you lose your edits when you come back the unsaved buffer
-- We could prompt. Or maybe we should save the blocks when you remove focus from a buffer?
--
--     local buffer_modified = vim.fn.getbufvar(bufnr, 'modified')
--     if buffer_modified then
--         dprint("Buffer was modified. Checking equivalence.");
--         if not equivalent(block['content'], content) then
--             dprint("Blocks are equivalent");
--             vim.ui.input({ prompt = 'liveblock ' .. block.args[1] .. ' updating in another file. Overwrite (y/n)' }, function(input)
--                if (input == 'y') then
--                  print("overwriting")
--                else
--                  print("not overwriting")
--                end
--           end)
--         end
--     end

      local start_idx = block.start_line
      local end_idx = block.end_line - 1

      vim.api.nvim_buf_set_lines(bufnr, start_idx, end_idx, false, content)
      block_updated = true
    elseif err then
      vim.notify('Liveblocks error: ' .. err, vim.log.levels.WARN)
    end
  end
  dprint("done refreshing");

  if block_updated then
    vim.cmd('silent! update')
  end
end

local function write_block_to_file(block, bufnr)
  dprint('Writing block to file');
  if is_command_block(block.args) then
    return false, 'Cannot write back to command blocks'
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local curfile = vim.api.nvim_buf_get_name(bufnr)
  local project_dir = find_local_project_dir(curfile)

  if not project_dir then
    vim.notify('Block is not in an allowed project directory. Please add to `root_dirs` config', vim.log.levels.WARN)
  end

  local filepath = table.concat(block.args, ' ')

  local resolved_path = resolve_path(filepath, project_dir)
  local full_path = vim.fn.fnamemodify(resolved_path, ':p')

  -- Ensure directory exists
  local dir = vim.fn.fnamemodify(full_path, ':h')
  vim.fn.mkdir(dir, 'p')

  local content_lines = vim.api.nvim_buf_get_lines(
    bufnr,
    block.start_line,
    block.end_line - 1,
    false
  )

  local file = io.open(full_path, 'w')
  if not file then
    return false, 'Could not write to file: ' .. full_path
  end

  file:write(table.concat(content_lines, '\n'))
  if #content_lines > 0 then
    file:write('\n')
  end
  file:close()

  return true, resolved_path
end

-- TODO probably remove this once you've tested the other functiont 
function M.write_back_all()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = parse_liveblocks(lines)

  local curfile = vim.api.nvim_buf_get_name(bufnr)
  local project_dir = find_local_project_dir(curfile)

  if not project_dir then
    vim.notify('Block is not in an allowed project directory. Please add to `root_dirs` config', vim.log.levels.WARN)
  end

  for _, block in ipairs(blocks) do
      if is_command_block(block.args) then
        vim.notify('Cannot write back to command blocks', vim.log.levels.WARN)
        return
      end

      local filepath = table.concat(block.args, ' ')
      local resolved_path = resolve_path(filepath, project_dir)
      local full_path = vim.fn.fnamemodify(resolved_path, ':p')

      local content_lines = vim.api.nvim_buf_get_lines(
        bufnr,
        block.start_line,
        block.end_line - 1,
        false
      )

      local file = io.open(full_path, 'w+')
      if not file then
        vim.notify('Could not write to file: ' .. full_path, vim.log.levels.ERROR)
        return
      end

      file:write(table.concat(content_lines, '\n'))
      if #content_lines > 0 then
        file:write('\n')
      end
      file:close()

      return
  end
end

local function get_current_block()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = parse_liveblocks(lines)

  for _, block in ipairs(blocks) do
    if cursor_line >= block.start_line and cursor_line <= block.end_line then
        return block
    end
    return false
  end
end

function M.goto()
    local current_block = get_current_block()
    dprint(vim.inspect(current_block))
    if current_block then
        dprint("goto fullpath at " .. current_block.full_path)
      vim.cmd.edit(current_block.full_path)
    end
end

function M.write_back()
  local block = get_current_block()
  if current_block then
    local success, result = write_block_to_file(block, bufnr)
    if not success then
      vim.notify('Liveblocks error: ' .. result, vim.log.levels.ERROR)
    end
  end
end

function M.write_all_blocks()
  if not is_in_allowed_directory() then
    return
  end
  dprint("Writing all blocks")

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = parse_liveblocks(lines)

  if #blocks == 0 then
    return
  end

  local written_count = 0
  local errors = {}

  for _, block in ipairs(blocks) do
    local success, result = write_block_to_file(block, bufnr)
    if success then
      written_count = written_count + 1
    elseif result ~= 'Cannot write back to command blocks' then
      table.insert(errors, result)
    end
  end
end

function M.scan_all_blocks()
  local fence = fence()
  local results = {}

  for _, root_dir in ipairs(M.config.root_dirs) do
    local expanded_root = vim.fn.expand(root_dir)
    local md_files = vim.fn.globpath(expanded_root, '**/*.md', false, true)

    for _, filepath in ipairs(md_files) do
      local file = io.open(filepath, 'r')
      if file then
        local content = file:read('*all')
        file:close()

        local lines = vim.split(content, '\n', { plain = true })
        local i = 1

        while i <= #lines do
          local line = lines[i]
          local match = line:match(fence['start_pattern'])

          if match then
            local block_content = {}
            local start_line = i
            local args = vim.split(vim.trim(match), '%s+')
            local end_line = nil

            for j = i + 1, #lines do
              if lines[j]:match(fence['end_pattern']) then
                end_line = j
                break
              else
                table.insert(block_content, lines[j])
              end
            end

            if end_line then
              table.insert(results, {
                source_file = filepath,
                start_line = start_line,
                end_line = end_line,
                args = args,
                content = block_content,
                is_command = is_command_block(args),
              })
              i = end_line + 1
            else
              i = i + 1
            end
          else
            i = i + 1
          end
        end
      end
    end
  end

  return results
end

return M
