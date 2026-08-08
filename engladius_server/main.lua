io.stdout:setvbuf("no")

function get_mex(arr)
    local present = {}
    
    for _, val in ipairs(arr) do
        if val >= 0 then
            present[val] = true
        end
    end
    
    local mex = 0
    while present[mex] do
        mex = mex + 1
    end
    
    return mex
end

local enet = require("enet")
local bit = require("bit")
local server
local players = {}
local player_addr_to_id = {}
local tick_rate = 20
local tick_timer = 0
local server_tick = 1
local position_sequence = 0
local tick_delta = 1 / tick_rate
local server_fps_cap = 120
local server_fps_cap_timer = 0
local player_default_speed = 140

---@diagnostic disable-next-line: duplicate-set-field
function love.load()
    print("Engladius Server Software (ESS) version 0.0.1-dev")
    server = enet.host_create("*:9999")
    if server == nil then
        print("Server failed to create")
        love.event.quit()
    end

end


---@diagnostic disable-next-line: duplicate-set-field
function love.update(delta)

    
    
    if not server then return end -- if the server wasnt created yet then return from this function
    print(1/delta)
    local event = server:service(10)
    while event do
        if event.type == "connect" then
            local ids = {}
            for id, _ in pairs(players) do
                table.insert(ids, tonumber(id))
            end
            local mex = get_mex(ids)
            local id_str = tostring(mex)
            print("Client connected with id " .. id_str)

            -- Notify other players of new joiner
            for _, player in pairs(players) do
                player.peer:send("j" .. love.data.pack("string", "<I4ff", mex, 0.0, 0.0), 0, "reliable")
            end

            -- Notify new joiner of other players who already existed
            for player_id, player in pairs(players) do
                event.peer:send("j" .. love.data.pack("string", "<I4ff", player_id, player.x, player.y), 0, "reliable")
            end

            server:flush()

            
            players[id_str] = {
                x = 0,
                y = 0,
                peer = event.peer,
                input_frames_to_process = {},
                frozen_timer = 0,
                last_seq = nil,
                scheduled_inputs = {},
                first_input_tick = nil
            }
            player_addr_to_id[tostring(event.peer)] = id_str
        end

        if event.type == "disconnect" then
            local addr = tostring(event.peer)
            local id_str = player_addr_to_id[addr]

            print("Client disconnected with id " .. id_str)
            players[id_str] = nil
            player_addr_to_id[addr] = nil


            local id_num = tonumber(id_str)

            if id_num then
                for _, player in pairs(players) do -- Notify other players of leaving
                    player.peer:send("l" .. love.data.pack("string", "<I4", id_num), 0, "reliable")
                end
                server:flush()
            end
        end

        if event.type == "receive" then
            local addr = tostring(event.peer)
            local id_str = player_addr_to_id[addr]

            if event.data:sub(1, 1) == "p" then
                local player = players[id_str]
                if player then
                    local _, input_seq, input_byte = love.data.unpack("<i1I4I1", event.data)
                    if player.last_seq == nil then
                        player.scheduled_inputs[tostring(server_tick)] = {
                            down = bit.band(input_byte, 1) ~= 0,
                            up = bit.band(input_byte, 2) ~= 0,
                            right = bit.band(input_byte, 4) ~= 0,
                            left = bit.band(input_byte, 8) ~= 0,
                            seq = input_seq,
                        }
                        player.first_input_tick = {server = server_tick, client = input_seq}
                        
                        player.last_seq = input_seq
                    else
                        if input_seq > player.last_seq then
                            for i = player.last_seq + 1, input_seq - 1 do
                                player.scheduled_inputs[tostring(player.first_input_tick.server + (i - player.first_input_tick.client))] = {
                                    down = false,
                                    up = false,
                                    right = false,
                                    left = false,
                                    seq = i
                                }
                            end
                            player.scheduled_inputs[tostring(player.first_input_tick.server + (input_seq - player.first_input_tick.client))] = {
                                down = bit.band(input_byte, 1) ~= 0,
                                up = bit.band(input_byte, 2) ~= 0,
                                right = bit.band(input_byte, 4) ~= 0,
                                left = bit.band(input_byte, 8) ~= 0,
                                seq = input_seq
                            }
                            player.last_seq = input_seq
                        end
                    end
                    
                    
            
                
                end
            end
        end

        event = server:service()
    end


    for _, player in pairs(players) do
        player.frozen_timer = player.frozen_timer + delta
    end
    

    tick_timer = tick_timer + delta
    while tick_timer >= 1 / tick_rate do

        tick_timer = tick_timer - 1 / tick_rate

        for player_id, player in pairs(players) do

            local seq_nums = {}

            local this_tick_input = player.scheduled_inputs[tostring(server_tick)]
            player.scheduled_inputs[tostring(server_tick)] = nil

            if this_tick_input then
                
                if this_tick_input.down then
                    player.y = player.y + tick_delta * player_default_speed
                    player.frozen_timer = 0
                end
                if this_tick_input.up then
                    player.y = player.y - tick_delta * player_default_speed
                    player.frozen_timer = 0
                end
                if this_tick_input.right then
                    player.x = player.x + tick_delta * player_default_speed
                    player.frozen_timer = 0
                end
                if this_tick_input.left then
                    player.x = player.x - tick_delta * player_default_speed
                    player.frozen_timer = 0
                end
            end

            

           
        

            

            -- add player collision with each other
            for iteration = 1, 10 do
                for player_id1, player1 in pairs(players) do
                    for player_id2, player2 in pairs(players) do
                        if player_id1 ~= player_id2 then
                            local distance = math.sqrt((player1.x - player2.x) ^ 2 + (player1.y - player2.y) ^ 2)

                            local dx
                            local dy

                            if distance == 0.0 then
                                dx = 0.70710678118
                                dy = 0.70710678118
                            else
                                dx = (player2.x - player1.x) / distance
                                dy = (player2.y - player1.y) / distance
                            end

                            if distance < 20.0 then
                                player1.x = player1.x - dx * 2
                                player1.y = player1.y - dy * 2
                                player2.x = player2.x + dx * 2
                                player2.y = player2.y + dy * 2
                            end
                        end
                    end
                end

                -- make a bounding box to hold the players in

                for player_id, player in pairs(players) do
                    player.x = math.min(math.max(player.x, -1000), 1000)
                    player.y = math.min(math.max(player.y, -1000), 1000)
                end
            end

            -- increment frozen timer
            
            -- Send final positions
            
            if this_tick_input then
                player.peer:send("I" .. love.data.pack("string", "<I4ff", this_tick_input.seq, player.x, player.y), 0, "unreliable")
            end
            

            server:flush()
            player.input_frames_to_process = {}
            
        end

        
        for player_id1, player1 in pairs(players) do
            for player_id2, player2 in pairs(players) do
                if player_id1 ~= player_id2 then
                    player1.peer:send(
                        "p" .. love.data.pack("string", "<I4I4ff", player_id2, position_sequence, player2.x, player2.y),
                        0,
                        "unreliable")
                end
            end

            if player1.frozen_timer > 0.09 then
                player1.peer:send("w0", 0, "unreliable")
            else
                player1.peer:send("w1", 0, "unreliable")
            end
        end
        position_sequence = position_sequence + 1


        server_tick = server_tick + 1
        
    end

    
end