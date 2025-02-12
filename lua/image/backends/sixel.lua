local magick = require("image/magick")

local uv = vim.uv
if uv == nil then uv = vim.loop end

---@type Backend
---@diagnostic disable-next-line: missing-fields
local backend = {
  state = nil,
  stdout = nil,
  features = {
    crop = false,
  },
}

backend.setup = function(state)
  backend.state = state
  if backend.stdout == nil then backend.stdout = uv.new_tty(1, false) end
end

local _render_sixel_str = function(s, x, y)
  vim.defer_fn(function()
    backend.stdout:write(string.format("\27[s\27[%d;%dH%s\27[u", y + 1, x + 1, s))
    backend.stdout:write(string.format("\27[s\27[%d;%dH--END--\27[u", y + 2, x + 1))
  end, 50)
end

backend.render = function(image, x, y, width, height)
  -- width is overflowed not sure why
  -- and not sure why height is the line height
  local cropped = magick.load_image(image.cropped_path)
  local pw = cropped:get_width()
  local ph = cropped:get_height()
  local aspect_ratio = pw/ph
  
  local sixel_str = vim.fn.system(string.format("img2sixel -w %d -h %d %s", height*aspect_ratio*10, height*10, image.cropped_path))
  --local sixel_str = vim.fn.system("img2sixel " .. image.cropped_path)
  vim.notify(
                  string.format("img2sixel -w %d -h %d %s", height*aspect_ratio*10, height*10, image.cropped_path),
                  vim.log.levels.WARN
                )
  vim.notify("render x:"..x .." y:".. y,vim.log.levels.WARN)
  if image.is_rendered ~= true then
    _render_sixel_str(sixel_str, x, y)
    image.is_rendered = true
    backend.state.images[image.id] = image
  end
end

--local _derender_with_sixel = function(image)
--  -- Currently not working...
--  -- Getting where the image was set to be created
--  local x = image.geometry.x
--  local y = image.geometry.y
--  -- Getting the cropped pixel geometry
--  local cropped = magick.load_image(image.cropped_path)
--  local pw = cropped:get_width()
--  local ph = cropped:get_height()
--  -- Constructing the sixel string
--  local sixel_header = "P;2;;q#0;2;0;0;0" -- Set color at index 0 to color RGB (0,0,0)
--  local blank_line = string.format("#0!%d@~", pw) -- Making a blank line
--  local blank_code = string.rep(blank_line, math.ceil(ph / 6))
--  local sixel_str = sixel_header .. blank_code .. "\\"
--
--  local f = assert(io.open("./clear_test.sixel", "wb"))
--  f:write(sixel_str)
--  f:close()
--
--  local render_str = "33;46m" .. sixel_str
--
--  _render_sixel_str(string.rep(" ", image.sixel_len), x, y)
--  _render_sixel_str(render_str, x, y)
--  image.is_rendered = false
--end

backend.clear = function(image_id, shallow)
  -- one
  if image_id then
    local image = backend.state.images[image_id]
    if not image then return end
    if not image.is_rendered then return end
    vim.notify(
                  image.cropped_path,
                  vim.log.levels.WARN
                )
    local x = image.geometry.x
    local y = image.geometry.y
    -- geometry unable to provide correct x y coords here unless we reassign it at rendering stage 
    vim.notify("clear x:"..x .." y:".. y,vim.log.levels.WARN)
    vim.defer_fn(function()
      backend.stdout:write(string.format("\27[s\27[%d;%dHtest\27[u", y+1, x + 1))
    end, 50)
    -- Clear screen
    image.is_rendered = false
    if not shallow then backend.state.images[image_id] = nil end
    return
  end

  -- all
  for id, image in pairs(backend.state.images) do
    if image.is_rendered then 
      vim.notify(
                  image.cropped_path,
                  vim.log.levels.WARN
                )
      local x = image.geometry.x
      local y = image.geometry.y
      vim.notify("clear x:"..x .." y:".. y,vim.log.levels.WARN)
      vim.defer_fn(function()
        backend.stdout:write(string.format("\27[s\27[%d;%dHtest\27[u", y+1, x + 1))
      end, 50)
      -- Clear screen
      image.is_rendered = false
    end
    
    if not shallow then backend.state.images[id] = nil end
  end
end

return backend
