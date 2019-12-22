local network = require "network"

local server = {}

local address = false

server.load = function()
  network.server.start()
  address = network.server.get_address()

  network.set_lenience("mouse", true)
  network.set_keys("mouse", {"x", "y"})
end

server.update = function(dt)
  local mx, my = love.mouse.getPosition()
  network.server.queue_all("mouse", {x = mx, y = my})
  network.server.update(dt)
end

server.draw = function()
  love.graphics.print(address, 100, 0)
  love.graphics.print("Number of clients: "..tostring(#network.server.get_peers()), 300, 0)
end

server.quit = function()
  network.server.quit()
end

server.keypressed = function(key)
end

return server
