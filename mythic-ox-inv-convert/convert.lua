--[[
    Mythic Inventory to ox_inventory Converter
    This script converts mythic-inventory items to ox_inventory format
    
    Usage:
    1. Place this script in your mythic-inventory folder
    2. Run the script to generate ox_inventory items.lua
    3. Copy the generated content to your ox_inventory/items.lua file
    4. Make sure the convert.lua is running on the server-side of mythic-inventory
]]

-- Items are already loaded in _itemsSource from mythic-inventory

-- Type mappings from mythic to ox_inventory
local typeMappings = {
    [1] = "consumable",    -- consumable
    [2] = "weapon",        -- weapon
    [3] = "tool",          -- tool
    [4] = "crafting",      -- crafting ingredient
    [5] = "collectable",   -- collectable
    [6] = "junk",          -- junk
    [7] = "misc",          -- unknown/misc
    [8] = "evidence",      -- evidence
    [9] = "ammo",          -- ammo
    [10] = "container",    -- container
    [11] = "gem",          -- gem
    [12] = "drug",         -- paraphernalia
    [13] = "clothing",     -- wearable
    [14] = "contraband",   -- contraband
    [15] = "accessory",    -- gang chain
    [16] = "attachment",   -- weapon attachment
    [17] = "schematic"     -- schematic
}

-- Animation mappings
local animMappings = {
    ["water"] = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
    ["eat"] = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' },
    ["donut"] = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' },
    ["egobar"] = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' },
    ["ifak"] = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
    ["firstaid"] = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
    ["adjust"] = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
    ["smoking"] = { dict = 'WORLD_HUMAN_SMOKING', clip = nil }
}

-- Prop mappings
local propMappings = {
    ["water"] = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
    ["burger"] = { model = `prop_cs_burger_01`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) },
    ["donut"] = { model = `prop_ld_snack_01`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) },
    ["cigarette"] = { model = `prop_cs_ciggy_01`, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
    ["bandage"] = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) }
}

-- Status mappings
local statusMappings = {
    ["PLAYER_HUNGER"] = "hunger",
    ["PLAYER_THIRST"] = "thirst",
    ["PLAYER_STRESS"] = "stress"
}

-- Function to safely convert table data to string
local function safeTableToString(tbl, indent)
    indent = indent or 0
    local spaces = string.rep("\t", indent)
    local result = "{\n"
    
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            result = result .. spaces .. string.format("\t%s = %s,\n", k, safeTableToString(v, indent + 1))
        elseif type(v) == "string" then
            result = result .. spaces .. string.format("\t%s = '%s',\n", k, v)
        elseif type(v) == "function" then
            result = result .. spaces .. string.format("\t%s = function() -- function removed\n", k)
        else
            result = result .. spaces .. string.format("\t%s = %s,\n", k, tostring(v))
        end
    end
    
    result = result .. spaces .. "}"
    return result
end

-- Function to safely output a property value
local function safeOutputProperty(value, propertyName, itemName)
    if type(value) == "string" then
        return string.format("'%s'", value)
    elseif type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    elseif type(value) == "table" then
        -- Check if it's a simple table with basic values
        local hasComplexData = false
        for k, v in pairs(value) do
            if type(v) == "function" or type(v) == "table" then
                hasComplexData = true
                break
            end
        end
        
        if hasComplexData then
            print("Warning: Skipping complex " .. propertyName .. " for " .. itemName)
            return nil
        else
            return safeTableToString(value, 0)
        end
    else
        print("Warning: Skipping " .. propertyName .. " for " .. itemName .. " (type: " .. type(value) .. ")")
        return nil
    end
end

-- Convert mythic item to ox_inventory format
local function convertItem(item)
    local oxItem = {
        label = item.label,
        weight = item.weight or 0
    }
    
    -- Handle stackable items
    if item.isStackable and item.isStackable > 1 then
        oxItem.stack = item.isStackable
    elseif item.isStackable == false then
        oxItem.stack = false
    end
    
    -- Handle consume (for consumables)
    if item.type == 1 and item.isRemoved then
        oxItem.consume = 1
    elseif item.type == 1 and not item.isRemoved then
        oxItem.consume = 0.3
    end
    
    -- Handle close UI
    if item.closeUi == false then
        oxItem.close = false
    end
    
    -- Handle durability/degrade
    if item.durability then
        -- Convert seconds to minutes for ox_inventory
        oxItem.degrade = math.floor(item.durability / 60)
    end
    
    -- Handle client-side properties
    local client = {}
    
    -- Handle animations
    if item.animConfig and item.animConfig.anim then
        local animName = item.animConfig.anim
        if animMappings[animName] then
            client.anim = animMappings[animName]
        else
            client.anim = animName
        end
    end
    
    -- Handle props
    if item.animConfig and item.animConfig.anim then
        local animName = item.animConfig.anim
        if propMappings[animName] then
            client.prop = propMappings[animName]
        end
    end
    
    -- Handle use time
    if item.animConfig and item.animConfig.time then
        client.usetime = item.animConfig.time
    end
    
    -- Handle status effects
    if item.statusChange then
        client.status = {}
        
        if item.statusChange.Add then
            for status, value in pairs(item.statusChange.Add) do
                local oxStatus = statusMappings[status] or status:lower()
                client.status[oxStatus] = value * 1000 -- Convert to ox_inventory format
            end
        end
        
        if item.statusChange.Remove then
            for status, value in pairs(item.statusChange.Remove) do
                local oxStatus = statusMappings[status] or status:lower()
                client.status[oxStatus] = -(value * 1000) -- Negative for removal
            end
        end
    end
    
    -- Handle disable properties
    if item.animConfig and item.animConfig.pbConfig then
        local pb = item.animConfig.pbConfig
        client.disable = {
            move = pb.disableMovement or false,
            car = pb.disableCarMovement or false,
            combat = pb.disableCombat or false
        }
    end
    
    -- Handle cancel
    if item.animConfig and item.animConfig.pbConfig and item.animConfig.pbConfig.canCancel then
        client.cancel = item.animConfig.pbConfig.canCancel
    end
    
    -- Handle notifications
    if item.type == 1 then
        client.notification = string.format("You used %s", item.label)
    end
    
    -- Handle specific item types
    if item.type == 2 then -- Weapons
        if item.weapon then
            client.weapon = item.weapon
        end
        if item.ammoType and item.ammoType ~= "NONE" then
            client.ammo = item.ammoType
        end
        if item.requiresLicense then
            client.license = item.requiresLicense
        end
    elseif item.type == 9 then -- Ammo
        if item.ammoType then
            client.ammo = item.ammoType
        end
    elseif item.type == 10 then -- Containers
        if item.container then
            client.container = item.container
        end
    elseif item.type == 15 then -- Gang chains
        if item.gangChain then
            client.gangChain = item.gangChain
        end
    elseif item.type == 16 then -- Weapon attachments
        if item.component then
            -- Handle component as string or simple value
            if type(item.component) == "string" then
                client.component = item.component
            elseif type(item.component) == "number" then
                client.component = item.component
            else
                -- Skip complex component data
                print("Warning: Skipping complex component data for " .. item.name)
            end
        end
    end
    
    -- Handle special properties (only if they're simple values)
    if item.state and type(item.state) == "string" then
        client.state = item.state
    end
    
    if item.drugState and type(item.drugState) == "table" then
        -- Only include simple drugState data
        local simpleDrugState = {}
        for k, v in pairs(item.drugState) do
            if type(v) ~= "function" and type(v) ~= "table" then
                simpleDrugState[k] = v
            end
        end
        if next(simpleDrugState) then
            client.drugState = simpleDrugState
        end
    end
    
    -- Add client properties if any exist
    if next(client) then
        oxItem.client = client
    end
    
    -- Handle server-side properties
    local server = {}
    
    if item.price then
        server.price = item.price
    end
    
    if item.requiresLicense then
        server.license = item.requiresLicense
    end
    
    if item.useRestrict and type(item.useRestrict) == "table" then
        -- Only include simple restrict data
        local simpleRestrict = {}
        for k, v in pairs(item.useRestrict) do
            if type(v) ~= "function" then
                if type(v) == "table" then
                    local simpleSubTable = {}
                    for k2, v2 in pairs(v) do
                        if type(v2) ~= "function" then
                            simpleSubTable[k2] = v2
                        end
                    end
                    if next(simpleSubTable) then
                        simpleRestrict[k] = simpleSubTable
                    end
                else
                    simpleRestrict[k] = v
                end
            end
        end
        if next(simpleRestrict) then
            server.restrict = simpleRestrict
        end
    end
    
    -- Add server properties if any exist
    if next(server) then
        oxItem.server = server
    end
    
    -- Handle buttons for special items
    if item.type == 15 or item.type == 16 then -- Gang chains and attachments
        oxItem.buttons = {
            {
                label = 'Use',
                action = function(slot)
                    -- This would need to be implemented in your ox_inventory
                    print(string.format('Using %s', item.label))
                end
            }
        }
    end
    
    return oxItem
end

-- Main conversion function
local function convertItems()
    local convertedItems = {}
    
    print("Starting conversion...")
    
    -- Items are already loaded in _itemsSource from mythic-inventory
    print("Using existing _itemsSource from mythic-inventory...")
    
    -- Convert all items
    for category, items in pairs(_itemsSource) do
        print(string.format("Converting category: %s (%d items)", category, #items))
        
        for _, item in ipairs(items) do
            if item.name then
                local converted = convertItem(item)
                convertedItems[item.name] = converted
            end
        end
    end
    
    -- Generate the output
    local output = "return {\n"
    
    for itemName, itemData in pairs(convertedItems) do
        output = output .. string.format("\t['%s'] = {\n", itemName)
        
        -- Basic properties
        if itemData.label then
            output = output .. string.format("\t\tlabel = '%s',\n", itemData.label)
        end
        
        if itemData.weight then
            output = output .. string.format("\t\tweight = %s,\n", tostring(itemData.weight))
        end
        
        if itemData.stack ~= nil then
            output = output .. string.format("\t\tstack = %s,\n", tostring(itemData.stack))
        end
        
        if itemData.consume ~= nil then
            output = output .. string.format("\t\tconsume = %s,\n", tostring(itemData.consume))
        end
        
        if itemData.close ~= nil then
            output = output .. string.format("\t\tclose = %s,\n", tostring(itemData.close))
        end
        
        if itemData.degrade then
            output = output .. string.format("\t\tdegrade = %s,\n", tostring(itemData.degrade))
        end
        
        -- Client properties
        if itemData.client then
            output = output .. "\t\tclient = {\n"
            
            if itemData.client.image then
                output = output .. string.format("\t\t\timage = '%s',\n", itemData.client.image)
            end
            
            if itemData.client.status then
                output = output .. "\t\t\tstatus = {\n"
                for status, value in pairs(itemData.client.status) do
                    output = output .. string.format("\t\t\t\t%s = %s,\n", status, tostring(value))
                end
                output = output .. "\t\t\t},\n"
            end
            
            if itemData.client.anim then
                if type(itemData.client.anim) == "table" then
                    output = output .. string.format("\t\t\tanim = { dict = '%s', clip = '%s'", 
                        itemData.client.anim.dict or '', itemData.client.anim.clip or '')
                    if itemData.client.anim.flag then
                        output = output .. string.format(", flag = %s", tostring(itemData.client.anim.flag))
                    end
                    output = output .. " },\n"
                else
                    output = output .. string.format("\t\t\tanim = '%s',\n", itemData.client.anim)
                end
            end
            
            if itemData.client.prop then
                if type(itemData.client.prop) == "table" then
                    output = output .. string.format("\t\t\tprop = { model = %s, pos = vec3(%s, %s, %s), rot = vec3(%s, %s, %s) },\n",
                        tostring(itemData.client.prop.model),
                        tostring(itemData.client.prop.pos.x), tostring(itemData.client.prop.pos.y), tostring(itemData.client.prop.pos.z),
                        tostring(itemData.client.prop.rot.x), tostring(itemData.client.prop.rot.y), tostring(itemData.client.prop.rot.z))
                else
                    output = output .. string.format("\t\t\tprop = '%s',\n", itemData.client.prop)
                end
            end
            
            if itemData.client.usetime then
                output = output .. string.format("\t\t\tusetime = %s,\n", tostring(itemData.client.usetime))
            end
            
            if itemData.client.disable then
                output = output .. "\t\t\tdisable = {\n"
                for key, value in pairs(itemData.client.disable) do
                    output = output .. string.format("\t\t\t\t%s = %s,\n", key, tostring(value))
                end
                output = output .. "\t\t\t},\n"
            end
            
            if itemData.client.cancel ~= nil then
                output = output .. string.format("\t\t\tcancel = %s,\n", tostring(itemData.client.cancel))
            end
            
            if itemData.client.notification then
                output = output .. string.format("\t\t\tnotification = '%s',\n", itemData.client.notification)
            end
            
            if itemData.client.weapon then
                output = output .. string.format("\t\t\tweapon = '%s',\n", itemData.client.weapon)
            end
            
            if itemData.client.ammo then
                output = output .. string.format("\t\t\tammo = '%s',\n", itemData.client.ammo)
            end
            
            if itemData.client.license ~= nil then
                output = output .. string.format("\t\t\tlicense = %s,\n", tostring(itemData.client.license))
            end
            
            if itemData.client.container then
                output = output .. string.format("\t\t\tcontainer = %s,\n", tostring(itemData.client.container))
            end
            
            if itemData.client.gangChain then
                output = output .. string.format("\t\t\tgangChain = '%s',\n", itemData.client.gangChain)
            end
            
            if itemData.client.component then
                local safeValue = safeOutputProperty(itemData.client.component, "component", itemName)
                if safeValue then
                    output = output .. string.format("\t\t\tcomponent = %s,\n", safeValue)
                end
            end
            
            if itemData.client.state then
                output = output .. string.format("\t\t\tstate = '%s',\n", itemData.client.state)
            end
            
            if itemData.client.drugState then
                -- Handle drugState as a string or simple table
                if type(itemData.client.drugState) == "table" then
                    output = output .. "\t\t\tdrugState = {\n"
                    for k, v in pairs(itemData.client.drugState) do
                        if type(v) == "string" then
                            output = output .. string.format("\t\t\t\t%s = '%s',\n", k, v)
                        elseif type(v) == "number" or type(v) == "boolean" then
                            output = output .. string.format("\t\t\t\t%s = %s,\n", k, tostring(v))
                        else
                            -- Skip complex values
                            print("Warning: Skipping complex drugState value for " .. itemName .. "." .. k)
                        end
                    end
                    output = output .. "\t\t\t},\n"
                elseif type(itemData.client.drugState) == "string" or type(itemData.client.drugState) == "number" then
                    output = output .. string.format("\t\t\tdrugState = '%s',\n", tostring(itemData.client.drugState))
                else
                    print("Warning: Skipping complex drugState for " .. itemName)
                end
            end
            
            if itemData.client.state then
                output = output .. string.format("\t\t\tstate = '%s',\n", itemData.client.state)
            end
            
            output = output .. "\t\t},\n"
        end
        
        -- Server properties
        if itemData.server then
            output = output .. "\t\tserver = {\n"
            
            if itemData.server.price then
                output = output .. string.format("\t\t\tprice = %s,\n", tostring(itemData.server.price))
            end
            
            if itemData.server.license ~= nil then
                output = output .. string.format("\t\t\tlicense = %s,\n", tostring(itemData.server.license))
            end
            
            if itemData.server.restrict then
                -- Handle restrict as a table
                if type(itemData.server.restrict) == "table" then
                    output = output .. "\t\t\trestrict = {\n"
                    for k, v in pairs(itemData.server.restrict) do
                        if type(v) == "table" then
                            output = output .. string.format("\t\t\t\t%s = {\n", k)
                            for k2, v2 in pairs(v) do
                                if type(v2) == "string" then
                                    output = output .. string.format("\t\t\t\t\t%s = '%s',\n", k2, v2)
                                else
                                    output = output .. string.format("\t\t\t\t\t%s = %s,\n", k2, tostring(v2))
                                end
                            end
                            output = output .. "\t\t\t\t},\n"
                        elseif type(v) == "string" then
                            output = output .. string.format("\t\t\t\t%s = '%s',\n", k, v)
                        else
                            output = output .. string.format("\t\t\t\t%s = %s,\n", k, tostring(v))
                        end
                    end
                    output = output .. "\t\t\t},\n"
                else
                    output = output .. string.format("\t\t\trestrict = %s,\n", tostring(itemData.server.restrict))
                end
            end
            
            output = output .. "\t\t},\n"
        end
        
        -- Buttons
        if itemData.buttons then
            output = output .. "\t\tbuttons = {\n"
            for _, button in ipairs(itemData.buttons) do
                output = output .. "\t\t\t{\n"
                output = output .. string.format("\t\t\t\tlabel = '%s',\n", button.label)
                output = output .. "\t\t\t\taction = function(slot)\n"
                output = output .. "\t\t\t\t\tprint('Using " .. itemName .. "')\n"
                output = output .. "\t\t\t\tend\n"
                output = output .. "\t\t\t},\n"
            end
            output = output .. "\t\t},\n"
        end
        
        output = output .. "\t},\n\n"
    end
    
    output = output .. "}"
    
    -- Write to file using FiveM's SaveResourceFile
    local success = SaveResourceFile(GetCurrentResourceName(), "ox_inventory_items.lua", output, -1)
    if success then
        print("Conversion complete! Output saved to ox_inventory_items.lua")
        print(string.format("Converted %d items", #convertedItems))
        print("File saved in your mythic-inventory resource folder")
    else
        print("Error: Could not write output file")
        print("Printing to console instead:")
        print("=== CONVERTED ITEMS FOR ox_inventory ===")
        print(output)
        print("=== END CONVERTED ITEMS ===")
    end
end

-- Run the conversion
convertItems()
