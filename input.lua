local input = {}

-- Store recent actions in memory before writing to file
local action_buffer = {}

local function log_player_action(action)
    table.insert(action_buffer, action)
    -- Write buffer if it gets too large
    -- game.print(action_buffer)
    if #action_buffer >= 100 then
        helpers.write_file("player_actions.json", helpers.table_to_json(action_buffer) .. "\n", true)
        action_buffer = {}
    end
end

function input.track_player_input(event)
    local player = game.players[1]
    if not player then return end
    
    local base_action = {
        tick = game.tick,
        type = event.name,
        position = {x = player.position.x, y = player.position.y}
    }

    -- Handle different event types
    if event.name == defines.events.on_built_entity then
        local entity = event.entity
        base_action.action_type = "build"
        base_action.entity = {
            name = entity.name,
            position = {x = entity.position.x, y = entity.position.y},
            direction = entity.direction,
            type = entity.type
        }

    elseif event.name == defines.events.on_player_mined_entity then
        local entity = event.entity
        base_action.action_type = "mine"
        base_action.entity = {
            name = entity.name,
            position = {x = entity.position.x, y = entity.position.y}
        }

    elseif event.name == defines.events.on_player_crafted_item then
        base_action.action_type = "craft"
        base_action.item = {
            name = event.item_stack.name,
            count = event.item_stack.count
        }
        
    elseif event.name == defines.events.on_player_changed_position then
        base_action.action_type = "move"
        base_action.previous_position = event.old_position and {
            x = event.old_position.x,
            y = event.old_position.y
        }

    elseif event.name == defines.events.on_player_main_inventory_changed then
        base_action.action_type = "inventory"
        -- Capture inventory changes
        local main_inventory = player.get_main_inventory()
        if main_inventory then
            base_action.inventory = {}
            for item_name, count in pairs(main_inventory.get_contents()) do
                base_action.inventory[item_name] = count
            end
        end

    elseif event.name == defines.events.on_player_rotated_entity then
        local entity = event.entity
        base_action.action_type = "rotate"
        base_action.entity = {
            name = entity.name,
            position = {x = entity.position.x, y = entity.position.y},
            previous_direction = event.previous_direction,
            new_direction = entity.direction
        }


    elseif event.name == defines.events.on_research_started then
        base_action.action_type = "research_start"
        base_action.research = {
            name = event.research.name,
            level = event.research.level,
            progress = event.research.progress,
            remaining_cost = event.research.research_unit_count
        }

    elseif event.name == defines.events.on_research_finished then
        base_action.action_type = "research_complete"
        base_action.research = {
            name = event.research.name,
            level = event.research.level,
            effects = {} -- We'll populate this with unlocked items/recipes
        }
        
        -- Get unlocked items/recipes from the research
        local unlocked = {}
        for _, effect in pairs(event.research.effects) do
            if effect.type == "unlock-recipe" then
                table.insert(unlocked, {
                    type = "recipe",
                    name = effect.recipe
                })
            end
        end
    end
    -- base_action.research.unlocked = unlocked

    -- Add cursor position for relevant actions
    if event.cursor_position then
        base_action.cursor = {
            x = event.cursor_position.x,
            y = event.cursor_position.y
        }
    end

    log_player_action(base_action)
    -- helpers.write_file("player_actions.json", helpers.table_to_json(action_buffer) .. "\n", true)
end

return input