local M = {}

M.config = {
  aliases = {},
  root_dirs = {},
  blocks_dir = 'liveblocks',
  debug = true,
}

function M.setup(opts)
  print("setup ")
  opts = opts or {}
  M.config.aliases = opts.aliases or {}
  M.config.root_dirs = opts.root_dirs or {}
  M.config.blocks_dir = opts.blocks_dir or 'liveblocks'
  M.config.debug = opts.debug or false
end

local function printd(s)
  if M.config.debug == true then
      print(s)
  end
end

local function is_in_allowed_directory()
  printd("checking if in allowed directory")
  if #M.config.root_dirs == 0 then
    printd("no root dirs")
    return true
  end

  local bufpath = vim.api.nvim_buf_get_name(0)
  for _, root_dir in ipairs(M.config.root_dirs) do
    local expanded_root = vim.fn.expand(root_dir)
    if vim.startswith(bufpath, expanded_root) then
        printd("In allowed directory" .. bufpath)
      return true
    end
  end

    printd("Not allowed" .. bufpath)
  return false
end

local function resolve_path(path)
  if M.config.aliases[path] then
    path = M.config.aliases[path]
  end

  -- If path is not absolute, prepend blocks_dir
  if not vim.startswith(path, '/') and not vim.startswith(path, '~') then
    local cwd = vim.fn.getcwd()
    path = cwd .. '/' .. M.config.blocks_dir .. '/' .. path
  end

  return path
end

local function parse_liveblocks(lines)
        printd("parsing liveblocks")
  local blocks = {}
  local i = 1

  while i <= #lines do
    local line = lines[i]
    local start_pattern = '%[//%]:%s*#liveblock%s+(.+)'
    local match = line:match(start_pattern)

    if match then
        printd("Found match")
      local start_line = i
      local args = vim.split(vim.trim(match), '%s+')

      local end_line = nil
      for j = i + 1, #lines do
        if lines[j]:match('%[//%]:%s*#/liveblock') then
          end_line = j
          break
        end
      end

      if end_line then
        table.insert(blocks, {
          start_line = start_line,
          end_line = end_line,
          args = args,
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

local function read_file_content(filepath)
    print("reading filecontent " .. filepath)
  local resolved_path = resolve_path(filepath)
  local full_path = vim.fn.fnamemodify(resolved_path, ':p')

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

local function execute_command(args)
  local cmd = table.concat(args, ' ')
  local handle = io.popen(cmd)
  if not handle then
    return nil, 'Could not execute command: ' .. cmd
  end

  local output = handle:read('*all')
  handle:close()

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

  if args[1] == 'cmd' then
    local cmd_args = {}
    for i = 2, #args do
      table.insert(cmd_args, args[i])
    end
    return execute_command(cmd_args)
  else
    local filepath = table.concat(args, ' ')
    return read_file_content(filepath)
  end
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

  local modified = false

  for i = #blocks, 1, -1 do
    local block = blocks[i]
    local content, err = get_block_content(block.args)

    if content then
      local start_idx = block.start_line
      local end_idx = block.end_line - 1

      vim.api.nvim_buf_set_lines(bufnr, start_idx, end_idx, false, content)
      modified = true
    elseif err then
      vim.notify('Liveblocks error: ' .. err, vim.log.levels.WARN)
    end
  end

  if modified then
    vim.cmd('silent! update')
  end
end

local function write_block_to_file(block, bufnr)
  if block.args[1] == 'cmd' then
    return false, 'Cannot write back to command blocks'
  end

  local filepath = table.concat(block.args, ' ')
  local resolved_path = resolve_path(filepath)
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

  for _, block in ipairs(blocks) do
      if block.args[1] == 'cmd' then
        vim.notify('Cannot write back to command blocks', vim.log.levels.WARN)
        return
      end

      local filepath = table.concat(block.args, ' ')
      local resolved_path = resolve_path(filepath)
      local full_path = vim.fn.fnamemodify(resolved_path, ':p')
      printd("writing to " .. full_path)

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

      vim.notify('Written to ' .. resolved_path, vim.log.levels.INFO)
      return
  end
end

function M.write_back()
    printd("write back")
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = parse_liveblocks(lines)

  for _, block in ipairs(blocks) do
    if cursor_line >= block.start_line and cursor_line <= block.end_line then
      local success, result = write_block_to_file(block, bufnr)
      if success then
        vim.notify('Written to ' .. result, vim.log.levels.INFO)
      else
        vim.notify('Liveblocks error: ' .. result, vim.log.levels.ERROR)
      end
      return
    end
  end

  vim.notify('Cursor is not inside a liveblock', vim.log.levels.WARN)
end

function M.write_all_blocks()
  if not is_in_allowed_directory() then
    return
  end

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

  if #errors > 0 then
    vim.notify('Liveblocks: Written ' .. written_count .. ' blocks with ' .. #errors .. ' errors', vim.log.levels.WARN)
  elseif written_count > 0 then
    vim.notify('Liveblocks: Written ' .. written_count .. ' blocks', vim.log.levels.INFO)
  end
end

return M
