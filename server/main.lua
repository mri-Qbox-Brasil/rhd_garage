if not lib.checkDependency('ox_lib', '3.23.1') then error('This resource requires ox_lib version 3.23.1') end

--- callback
lib.callback.register('rhd_garage:cb_server:removeMoney', function(src, type, amount)
    return fw.rm(src, type, amount)
end)

--- Checks if the player can store the vehicle in the garage
---@return number|false entity
---@return string? error
---@return string? plate
---@return boolean? service
local function getStorableVehicle(src, netId, garage, pleaseUpdate)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
        return false, locale('notify.error.not_veh_exist')
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(entity)) > 15.0 then
        return false, locale('notify.error.not_veh_exist')
    end

    local plate = utils.getPlate(entity)
    local gz = GarageZone[garage]

    if gz and gz.vehicles then
        if fw.gvobp(src, plate) then
            return false, locale('notify.error.is_service_garage')
        end
        return entity, nil, plate, true
    end

    if not fw.gvobp(src, plate, { onlyOwner = not (gz and gz.shared) }, pleaseUpdate) then
        return false, locale('notify.error.not_owned')
    end

    return entity, nil, plate, false
end

lib.callback.register('rhd_garage:cb_server:canStoreVehicle', function (src, netId, garage)
    local entity, err = getStorableVehicle(src, netId, garage)
    return entity and true or false, err
end)

lib.callback.register('rhd_garage:cb_server:storeVehicle', function (src, netId, garage, pleaseUpdate)
    local entity, err, plate, service = getStorableVehicle(src, netId, garage, pleaseUpdate)
    if not entity then return false, err end

    -- server side delete works whoever is the network owner, the client one silently fails
    exports.qbx_core:DeleteVehicle(entity)
    if not service then fw.uvs(plate, 1, garage) end
    return true
end)

lib.callback.register('rhd_garage:cb_server:getvehiclePropByPlate', function (_, plate)
    return fw.gpvbp(plate)
end)

lib.callback.register('rhd_garage:cb_server:getVehicleList', function(src, garage, impound, shared)
    return fw.gpvbg(src, garage, {
        impound = impound,
        shared = shared
    })
end)

lib.callback.register("rhd_garage:cb_server:swapGarage", function (source, clientData)
    return fw.svg(clientData.newgarage, clientData.plate)
end)

lib.callback.register("rhd_garage:cb_server:transferVehicle", function (src, clientData)
    if src == clientData.targetSrc then
        return false, locale("notify.error.cannot_transfer_to_myself")
    end

    local tid = clientData.targetSrc

    if not fw.rm(src, "cash", clientData.price) then
        return false, locale("notify.error.need_money", lib.math.groupdigits(clientData.price, '.'))
    end

    print("Transfer vehicle from " .. fw.gn(src) .. " to " .. fw.gn(tid))
    print("Plate: " .. clientData.plate)
    local success = fw.uvo(src, tid, clientData.plate)
    if success then utils.notify(tid, locale("notify.success.transferveh.target", fw.gn(src), clientData.garage), "success") end
    return success, locale("notify.success.transferveh.source", fw.gn(tid))
end)

lib.callback.register('rhd_garage:cb_server:getVehicleInfoByPlate', function (_, plate)
    return fw.gpvbp(plate)
end)

--- Event
RegisterNetEvent("rhd_garage:server:removeTemp", function ( data )
    if GetInvokingResource() then return end
    local player = exports.qbx_core:GetPlayer(source)
    local citizenid = player.PlayerData.citizenid
    if tempVehicle[citizenid] == data.model then
        tempVehicle[citizenid] = nil
    end
end)

lib.addCommand('removeTemp', {
    help = 'Recuperar garagem de player',
    restricted = 'group.admin',
    params = {
        { name = 'id', help = 'ID do player', type = 'number' }
    }
}, function(source, args)
    if args.id then
        local player = exports.qbx_core:GetPlayer(tonumber(args.id))
        local citizenid = player.PlayerData.citizenid
        tempVehicle[citizenid] = nil
        lib.notify(tonumber(args.id), {description = "Seus veículos de aluguel foram recuperados.", type = "success", duration = 10000})
        lib.notify(source, {description = "Garagem recuperada do id: " .. args.id .. " cidadão: " .. citizenid .. " de nome " .. player.PlayerData.name .. ".", type = "success", duration = 10000})
    else
        lib.notify(source, {description = "ID inválido.", type = "error", duration = 10000})
    end
end)

RegisterNetEvent("rhd_garage:server:updateState", function ( data )
    if GetInvokingResource() then return end
    if type(data) ~= "table" or type(data.plate) ~= "string" or data.state ~= 0 then return end

    local vehicle = fw.gpvbp(data.plate)
    if not vehicle.owner then return end

    local gz = GarageZone[vehicle.garage]
    if vehicle.owner.citizenid ~= fw.gi(source) and not (gz and gz.shared) then return end

    fw.uvs(data.plate, 0, data.garage)
end)

RegisterNetEvent("rhd_garage:server:saveGarage", function(label, data, oldLabel)
    if GetInvokingResource() then return end
    if not IsPlayerAceAllowed(source, ('command.%s'):format(locale('command.admin.garagelist'))) then return end
    if type(label) ~= "string" or (data ~= nil and type(data) ~= "table") then return end
    if oldLabel ~= nil and type(oldLabel) ~= "string" then return end
    storage.SaveGarage(label, data, oldLabel)
end)

RegisterNetEvent("rhd_garage:server:saveCustomVehicleName", function (fileData)
    if GetInvokingResource() then return end
    if type(fileData) ~= "table" or type(fileData) == "nil" then return end
    return storage.SaveVehicleName(fileData)
end)

local vehicleSpawnCooldown = {}

lib.callback.register('rhd_garage:server:spawnVehicle', function(source, model, coords, props)
    local playerId = source

    if vehicleSpawnCooldown[playerId] then
        return false, 'cooldown'
    end

    vehicleSpawnCooldown[playerId] = true

    -- qbx.spawnVehicle errors when no client takes ownership in time, common on a full server
    local ok, netid, veh = pcall(qbx.spawnVehicle, {
        model = model,
        spawnSource = coords,
        warp = false,
        props = props
    })

    SetTimeout(3000, function()
        vehicleSpawnCooldown[playerId] = nil
    end)

    if not ok then
        lib.print.warn(('spawnVehicle failed for %s (%s): %s'):format(playerId, model, netid))
        return false, 'failed'
    end

    return netid, veh
end)

AddEventHandler('playerDropped', function()
    vehicleSpawnCooldown[source] = nil
end)

--- exports
exports("Garage", function ()
    return GarageZone
end)
