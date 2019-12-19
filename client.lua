local enet = require "enet"
local socket = require "socket"

local client = {}

-- Set up update rate (we don't want to update every frame, as that's too intensive)
local updates_per_sec = 30
local rate = 1/updates_per_sec
local tick = 0

local broadcast_port = 11111
local client_port = 11113

local udp = false

local password = "doom"

local valid_addresses = {}

client.load = function()
  udp = socket.udp()
  udp:settimeout(0)
  udp:setsockname("0.0.0.0", client_port)
  assert(udp:setoption("broadcast", true))

  client.promote()
end

client.update = function(dt)
  tick = tick + dt
  if tick > rate then
    tick = tick - rate

    client.listen()
  end
end

client.draw = function()
  for i, v in ipairs(valid_addresses) do
    love.graphics.print(v.ip..":"..tostring(v.port), 0, i*12)
  end
end

client.keypressed = function(key)
  if key == "r" then
    client.refresh()
  else
    local num = tonumber(key)
    if num then
      local address = valid_addresses
      client.connect(address.ip, address.port)
  end
end

client.quit = function()
  udp:close()
  udp = false
end

client.promote = function()
  udp:sendto(password, "255.255.255.255", broadcast_port)
end

client.listen = function()
  local data
  repeat
    data, ip, port = udp:receivefrom()
    if data then
      table.insert(valid_addresses, {ip = ip, port = data})
    end
  until not data
end

client.refresh = function()
  valid_addresses = {}
  client.promote()
end

client.connect = function(ip, port)
end

return client
