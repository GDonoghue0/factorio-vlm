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


local function get_research_state(force)
    local research = {
        current_research = nil,
        progress = 0,
        completed_techs = {},
        available_techs = {}
    }
    
    -- Current research
    if force.current_research then
        research.current_research = {
            name = force.current_research.name,
            progress = force.research_progress,
            level = force.current_research.level
        }
    end
    
    -- Get completed technologies
    for name, tech in pairs(force.technologies) do
        if tech.researched then
            research.completed_techs[name] = {
                level = tech.level,
                completed_at = game.tick -- Could be useful for tracking research order
            }
        elseif tech.enabled then
            -- Track available but not yet researched techs
            research.available_techs[name] = {
                level = tech.level,
                prerequisites = tech.prerequisites
            }
        end
    end
    
    return research
end

local function get_power_statistics(force, surface)
    local power_stats = {
        networks = {},
        total_consumption = 0,
        total_production = 0,
        accumulator_charge = 0  -- This will come from storage stats
    }
    
    -- Find all electric poles on the surface
    local poles = surface.find_entities_filtered{
        type = "electric-pole"
    }
    
    -- Track which networks we've already processed
    local processed_networks = {}
    
    for _, pole in pairs(poles) do
        local network_id = pole.electric_network_id
        if network_id and not processed_networks[network_id] then
            processed_networks[network_id] = true
            
            if pole.electric_network_statistics then
                local stats = pole.electric_network_statistics
                
                -- For electric networks:
                -- input_counts = consumption
                -- output_counts = production
                -- storage_counts = accumulator charge
                local network_stats = {
                    consumption = {},
                    production = {},
                    accumulator = {}
                }
                
                -- Get consumption (input counts)
                for name, count in pairs(stats.input_counts) do
                    network_stats.consumption[name] = count
                    power_stats.total_consumption = power_stats.total_consumption + count
                end
                
                -- Get production (output counts)
                for name, count in pairs(stats.output_counts) do
                    network_stats.production[name] = count
                    power_stats.total_production = power_stats.total_production + count
                end
                
                -- Get accumulator charge (storage counts)
                if stats.storage_counts then
                    for name, count in pairs(stats.storage_counts) do
                        network_stats.accumulator[name] = count
                        power_stats.accumulator_charge = power_stats.accumulator_charge + count
                    end
                end
                
                power_stats.networks[network_id] = network_stats
            end
        end
    end
    
    return power_stats
end

local function get_production_statistics(force, surface)
    local stats = {
        consumption = {},  -- Will come from output_counts for items/fluids
        production = {},  -- Will come from input_counts for items/fluids
        fluids_consumed = {},
        fluids_produced = {}
    }
    
    -- Get item statistics
    local item_stats = force.get_item_production_statistics(surface)
    
    -- For items, output_counts represents consumption
    for name, count in pairs(item_stats.output_counts) do
        if count > 0 then
            stats.consumption[name] = count
        end
    end
    
    -- For items, input_counts represents production
    for name, count in pairs(item_stats.input_counts) do
        if count > 0 then
            stats.production[name] = count
        end
    end
    
    -- Get fluid statistics similarly
    local fluid_stats = force.get_fluid_production_statistics(surface)
    if fluid_stats then
        -- For fluids, output_counts represents consumption
        for name, count in pairs(fluid_stats.output_counts) do
            if count > 0 then
                stats.fluids_consumed[name] = count
            end
        end
        
        -- For fluids, input_counts represents production
        for name, count in pairs(fluid_stats.input_counts) do
            if count > 0 then
                stats.fluids_produced[name] = count
            end
        end
    end
    
    return stats
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

local function get_automation_stats(force, surface)
    local stats = {
        assemblers = {},
        miners = {},
        inserters = {},
        belts = {}
    }
    
    -- Track automated production
    local entities = surface.find_entities_filtered{
        type = {"assembling-machine", "mining-drill", "inserter", "transport-belt"}
    }
    
    for _, entity in pairs(entities) do
        if entity.type == "assembling-machine" then
            table.insert(stats.assemblers, {
                name = entity.name,
                position = entity.position,
                recipe = entity.get_recipe(),
                status = entity.status,
                productivity = entity.productivity_bonus
            })
        elseif entity.type == "mining-drill" then
            table.insert(stats.miners, {
                name = entity.name,
                position = entity.position,
                mining_target = entity.mining_target and entity.mining_target.name,
                status = entity.status
            })
        end
    end
    
    return stats
end

local function get_logistics_state(force, surface)
    local logistics = {
        networks = {},
        storage = {},
        requests = {}
    }

    -- Ensure that force.logistic_networks and the specific surface index exist
    if force.logistic_networks and force.logistic_networks[surface.index] then
        for _, network in pairs(force.logistic_networks[surface.index]) do
            table.insert(logistics.networks, {
                cell_count = network.cell_count,
                robot_count = network.robot_count,
                available_robots = network.available_logistic_robots,
                all_construction_robots = network.all_construction_robots
            })
        end
    end

    return logistics
end



-- Pattern detection for common structures
local function detect_belt_line(entities, start_entity)
    if start_entity.name ~= "transport-belt" then return nil end
    
    local pattern = {
        type = "belt_line",
        start_pos = start_entity.position,
        direction = start_entity.direction,
        length = 1
    }
    
    local current_pos = {x = start_entity.position.x, y = start_entity.position.y}
    local dx, dy = 0, 0
    
    -- Determine direction vector based on belt direction
    if start_entity.direction == defines.direction.north then dy = -1
    elseif start_entity.direction == defines.direction.south then dy = 1
    elseif start_entity.direction == defines.direction.east then dx = 1
    elseif start_entity.direction == defines.direction.west then dx = -1 end
    
    -- Look for consecutive belts
    while true do
        current_pos.x = current_pos.x + dx
        current_pos.y = current_pos.y + dy
        
        local next_entity = find_entity_at_position(entities, current_pos)
        if not next_entity or 
           next_entity.name ~= "transport-belt" or 
           next_entity.direction ~= start_entity.direction then
            break
        end
        
        pattern.length = pattern.length + 1
    end
    
    return pattern.length > 2 and pattern or nil
end

local function detect_mining_array(entities, start_entity)
    if start_entity.name ~= "electric-mining-drill" and 
       start_entity.name ~= "burner-mining-drill" then 
        return nil 
    end
    
    local pattern = {
        type = "mining_array",
        start_pos = start_entity.position,
        drill_type = start_entity.name,
        rows = 1,
        cols = 1
    }
    
    -- Look for rectangular array of drills
    local current_pos = {x = start_entity.position.x, y = start_entity.position.y}
    local drill_size = 3  -- Mining drills are 3x3
    
    -- Find width (columns)
    while true do
        current_pos.x = current_pos.x + drill_size
        local next_entity = find_entity_at_position(entities, current_pos)
        if not next_entity or next_entity.name ~= start_entity.name then
            break
        end
        pattern.cols = pattern.cols + 1
    end
    
    -- Find height (rows)
    current_pos = {x = start_entity.position.x, y = start_entity.position.y}
    while true do
        current_pos.y = current_pos.y + drill_size
        local next_entity = find_entity_at_position(entities, current_pos)
        if not next_entity or next_entity.name ~= start_entity.name then
            break
        end
        pattern.rows = pattern.rows + 1
    end
    
    return (pattern.rows > 1 or pattern.cols > 1) and pattern or nil
end

local function find_entity_at_position(entities, pos)
    for _, entity in pairs(entities) do
        if math.abs(entity.position.x - pos.x) < 0.1 and 
           math.abs(entity.position.y - pos.y) < 0.1 then
            return entity
        end
    end
    return nil
end

-- Modify the get_state_changes function to use pattern compression
local function get_compressed_entities(entities)
    local compressed = {}
    local used_entities = {}
    
    -- First pass: detect patterns
    for _, entity in pairs(entities) do
        if not used_entities[entity] then
            -- Try detecting each pattern type
            local pattern = detect_belt_line(entities, entity)
                        or detect_mining_array(entities, entity)
            
            if pattern then
                table.insert(compressed, pattern)
                -- Mark all entities in the pattern as used
                mark_pattern_entities_as_used(entities, pattern, used_entities)
            else
                -- If no pattern found, add individual entity
                table.insert(compressed, entity)
                used_entities[entity] = true
            end
        end
    end
    
    return compressed
end

local function mark_pattern_entities_as_used(entities, pattern, used_entities)
    if pattern.type == "belt_line" then
        local dx, dy = 0, 0
        if pattern.direction == defines.direction.north then dy = -1
        elseif pattern.direction == defines.direction.south then dy = 1
        elseif pattern.direction == defines.direction.east then dx = 1
        elseif pattern.direction == defines.direction.west then dx = -1 end
        
        local current_pos = {x = pattern.start_pos.x, y = pattern.start_pos.y}
        for i = 1, pattern.length do
            local entity = find_entity_at_position(entities, current_pos)
            if entity then used_entities[entity] = true end
            current_pos.x = current_pos.x + dx
            current_pos.y = current_pos.y + dy
        end
    elseif pattern.type == "mining_array" then
        local drill_size = 3
        for row = 0, pattern.rows - 1 do
            for col = 0, pattern.cols - 1 do
                local pos = {
                    x = pattern.start_pos.x + (col * drill_size),
                    y = pattern.start_pos.y + (row * drill_size)
                }
                local entity = find_entity_at_position(entities, pos)
                if entity then used_entities[entity] = true end
            end
        end
    end
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