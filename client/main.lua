local VehicleShow = nil
local Deformation = lib.load('modules.deformation')

local function destroyPreview()
    if VehicleShow and DoesEntityExist(VehicleShow) then
        utils.destroyPreviewCam(VehicleShow)
        DeleteVehicle(VehicleShow)
        VehicleShow = nil
    end
end

local function spawnvehicle ( data )
    lib.requestModel(data.model)
    if not data.plate then
        local random = tostring(math.random(10000, 99999))
        data.plate = ('MRI%s'):format(random)
    end

    local serverData = lib.callback.await("rhd_garage:cb_server:createVehicle", false, {
        model = data.model,
        plate = data.plate,
        coords = data.coords,
        vehtype = utils.getVehicleTypeByModel(data.model)
    })

    if serverData.netId < 1 then
        return
    end

    while not NetworkDoesEntityExistWithNetworkId(serverData.netId) do Wait(10) end
    local veh = NetworkGetEntityFromNetworkId(serverData.netId)
    
    while utils.getPlate(veh) ~= serverData.plate do
        SetVehicleNumberPlateText(veh, serverData.plate) Wait(10)
    end

    SetVehicleOnGroundProperly(veh)
    if Config.SpawnInVehicle then
        TaskWarpPedIntoVehicle(cache.ped, veh, -1)
    end

    SetVehicleEngineHealth(veh, data.engine + 0.0)
    SetVehicleBodyHealth(veh, data.body + 0.0)
    Deformation.set(veh, serverData.deformation)

    utils.setFuel(veh, data.fuel)

    TriggerServerEvent("rhd_garage:server:updateState", {
        vehicle = veh,
        prop = serverData.props,
        plate = serverData.plate,
        state = 0,
        garage = data.garage,
        deformation = serverData.deformation
    })
    
    Entity(veh).state:set('vehlabel', data.vehicle_name)
    -- if not exports.mri_Qcarkeys:HavePermanentKey(serverData.plate:trim()) then
    --     exports.mri_Qcarkeys:GiveKeyItem(serverData.plate:trim(), veh)
    -- end
    if string.sub(data.plate, 1, 3) == "MRI" then
        TriggerEvent("vehiclekeys:client:SetOwner", serverData.plate:trim())
    end
end

local function actionMenu ( data )
    local actionData = {
        id = 'garage_action',
        title = data.plate or data.vehName,
        description = data.vehicle_name,
        menu = 'garage_menu',
        onBack = destroyPreview,
        onExit = destroyPreview,
        options = {
            {
                title = data.impound and locale('rhd_garage:pay_impound') or locale('rhd_garage:take_out_veh'),
                icon = data.impound and 'hand-holding-dollar' or 'sign-out-alt',
                iconAnimation = Config.IconAnimation,
                onSelect = function ()
                    if data.impound then
                        utils.createMenu({
                            id = 'pay_methode',
                            title = locale('rhd_garage:pay_methode'),
                            options = {
                                {
                                    title = locale('rhd_garage:pay_methode_cash'),
                                    icon = 'dollar-sign',
                                    description = locale('rhd_garage:pay_with_cash'),
                                    iconAnimation = Config.IconAnimation,
                                    onSelect = function ()
                                        destroyPreview()
                                        if fw.gm('cash') < data.depotprice then return utils.notify(locale('rhd_garage:not_enough_cash'), 'error') end
                                        local success = lib.callback.await('rhd_garage:cb_server:removeMoney', false, 'cash', data.depotprice)
                                        if success then
                                            utils.notify(locale('rhd_garage:success_pay_impound'), 'success')
                                            return spawnvehicle( data )
                                        end
                                    end
                                },
                                {
                                    title = locale('rhd_garage:pay_methode_bank'),
                                    icon = 'fab fa-cc-mastercard',
                                    description = locale('rhd_garage:pay_with_bank'),
                                    iconAnimation = Config.IconAnimation,
                                    onSelect = function ()  
                                        destroyPreview()
                                        if fw.gm('bank') < data.depotprice then return utils.notify(locale('rhd_garage:not_enough_bank'), 'error') end
                                        local success = lib.callback.await('rhd_garage:cb_server:removeMoney', false, 'bank', data.depotprice)
                                        if success then
                                            utils.notify(locale('rhd_garage:success_pay_impound'), 'success')
                                            return spawnvehicle( data )
                                        end
                                    end
                                }
                            }
                        })
                        return
                    end
                    destroyPreview()
                    spawnvehicle( data )
                end
            },
            
        }
    }
    
    if not data.impound and data.plate then
        if Config.TransferVehicle.enable then
            actionData.options[#actionData.options+1] = {
                title = locale("rhd_garage:transferveh_title"),
                icon = "exchange-alt",
                iconAnimation = Config.IconAnimation,
                metadata = {
                    ["Preço"] = 'R$ '.. lib.math.groupdigits(Config.TransferVehicle.price, '.')
                },
                onSelect = function ()
                    destroyPreview()
                    local transferInput = lib.inputDialog(data.vehName, {
                        { type = 'number', label = 'Player Id', required = true },
                    })

                    if transferInput then
                        local clData = {
                            targetSrc = transferInput[1],
                            plate = data.plate,
                            ["Preço"] = 'R$ '.. Config.TransferVehicle.price,
                            garage = data.garage
                        }
                        lib.callback('rhd_garage:cb_server:transferVehicle', false, function (success, information)
                            if not success then return
                                utils.notify(information, "error")
                            end

                            utils.notify(information, "success")
                        end, clData)
                    end
                end
            }
        end

        if Config.SwapGarage.enable then
            actionData.options[#actionData.options+1] = {
                title = locale('rhd_garage:swapgarage_title'),
                icon = "retweet",
                iconAnimation = Config.IconAnimation,
                metadata = {
                    ["Preço"] = 'R$ '.. lib.math.groupdigits(Config.SwapGarage.price, '.')
                },
                onSelect = function ()
                    destroyPreview()

                    local garageTable = function ()
                        local result = {}
                        for k, v in pairs(GarageZone) do
                            if k ~= data.garage and not v.impound then
                                result[#result+1] = { value = k }
                            end
                        end
                        return result
                    end

                    local garageInput = lib.inputDialog(data.garage, {
                        { type = 'select', label = locale('rhd_garage:swapgarage_input_label'), options = garageTable(), required = true},
                    })

                    if garageInput then
                        local vehdata = {
                            plate = data.plate,
                            newgarage = garageInput[1]
                        }

                        if fw.gm('cash') < Config.SwapGarage.price then return utils.notify(locale("rhd_garage:swapgarage_need_money", lib.math.groupdigits(Config.SwapGarage.price, '.')), 'error') end
                        local success = lib.callback.await('rhd_garage:cb_server:removeMoney', false, 'cash', Config.SwapGarage.price)
                        if not success then return end

                        lib.callback('rhd_garage:cb_server:swapGarage', false, function (success)
                            if not success then return
                                utils.notify(locale("rhd_garage:swapgarage_error"), "error")
                            end
    
                            utils.notify(locale('rhd_garage:swapgarage_success', vehdata.newgarage), "success")
                        end, vehdata)
                    end
                end
            }
        end

        actionData.options[#actionData.options+1] = {
            title = locale('rhd_garage:change_veh_name'),
            icon = 'pencil',
            iconAnimation = Config.IconAnimation,
            metadata = {
                ["Preço"] = 'R$ '.. lib.math.groupdigits(Config.SwapGarage.price, '.')
            },
            onSelect = function ()
                destroyPreview()
                
                local input = lib.inputDialog(data.vehName, {
                    { type = 'input', label = '', placeholder = locale('rhd_garage:change_veh_name_input'), required = true, max = 20 },
                })
                
                if input then
                    if fw.gm('cash') < Config.changeNamePrice then return utils.notify(locale('rhd_garage:change_veh_name_nocash'), 'error') end

                    local success = lib.callback.await('rhd_garage:cb_server:removeMoney', false, 'cash', Config.changeNamePrice)
                    if success then
                        CNV[data.plate] = {
                            name = input[1]
                        }
    
                        TriggerServerEvent('rhd_garage:server:saveCustomVehicleName', CNV)
                    end
                end
            end
        }

        actionData.options[#actionData.options+1] = {
            title = locale('rhd_garage:givekeys'),
            icon = 'key',
            iconAnimation = Config.IconAnimation,
            metadata = {
                ["Preço"] = 'R$ '..lib.math.groupdigits(Config.GiveKeys.price, '.')
            },
            onSelect = function ()


                local input = lib.alertDialog({
                    header = 'Criar cópia de chave',
                    content = 'Você deseja copiar a chave do seu veículo por R$'..Config.GiveKeys.price..'?',
                    centered = true,
                    cancel = true
                }) == "confirm"
                
                if input then
                    if fw.gm('cash') < Config.GiveKeys.price then destroyPreview() return utils.notify('Você não possui dinheiro suficiente na carteira.', 'error') end

                    local success = lib.callback.await('rhd_garage:cb_server:removeMoney', false, 'cash', Config.GiveKeys.price)
                    if success then
                        exports.mri_Qcarkeys:GiveKeyItem(data.plate, data.entity)
                    end
                end
                destroyPreview()
            end
        }
    end

    utils.createMenu(actionData)
end

--- Get available spawn point
---@param point table
---@param targetPed boolean
---@return vector4?
local function getAvailableSP(point, targetPed)
    local results = nil
    local targetCoords = vec(GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.0, 0.5))

    if type(point) ~= "table" then
        return
    end

    if #point > 0 then
        for i=1, #point do
            local c = point[i]
            local vec3 = vec(c.x, c.y, c.z)
            local dist = #(targetCoords - vec(vec3.x, vec3.y, vec3.z))
            local closestveh = lib.getClosestVehicle(vec3, 3.0, true)
            if not targetPed then
                if not closestveh and dist < 3.0 then
                    results = c
                    break
                end
            else
                if not closestveh then
                    results = c
                    break
                end
                
            end
        end
    end

    return results
end

local function openMenu ( data )
    if not data then return end
    data.type = data.type or "car"
    
    local menuData = {
        id = 'garage_menu',
        title = data.garage,
        options = {}
    }

    -- print(json.encode(data))
    local vehicles = exports.qbx_core:GetVehiclesByHash()
    

    if data.vehicles then
        for i=1, #data.vehicles do
            local v = data.vehicles[i]
            -- print(v)
            local vehModel = v
            local vehName = GetLabelText(GetDisplayNameFromVehicleModel(v))


            menuData.options[#menuData.options+1] = {
                title = vehName,
                icon = 'car',
                iconColor = 'white',
                onSelect = function ()
                    local defaultcoords = vec(GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.0, 0.5), GetEntityHeading(cache.ped)+90)

                    if data.spawnpoint then
                        defaultcoords = getAvailableSP(data.spawnpoint, data.targetped)
                    end

                    if not defaultcoords then
                        return utils.notify(locale('rhd_garage:no_parking_spot'), 'error', 8000)
                    end
                    
                    local vehInArea = lib.getClosestVehicle(defaultcoords.xyz)
                    if DoesEntityExist(vehInArea) then return utils.notify(locale('rhd_garage:no_parking_spot'), 'error') end
    
                    VehicleShow = utils.createPlyVeh(vehModel, defaultcoords)
                    SetEntityAlpha(VehicleShow, 200, false)
                    FreezeEntityPosition(VehicleShow, true)
                    SetVehicleDoorsLocked(VehicleShow, 2)
                    utils.createPreviewCam(VehicleShow)
    
                    actionMenu({
                        prop = nil,
                        engine = 1000,
                        fuel = 100,
                        body = 1000,
                        model = vehModel,
                        plate = nil,
                        coords = defaultcoords,
                        garage = data.garage,
                        vehName = vehName,
                        vehicle_name = nil,
                        impound = data.impound,
                        shared = data.shared,
                        deformation = nil,
                        depotprice = nil,
                        entity = VehicleShow
                    })
                end,
            }
        end


    end

    local vehData = lib.callback.await('rhd_garage:cb_server:getVehicleList', false, data.garage, data.impound, data.shared)
    
    if not vehData then
        return    
    end

    for i=1, #vehData do
        local vd = vehData[i]
        local vehProp = vd.vehicle
        local vehModel = vd.model
        local plate = vd.plate
        local vehDeformation = vd.deformation
        local gState = vd.state
        local pName = vd.owner or "Unkown Players"
        local fakeplate = vd.fakeplate
        local engine = vd.engine
        local body = vd.body
        local fuel = vd.fuel
        local dp = vd.depotprice

        local vehName = vd.vehicle_name or fw.gvn( vehModel )
        local customvehName = CNV[plate:trim()] and CNV[plate:trim()].name
        local vehlabel = customvehName or vehName

        local shared_garage = data.shared
        local disabled = false
        local description = ''

        plate = fakeplate and fakeplate:trim() or plate:trim()

        local vehicleClass = GetVehicleClassFromName(vehModel)
        local vehicleType = utils.classCheck(vehicleClass)
        local icon = Config.Icons[vehicleType]
        local ImpoundPrice = dp > 0 and dp or Config.ImpoundPrice[vehicleClass]

        if gState == 0 then
            if vehFunc.govbp(plate) then
                disabled = true
                description = 'STATUS: ' ..  locale('rhd_garage:veh_out_garage'):upper()
            else
                description = locale('rhd_garage:impound_price', ImpoundPrice)
            end
        elseif gState == 1 then
            description = 'STATUS: ' ..  locale('rhd_garage:veh_in_garage'):upper()
            if shared_garage then
                description = locale('rhd_garage:shared_owner_label', pName) .. ' \n' .. 'STATUS: ' .. locale('rhd_garage:veh_in_garage')
            end
        end

        local vehicleLabel = ('%s [ %s ]'):format(vehlabel, plate)
        
        if utils.garageType("check", data.type, vehicleType) then
            menuData.options[#menuData.options+1] = {
                title = vehicleLabel,
                icon = icon,
                disabled = disabled,
                description = description,
                iconAnimation = Config.IconAnimation,
                metadata = {
                    { label = '⛽ Combustível', value = math.floor(fuel) .. '%', progress = math.floor(fuel), colorScheme = utils.getColorLevel(math.floor(fuel))},
                    { label = '🧰 Lataria', value = math.floor(body / 10) .. '%', progress = math.floor(body / 10), colorScheme = utils.getColorLevel(math.floor(body / 10))},
                    { label = '🔧 Motor', value = math.floor(engine/ 10) .. '%', progress = math.floor(engine / 10), colorScheme = utils.getColorLevel(math.floor(engine / 10))}
                },
                onSelect = function ()
                    local defaultcoords = vec(GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.0, 0.5), GetEntityHeading(cache.ped)+90)

                    if data.spawnpoint then
                        defaultcoords = getAvailableSP(data.spawnpoint, data.targetped)
                    end

                    if not defaultcoords then
                        return utils.notify(locale('rhd_garage:no_parking_spot'), 'error', 8000)
                    end
                    
                    local vehInArea = lib.getClosestVehicle(defaultcoords.xyz)
                    if DoesEntityExist(vehInArea) then return utils.notify(locale('rhd_garage:no_parking_spot'), 'error') end
    
                    VehicleShow = utils.createPlyVeh(vehModel, defaultcoords)
                    SetEntityAlpha(VehicleShow, 200, false)
                    FreezeEntityPosition(VehicleShow, true)
                    SetVehicleDoorsLocked(VehicleShow, 2)
                    utils.createPreviewCam(VehicleShow)

                    if vehProp and next(vehProp) then
                        vehFunc.svp(VehicleShow, vehProp)
                    end
    
                    actionMenu({
                        prop = vehProp,
                        engine = engine,
                        fuel = fuel,
                        body = body,
                        model = vehModel,
                        plate = plate,
                        coords = defaultcoords,
                        garage = data.garage,
                        vehName = vehicleLabel,
                        vehicle_name = vehlabel,
                        impound = data.impound,
                        shared = data.shared,
                        deformation = vehDeformation,
                        depotprice = ImpoundPrice,
                        entity = VehicleShow
                    })
                end,
            }
        end
    end

    if #menuData.options < 1 then 
        menuData.options[#menuData.options+1] = {
            title = locale('rhd_garage:no_vehicles_in_garage'),
            disabled = true
        }
    end

    utils.createMenu(menuData)
end

local function storeVeh ( data )
    -- print(json.encode(data))
    -- {"targetped":true,"spawnpoint":[{"x":105.08464050292969,"y":-1076.3994140625,"z":28.91999816894531,"w":340.0},{"x":107.84837341308594,"y":-1077.8819580078126,"z":28.91999816894531,"w":340.0},{"x":111.22987365722656,"y":-1079.630859375,"z":28.91999626159668,"w":340.0},{"x":106.56298828125,"y":-1064.118896484375,"z":28.92056465148925,"w":246.5},{"x":108.02095031738281,"y":-1060.681640625,"z":28.91999816894531,"w":246.5},{"x":109.59732818603516,"y":-1057.3714599609376,"z":28.9200210571289,"w":246.5},{"x":111.0271224975586,"y":-1053.5751953125,"z":28.9282112121582,"w":246.5}],"garage":"Garagem da Praça 1 ","type":["car","motorcycle","cycles"]}

    local myCoords = GetEntityCoords(cache.ped)
    local vehicle = cache.vehicle and cache.vehicle or lib.getClosestVehicle(myCoords)

    if not vehicle then return
        utils.notify(locale('rhd_garage:not_vehicle_exist'), 'error')
    end

    local prop = vehFunc.gvp(vehicle)
    local plate = prop.plate:trim()
    local shared = data.shared
    local deformation = Deformation.get(vehicle)
    local fuel = utils.getFuel(vehicle)
    local engine = GetVehicleEngineHealth(vehicle)
    local body = GetVehicleBodyHealth(vehicle)
    local model = prop.model

    local isOwned = lib.callback.await('rhd_garage:cb_server:getvehowner', false, plate, shared, {
        mods = prop,
        deformation = deformation,
        fuel =  fuel,
        engine = engine,
        body = body,
        vehicle_name = Entity(vehicle).state.vehlabel
    })

    print(not isOwned, string.sub(plate, 1, 3) ~= "MRI")
    if not isOwned and (string.sub(plate, 1, 3) ~= "MRI") then 
        return utils.notify(locale('rhd_garage:not_owned'), 'error')
    end
    if data.vehicles == {} then
        if isOwned or string.sub(plate, 1, 3) ~= "MRI" then
            return utils.notify("Você não pode estacionar aqui.", "error", 10000)
        end
    end
    if cache.vehicle and cache.seat == -1 then
        TaskLeaveAnyVehicle(cache.ped, true, 0)
        Wait(1000)
    end
    if DoesEntityExist(vehicle) then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
        if string.sub(plate, 1, 3) ~= "MRI" then
            TriggerServerEvent('rhd_garage:server:updateState', { plate = plate, state = 1, garage = data.garage })
        else
            local vehiclename = string.lower(GetDisplayNameFromVehicleModel(model))
            TriggerServerEvent('rhd_garage:server:removeTemp', { model = vehiclename })
        end
        utils.notify(locale('rhd_garage:success_stored'), 'success')
    end
end

--- exports 
exports('openMenu', openMenu)
exports('storeVehicle', storeVeh)
