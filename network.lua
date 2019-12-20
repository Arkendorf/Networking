local enet = require "enet"
local socket = require "socket"

local network = {
  server = {},
  client = {},
}

local updates_per_sec = 30
local rate = 1/updates_per_sec
local tick = 0

local broadcast_port = 11111
local server_port = 11112
local client_port = 11113

local udp = false
local host = false
local server = false

local status = "disconnected"

local password = "doom"

local valid_addresses = {}

network.load = function()
  udp = socket.udp()
end

network.server.start = function()
  network.load()
  udp:settimeout(0)
  udp:setsockname("0.0.0.0", broadcast_port)

  host = assert(enet.host_create("*:"..tostring(server_port)))
end

network.server.update = function(dt)
  tick = tick + dt
  if tick > rate then
    tick = tick - rate

    network.server.listen()

    network.server.update_enet(dt)
  end
end

network.server.quit = function()
  udp:close()
  udp = false

  host:flush()
  host:destroy()
  host = false
end

network.server.update_enet = function(dt)
  local event = host:service()
  if event and event.type == "receive" then
  end
end

network.server.listen = function()
  local data, ip, port
  repeat
    data, ip, port = udp:receivefrom()
    if data and data == password then
      udp:sendto(server_port, ip, port)
    end
  until not data
end

network.server.send = function(event, data, peer)
  peer:send(network.format(event, data))
end

network.server.send_to_all = function(event, data)
  host:broadcast(network.format(event, data))
end

network.client.start = function()
  status = "disconnected"

  udp = socket.udp()
  udp:settimeout(0)
  udp:setsockname("0.0.0.0", client_port)
  assert(udp:setoption("broadcast", true))

  network.client.promote()
end

network.client.update = function(dt)
  tick = tick + dt
  if tick > rate then
    tick = tick - rate

    if status == "disconnected" then
      network.client.listen()
    else
      network.client.update_enet(dt)
    end
  end
end

network.client.quit = function()
  if status == "disconnected" then
    network.client.close_udp()
  else
    network.client.close_enet()
  end
end

network.client.update_enet = function(dt)
  local event = host:service()
  if event then
    if event.type == "connect" then
      status = "connected"
    end
  end
end

network.client.close_udp = function()
  udp:close()
  udp = false
end

network.client.close_enet = function()
  server:disconnect()
  host:flush()
  host:destroy()
  server = false
  host = false
end

network.client.promote = function()
  udp:sendto(password, "255.255.255.255", broadcast_port)
end

network.client.listen = function()
  local data
  repeat
    data, ip, port = udp:receivefrom()
    if data then
      table.insert(valid_addresses, {ip = ip, port = data})
    end
  until not data
end

network.client.refresh = function()
  valid_addresses = {}
  network.client.promote()
end

network.client.connect = function(ip, port)
  host = enet.host_create()
  server = host:connect(ip..":"..tostring(port))

  if server then
    status = "connecting"
    network.client.close_udp()
    return true
  else
    return false
  end
end

network.client.get_addresses = function()
  return valid_addresses
end

network.client.get_status = function()
  return status
end



network.format = function(event, data)
  return {event, data}
end

return network
