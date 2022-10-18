


local script_data = {
    print = nil,
    forces = {}
}

local instalise_force = function(force)
    script_data.forces[force.index] = {}
    for _, tech in pairs(force.technologies) do
        for _, effect in pairs(tech.effects) do
            if effect.type == "unlock-recipe" then
                for _, result in pairs(game.recipe_prototypes[effect.recipe].products) do
                    if game.item_prototypes[result.name] then
                        if game.item_prototypes[result.name].place_result then
                            if not script_data.forces[force.index][game.item_prototypes[result.name].place_result] then
                                script_data.forces[force.index][game.item_prototypes[result.name].place_result.name] = tech.researched
                            end
                        end
                    end
                end
            end
        end
    end
    for name, entity in pairs(game.entity_prototypes) do
        if script_data.forces[force.index][name] == nil then
            script_data.forces[force.index][name] = true
        end
    end
end

local reset_forces = function()
    script_data.forces = {}
    for force_name, force in pairs(game.forces) do
        if force.players then
            instalise_force(force)
        end
    end
end

local prototype_cache = {}
local get_prototype = function(name)
    local prototype = prototype_cache[name]
    if prototype then return prototype end
    prototype = game.entity_prototypes[name]
    prototype_cache[name] = prototype
    return prototype
end


local is_unlocked = function(entity)
    local name = entity.ghost_name
    return script_data.forces[entity.force.index][name] or false
end


local on_entity_build = function(event)
    local entity = event.created_entity or event.entity
    if not (entity and entity.valid) then return end
    local tick = event.tick
    local player_index = event.player_index

    if entity.type == "entity-ghost" then
        local name = entity.ghost_name

        if not is_unlocked(entity) then
            script_data.print = script_data.print or {}
            script_data.print[player_index] = script_data.print[player_index] or {}
            if not script_data.print[player_index][name] then
                script_data.print[player_index][name] = true
            end
            entity.destroy()
        end
    end
end

local on_tick = function(event)
    if script_data.print then
        for player_index, entities in pairs(script_data.print) do
            local player = game.get_player(player_index)
            local offset = 0
            for name, _ in pairs(entities) do
                player.create_local_flying_text
                {
                    text={"script.entity-not-unlocked", get_prototype(name).localised_name},
                    position={player.position.x, player.position.y + offset},
                    color=nil,
                    time_to_live=nil,
                    speed=nil
                }
                offset = offset - 0.3
            end
        end
    end
    script_data.print = nil
end

local on_force_created = function(event)
    instalise_force(event.force)
end

local on_forces_merging = function(event)
    script_data.forces[event.source.index] = nil
end

local on_research_finished = function(event)
    local tech = event.research
    for _, effect in pairs(tech.effects) do
        if effect.type == "unlock-recipe" then
            for _, result in pairs(game.recipe_prototypes[effect.recipe].products) do
                if game.item_prototypes[result.name] then
                    if game.item_prototypes[result.name].place_result then
                        if not script_data.forces[tech.force.index][game.item_prototypes[result.name].place_result] then
                            script_data.forces[tech.force.index][game.item_prototypes[result.name].place_result.name] = true
                        end
                    end
                end
            end
        end
    end
end

local on_research_reversed = function(event)
    script_data.forces[event.research.force.index] = nil
    instalise_force(event.research.force)
end

local on_force_reset = function(event)
    script_data.forces[event.force.index] = nil
    instalise_force(event.force)
end

local events = {
    [defines.events.on_built_entity] = on_entity_build,
    [defines.events.on_force_created] = on_force_created,
    [defines.events.on_forces_merging] = on_forces_merging,
    [defines.events.on_research_finished] = on_research_finished,
    [defines.events.on_research_reversed] = on_research_reversed,
    [defines.events.on_force_reset] = on_force_reset,
     
    [defines.events.on_tick] = on_tick,
}

local lib = {}

lib.get_events = function() return events end

lib.on_init = function()
  global.research = global.research or script_data
  reset_forces()
end

lib.on_load = function()
  script_data = global.research or script_data
end

lib.on_configuration_changed = function()
  reset_forces()
end

return lib