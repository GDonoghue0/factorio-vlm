local function write_state(state)
    helpers.write_file("factorio_state.json", helpers.table_to_json(state), false) -- false means overwrite the file
end

script.on_event(defines.events.on_tick, function(event)
    -- Only run every 60 ticks (about 1 second)
    if event.tick % 60 ~= 0 then return end
    
    local player = game.players[1]
    if not player then return end
    
    local state = {
        tick = game.tick,
        player = {
            position = {
                x = player.position.x,
                y = player.position.y
            },
            character = player.character and true or false,
            inventory = {}
        },
        visible_entities = {},
        timestamp = game.tick  -- Using tick instead of os.time() since that might not be available either
    }
    
    -- Get inventory contents
    local main_inventory = player.get_main_inventory()
    if main_inventory then
        for item_name, count in pairs(main_inventory.get_contents()) do
            state.player.inventory[item_name] = count
        end
    end
    
    -- Get visible entities
    local entities = player.surface.find_entities_filtered{
        position = player.position,
        radius = 32
    }
    
    for _, entity in pairs(entities) do
        table.insert(state.visible_entities, {
            name = entity.name,
            position = {
                x = entity.position.x,
                y = entity.position.y
            },
            type = entity.type
        })
    end
    
    write_state(state)
end)