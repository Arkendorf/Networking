local network = require "network"

local client = {}

client.load = function()
  network.client.start()
end

client.update = function(dt)
  network.client.update(dt)
end

client.draw = function()
  local status = network.client.get_status()
  love.graphics.print(network.client.get_status(), 100, 0)
  if status == "disconnected" then
    for i, v in ipairs(network.client.get_addresses()) do
      love.graphics.print(tostring(i)..". "..v.ip..":"..tostring(v.port), 0, i*12)
    end
  end
end

client.keypressed = function(key)
  if key == "r" then
    network.client.refresh()
  else
    local num = tonumber(key)
    if num then
      local address = network.client.get_addresses()[num]
      if address then
        network.client.connect(address.ip, address.port)
      end
    end
  end
end

client.quit = function()
  network.client.quit()
end

return client
