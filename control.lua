local stats = require("stats")

-- Store previous state
local previous_state = nil

-- Deep compare two tables, return true if they're different
local function is_different(t1, t2)
    if t1 == t2 then return false end
    if type(t1) ~= "table" or type(t2) ~= "table" then return true end
    
    local checked_keys = {}
    for k, v1 in pairs(t1) do
        checked_keys[k] = true
        local v2 = t2[k]
        if is_different(v1, v2) then return true end
    end
    
    -- Check for keys in t2 that aren't in t1
    for k, _ in pairs(t2) do
        if not checked_keys[k] then return true end
    end
    
    return false
end

-- Get changes between two states
local function get_state_changes(old_state, new_state)
    if not old_state then return new_state end
    
    local changes = {
        tick = new_state.tick,
        changes = {}
    }
    
    -- Check player changes
    if is_different(old_state.player.position, new_state.player.position) then
        changes.changes.player_position = new_state.player.position
    end
    
    -- Check inventory changes
    local inv_changes = {}
    local has_inv_changes = false
    for item_name, new_count in pairs(new_state.player.inventory) do
        local old_count = old_state.player.inventory[item_name]
        if old_count ~= new_count then
            inv_changes[item_name] = new_count
            has_inv_changes = true
        end
    end
    -- Check for items that were completely removed
    for item_name, old_count in pairs(old_state.player.inventory) do
        if not new_state.player.inventory[item_name] then
            inv_changes[item_name] = 0
            has_inv_changes = true
        end
    end
    if has_inv_changes then
        changes.changes.inventory = inv_changes
    end
    
    -- Check entity changes
    local old_entities = {}
    local new_entities = {}
    
    -- Index entities by position for easier comparison
    for _, entity in ipairs(old_state.visible_entities) do
        local pos_key = string.format("%d,%d", math.floor(entity.position.x), math.floor(entity.position.y))
        old_entities[pos_key] = entity
    end
    for _, entity in ipairs(new_state.visible_entities) do
        local pos_key = string.format("%d,%d", math.floor(entity.position.x), math.floor(entity.position.y))
        new_entities[pos_key] = entity
    end
    
    -- Find entity changes
    local entity_changes = {
        added = {},
        removed = {},
        modified = {}
    }
    local has_entity_changes = false
    
    -- Check for new and modified entities
    for pos_key, new_entity in pairs(new_entities) do
        local old_entity = old_entities[pos_key]
        if not old_entity then
            table.insert(entity_changes.added, new_entity)
            has_entity_changes = true
        elseif is_different(old_entity, new_entity) then
            table.insert(entity_changes.modified, new_entity)
            has_entity_changes = true
        end
    end
    
    -- Check for removed entities
    for pos_key, old_entity in pairs(old_entities) do
        if not new_entities[pos_key] then
            table.insert(entity_changes.removed, old_entity)
            has_entity_changes = true
        end
    end
    
    if has_entity_changes then
        changes.changes.entities = entity_changes
    end
    
    -- Only return changes if there are any
    return next(changes.changes) and changes or nil
end

local function get_player_actions(player)
    local actions = {
        mining = player.mining_state and {
            target = player.mining_state.name,
            position = player.mining_state.position,
            progress = player.mining_state.progress
        } or nil,
        crafting = {},
        equipment = player.character and {
            active_modules = {},
            grid_stats = {}
        } or nil,
        cursor_stack = player.cursor_stack and player.cursor_stack.valid_for_read and {
            name = player.cursor_stack.name,
            count = player.cursor_stack.count
        } or nil
    }
    
    -- Check if player has a character before accessing crafting_queue
    if player.character and player.crafting_queue then
        for i, item in pairs(player.crafting_queue) do
            table.insert(actions.crafting, {
                item = item.recipe,
                count = item.count,
                progress = item.progress
            })
        end
    end

    -- Get equipment if available
    if player.character and player.character.grid then
        local grid = player.character.grid
        for _, equipment in pairs(grid.equipment) do
            table.insert(actions.equipment.active_modules, {
                name = equipment.name,
                position = equipment.position,
                energy = equipment.energy,
                shield = equipment.shield
            })
        end
    end

    return actions
end


script.on_event(defines.events.on_tick, function(event)
    -- Only run every 60 ticks (about 1 second)
    if event.tick % 60 ~= 0 then return end
    
    local player = game.players[1]
    if not player then return end
    
    local force = player.force
    local surface = player.surface  -- Get the player's current surface
    
    -- Build current state
    local current_state = {
        tick = game.tick,
        player = {
            position = {
                x = player.position.x,
                y = player.position.y
            },
            inventory = {},
            actions = get_player_actions(player)
        },
        visible_entities = {},
        
        -- Add new state components with surface parameter
        visible_entities = {},
        automation = get_automation_stats(force, surface),
        logistics = get_logistics_state(force, surface),
        production = get_production_statistics(force, surface),
        research = get_research_state(force),
        power = get_power_statistics(force, surface),
    }
    
    -- Get inventory contents
    local main_inventory = player.get_main_inventory()
    if main_inventory then
        for item_name, count in pairs(main_inventory.get_contents()) do
            current_state.player.inventory[item_name] = count
        end
    end
    
    -- Get visible entities
    local entities = player.surface.find_entities_filtered{
        position = player.position,
        radius = 32
    }
    
    for _, entity in pairs(entities) do
        table.insert(current_state.visible_entities, {
            name = entity.name,
            position = {
                x = entity.position.x,
                y = entity.position.y
            },
            type = entity.type
        })
    end

    game.take_screenshot{
        player = player,
        resolution = {x = 1920, y = 1080},  -- 16:9 aspect ratio
        zoom = 0.75,
        path = string.format("state_%d.jpg", event.tick),
        show_gui = false,
        show_entity_info = true,
        anti_alias = false,
        quality = 80
    }
    
    -- Get delta and write if there are changes
    local changes = get_state_changes(previous_state, current_state)
    if changes then
        helpers.write_file("factorio_state_changes.json", helpers.table_to_json(changes) .. "\n", true)  -- true to append
    end
    
    -- Update previous state
    previous_state = current_state
end)

remote.add_interface("factorio_ai", {
    test_command = function()
        game.print("Remote interface is working!")
        return true
    end,

    move = function(direction)
        local player = game.players[1]
        if not player then return false end
        
        -- Set the walking state
        if direction == "north" then
            player.walking_state = {walking = true, direction = defines.direction.north}
        elseif direction == "stop" then
            player.walking_state = {walking = false}
        end
        
        return true
    end,

    execute_command = function(command)
        local player = game.players[1]
        if not player then return {success=false, error="No player"} end

        
        if command.action == "move" then
            -- Implement movement
            -- We'll need to figure out exact implementation
            return {success=true}
            
        elseif command.action == "build" then
            -- Implement building
            local success = player.surface.can_place_entity{
                name = command.entity,
                position = command.position,
                direction = command.direction,
                force = player.force
            }
            
            if success then
                player.surface.create_entity{
                    name = command.entity,
                    position = command.position,
                    direction = command.direction,
                    force = player.force
                }
            end
            
            return {success=success}
        end
        
        return {success=false, error="Unknown command"}
    end
})