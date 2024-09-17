local VehicleShow = nil
local Deformation = require 'modules.deformation'

local function destroyPreview()
    if VehicleShow and DoesEntityExist(VehicleShow) then
        utils.destroyPreviewCam(VehicleShow)
        DeleteVehicle(VehicleShow)
        VehicleShow = nil
    end
end

local function swapEnabled(from)
    if GarageZone[from] then
        local fromJob = GarageZone[from]['job']
        local fromGang = GarageZone[from]['gang']

        if GarageZone[from]['vehicles'] and #GarageZone[from]['vehicles'] > 0 then
            return false
        end
        return not (fromJob or fromGang)
    else
        return false
    end

end

local function canSwapVehicle(to)
    local toJob = GarageZone[to]['job']
    local toGang = GarageZone[to]['gang']

    if GarageZone[to]['vehicles'] and #GarageZone[to]['vehicles'] > 0 then
        return false
    end

    return not(toJob or toGang)
end

--- Spawn Vehicle
---@param data GarageVehicleData
local function spawnvehicle ( data )
    local vehData = {
        model = data.model
    }
    if data.plate then
        local vehData = lib.callback.await('rhd_garage:cb_server:getvehiclePropByPlate', false, data.plate)
        if not vehData then return error('Failed to load vehicle data with number plate ' .. data.plate) end
    end
    if Config.InDevelopment then
        print(json.encode(data))
    end
    local vehEntity = utils.createPlyVeh(vehData.model, data.coords)
    SetVehicleOnGroundProperly(vehEntity)
    if Config.SpawnInVehicle then TaskWarpPedIntoVehicle(cache.ped, vehEntity, -1) end
    local engine = vehData.engine or 1000
    local body = vehData.body or 1000

    SetVehicleEngineHealth(vehEntity, engine + 0.0)
    SetVehicleBodyHealth(vehEntity, body + 0.0)
    utils.setFuel(vehEntity, vehData.fuel)
    if vehData.mods or data.prop then
        vehFunc.svp(vehEntity, vehData.mods or data.prop)
    end
    if vehData.deformation or data.deformation then
        Deformation.set(vehEntity, vehData.deformation or data.deformation)
    end
    TriggerServerEvent("rhd_garage:server:updateState", { plate = vehData.plate or data.plate, state = 0, garage = vehData.garage or data.garage, })
    Entity(vehEntity).state:set('vehlabel', vehData.vehicle_name or data.vehicle_name)

    if GetResourceState('mri_Qcarkeys') == 'started' and Config.GiveKeys.onspawn then
        local plate = vehData.plate or data.plate
        if exports.mri_Qcarkeys:HavePermanentKey(plate) then return end
        exports.mri_Qcarkeys:GiveKeyItem(plate)
    end

    if Config.GiveKeys.tempkeys then
        TriggerEvent("vehiclekeys:client:SetOwner", vehData.plate:trim())
    end

    if not data.plate then
        local plate = GetVehicleNumberPlateText(vehEntity)
        TriggerEvent("vehiclekeys:client:SetOwner", plate)
    end
end
local function getVehMetadata(data)
    local fuel = data.fuel
    local body = data.body
    local engine = data.engine
    return  {
        { label = '⛽ Combustível', value = math.floor(fuel) .. '%', progress = math.floor(fuel), colorScheme = utils.getColorLevel(math.floor(fuel))},
        { label = '🧰 Lataria', value = math.floor(body / 10) .. '%', progress = math.floor(body / 10), colorScheme = utils.getColorLevel(math.floor(body / 10))},
        { label = '🔧 Motor', value = math.floor(engine/ 10) .. '%', progress = math.floor(engine / 10), colorScheme = utils.getColorLevel(math.floor(engine / 10))}
    }
end
--- Garage Action
---@param data GarageVehicleData
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
                title = data.vehName,
                icon = data.icon --[[@as string]],
                readOnly = true,
                iconAnimation = Config.IconAnimation,
                metadata = getVehMetadata(data),
            },
            {
                title = data.impound and locale('garage.pay_impound') or locale('garage.take_out_veh'),
                icon = data.impound and 'hand-holding-dollar' or 'sign-out-alt',
                iconAnimation = Config.IconAnimation,
                onSelect = function ()
                    if data.impound then
                        utils.createMenu({
                            id = 'pay_methode',
                            title = locale('context.insurance.pay_methode_header'):upper(),
                            onExit = destroyPreview,
                            menu = 'garage_action',
                            options = {
                                {
                                    title = locale('context.insurance.pay_methode_cash_title'):upper(),
                                    icon = 'dollar-sign',
                                    description = locale('context.insurance.pay_methode_cash_desc'),
                                    iconAnimation = Config.IconAnimation,
                                    onSelect = function ()
                                        destroyPreview()
                                        if fw.gm('cash') < data.depotprice then return utils.notify(locale('notify.error.not_enough_cash'), 'error') end
                                        local success = lib.callback.await('rhd_garage:cb_server:removeMoney', false, 'cash', data.depotprice)
                                        if success then
                                            utils.notify(locale('garage.success_pay_impound'), 'success')
                                            return spawnvehicle( data )
                                        end
                                    end
                                },
                                {
                                    title = locale('context.insurance.pay_methode_bank_title'):upper(),
                                    icon = 'fab fa-cc-mastercard',
                                    description = locale('context.insurance.pay_methode_bank_desc'),
                                    iconAnimation = Config.IconAnimation,
                                    onSelect = function ()
                                        destroyPreview()
                                        if fw.gm('bank') < data.depotprice then return utils.notify(locale('notify.error.not_enough_bank'), 'error') end
                                        local success = lib.callback.await('rhd_garage:cb_server:removeMoney', false, 'bank', data.depotprice)
                                        if success then
                                            utils.notify(locale('garage.success_pay_impound'), 'success')
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
                title = locale("context.garage.transferveh_title"),
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

        if Config.SwapGarage.enable and swapEnabled(data.garage) then
            actionData.options[#actionData.options+1] = {
                title = locale('context.garage.swapgarage'),
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
                            if k ~= data.garage and not v.impound and canSwapVehicle(k) then
                                result[#result+1] = { value = k }
                            end
                        end
                        return result
                    end

                    local garageInput = lib.inputDialog(data.garage:upper(), {
                        { type = 'select', label = locale('input.garage.swapgarage'), options = garageTable(), required = true},
                    })

                    if garageInput then
                        local vehdata = {
                            plate = data.plate,
                            newgarage = garageInput[1]
                        }

                        if fw.gm('cash') < Config.SwapGarage.price then return utils.notify(locale("notify.error.need_money", lib.math.groupdigits(Config.SwapGarage.price, '.')), 'error') end
                        local success = lib.callback.await('rhd_garage:cb_server:removeMoney', false, 'cash', Config.SwapGarage.price)
                        if not success then return end

                        lib.callback('rhd_garage:cb_server:swapGarage', false, function (success)
                            if not success then return
                                utils.notify(locale("notify.error.swapgarage"), "error")
                            end

                            utils.notify(locale('notify.success.swapgarage', vehdata.newgarage), "success")
                        end, vehdata)
                    end
                end
            }
        end

        actionData.options[#actionData.options+1] = {
            title = locale('context.garage.change_veh_name'),
            icon = 'pencil',
            iconAnimation = Config.IconAnimation,
            metadata = {
                ["Preço"] = 'R$ '.. lib.math.groupdigits(Config.SwapGarage.price, '.')
            },
            onSelect = function ()
                destroyPreview()

                local input = lib.inputDialog(data.vehName, {
                    { type = 'input', label = '', placeholder = locale('input.garage.change_veh_name'), required = true, max = 20 },
                })

                if input then
                    if fw.gm('cash') < Config.changeNamePrice then return utils.notify(locale('notify.error.not_enough_cash'), 'error') end

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
            title = locale('context.garage.vehicle_keys'),
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
---@param ignoreDist boolean
---@return vector4?
local function getAvailableSP(point, ignoreDist, default)
    assert(
        type(point) == "table" and point[1], 'Invalid "point" parameter: Expected a non-empty array table.'
    )

    local coords = default

    local result
    lib.array.forEach(point, function (c)
        local sp = vec(c.x, c.y, c.z, c.w)
        local vehEntity = lib.getClosestVehicle(sp.xyz, 3.0, true)

        if ignoreDist and not vehEntity then
            result = sp
        end

        local dist = #(coords.xyz - sp.xyz)
        if not ignoreDist and dist < 2.5 and not vehEntity then
            result = sp
        end
    end)

    return result
end

--- Open Garage
---@param data GarageVehicleData
local function openMenu ( data )
    if not data then return end
    data.type = data.type or "car"

    local menuData = {
        id = 'garage_menu',
        title = data.garage,
        options = {}
    }

    if data.vehicles then
        for i=1, #data.vehicles do
            local v = data.vehicles[i]
            local vehModel = v
            local vehName = GetLabelText(GetDisplayNameFromVehicleModel(v))


            menuData.options[#menuData.options+1] = {
                title = vehName,
                icon = 'car',
                iconColor = 'white',
                onSelect = function ()
                    local defaultcoords = vec(GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.0, 0.5), GetEntityHeading(cache.ped)+90)

                    if data.spawnpoint then
                        defaultcoords = getAvailableSP(data.spawnpoint, data.targetped, defaultcoords)
                    end

                    if not defaultcoords then
                        return utils.notify(locale('notify.error.no_parking_spot'), 'error', 8000)
                    end

                    local vehInArea = lib.getClosestVehicle(defaultcoords.xyz)
                    if DoesEntityExist(vehInArea) then return utils.notify(locale('notify.error.no_parking_spot'), 'error') end

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
        local plate = utils.string.trim(vd.plate)
        local vehDeformation = vd.deformation
        local gState = vd.state
        local pName = vd.owner or "Unkown Players"
        local fakeplate = vd.fakeplate and utils.string.trim(vd.fakeplate)
        local engine = vd.engine
        local body = vd.body
        local fuel = vd.fuel
        local dp = vd.depotprice

        local vehName = vd.vehicle_name or fw.gvn( vehModel )
        local customvehName = CNV[plate] and CNV[plate].name
        local vehlabel = customvehName or vehName

        local shared_garage = data.shared
        local disabled = false
        local description = ''

        plate = fakeplate or plate

        local vehicleClass = GetVehicleClassFromName(vehModel)
        local icon = Config.Icons[vehicleClass] or 'car'
        local ImpoundPrice = dp > 0 and dp or Config.ImpoundPrice[vehicleClass]

        if gState == 0 then
            if vehFunc.govbp(plate) then
                disabled = true
                description = 'STATUS: ' ..  locale('status.out')
            else
                description = locale('garage.impound_price', ImpoundPrice)
            end
        elseif gState == 1 then
            description = 'STATUS: ' ..  locale('status.in')
            if shared_garage then
                description = locale('context.garage.owner_label', pName) .. ' \n' .. 'STATUS: ' .. locale('status.in')
            end
        end

        local vehicleLabel = ('%s [ %s ]'):format(vehlabel, plate)
        menuData.options[#menuData.options+1] = {
            title = vehicleLabel,
            icon = icon,
            disabled = disabled,
            description = description:upper(),
            iconAnimation = Config.IconAnimation,
            metadata = getVehMetadata(vd),
            onSelect = function ()
                local pedHeading = GetEntityHeading(cache.ped)
                local worlcoords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.0, 0.5)
                local defaultcoords = vec(worlcoords, pedHeading+90)

                if data.spawnpoint then
                    defaultcoords = getAvailableSP(data.spawnpoint, data.ignoreDist, defaultcoords) --[[@as vector4]]
                end

                if not defaultcoords then
                    return utils.notify(locale('notify.error.no_parking_spot'), 'error', 8000)
                end

                local vehInArea = lib.getClosestVehicle(defaultcoords.xyz)
                if DoesEntityExist(vehInArea) then return utils.notify(locale('notify.error.no_parking_spot'), 'error') end

                VehicleShow = utils.createPlyVeh(vehModel, defaultcoords)
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
                    icon = icon
                })
            end,
        }
    end

    if #menuData.options < 1 then
        menuData.options[#menuData.options+1] = {
            title = locale('garage.no_vehicles'):upper(),
            disabled = true
        }
    end

    utils.createMenu(menuData)
end

--- Store Vehicle To Garage
---@param data GarageVehicleData
local function storeVeh ( data )
    local myCoords = GetEntityCoords(cache.ped)
    local vehicle = cache.vehicle or lib.getClosestVehicle(myCoords)

    local vehicleClass = GetVehicleClass(vehicle)
    local vehicleType = utils.getCategoryByClass(vehicleClass)

    if not vehicle then return
        utils.notify(locale('notify.error.not_veh_exist'), 'error')
    end

    if not lib.table.contains(data.type, vehicleType) then return
        utils.notify(locale('notify.info.invalid_veh_classs', data.garage))
    end

    local prop = vehFunc.gvp(vehicle)
    local plate = utils.string.trim(prop.plate)
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

    if not isOwned and not data.vehicles then return
        utils.notify(locale('notify.error.not_owned'), 'error')
    end
    if cache.vehicle and cache.seat == -1 then
        TaskLeaveAnyVehicle(cache.ped, true, 0)
        Wait(1000)
    end
    if DoesEntityExist(vehicle) then
        if GetResourceState('mri_Qcarkeys') == 'started' and Config.GiveKeys.onspawn then
            exports.mri_Qcarkeys:RemoveKeyItem(plate)
        end

        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
        TriggerServerEvent('rhd_garage:server:updateState', {plate = plate, state = 1, garage = data.garage})
        utils.notify(locale('notify.success.store_veh'), 'success')
    end
end

--- exports
exports('openMenu', openMenu)
exports('storeVehicle', storeVeh)