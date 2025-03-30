local pedcreator = {}

local pedlist = lib.loadJson('data.peds')

local curPed = nil
local busycreate = false
local glm = require "glm"
local debugzone = require 'modules.debugzone'

local function CancelPlacement()
    DeletePed(curPed)
    busycreate = false
    curPed = nil
end


---@param data table[]
local function tovec3(data)
    local results = {}
    for i=1, #data do
        local c = data[i]
        results[#results+1] = vec(c.x, c.y, c.z)
    end
    return results
end

---@param zone {points: vector3[], thickness: number}
function pedcreator.start(zone)
    if not zone then return end
    if busycreate then return end
    local pedIndex = 1
    local pedmodels = pedlist[pedIndex]
    local points = tovec3(zone.points)
    local polygon = glm.polygon.new(points)

    local text = [[
    [X]: Cancelar
    [Enter]: Confirmar
    [Setas Direita/Esquerda]: Rotacionar Ped
    [Mouse Scroll Cima/Baixo]: Mudar Ped
    ]]

    utils.drawtext('show', text)
    lib.requestModel(pedmodels, 150000)
    curPed = CreatePed(0, pedmodels, 1.0, 1.0, 1.0, 0.0, false, false)
    SetEntityAlpha(curPed, 150, false)
    SetEntityCollision(curPed, false, false)
    FreezeEntityPosition(curPed, true)

    local notif = false
    local pc = nil
    local heading = 0.0

    local results = promise.new()
    CreateThread(function()
        busycreate = true

        while busycreate do
            local hit, coords = utils.raycastCam(20.0)
            CurrentCoords = GetEntityCoords(curPed)
            
            local inZone = glm.polygon.contains(polygon, CurrentCoords, zone.thickness / 4)
            local debugColor = inZone and {r = 10, g = 244, b = 115, a = 50} or {r = 240, g = 5, b = 5, a = 50}
            debugzone.start(polygon, zone.thickness, debugColor)

            if hit == 1 then
                SetEntityCoords(curPed, coords.x, coords.y, coords.z)
            end

            DisableControlAction(0, 174, true)
            DisableControlAction(0, 175, true)
            DisableControlAction(0, 73, true)
            DisableControlAction(0, 176, true)
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 172, true)
            DisableControlAction(0, 173, true)
            
            if IsDisabledControlPressed(0, 174) then
                heading = heading + 0.5
                if heading > 360 then heading = 0.0 end
            end
    
            if IsDisabledControlPressed(0, 175) then
                heading = heading - 0.5
                if heading < 0 then heading = 360.0 end
            end

            if IsDisabledControlJustPressed(0, 14) then
                local newIndex = pedIndex+1
                local newModel = pedlist[newIndex]
                if newModel then
                    DeleteEntity(curPed)
                    lib.requestModel(newModel)
                    local newped = CreatePed(0, newModel, 1.0, 1.0, 1.0, 0.0, false, false)
                    SetEntityAlpha(newped, 150, false)
                    SetEntityCollision(newped, false, false)
                    FreezeEntityPosition(newped, true)
                    curPed = newped
                    pedIndex = newIndex
                end
            end

            if IsDisabledControlJustPressed(0, 15) then
                local newIndex = pedIndex-1

                if newIndex >= 1 then
                    local newModel = pedlist[newIndex]
                    if newModel then
                        DeleteEntity(curPed)
                        lib.requestModel(newModel)
                        local newped = CreatePed(0, newModel, 1.0, 1.0, 1.0, 0.0, false, false)
                        SetEntityAlpha(newped, 150, false)
                        SetEntityCollision(newped, false, false)
                        FreezeEntityPosition(newped, true)
                        curPed = newped
                        pedIndex = newIndex
                    end
                end
            end
            
            SetEntityHeading(curPed, heading)

            if IsDisabledControlJustPressed(0, 176) then
                if hit == 1 then
                    if inZone then
                        pc = {
                            model = pedlist[pedIndex],
                            coords = vec(CurrentCoords.x, CurrentCoords.y, CurrentCoords.z, heading)
                        }
                        utils.notify("Localização do PED definida com sucesso!", "success", 8000)
                        CancelPlacement()
                        results:resolve(pc)
                        if notif then notif = false end
                    else
                        if not notif then
                            utils.notify("Só pode estar na zona!", "error", 8000)
                            notif = true
                        end
                    end
                end
            end
            Wait(1)
        end
        utils.drawtext('hide')
    end)

    return Citizen.Await(results)
end

return pedcreator