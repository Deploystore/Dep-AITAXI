local activeTaxi = nil
local activeDriver = nil
local activeBlip = nil
local tripStatus = 'NONE' -- 'SPAWNING_FADE', 'WAITING_FOR_PLAYER_SEAT', 'WAITING_FOR_WAYPOINT', 'DRIVING_TO_DESTINATION', 'ARRIVED'
local tripDestination = nil
local tripDrivingStyle = 'normal'
local totalDistanceKM = 0.0
local currentFare = Config.BaseFare

function IsTaxiActive()
    return tripStatus ~= 'NONE'
end

local function LoadModelSafely(modelName)
    local hash = (type(modelName) == 'number' and modelName or GetHashKey(modelName))
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        print('^1[DepAITaxi]^7 Model invalid or missing in cdimage: ' .. tostring(modelName))
        return false, hash
    end
    RequestModel(hash)
    local attempts = 0
    while not HasModelLoaded(hash) and attempts < 60 do
        Citizen.Wait(50)
        attempts = attempts + 1
    end
    return HasModelLoaded(hash), hash
end

local tripPreferences = {}
local tripSubPreferences = {}

local function InitSeatbackDUI() end
local function CleanupSeatbackDUI() end
local function SendDataToDUI(action, data) end

local function TriggerDriverSpeech(dialogueText)
    if not dialogueText or dialogueText == '' then return end
    
    local speechData = {
        text = dialogueText,
        driverName = Config.DriverName or 'Niko Bellic'
    }

    SendNUIMessage({
        action = 'AI_DRIVER_SPEAK',
        data = speechData
    })

    SendDataToDUI('AI_DRIVER_SPEAK', speechData)
    
    BeginTextCommandPrint("STRING")
    AddTextComponentSubstringPlayerName("~b~[AI Şoför " .. (Config.DriverName or 'Niko') .. "]:~s~ " .. dialogueText)
    EndTextCommandPrint(5500, true)
end

local cabinWindowsOpen = false
local cabinInteriorLight = false
local tabletTouchActive = false
local birdsEyeCam = nil
local isBirdsEyeActive = false
local isBoardingQuestionActive = false

local function ToggleBirdsEyeCamera()
    if not activeTaxi or not DoesEntityExist(activeTaxi) then return end
    local pPed = PlayerPedId()
    if not IsPedInVehicle(pPed, activeTaxi, false) then return end

    isBirdsEyeActive = not isBirdsEyeActive

    if isBirdsEyeActive then
        if not birdsEyeCam then
            birdsEyeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        end
        AttachCamToEntity(birdsEyeCam, activeTaxi, 0.0, -0.4, 7.8, -85.0, 0.0, 0.0, true)
        SetCamFov(birdsEyeCam, 65.0)
        SetCamActive(birdsEyeCam, true)
        RenderScriptCams(true, true, 700, true, true)
        Framework.Notify('360° Kuş Bakışı Kamera Aktif. [C] ile kabine dönebilirsiniz.', 'success')
    else
        if birdsEyeCam then
            RenderScriptCams(false, true, 700, true, true)
            DestroyCam(birdsEyeCam, false)
            birdsEyeCam = nil
        end
        Framework.Notify('Kabin Görünümüne dönüldü.', 'primary')
    end
end

local function ToggleCabinWindows()
    if not activeTaxi or not DoesEntityExist(activeTaxi) then return end
    cabinWindowsOpen = not cabinWindowsOpen
    if cabinWindowsOpen then
        RollDownWindow(activeTaxi, 0)
        RollDownWindow(activeTaxi, 1)
        RollDownWindow(activeTaxi, 2)
        RollDownWindow(activeTaxi, 3)
        Framework.Notify(_L('windows_open_notify'), 'success')
    else
        RollUpWindow(activeTaxi, 0)
        RollUpWindow(activeTaxi, 1)
        RollUpWindow(activeTaxi, 2)
        RollUpWindow(activeTaxi, 3)
        Framework.Notify(_L('windows_close_notify'), 'primary')
    end
    SendDataToDUI('UPDATE_CABIN_CONTROLS', { windows = cabinWindowsOpen, light = cabinInteriorLight })
end

local function ToggleCabinInteriorLight()
    if not activeTaxi or not DoesEntityExist(activeTaxi) then return end
    cabinInteriorLight = not cabinInteriorLight
    SetVehicleInteriorlight(activeTaxi, cabinInteriorLight)
    if cabinInteriorLight then
        Framework.Notify(_L('light_open_notify'), 'success')
    else
        Framework.Notify(_L('light_close_notify'), 'primary')
    end
    SendDataToDUI('UPDATE_CABIN_CONTROLS', { windows = cabinWindowsOpen, light = cabinInteriorLight })
end

local function ToggleTabletTouch()
    if not activeTaxi or not DoesEntityExist(activeTaxi) then return end
    local pPed = PlayerPedId()
    if not IsPedInVehicle(pPed, activeTaxi, false) then return end
    
    tabletTouchActive = not tabletTouchActive
    SetNuiFocus(tabletTouchActive, tabletTouchActive)
    if tabletTouchActive then
        SendNUIMessage({
            action = 'OPEN_TABLET_TOUCH',
            data = {
                windows = cabinWindowsOpen,
                light = cabinInteriorLight
            }
        })
        Framework.Notify('Tablete dokunma modu açıldı. Kapatmak için [ESC] veya [E] basın.', 'primary')
    else
        SendNUIMessage({
            action = 'CLOSE_TABLET_TOUCH'
        })
    end
end

RegisterNUICallback('cabinAction', function(data, cb)
    if not data or not data.action then cb('ok') return end
    if data.action == 'windows' then
        ToggleCabinWindows()
    elseif data.action == 'light' then
        ToggleCabinInteriorLight()
    elseif data.action == 'cancel' then
        CancelAITaxiTrip()
    end
    cb('ok')
end)

local function TriggerDriverSpeech(text)
    if not text or text == '' then return end
    local driverName = Config.DriverName or "Niko Bellic"

    SendNUIMessage({
        action = 'AI_DRIVER_SPEAK',
        data = {
            text = text,
            driverName = driverName
        }
    })

    SendDataToDUI('AI_DRIVER_SPEAK', {
        text = text,
        driverName = driverName
    })
end

local function ProcessAISpeechPrompt(userSpeech)
    if not userSpeech or userSpeech == '' then return end
    local prompt = string.lower(userSpeech)
    local actionExecuted = false
    local immediateResponse = nil
    local curStreet = 'Los Santos'

    if activeTaxi and DoesEntityExist(activeTaxi) then
        local sH1, sH2 = GetStreetNameAtCoord(GetEntityCoords(activeTaxi).x, GetEntityCoords(activeTaxi).y, GetEntityCoords(activeTaxi).z)
        curStreet = GetStreetNameFromHashKey(sH1) or 'Los Santos'
    end

    if Config.AIAssistantRules and Config.AIAssistantRules.CustomDialogues then
        for actionKey, dialogue in pairs(Config.AIAssistantRules.CustomDialogues) do
            if dialogue.keywords then
                for _, kw in ipairs(dialogue.keywords) do
                    if string.find(prompt, string.lower(kw), 1, true) then
                        immediateResponse = dialogue.response
                        if string.find(immediateResponse, "%%s") then
                            immediateResponse = string.format(immediateResponse, curStreet)
                        end

                        if dialogue.action then
                            local act = dialogue.action
                            if act == 'windows_open' then
                                cabinWindowsOpen = false
                                ToggleCabinWindows()
                            elseif act == 'windows_close' then
                                cabinWindowsOpen = true
                                ToggleCabinWindows()
                            elseif act == 'light_open' then
                                cabinInteriorLight = false
                                ToggleCabinInteriorLight()
                            elseif act == 'light_close' then
                                cabinInteriorLight = true
                                ToggleCabinInteriorLight()
                            elseif act == 'drive_fast' then
                                currentDrivingStyle = 'fast'
                                SetDriverSpeedAndStyle()
                            elseif act == 'drive_cautious' then
                                currentDrivingStyle = 'cautious'
                                SetDriverSpeedAndStyle()
                            elseif act == 'cancel_trip' then
                                CancelCurrentTrip()
                            elseif act == 'music_lofi' then
                                tripSubPreferences.musicGenre = 'Lo-Fi Beats'
                                SendNUIMessage({ action = 'START_TRIP_MEDIA', data = { genre = 'Lo-Fi Beats' } })
                            elseif act == 'music_synth' then
                                tripSubPreferences.musicGenre = '80s Synthwave'
                                SendNUIMessage({ action = 'START_TRIP_MEDIA', data = { genre = '80s Synthwave' } })
                            elseif act == 'music_pop' then
                                tripSubPreferences.musicGenre = 'Pop Hits'
                                SendNUIMessage({ action = 'START_TRIP_MEDIA', data = { genre = 'Pop Hits' } })
                            elseif act == 'music_stop' then
                                tripSubPreferences.musicGenre = 'Radio Off'
                                SendNUIMessage({ action = 'STOP_TRIP_MEDIA' })
                            end
                        end
                        actionExecuted = true
                        break
                    end
                end
            end
            if actionExecuted then break end
        end
    end

    if actionExecuted and immediateResponse then
        TriggerDriverSpeech(immediateResponse)
    else
        SendNUIMessage({
            action = 'PROCESS_DYNAMIC_AI_PROMPT',
            data = {
                userPrompt = userSpeech,
                street = curStreet,
                driverName = Config.DriverName or "Niko Bellic",
                customBackend = Config.AIAssistantRules and Config.AIAssistantRules.CustomBackend or nil
            }
        })
    end
end
local cabinWindowsOpen = false
local cabinInteriorLight = false

function ToggleCabinWindows()
    if not activeTaxi or not DoesEntityExist(activeTaxi) then return end
    cabinWindowsOpen = not cabinWindowsOpen
    print('^2[DepAITaxi]^7 ToggleCabinWindows executed! State: ' .. tostring(cabinWindowsOpen))

    if cabinWindowsOpen then
        RollDownWindow(activeTaxi, 0)
        RollDownWindow(activeTaxi, 1)
        RollDownWindow(activeTaxi, 2)
        RollDownWindow(activeTaxi, 3)
        TriggerDriverSpeech(_L('windows_opened_speech'))
        Framework.Notify(_L('windows_open_notify'), 'info')
    else
        RollUpWindow(activeTaxi, 0)
        RollUpWindow(activeTaxi, 1)
        RollUpWindow(activeTaxi, 2)
        RollUpWindow(activeTaxi, 3)
        TriggerDriverSpeech(_L('windows_closed_speech'))
        Framework.Notify(_L('windows_close_notify'), 'info')
    end
end

function ToggleCabinInteriorLight()
    if not activeTaxi or not DoesEntityExist(activeTaxi) then return end
    cabinInteriorLight = not cabinInteriorLight
    print('^2[DepAITaxi]^7 ToggleCabinInteriorLight executed! State: ' .. tostring(cabinInteriorLight))
    SetVehicleInteriorlight(activeTaxi, cabinInteriorLight)
    if cabinInteriorLight then
        Framework.Notify(_L('light_open_notify'), 'info')
    else
        Framework.Notify(_L('light_close_notify'), 'info')
    end
end

function ProcessAISpeechPrompt(userPrompt)
    if not userPrompt or userPrompt == '' then return end
    print('^2[DepAITaxi]^7 User Speech Prompt: ' .. tostring(userPrompt))
    SendNUIMessage({
        action = 'PROCESS_DYNAMIC_AI_PROMPT',
        data = {
            userPrompt = userPrompt
        }
    })
end

RegisterCommand('taxises', function()
    if not activeTaxi or not DoesEntityExist(activeTaxi) then return end
    SendNUIMessage({
        action = 'SHOW_BOARDING_QUESTION',
        data = { driverName = Config.DriverName or "Niko Bellic" }
    })
    SetNuiFocus(true, true)
end, false)

RegisterKeyMapping('taxises', 'AI Taksi Sağ Kontrol Paneli', 'keyboard', 'N')


RegisterNUICallback('submitVoicePrompt', function(data, cb)
    if data and data.prompt then
        ProcessAISpeechPrompt(data.prompt)
    end
    cb('ok')
end)

RegisterNUICallback('triggerSpeechFromNUI', function(data, cb)
    if data and data.text then
        local driverName = data.driverName or Config.DriverName or "Niko Bellic"
        SendDataToDUI('AI_DRIVER_SPEAK', {
            text = data.text,
            driverName = driverName
        })
    end
    cb('ok')
end)

function ToggleAIControlPanel()
    if not isBoardingQuestionActive then
        isBoardingQuestionActive = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'SHOW_BOARDING_QUESTION',
            data = {
                question = _L('greeting_question'),
                driverName = Config.DriverName or "Niko Bellic",
                locales = Locales[Config.Language or 'en'] or Locales['en']
            }
        })
    else
        isBoardingQuestionActive = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'HIDE_BOARDING_QUESTION' })
    end
end

RegisterNUICallback('openBoardingPanel', function(data, cb)
    ToggleAIControlPanel()
    cb('ok')
end)

RegisterNUICallback('boardingQuestionAnswer', function(data, cb)
    isBoardingQuestionActive = false
    SetNuiFocus(false, false)
    local answer = data and data.answer or 'close'
    print('^2[DepAITaxi]^7 Action Selected: ' .. tostring(answer))

    if answer == 'windows' or answer == 'window' or answer == 'cam' then
        ToggleCabinWindows()
    elseif answer == 'light' or answer == 'isik' or answer == 'kabin' then
        ToggleCabinInteriorLight()
    elseif answer == 'fast' or answer == 'boost' or answer == 'turbo' then
        UpdateTaxiDrivingStyle('fast')
        TriggerDriverSpeech(_L('turbo_speech'))
        Framework.Notify(_L('turbo_set_notify'), 'success')
    elseif answer == 'sport' then
        UpdateTaxiDrivingStyle('sport')
        TriggerDriverSpeech(_L('sport_speech'))
        Framework.Notify(_L('sport_set_notify'), 'success')
    elseif answer == 'horn' or answer == 'korna' then
        if activeTaxi and DoesEntityExist(activeTaxi) then
            StartVehicleHorn(activeTaxi, 1500, GetHashKey("HELDDOWN"), false)
            TriggerDriverSpeech(_L('horn_speech'))
        end
    elseif answer == 'cautious' or answer == 'sakin' or answer == 'normal' then
        UpdateTaxiDrivingStyle('cautious')
        TriggerDriverSpeech(_L('cautious_speech'))
    elseif answer == 'hazard' or answer == 'dortlu' then
        if activeTaxi and DoesEntityExist(activeTaxi) then
            local state = not (isHazardActive or false)
            isHazardActive = state
            SetVehicleIndicatorLights(activeTaxi, 0, state)
            SetVehicleIndicatorLights(activeTaxi, 1, state)
            TriggerDriverSpeech(state and _L('hazard_on_speech') or _L('hazard_off_speech'))
        end
    elseif answer == 'lock' or answer == 'kilit' then
        if activeTaxi and DoesEntityExist(activeTaxi) then
            local isLocked = GetVehicleDoorLockStatus(activeTaxi) == 2
            SetVehicleDoorsLocked(activeTaxi, isLocked and 1 or 2)
            TriggerDriverSpeech(isLocked and _L('lock_off_speech') or _L('lock_on_speech'))
        end
    elseif answer == 'ac' or answer == 'klima' then
        TriggerDriverSpeech(_L('ac_speech'))
        Framework.Notify(_L('ac_set_notify'), 'primary')
    elseif answer == 'wait' or answer == 'bekle' then
        TriggerDriverSpeech(_L('wait_speech'))
        Framework.Notify(_L('wait_set_notify'), 'primary')
    elseif answer == 'stop' or answer == 'dur' or answer == 'sagacek' then
        if activeDriver and DoesEntityExist(activeDriver) and activeTaxi and DoesEntityExist(activeTaxi) then
            TaskVehicleTempAction(activeDriver, activeTaxi, 27, 4000)
            TriggerDriverSpeech(_L('stop_speech'))
        end
    elseif answer == 'music' or answer == 'muzik' or answer == 'radio' then
        SendNUIMessage({
            action = 'START_TRIP_MEDIA',
            data = { genre = 'lofi' }
        })
        TriggerDriverSpeech(_L('music_speech'))
    elseif answer == 'joke' or answer == 'fikra' then
        local jokes = {
            "What has an eye but cannot see? A needle!",
            "Why did the computer take a taxi? Because it had too many drives!",
            "Which vegetable is the fastest? A runner bean!"
        }
        TriggerDriverSpeech(jokes[math.random(1, #jokes)])
    end

    SendNUIMessage({ action = 'HIDE_BOARDING_QUESTION' })
    cb('ok')
end)

RegisterNUICallback('cabinAction', function(data, cb)
    local actionType = data and data.action
    print('^2[DepAITaxi]^7 Cabin Action Triggered: ' .. tostring(actionType))

    if actionType == 'windows' or actionType == 'window' or actionType == 'cam' then
        ToggleCabinWindows()
    elseif actionType == 'light' or actionType == 'isik' or actionType == 'kabin' then
        ToggleCabinInteriorLight()
    elseif actionType == 'fast' or actionType == 'hizli' or actionType == 'sollama' then
        UpdateTaxiDrivingStyle('fast')
        TriggerDriverSpeech(_L('turbo_speech'))
    elseif actionType == 'cautious' or actionType == 'sakin' then
        UpdateTaxiDrivingStyle('cautious')
        TriggerDriverSpeech(_L('cautious_speech'))
    elseif actionType == 'stop' or actionType == 'dur' or actionType == 'sagacek' then
        if activeDriver and DoesEntityExist(activeDriver) and activeTaxi and DoesEntityExist(activeTaxi) then
            TaskVehicleTempAction(activeDriver, activeTaxi, 27, 4000)
            TriggerDriverSpeech(_L('stop_speech'))
        end
    end
    cb('ok')
end)

RegisterNUICallback('changeStyle', function(data, cb)
    local style = data and data.style
    if style then
        UpdateTaxiDrivingStyle(style)
    end
    cb('ok')
end)

RegisterNetEvent('DepAITaxi:client:onCustomBackendResponse', function(reqType, data)
    if not data then return end
    if reqType == 'stt' and (data.transcript or data.text) then
        local transcript = data.transcript or data.text
        ProcessAISpeechPrompt(transcript)
    elseif reqType == 'chat' and (data.reply or data.response or data.text) then
        local reply = data.reply or data.response or data.text
        TriggerDriverSpeech(reply)
    end
end)

RegisterNUICallback('handleAIVoiceAction', function(data, cb)
    if data and data.action then
        local act = data.action
        if act == 'windows_open' then
            cabinWindowsOpen = false
            ToggleCabinWindows()
        elseif act == 'windows_close' then
            cabinWindowsOpen = true
            ToggleCabinWindows()
        elseif act == 'light_open' then
            cabinInteriorLight = false
            ToggleCabinInteriorLight()
        elseif act == 'light_close' then
            cabinInteriorLight = true
            ToggleCabinInteriorLight()
        elseif act == 'drive_fast' then
            currentDrivingStyle = 'fast'
            SetDriverSpeedAndStyle()
        elseif act == 'drive_cautious' then
            currentDrivingStyle = 'cautious'
            SetDriverSpeedAndStyle()
        elseif act == 'cancel_trip' then
            CancelCurrentTrip()
        elseif act == 'music_lofi' then
            tripSubPreferences.musicGenre = 'Lo-Fi Beats'
            SendNUIMessage({ action = 'START_TRIP_MEDIA', data = { genre = 'Lo-Fi Beats' } })
        elseif act == 'music_synth' then
            tripSubPreferences.musicGenre = '80s Synthwave'
            SendNUIMessage({ action = 'START_TRIP_MEDIA', data = { genre = '80s Synthwave' } })
        elseif act == 'music_pop' then
            tripSubPreferences.musicGenre = 'Pop Hits'
            SendNUIMessage({ action = 'START_TRIP_MEDIA', data = { genre = 'Pop Hits' } })
        elseif act == 'music_stop' then
            tripSubPreferences.musicGenre = 'Radio Off'
            SendNUIMessage({ action = 'STOP_TRIP_MEDIA' })
        end
    end
    cb('ok')
end)

RegisterNUICallback('closeTabletTouch', function(data, cb)
    tabletTouchActive = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('closeVoiceModal', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterCommand('taxicam', ToggleCabinWindows, false)
RegisterCommand('taxiisik', ToggleCabinInteriorLight, false)
RegisterCommand('taxitablet', ToggleTabletTouch, false)
RegisterCommand('taxikamera', ToggleBirdsEyeCamera, false)

function StartActiveTaxiThreads()
    local hudData = {
        inCar = true,
        fare = string.format("%.2f", currentFare),
        distanceKM = string.format("%.2f", totalDistanceKM),
        status = 'Harita İşareti Bekleniyor...',
        preferences = tripPreferences,
        subPreferences = tripSubPreferences
    }
        SendNUIMessage({
            action = 'SET_IN_CAR_HUD',
            data = hudData
        })
        SendDataToDUI('SET_IN_CAR_HUD', hudData)
        SendDataToDUI('UPDATE_CABIN_CONTROLS', { windows = cabinWindowsOpen, light = cabinInteriorLight })

        -- Continuous Fuel & Engine Watcher Thread (Prevents cdn-fuel / other fuel scripts from stalling AI taxi)
        Citizen.CreateThread(function()
            while activeTaxi and DoesEntityExist(activeTaxi) do
                if Config.SetFullFuel ~= false then
                    Framework.SetFuel(activeTaxi, 100.0)
                    if not GetIsVehicleEngineRunning(activeTaxi) then
                        SetVehicleEngineOn(activeTaxi, true, true, false)
                    end
                end
                Citizen.Wait(2000)
            end
        end)

        Citizen.CreateThread(function()
            while activeTaxi and DoesEntityExist(activeTaxi) do
                local pPed = PlayerPedId()
                if IsPedInVehicle(pPed, activeTaxi, false) then
                    Citizen.Wait(0)
                    if IsControlJustPressed(0, 38) then
                        ToggleAIControlPanel()
                    end
                    if IsControlJustPressed(0, 74) then
                        ToggleCabinWindows()
                    end

                    if IsControlJustPressed(0, 26) then
                        ToggleBirdsEyeCamera()
                    end
                    if IsControlJustPressed(0, 249) or IsControlJustPressed(0, 306) then
                        SendNUIMessage({ action = 'START_VOICE_INPUT' })
                    end
                    if IsControlJustReleased(0, 249) or IsControlJustReleased(0, 306) then
                        SendNUIMessage({ action = 'STOP_VOICE_INPUT' })
                    end
                    if IsControlJustPressed(0, 47) then
                        ToggleCabinInteriorLight()
                    end
                else
                    if tabletTouchActive then
                        tabletTouchActive = false
                        SetNuiFocus(false, false)
                    end
                    if isBirdsEyeActive then
                        ToggleBirdsEyeCamera()
                    end
                    Citizen.Wait(1000)
                end
            end
        end)

        Citizen.CreateThread(function()
            local talkingTicks = 0
            local wasTalking = false
            while activeTaxi and DoesEntityExist(activeTaxi) do
                Citizen.Wait(250)
                local pPed = PlayerPedId()
                if IsPedInVehicle(pPed, activeTaxi, false) then
                    local isTalking = NetworkIsPlayerTalking(PlayerId())
                    if isTalking then
                        talkingTicks = talkingTicks + 1
                        wasTalking = true
                    else
                        if wasTalking then
                            if talkingTicks >= 3 then -- Spoke for >0.75 seconds
                                local conversationalReplies = {
                                    _L('dialogue_intrip_1'),
                                    _L('dialogue_intrip_2'),
                                    _L('dialogue_intrip_3'),
                                    _L('cautious_speech')
                                }
                                local reply = conversationalReplies[math.random(1, #conversationalReplies)]
                                TriggerDriverSpeech(reply)
                            end
                            talkingTicks = 0
                            wasTalking = false
                        end
                    end
                else
                    talkingTicks = 0
                    wasTalking = false
                end
            end
        end)

        Citizen.CreateThread(function()
            local maxAudioDistance = 28.0
            local lastInCarState = nil
            local lastWindowsState = nil

            while activeTaxi and DoesEntityExist(activeTaxi) do
                local pPed = PlayerPedId()
                local inCar = IsPedInVehicle(pPed, activeTaxi, false)
                
                if inCar then
                    if lastInCarState ~= true or lastWindowsState ~= cabinWindowsOpen then
                        lastInCarState = true
                        lastWindowsState = cabinWindowsOpen
                        SendNUIMessage({
                            action = 'UPDATE_3D_AUDIO_SPATIAL',
                            data = {
                                distVolume = 1.0,
                                pan = 0.0,
                                inCar = true,
                                distance = 0.0,
                                windowsOpen = cabinWindowsOpen
                            }
                        })
                    end
                    Citizen.Wait(1000)
                else
                    lastInCarState = false
                    Citizen.Wait(100)
                    local taxiCoords = GetEntityCoords(activeTaxi)
                    local camCoords = GetGameplayCamCoords()
                    local camRot = GetGameplayCamRot(2)
                    local distance = #(camCoords - taxiCoords)

                    local distVolume = 1.0
                    local pan = 0.0

                    if distance >= maxAudioDistance then
                        distVolume = 0.0
                        pan = 0.0
                    else
                        local normDist = distance / maxAudioDistance
                        distVolume = (1.0 - normDist) ^ 1.6
                        if not cabinWindowsOpen then
                            distVolume = distVolume * 0.40
                        end

                        local dx = taxiCoords.x - camCoords.x
                        local dy = taxiCoords.y - camCoords.y
                        local angleToVeh = math.atan2(dy, dx)
                        local camHeadingRad = math.rad(camRot.z + 90.0)
                        local relAngle = angleToVeh - camHeadingRad
                        while relAngle > math.pi do relAngle = relAngle - (2.0 * math.pi) end
                        while relAngle < -math.pi do relAngle = relAngle + (2.0 * math.pi) end

                        pan = math.sin(relAngle)
                        if pan > 1.0 then pan = 1.0 elseif pan < -1.0 then pan = -1.0 end
                    end

                    SendNUIMessage({
                        action = 'UPDATE_3D_AUDIO_SPATIAL',
                        data = {
                            distVolume = distVolume,
                            pan = pan,
                            inCar = false,
                            distance = distance,
                            windowsOpen = cabinWindowsOpen
                        }
                    })
                end
            end

            SendNUIMessage({
                action = 'UPDATE_3D_AUDIO_SPATIAL',
                data = {
                    distVolume = 0.0,
                    pan = 0.0,
                    inCar = false,
                    distance = 999.0,
                    windowsOpen = true
                }
            })
        end)
end

function StartSmartAIDriving(destCoords, styleKey)
    if not activeDriver or not DoesEntityExist(activeDriver) or not activeTaxi or not DoesEntityExist(activeTaxi) then return end
    
    local styleData = Config.DrivingStyles[styleKey] or Config.DrivingStyles['normal']
    local cruiseSpeed = styleData.speed or 22.0
    local drivingStyleFlag = styleData.style or 786603

    if tripPreferences.highway then
        local routeType = tripSubPreferences.routeType or 'En Hızlı Otoban'
        if routeType == 'En Hızlı Otoban' then
            cruiseSpeed = math.max(cruiseSpeed, 33.0)
            drivingStyleFlag = 2883621 -- Fast overtaking highway flag
        elseif routeType == 'Manzaralı Sahil Yolu' then
            cruiseSpeed = 14.0
            drivingStyleFlag = 447 -- Cautious scenic flag
        elseif routeType == 'Şehir İçi Rota' then
            cruiseSpeed = 22.0
            drivingStyleFlag = 786603
        end
    end

    if styleKey == 'fast' or styleKey == 'sport' then
        SetDriverAbility(activeDriver, 1.0)
        SetDriverAggressiveness(activeDriver, 0.4)
        SetVehicleEnginePowerMultiplier(activeTaxi, 1.35)
        SetVehicleCheatPowerIncrease(activeTaxi, 1.2)
        ModifyVehicleTopSpeed(activeTaxi, 1.3)
        SetVehicleStrong(activeTaxi, true)
        SetVehicleHasStrongAxles(activeTaxi, true)
    else
        SetDriverAbility(activeDriver, 1.0)
        SetDriverAggressiveness(activeDriver, 0.1)
        SetVehicleEnginePowerMultiplier(activeTaxi, 1.0)
        SetVehicleCheatPowerIncrease(activeTaxi, 1.0)
    end

    SetDriveTaskMaxCruiseSpeed(activeDriver, cruiseSpeed)
    SetDriveTaskDrivingStyle(activeDriver, drivingStyleFlag)

    TaskVehicleDriveToCoordLongrange(
        activeDriver, 
        activeTaxi, 
        destCoords.x, 
        destCoords.y, 
        destCoords.z, 
        cruiseSpeed, 
        drivingStyleFlag, 
        6.0
    )
end

function HandleTaxiStateLoop()
    while tripStatus == 'SPAWNING_FADE' or tripStatus == 'WAITING_FOR_PLAYER_SEAT' do
        Citizen.Wait(200)
        local playerPed = PlayerPedId()
        if IsPedInVehicle(playerPed, activeTaxi, false) then
            tripStatus = 'WAITING_FOR_WAYPOINT'
            Framework.Notify(_L('board_notify'), 'info')
            
            local quietMode = tripSubPreferences.quietType or 'Sohbetli'
            if quietMode ~= 'Tam Sessiz' then
                isBoardingQuestionActive = true
                local greeting = _L('driver_greeting', Config.DriverName or "Niko")
                TriggerDriverSpeech(greeting)

                local questionData = {
                    question = _L('greeting_question'),
                    driverName = Config.DriverName or "Niko Bellic"
                }
                SendNUIMessage({
                    action = 'SHOW_BOARDING_QUESTION',
                    data = questionData
                })
                SetNuiFocus(true, true)

                Citizen.SetTimeout(12000, function()
                    if isBoardingQuestionActive then
                        isBoardingQuestionActive = false
                        SetNuiFocus(false, false)
                        SendNUIMessage({ action = 'HIDE_BOARDING_QUESTION' })
                    end
                end)
            end
            break
        end
    end

    while tripStatus == 'WAITING_FOR_WAYPOINT' do
        Citizen.Wait(500)

        if Framework.HasWaypoint() then
            tripDestination = Framework.GetWaypointCoords()
            if tripDestination then
                tripStatus = 'DRIVING_TO_DESTINATION'
                Framework.Notify(_L('waypoint_set'), 'success')
                StartSmartAIDriving(tripDestination, tripDrivingStyle)
                break
            end
        else
            SendNUIMessage({
                action = 'UPDATE_TAXIMETER',
                data = {
                    distanceKM = '0.00',
                    fare = string.format("%.2f", Config.BaseFare),
                    status = 'Harita İşareti Bekleniyor...',
                    drivingStyle = tripDrivingStyle
                }
            })
        end
    end

    local lastPos = GetEntityCoords(activeTaxi)
    local stuckCounter = 0
    local dialogueTimer = 0
    local dialogueIndex = 1
    local playerLeftCounter = 0

    while tripStatus == 'DRIVING_TO_DESTINATION' do
        Citizen.Wait(1000)
        if not DoesEntityExist(activeTaxi) then
            CancelAITaxiTrip()
            return
        end

        local pPed = PlayerPedId()
        if not IsPedInVehicle(pPed, activeTaxi, false) then
            playerLeftCounter = playerLeftCounter + 1
            if playerLeftCounter >= 3 then
                Framework.Notify(_L('left_vehicle'), 'info')
                DespawnTaxiVehicle()
                return
            end
        else
            playerLeftCounter = 0
        end

        local currentPos = GetEntityCoords(activeTaxi)
        local stepDist = #(currentPos - lastPos)
        local currentSpeedKMH = GetEntitySpeed(activeTaxi) * 3.6
        lastPos = currentPos

        totalDistanceKM = totalDistanceKM + (stepDist / 1000.0)
        currentFare = Config.BaseFare + (totalDistanceKM * Config.PricePerKM)

        local meterData = {
            distanceKM = string.format("%.2f", totalDistanceKM),
            fare = string.format("%.2f", currentFare),
            status = 'Gidiliyor...',
            drivingStyle = tripDrivingStyle
        }
        SendNUIMessage({
            action = 'UPDATE_TAXIMETER',
            data = meterData
        })
        SendDataToDUI('UPDATE_TAXIMETER', meterData)

        local sHash1, sHash2 = GetStreetNameAtCoord(currentPos.x, currentPos.y, currentPos.z)
        local streetName = GetStreetNameFromHashKey(sHash1) or 'Los Santos'
        local currentSteer = GetVehicleSteeringAngle(activeTaxi)
        local currentHeading = GetEntityHeading(activeTaxi)
        local radHeading = math.rad(-currentHeading)

        local nearbyCarList = {}
        local vehPool = GetGamePool('CVehicle')
        for _, veh in ipairs(vehPool) do
            if veh ~= activeTaxi and DoesEntityExist(veh) then
                local vCoord = GetEntityCoords(veh)
                local dist = #(currentPos - vCoord)
                if dist < 65.0 then
                    local relX = vCoord.x - currentPos.x
                    local relY = vCoord.y - currentPos.y

                    local localX = relX * math.cos(radHeading) - relY * math.sin(radHeading)
                    local localY = relX * math.sin(radHeading) + relY * math.cos(radHeading)
                    local relHeading = (GetEntityHeading(veh) - currentHeading)

                    table.insert(nearbyCarList, {
                        x = math.floor(localX * 5.0),
                        y = math.floor(-localY * 5.0),
                        heading = math.floor(relHeading),
                        dist = math.floor(dist)
                    })
                end
            end
        end

        SendDataToDUI('UPDATE_TELEMETRY', {
            speedKMH = currentSpeedKMH,
            steeringAngle = currentSteer,
            heading = currentHeading,
            street = streetName,
            worldX = currentPos.x,
            worldY = currentPos.y,
            destX = tripDestination and tripDestination.x or 0,
            destY = tripDestination and tripDestination.y or 0,
            nearbyVehicles = nearbyCarList,
            isDriving = currentSpeedKMH > 1.5
        })

        local quietMode = tripSubPreferences.quietType or 'Tam Sessiz'
        if (quietMode == 'Sohbet Edebilir' or (not tripPreferences.quiet and quietMode ~= 'Tam Sessiz' and quietMode ~= 'Sadece Selamlaşma')) and Config.DriverDialogue and Config.DriverDialogue.inTrip and #Config.DriverDialogue.inTrip > 0 then
            dialogueTimer = dialogueTimer + 1
            if dialogueTimer >= 22 then -- Speaks every ~22 seconds
                local speechLine = Config.DriverDialogue.inTrip[dialogueIndex]
                if speechLine then
                    TriggerDriverSpeech(speechLine)
                end
                dialogueIndex = (dialogueIndex % #Config.DriverDialogue.inTrip) + 1
                dialogueTimer = 0
            end
        end

        if currentSpeedKMH < 1.0 then
            stuckCounter = stuckCounter + 1
            if stuckCounter >= 4 then
                StartVehicleHorn(activeTaxi, 600, GetHashKey("HELDDOWN"), false)
                ClearPedTasks(activeDriver)
                StartSmartAIDriving(tripDestination, tripDrivingStyle)
                stuckCounter = 0
            end
        else
            stuckCounter = 0
        end

        local dist2D = #(vector2(currentPos.x, currentPos.y) - vector2(tripDestination.x, tripDestination.y))
        if dist2D <= 22.0 then
            tripStatus = 'ARRIVED'
            
            if activeTaxi and DoesEntityExist(activeTaxi) then
                BringVehicleToHalt(activeTaxi, 10.0, 2, false)
            end

            Framework.Notify(_L('taxi_arrived'), 'success')
            
            if quietMode ~= 'Tam Sessiz' then
                local farewell = _L('dialogue_arrival_1')
                TriggerDriverSpeech(farewell)
            end
            break
        end
    end

    if tripStatus == 'ARRIVED' then
        TriggerServerEvent('DepAITaxi:server:payFare', math.ceil(currentFare))

        local finalMeterData = {
            distanceKM = string.format("%.2f", totalDistanceKM),
            fare = string.format("%.2f", currentFare),
            status = 'Ulaşıldı',
            drivingStyle = tripDrivingStyle
        }
        SendNUIMessage({
            action = 'UPDATE_TAXIMETER',
            data = finalMeterData
        })
        SendDataToDUI('UPDATE_TAXIMETER', finalMeterData)

        Citizen.Wait(800)
        local playerPed = PlayerPedId()
        if IsPedInVehicle(playerPed, activeTaxi, false) then
            TaskLeaveVehicle(playerPed, activeTaxi, 0)
        end

        local waitOut = 0
        while IsPedInVehicle(playerPed, activeTaxi, false) and waitOut < 35 do
            Citizen.Wait(150)
            waitOut = waitOut + 1
        end

        Framework.Notify(_L('left_vehicle'), 'info')
        DespawnTaxiVehicle()
    end
end

function UpdateTaxiDrivingStyle(newStyle)
    if not activeTaxi or not DoesEntityExist(activeTaxi) then return end
    tripDrivingStyle = newStyle
    print('^2[DepAITaxi]^7 Updating Driving Style to: ' .. tostring(newStyle))

    local styleData = Config.DrivingStyles[newStyle] or Config.DrivingStyles['normal']
    local cruiseSpeed = styleData.speed or 22.0
    local drivingStyleFlag = styleData.style or 786603

    if activeDriver and DoesEntityExist(activeDriver) then
        if newStyle == 'fast' or newStyle == 'sport' then
            SetDriverAbility(activeDriver, 1.0)
            SetDriverAggressiveness(activeDriver, 0.4)
            SetVehicleEnginePowerMultiplier(activeTaxi, 1.35)
            SetVehicleCheatPowerIncrease(activeTaxi, 1.2)
            ModifyVehicleTopSpeed(activeTaxi, 1.3)
            SetVehicleStrong(activeTaxi, true)
            SetVehicleHasStrongAxles(activeTaxi, true)
        else
            SetDriverAbility(activeDriver, 1.0)
            SetDriverAggressiveness(activeDriver, 0.1)
            SetVehicleEnginePowerMultiplier(activeTaxi, 1.0)
            SetVehicleCheatPowerIncrease(activeTaxi, 1.0)
        end

        SetDriveTaskMaxCruiseSpeed(activeDriver, cruiseSpeed)
        SetDriveTaskDrivingStyle(activeDriver, drivingStyleFlag)

        if tripDestination then
            TaskVehicleDriveToCoordLongrange(
                activeDriver, activeTaxi,
                tripDestination.x, tripDestination.y, tripDestination.z,
                cruiseSpeed, drivingStyleFlag, 6.0
            )
        end
    end
end

function CancelAITaxiTrip()
    if not IsTaxiActive() then return end
    tripStatus = 'NONE'
    TriggerServerEvent('DepAITaxi:server:cancelTrip')
    Framework.Notify(_L('trip_cancelled'), 'info')

    SendNUIMessage({
        action = 'UPDATE_TAXIMETER',
        data = {
            status = 'İptal Edildi',
            fare = '0.00',
            distanceKM = '0.00'
        }
    })

    DespawnTaxiVehicle()
end

local isDespawning = false

function DespawnTaxiVehicle()
    if isDespawning then return end
    isDespawning = true

    SendNUIMessage({ action = 'HIDE_BOARDING_QUESTION' })
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'STOP_TRIP_MEDIA'
    })
    SendNUIMessage({
        action = 'SET_IN_CAR_HUD',
        data = { inCar = false }
    })

    if activeBlip and DoesBlipExist(activeBlip) then
        RemoveBlip(activeBlip)
        activeBlip = nil
    end

    CleanupSeatbackDUI()

    if birdsEyeCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(birdsEyeCam, false)
        birdsEyeCam = nil
        isBirdsEyeActive = false
    end

    local vehToDelete = activeTaxi
    local driverToDelete = activeDriver
    local propToDelete = seatbackProp

    activeTaxi = nil
    activeDriver = nil
    seatbackProp = nil
    tripStatus = 'NONE'

    Citizen.CreateThread(function()
        if driverToDelete and DoesEntityExist(driverToDelete) and vehToDelete and DoesEntityExist(vehToDelete) then
            SetVehicleHandbrake(vehToDelete, false)
            ClearPedTasks(driverToDelete)
            SetDriverAbility(driverToDelete, 1.0)
            SetDriverAggressiveness(driverToDelete, 0.4)
            SetDriveTaskMaxCruiseSpeed(driverToDelete, 22.0)
            SetDriveTaskDrivingStyle(driverToDelete, 786603)
            TaskVehicleDriveWander(driverToDelete, vehToDelete, 22.0, 786603)

            Citizen.Wait(3500)

            for alpha = 255, 0, -35 do
                Citizen.Wait(70)
                if DoesEntityExist(vehToDelete) then
                    SetEntityAlpha(vehToDelete, math.max(0, alpha), false)
                end
            end

            if DoesEntityExist(driverToDelete) then
                DeleteEntity(driverToDelete)
            end
            if DoesEntityExist(vehToDelete) then
                DeleteEntity(vehToDelete)
            end
        else
            if driverToDelete and DoesEntityExist(driverToDelete) then
                DeleteEntity(driverToDelete)
            end
            if vehToDelete and DoesEntityExist(vehToDelete) then
                DeleteEntity(vehToDelete)
            end
        end

        if propToDelete and DoesEntityExist(propToDelete) then
            DeleteEntity(propToDelete)
        end

        isDespawning = false
    end)
end

function SpawnAndRequestAITaxi(destinationCoords, style, customVehModel, preferences, subPreferences)
    print('^2[DepAITaxi]^7 SpawnAndRequestAITaxi triggered! Model: ' .. tostring(customVehModel))

    if IsTaxiActive() then
        Framework.Notify(_L('already_has_taxi'), 'error')
        return false, _L('already_has_taxi')
    end

    tripPreferences = preferences or {}
    tripSubPreferences = subPreferences or {}

    local playerPed = PlayerPedId()

    local spawnPos = Config.TaxiSpawnCoords or vector4(-1042.02, -2718.46, 13.67, 240.0)

    local vehToLoad = customVehModel or Config.VehicleModel or 'vivanite2'
    local vehLoaded, vehHash = LoadModelSafely(vehToLoad)
    if not vehLoaded then
        print('^1[DepAITaxi]^7 Fallback vehicle model loading: ' .. tostring(Config.FallbackModel or Config.VehicleModel))
        vehToLoad = Config.VehicleModel or Config.FallbackModel or 'taxi'
        vehLoaded, vehHash = LoadModelSafely(vehToLoad)
        if not vehLoaded then
            vehToLoad = Config.FallbackModel or 'taxi'
            vehLoaded, vehHash = LoadModelSafely(vehToLoad)
        end
    end

    if not vehLoaded then
        Framework.Notify('Araç modeli yüklenemedi!', 'error')
        print('^1[DepAITaxi]^7 ERROR: Could not load any vehicle model!')
        return false, 'Model load error'
    end

    local driverToLoad = Config.DriverPed or 'a_m_y_business_01'
    local driverLoaded, driverHash = LoadModelSafely(driverToLoad)
    if not driverLoaded then
        driverToLoad = 'a_m_y_stlat_01'
        driverLoaded, driverHash = LoadModelSafely(driverToLoad)
    end

    print('^2[DepAITaxi]^7 Models loaded successfully. Creating Vehicle at ' .. tostring(spawnPos))

    activeTaxi = CreateVehicle(vehHash, spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w, true, false)
    SetVehicleOnGroundProperly(activeTaxi)
    SetVehicleHasBeenOwnedByPlayer(activeTaxi, true)
    SetVehicleEngineOn(activeTaxi, true, true, false)
    SetVehicleUndriveable(activeTaxi, false)
    Framework.SetFuel(activeTaxi, 100.0)
    SetVehicleLivery(activeTaxi, 0)
    SetVehicleCustomPrimaryColour(activeTaxi, 255, 191, 0)

    if tripPreferences.vip then
        SetVehicleNeonLightEnabled(activeTaxi, 0, true) -- Left
        SetVehicleNeonLightEnabled(activeTaxi, 1, true) -- Right
        SetVehicleNeonLightEnabled(activeTaxi, 2, true) -- Front
        SetVehicleNeonLightEnabled(activeTaxi, 3, true) -- Back
        
        local colorName = tripSubPreferences.vipColor or 'Neon Mor'
        local r, g, b = 180, 0, 255
        if colorName == 'Pembe Glow' then
            r, g, b = 255, 20, 147
        elseif colorName == 'Okyanus Mavi' then
            r, g, b = 0, 191, 255
        elseif colorName == 'Siber Yeşil' then
            r, g, b = 0, 255, 128
        end
        SetVehicleNeonLightsColour(activeTaxi, r, g, b)
        SetVehicleInteriorlight(activeTaxi, true)
    end

    if tripPreferences.ac then
        Framework.Notify('Araç klima ve hava akışı sistemi devreye girdi.', 'info')
    end

    if tripPreferences.music then
        SendNUIMessage({
            action = 'START_TRIP_MEDIA',
            data = {
                youtubeUrl = tripSubPreferences.youtubeUrl,
                genre = tripSubPreferences.musicGenre
            }
        })
    end

    if driverLoaded then
        activeDriver = CreatePedInsideVehicle(activeTaxi, 26, driverHash, -1, true, false)
        SetEntityVisible(activeDriver, false, false)
        SetEntityAlpha(activeDriver, 0, false)
        SetBlockingOfNonTemporaryEvents(activeDriver, true)
        SetPedCanBeDraggedOut(activeDriver, false)

        SetDriverAbility(activeDriver, 1.0) -- 100% Driving Skill
        SetDriverAggressiveness(activeDriver, 0.3) -- Smart smooth lane changes
        SetPedKeepTask(activeDriver, true)
    end

    activeBlip = AddBlipForEntity(activeTaxi)
    SetBlipSprite(activeBlip, 56) -- Taxi Icon
    SetBlipColour(activeBlip, 5)  -- Yellow
    SetBlipScale(activeBlip, 0.95)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Vivanite2 AI Taksi")
    EndTextCommandSetBlipName(activeBlip)

    tripDestination = destinationCoords
    tripDrivingStyle = style or Config.DefaultDrivingStyle
    tripStatus = 'SPAWNING_FADE'
    totalDistanceKM = 0.0
    currentFare = Config.BaseFare

    print('^2[DepAITaxi]^7 Taxi Created Successfully (ID: ' .. tostring(activeTaxi) .. ')')
    Framework.Notify(_L('taxi_called'), 'success')

    Citizen.CreateThread(function()
        for alpha = 0, 255, 10 do
            if DoesEntityExist(activeTaxi) then
                SetEntityAlpha(activeTaxi, alpha, false)
            end
            Citizen.Wait(40)
        end

        if DoesEntityExist(activeTaxi) then
            ResetEntityAlpha(activeTaxi)
            SetVehicleDoorsLocked(activeTaxi, 1)
            SetVehicleDoorsLockedForAllPlayers(activeTaxi, false)
            StartVehicleHorn(activeTaxi, 800, GetHashKey("HELDDOWN"), false)
        end
        if DoesEntityExist(activeDriver) then
            SetEntityVisible(activeDriver, false, false)
            SetEntityAlpha(activeDriver, 0, false)
        end

        tripStatus = 'WAITING_FOR_WAYPOINT'
        SetVehicleDoorsLocked(activeTaxi, 1)
        SetVehicleEngineOn(activeTaxi, true, true, false)
        Framework.SetFuel(activeTaxi, 100.0)
        TaskWarpPedIntoVehicle(playerPed, activeTaxi, 1)
        Framework.Notify(_L('board_notify'), 'success')

        local quietMode = tripSubPreferences.quietType or 'Sohbetli'
        if quietMode ~= 'Tam Sessiz' then
            isBoardingQuestionActive = true
            local greeting = _L('driver_greeting', Config.DriverName or "Niko")
            TriggerDriverSpeech(greeting)

            SendNUIMessage({
                action = 'SHOW_BOARDING_QUESTION',
                data = {
                    question = _L('greeting_question'),
                    driverName = Config.DriverName or "Niko Bellic",
                    locales = Locales[Config.Language or 'en'] or Locales['en']
                }
            })
            SetNuiFocus(true, true)
        end

        StartActiveTaxiThreads()
        Citizen.CreateThread(HandleTaxiStateLoop)
    end)

    return true, 'Success'
end

Citizen.CreateThread(function()
    local isHandleShown = false
    while true do
        Citizen.Wait(1000)
        local ped = PlayerPedId()
        if activeTaxi and DoesEntityExist(activeTaxi) and IsPedInVehicle(ped, activeTaxi, false) then
            if not isHandleShown then
                isHandleShown = true
                isBoardingQuestionActive = true
                SetNuiFocus(true, true)
                SetNuiFocusKeepInput(true)
                SendNUIMessage({ action = 'SHOW_AI_HANDLE' })
                SendNUIMessage({
                    action = 'SHOW_BOARDING_QUESTION',
                    data = {
                        question = _L('greeting_question'),
                        driverName = Config.DriverName or "Niko Bellic",
                        locales = Locales[Config.Language or 'en'] or Locales['en']
                    }
                })
            end
        else
            if isHandleShown then
                isHandleShown = false
                isBoardingQuestionActive = false
                SetNuiFocus(false, false)
                SetNuiFocusKeepInput(false)
                SendNUIMessage({ action = 'HIDE_AI_HANDLE' })
                SendNUIMessage({ action = 'HIDE_BOARDING_QUESTION' })
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    DespawnTaxiVehicle()
end)
