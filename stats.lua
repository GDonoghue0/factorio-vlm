local stats = {}


function stats.get_research_state(force)
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

function stats.get_power_statistics(force, surface)
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

function stats.get_production_statistics(force, surface)
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


function stats.get_automation_stats(force, surface)
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

function stats.get_logistics_state(force, surface)
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

return stats