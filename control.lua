-- Mod: se-blueprint-fix
-- Author: robot256
-- License: MIT
-- Description:
-- * Detects when a blueprint is created, selected from inventory, selected from a blueprint book
--     in inventory, a cut or copy selection is made, or a paste selection from the clipboard is made.
-- * If the blueprint contains a Spaceship Clamp entity, this mod sets the blueprint grid snapping
--     parameters so that at least one clamp will always be placed on the rail grid.  
-- * If this results in a different clamp being placed off the rail grid, a warning message is printed.

local DEBUG_PRINT = settings.global["se-blueprint-fix-debug-prints"].value
local DELETE_CONSOLE_OUTPUTS = settings.global["se-blueprint-fix-exclude-console-output"].value
local SNAP_CLAMPS = settings.global["se-blueprint-fix-force-snap"].value
  

local function updateBlueprint(bp)
  
	-- Search for spaceship clamps and spaceship console outputs
  local entities = bp.get_blueprint_entities()
	if entities and next(entities) then
		local origin
    for i,e in pairs(entities) do
      if DELETE_CONSOLE_OUTPUTS==true and (e.name == "se-struct-generic-output" or e.name == "se-spaceship-console-output") then
        entities[i] = nil
      end
			if SNAP_CLAMPS==true and (not origin and e.name == "se-spaceship-clamp") then
        -- Origin is upper left corner of the clamp
				origin = {x = e.position.x - 1, y = e.position.y - 1}
      end
		end
    
    -- Check if we found any clamps
    if origin then
      if origin.x ~= 0 or origin.y ~= 0 then
        if DEBUG_PRINT then game.print("Moving blueprint origin by {"..origin.x..", "..origin.y.."} tiles.") end
        
        -- Shift entities so the origin is at 0,0
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
        bp.set_blueprint_entities(entities)
        
        if grid_violated then
          game.print("WARNING: This blueprint has clamps aligned to different grids.")
        end
        
        -- Also shift blueprint tiles
        local tiles = bp.get_blueprint_tiles()
        if tiles and next(tiles) then
          for _,t in pairs(tiles) do
            t.position.x = t.position.x - origin.x
            t.position.y = t.position.y - origin.y
          end
          bp.set_blueprint_tiles(tiles)
        end
        
      else
        if DEBUG_PRINT then game.print("Origin already set correctly") end
      end
      
      -- Set the snap parameters if they are incorrect
      -- If player already set snap parameters, any even numbers are okay
      local grid = bp.blueprint_snap_to_grid
      local offset = bp.blueprint_position_relative_to_grid
      
      if not grid or grid.x % 2 == 1 or grid.y % 2 == 1 then
        if DEBUG_PRINT then game.print("Forcing blueprint grid to 2,2") end
        bp.blueprint_snap_to_grid = {x=2, y=2}
        bp.blueprint_position_relative_to_grid = {x=0, y=0}  -- If grid is set to 2, grid relative position doesn't matter
        
      elseif not offset or offset.x % 2 == 1 or offset.y % 2 == 1 then
        if DEBUG_PRINT then game.print("Forcing blueprint offset to 0,0") end
        bp.blueprint_position_relative_to_grid = {x=0, y=0}
        
      else
        if DEBUG_PRINT then game.print("Grid and offset already set correctly") end
      end
      
      bp.blueprint_absolute_snapping = true
      if DEBUG_PRINT then game.print("Finished making blueprint snap to Spaceship Clamp.") end
      
    else
      if DEBUG_PRINT then game.print("No Spaceship Clamp found in Blueprint.") end
    end
    
  elseif SNAP_CLAMPS==true then
    if DEBUG_PRINT then game.print("Blueprint is empty.") end
  end
end


-- Event triggers when player selects an area with the blueprint tool, before the blueprint GUI opens
script.on_event( defines.events.on_player_setup_blueprint, 
  function(event)
    local player = game.get_player(event.player_index)
    local item = player.blueprint_to_setup
    
    if item and item.valid_for_read then
      if DEBUG_PRINT then game.print("on_player_setup_blueprint is processing player.blueprint_to_setup") end
      updateBlueprint(item)
    end
  end
)

-- Event triggers when player closes the blueprint GUI for any reason (including if no change was made)
-- Does NOT trigger when a blueprint is modified within the blueprint library, or within a blueprint book in inventory.
script.on_event( defines.events.on_gui_closed, 
  function(event)
    local item = event.item
    
    if item and item.valid_for_read and item.is_blueprint then
      if DEBUG_PRINT then game.print("on_gui_closed is processing event.item") end
      updateBlueprint(item)
    end
  end
)

-- Event triggers when player confirms blueprint creation, after selecting copy/cut/paste tools,
--   after selecting a blueprint or book out of inventory, or after changing the active blueprint 
--   in a book selected from inventory.
-- Does NOT trigger when a blueprint or book is selected from the blueprint library.
script.on_event( defines.events.on_player_cursor_stack_changed,
  function(event)
    local player = game.get_player(event.player_index)
    local item = player.cursor_stack
    
    -- Need to use "valid_for_read" because "valid" returns true for empty LuaItemStack in cursor
    if item and item.valid_for_read then
      if item.is_blueprint then
        if DEBUG_PRINT then game.print("on_player_cursor_stack_changed is processing player.cursor_stack") end
        updateBlueprint(item)
      elseif item.is_blueprint_book then
        local active_index = item.active_index
        if active_index then
          local blueprint = item.get_inventory(defines.inventory.item_main)[active_index]
          if DEBUG_PRINT then game.print("on_player_cursor_stack_changed is processing player.cursor_stack["..active_index.."]") end
          updateBlueprint(blueprint)
        end
      end
    end
  end
)

-- Update cached mod settings
local function updateSettings(event)
  DEBUG_PRINT = settings.global["se-blueprint-fix-debug-prints"].value
  DELETE_CONSOLE_OUTPUTS = settings.global["se-blueprint-fix-exclude-console-output"].value
  SNAP_CLAMPS = settings.global["se-blueprint-fix-force-snap"].value
end
script.on_event(defines.events.on_runtime_mod_setting_changed, updateSettings)
script.on_init(updateSettings)
script.on_configuration_changed(updateSettings)
