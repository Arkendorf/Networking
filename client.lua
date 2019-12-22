local network = require "network"

local client = {}

local status = "disconnected"

local mx, my = 400, 300

client.load = function()
  network.client.start()

  network.set_keys("mouse", {"x", "y"})
end

client.update = function(dt)
  network.client.update(dt)
end

client.draw = function()
  status = network.client.get_status()
  love.graphics.print(network.client.get_status(), 100, 0)
  if status == "disconnected" then
    for i, v in ipairs(network.client.get_addresses()) do
      love.graphics.print(tostring(i)..". "..v, 0, i*12)
    end
  end

  love.graphics.circle("fill", mx, my, 16, 16)
end

client.keypressed = function(key)
  if key == "r" then
    network.client.refresh()
  elseif status == "disconnected" then
    local num = tonumber(key)
    if num then
      local address = network.client.get_addresses()[num]
      if address then
        if network.client.connect(address) then

          network.add_callback("mouse", function(data)
            mx = data.x
            my = data.y
          end)

          network.add_callback("disconnect", function()
            network.client.disconnect()
          end)

        end
      end
    end
  end
end

client.quit = function()
  network.client.quit()
end

return client
