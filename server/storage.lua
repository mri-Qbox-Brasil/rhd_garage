storage = {}

--- Save one garage, nil data deletes it
---@param label string
---@param data GarageData?
---@param oldLabel string? previous label when renaming
---@return boolean
function storage.SaveGarage(label, data, oldLabel)
    if oldLabel and oldLabel ~= label then GarageZone[oldLabel] = nil end
    GarageZone[label] = data

    local saved = SaveResourceFile(GetCurrentResourceName(), 'data/garages.json', json.encode(GarageZone), -1)
    if not saved then
        lib.print.error(('could not write data/garages.json (garage %s)'):format(label))
    end

    TriggerClientEvent('rhd_garage:client:syncGarage', -1, label, data, oldLabel)
    return saved
end

--- Save custom vehicle name data
---@param dataName table<string, CustomName>
function storage.SaveVehicleName(dataName)
    CNV = dataName
    SaveResourceFile(GetCurrentResourceName(), 'data/vehiclesname.json', json.encode(CNV), -1)
end
