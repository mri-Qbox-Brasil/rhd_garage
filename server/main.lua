local Utils = require 'modules.utils'

--- callback
lib.callback.register('rhd_garage:cb_server:removeMoney', function(src, type, amount)
    return Framework.server.removeMoney(src, type, amount)
end)

lib.callback.register('rhd_garage:cb_server:createVehicle', function (_, vehicleData, inside )
    local veh = CreateVehicleServerSetter(vehicleData.model, vehicleData.vehtype, vehicleData.coords.x, vehicleData.coords.y, vehicleData.coords.z, vehicleData.coords.w)

    if veh == 0 then return end

    while NetworkGetEntityOwner(veh) == -1 do Wait(0) end

    local netId, owner = NetworkGetNetworkIdFromEntity(veh), NetworkGetEntityOwner(veh)

    SetVehicleNumberPlateText(veh, vehicleData.plate)

    local db = {}
    local props = {}
    local deformation = {}
    
    if Framework.qb() then
        db.c = 'mods'
        db.t = 'player_vehicles'
        db.p = 'plate = ? OR fakeplate = ?'
        db.v = { vehicleData.plate:trim(), vehicleData.plate:trim() }
    else
        db.c = 'vehicle'
        db.t = 'owned_vehicles'
        db.p = 'plate = ?'
        db.v = { vehicleData.plate:trim() }
    end

    local result = MySQL.query.await(('SELECT %s, deformation FROM %s WHERE %s'):format(db.c, db.t, db.p), db.v)

    if result then
        props = result[1][db.c] deformation = result[1].deformation
    end
    TriggerClientEvent('ox_lib:setVehicleProperties', owner, netId, json.decode(props))

    return {
        netId = netId,
        props = json.decode(props),
        plate = vehicleData.plate,
        deformation = json.decode(deformation)
    }
end)

lib.callback.register('rhd_garage:cb_server:getvehowner', function (src, plate, shared)
    local isQB = Framework.qb()
    local isOwner = true

    local vehicledata = {
        cid = Framework.server.getIdentifier(src)
    }

    print(vehicledata.cid)
    if isQB then
        vehicledata.dbtable = "SELECT 1 FROM `player_vehicles` WHERE `citizenid` = ? and plate = ? OR fakeplate = ?"
        vehicledata.dbvalue = {vehicledata.cid, plate:trim(), plate:trim()}

        if shared then
            vehicledata.dbtable = "SELECT 1 FROM `player_vehicles` WHERE plate = ? OR fakeplate = ?"
            vehicledata.dbvalue = { plate:trim(), plate:trim() }
        end
    else
        vehicledata.dbtable = "SELECT `vehicle` FROM `owned_vehicles` WHERE `owner` = ? and plate = ?"
        vehicledata.dbvalue = { vehicledata.cid, plate:trim() }

        if shared then
            vehicledata.dbtable = "SELECT vehicle FROM owned_vehicles WHERE plate = ?"
            vehicledata.dbvalue = { plate:trim() }
        end
    end

    local result = MySQL.single.await(vehicledata.dbtable, vehicledata.dbvalue)

    if not result then
        isOwner = not isOwner
    end
    
     return isOwner
end)


lib.callback.register('rhd_garage:cb_server:getVehicleList', function(src, garage, impound, shared)
    local impound_garage = impound
    local shared_garage = shared
    local isQB = Framework.qb()

    local garageData = {
        cid = Framework.server.getIdentifier(src),
        vehicle = {}
    }
    
    if isQB then
        garageData.dbtable = "SELECT vehicle, mods, state, plate, fakeplate, deformation FROM player_vehicles WHERE garage = ? and citizenid = ?"
        garageData.dbvalue = {garage, garageData.cid}

        if impound_garage then
            if shared_garage then return false end
            garageData.dbtable = "SELECT vehicle, mods, state, plate, fakeplate, deformation FROM player_vehicles WHERE state = ? and citizenid = ?"
            garageData.dbvalue = {0, garageData.cid}
        end

        if shared_garage then
            garageData.dbtable = "SELECT player_vehicles.vehicle, player_vehicles.mods, player_vehicles.deformation, player_vehicles.state, player_vehicles.plate, player_vehicles.fakeplate, players.charinfo FROM player_vehicles LEFT JOIN players ON players.citizenid = player_vehicles.citizenid WHERE player_vehicles.garage = ?"
            garageData.dbvalue = {garage}
        end
    else
        garageData.dbtable = "SELECT vehicle, plate, stored, deformation FROM owned_vehicles WHERE garage = ? and owner = ?"
        garageData.dbvalue = {garage, garageData.cid}

        if impound_garage then
            if shared_garage then return false end
            garageData.dbtable = "SELECT vehicle, plate, stored, deformation FROM owned_vehicles WHERE stored = ? and owner = ?"
            garageData.dbvalue = {0, garageData.cid}
        end

        if shared_garage then
            garageData.dbtable = "SELECT owned_vehicles.vehicle, owned_vehicles.plate, owned_vehicles.stored, owned_vehicles.deformation, users.firstname, users.lastname FROM owned_vehicles LEFT JOIN users ON users.identifier = owned_vehicles.owner WHERE owned_vehicles.garage = ?"
            garageData.dbvalue = {garage}
        end
    end

    local result = MySQL.query.await(garageData.dbtable, garageData.dbvalue)

    if result and next(result) then
        if isQB then
            for k, v in pairs(result) do
                local charinfo = json.decode(v.charinfo)
                local vehicles = json.decode(v.mods)
                local deformation = json.decode(v.deformation)
                local state = v.state
                local model = v.vehicle
                local plate = v.plate
                local fakeplate = v.fakeplate
                local ownername = charinfo and ("%s %s"):format(charinfo.firstname, charinfo.lastname)
                
                garageData.vehicle[#garageData.vehicle+1] = {
                    vehicle = vehicles,
                    state = state,
                    model = model,
                    plate = plate,
                    fakeplate = fakeplate,
                    owner = ownername,
                    deformation = deformation
                }
            end
        else
            for k,v in pairs(result) do
                local vehicles = json.decode(v.vehicle)
                local deformation = json.decode(v.deformation)
                local state = v.stored
                local model = vehicles.model
                local plate = v.plate
                local ownername = ("%s %s"):format(v.firstname, v.lastname)

                garageData.vehicle[#garageData.vehicle+1] = {
                    vehicle = vehicles,
                    state = state,
                    model = model,
                    plate = plate,
                    owner = ownername,
                    deformation = deformation
                }
            end
        end
    end
    return garageData.vehicle
end)

lib.callback.register('rhd_garage:cb_server:getvehicledatabyplate', function (src, plate)
    local db = {}
    local ownerName = "Unkown"

    if Framework.qb() then
        db.s = "SELECT player_vehicles.citizenid, player_vehicles.vehicle, player_vehicles.mods, player_vehicles.deformation, player_vehicles.balance, player_vehicles.citizenid, players.charinfo FROM player_vehicles LEFT JOIN players ON players.citizenid = player_vehicles.citizenid WHERE plate = ? OR fakeplate = ?"
        db.v = { plate, plate }
    elseif Framework.esx() then
        db.s = "SELECT owned_vehicles.owner, owned_vehicles.vehicle, owned_vehicles.plate, owned_vehicles.owner, owned_vehicles.deformation, users.firstname, users.lastname FROM owned_vehicles LEFT JOIN users ON users.identifier = owned_vehicles.owner WHERE plate = ?"
        db.v = { plate }
    end

    local data = MySQL.single.await(db.s, db.v)
    if not data then return {} end

    db.data = {}

    if Framework.qb() then
        local mods = json.decode(data.mods)
        local charinfo = json.decode(data.charinfo)
        local deformation = json.decode(data.deformation)
        ownerName = ("%s %s"):format(charinfo.firstname, charinfo.lastname)
        db.data = {
            citizenid = data.citizenid,
            owner = ownerName,
            vehicle = data.vehicle,
            props = mods,
            balance = data.balance,
            deformation = deformation
        }
    elseif Framework.esx() then
        ownerName = ("%s %s"):format(data.firstname, data.lastname)
        local mods = json.decode(data.vehicle)
        local deformation = json.decode(data.deformation)
        db.data = {
            citizenid = data.owner,
            owner = ownerName,
            vehicle = mods.model,
            props = mods,
            balance = 0,
            deformation = deformation
        }
    end

    return db.data
end)

lib.callback.register("rhd_garage:cb_server:swapGarage", function (source, clientData)
    local identifier = Framework.server.getIdentifier(source)
    local isQB = Framework.qb()
    local db = {
        t = isQB and "player_vehicles" or "owned_vehicles",
        identifier_column = isQB and "citizenid" or "owner"
    }
    local changed = MySQL.update.await(("UPDATE %s SET garage = ? WHERE plate = ? AND %s = ?"):format(db.t, db.identifier_column), {
        clientData.newgarage,
        clientData.plate,
        identifier
    })
    return changed > 0
end)

RegisterNetEvent("rhd_garage:server:saveGarageZone", function(fileData)
    if type(fileData) ~= "table" or type(fileData) == "nil" then return end
    return Storage.save.garage(fileData)
end)

RegisterNetEvent("rhd_garage:server:saveCustomVehicleName", function (fileData)
    if type(fileData) ~= "table" or type(fileData) == "nil" then return end
    return Storage.save.vehname(fileData)
end)

--- exports
exports("Garage", function ()
    return GarageZone
end)
