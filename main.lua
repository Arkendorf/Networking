local server = require "server"
local client = require "client"

local mode = ""

love.load = function()
end

love.update = function(dt)
  if mode == "server" then
    server.update(dt)
  elseif mode == "client" then
    client.update(dt)
  end
end

love.draw = function()
  love.graphics.print(mode)
  if mode == "server" then
    server.draw()
  elseif mode == "client" then
    client.draw()
  end
end

love.keypressed = function(key)
  if mode == "" then
    if key == "1" then
      mode = "server"
      server.load()
    elseif key == "2" then
      mode = "client"
      client.load()
    end
  elseif mode == "client" then
    client.keypressed(key)
  end
end

love.quit = function()
  if mode == "server" then
    server.quit()
  elseif mode == "client" then
    client.quit()
  end
end
