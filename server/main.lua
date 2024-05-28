CreateThread(function()
    while not GlobalState.rhd_garage do GlobalState.rhd_garage = {} Wait(10) end
    Wait(100)
    GlobalState.rhd_garage = GarageZone
end)

--- callback
lib.callback.register('rhd_garage:cb_server:removeMoney', function(src, type, amount)
    return fw.rm(src, type, amount)
end)

local tempVehicle = {}
lib.callback.register('rhd_garage:cb_server:createVehicle', function (source, vehicleData )
    local player = exports.qbx_core:GetPlayer(source)
    local citizenid = player.PlayerData.citizenid
    local props = {}
    local deformation = {}

    if string.sub(vehicleData.plate, 1, 3) == "MRI" then
        if tempVehicle[citizenid] then utils.notify(source, "Você já possui um veículo alugado. Devolva-o primeiro.", "error", 10000) return { netId = 0 } end
        tempVehicle[citizenid] = vehicleData.model
    end

    local veh = CreateVehicleServerSetter(vehicleData.model, vehicleData.vehtype, vehicleData.coords.x, vehicleData.coords.y, vehicleData.coords.z, vehicleData.coords.w)
    Wait(100)
    
    while not DoesEntityExist(veh) do Wait(10) end
    while GetVehicleNumberPlateText(veh) == '' do Wait(10) end
    while NetworkGetEntityOwner(veh) == -1 do Wait(10) end
    SetVehicleNumberPlateText(veh, vehicleData.plate)
    
    local netId, owner = NetworkGetNetworkIdFromEntity(veh), NetworkGetEntityOwner(veh)
    local result = fw.gmdbp(vehicleData.plate)
    props = result.prop deformation = result.deformation
    lib.callback.await('rhd_garage:cb_client:vehicleSpawned', owner, netId, props)
    Entity(veh).state:set("VehicleProperties", props, true)
    return { netId = netId, props = props, plate = vehicleData.plate, deformation = deformation }
end)

lib.callback.register('rhd_garage:cb_server:getvehowner', function (src, plate, shared, pleaseUpdate)
    return fw.gvobp(src, plate, {
        owner = shared
    }, pleaseUpdate)
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
        return false, locale("rhd_garage:transferveh_cannot_transfer")
    end

    local tid = clientData.targetSrc
    if fw.rm(src, "cash", clientData.price) then
        return false, locale("rhd_garage:transferveh_no_money")
    end
    
    local success = fw.uvo(src, tid, clientData.plate)
    if success then utils.notify(tid, locale("rhd_garage:transferveh_success_target", fw.gn(src), clientData.garage), "success") end
    return success, locale("rhd_garage:transferveh_success_src", fw.gn(tid))
end)

lib.callback.register('rhd_garage:cb_server:getVehicleInfoByPlate', function (_, plate)
    return fw.gpvbp(plate)
end)

--- Event
RegisterNetEvent("rhd_garage:server:removeTemp", function ( data )
    if GetInvokingResource() then return end

    local player = exports.qbx_core:GetPlayer(source)
    local citizenid = player.PlayerData.citizenid

    print("removeTemp", citizenid, data.model)
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
    fw.uvs(data.plate, data.state, data.garage)
end)

RegisterNetEvent("rhd_garage:server:saveGarageZone", function(fileData)
    if GetInvokingResource() then return end
    if type(fileData) ~= "table" or type(fileData) == "nil" then return end
    return Storage.save.garage(fileData)
end)

RegisterNetEvent("rhd_garage:server:saveCustomVehicleName", function (fileData)
    if GetInvokingResource() then return end
    if type(fileData) ~= "table" or type(fileData) == "nil" then return end
    return Storage.save.vehname(fileData)
end)

--- exports
exports("Garage", function ()
    return GarageZone
end)
