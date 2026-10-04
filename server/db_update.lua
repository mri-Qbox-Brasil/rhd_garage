local UPDATE_SQL = {
    ADD_COLUMN_VEHICLE_NAME = 'ALTER TABLE player_vehicles ADD vehicle_name longtext DEFAULT NULL;',
    ADD_COLUMN_DEFORMATION = 'ALTER TABLE player_vehicles ADD deformation longtext DEFAULT NULL;',
    ADD_COLUMN_BALANCE = 'ALTER TABLE player_vehicles ADD balance int(11) NOT NULL DEFAULT 0;',
    ADD_COLUMN_PAYMENTAMOUNT = 'ALTER TABLE player_vehicles ADD paymentamount int(11) NOT NULL DEFAULT 0;',
    ADD_COLUMN_PAYMENTSLEFT = 'ALTER TABLE player_vehicles ADD paymentsleft int(11) NOT NULL DEFAULT 0;',
    ADD_COLUMN_FINANCETIME = 'ALTER TABLE player_vehicles ADD financetime int(11) NOT NULL DEFAULT 0;',
    -- every plate lookup is "plate = ? OR fakeplate = ?", without this index it scans the whole table
    ADD_INDEX_FAKEPLATE = 'ALTER TABLE player_vehicles ADD INDEX fakeplate (fakeplate);',
}

if Config.UsePoliceImpound then
    -- the player_vehicles triggers look up police_impound by plate on every update
    UPDATE_SQL.ADD_INDEX_POLICE_IMPOUND_PLATE = 'ALTER TABLE police_impound ADD INDEX plate (plate);'
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        local results = {}
        for k, v in pairs(UPDATE_SQL) do
            local status, err = pcall(function()
                MySQL.Sync.execute(v, {})
            end)
            if not status and not string.find(string.lower(err), 'duplicate') then
                results[#results + 1] = {
                    script = k,
                    error = err
                }
            end
        end
        if #results > 0 then
            print(string.format('^1Errors: %s^0', json.encode(results)))
        end
    end
end)
