-- Mod: se-blueprint-fix
-- Author: robot256
-- License: MIT
-- Description:  Detects when a blueprint is created or edited, or a copy/paste selection is made.
--               If the blueprint contains a Spaceship Clamp entity, this mod sets the blueprint 
--               grid snapping parameters so that at least one clamp will always be placed on the
--               rail grid.  If this results in a different clamp being placed off the rail grid,
--               a warning message is printed.

local function updateBlueprint(bp)
	local entities = bp.get_blueprint_entities()
	
  -- Search for clamps
  if entities and next(entities) then
		local origin
    for _,e in pairs(entities) do
			if e.name == "se-spaceship-clamp" then
        -- Origin is upper left corner of the clamp
				origin = {x=e.position.x-1, y=e.position.y-1}
        break
			end
		end
    
    -- Check if we found any clamps
    if origin then
      --game.print("Setting blueprint origin to {"..origin.x..", "..origin.y.."}")
      local grid_violated = false
      for _,e in pairs(entities) do
        e.position.x = e.position.x - origin.x
        e.position.y = e.position.y - origin.y
        -- Check that every clamp ends up on the rail grid after shifting the first clamp to origin
        if e.name == "se-spaceship-clamp" then
          if (e.position.x % 2 == 0) or (e.position.y % 2 == 0) then
            grid_violated = true
          end
        end
      end
      if grid_violated==true then
        game.print("WARNING: This blueprint has clamps aligned to different grids.")
      end
      
      -- Set the blueprint to these new positions
      bp.set_blueprint_entities(entities)
      -- Set the snap parameters
      -- If player already set snap parameters, even numbers are okay
      if (not bp.blueprint_snap_to_grid or
          bp.blueprint_snap_to_grid.x % 2 == 1 or
          bp.blueprint_snap_to_grid.y % 2 == 1) then
          
        bp.blueprint_snap_to_grid = {x=2, y=2}
        bp.blueprint_position_relative_to_grid = {x=0, y=0}  -- If grid is set to 2, grid relative position doesn't matter
        
      elseif (not bp.blueprint_position_relative_to_grid or
              bp.blueprint_position_relative_to_grid.x % 2 == 1 or
              bp.blueprint_position_relative_to_grid.y % 2 == 1) then
              
        bp.blueprint_position_relative_to_grid = {x=0, y=0}
      end
      bp.blueprint_absolute_snapping = true
      game.print("Finished making blueprint snap to Spaceship Clamp.")
    end
  end
end

--== ON_PLAYER_CONFIGURED_BLUEPRINT ==--
-- ID 70, fires when you select a blueprint to place
--== ON_PLAYER_SETUP_BLUEPRINT ==--
-- ID 68, fires when you select an area to make a blueprint or copy
-- Force Blueprints to only store empty vehicle wagons
script.on_event( {defines.events.on_player_setup_blueprint, 
                  defines.events.on_player_configured_blueprint, 
                  defines.events.on_gui_closed}, 
  function(event)
    local player = game.get_player(event.player_index)
    -- Get Blueprint from player (LuaItemStack object)
    
    
    -- Blueprint is contained here if player selects an area with the blueprint tool.
    local item1 = player.blueprint_to_setup
    
    -- Blueprint is contained here if player confirms the creation of said blueprint, or
    --   if player selects an area with the copy or paste tool.
    local item2 = player.cursor_stack
    
    -- Blueprint is contained here if player edits a blueprint from inventory and
    --   saves OR cancels the blueprint editor window.
    local item3 = event.item
    
    -- Check which one exists
    -- Need to use "valid_for_read" because "valid" returns true for empty LuaItemStack in cursor
    if item1 and item1.valid_for_read==true then
      game.print("Processing player.blueprint_to_setup")
      updateBlueprint(item1)
    elseif item2 and item2.valid_for_read==true and item2.is_blueprint==true then
      game.print("Processing player.cursor_stack")
      updateBlueprint(item2)
    elseif item3 and item3.valid_for_read==true and item3.is_blueprint==true then
      game.print("Processing event.item")
      updateBlueprint(item3)
    end
  end)
