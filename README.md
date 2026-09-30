# DepAITaxi - Advanced Autonomous AI Taxi System (Vivanite2)

An ultra-modern, fully autonomous AI Taxi system for FiveM. Equipped with a sleek Vue 3 UI, multi-framework compatibility (QBCore, QBX, ESX, Standalone), targeting integration, multi-fuel system support, in-cabin touch tablet controls, AI voice interactions, and dynamic driving behaviors.

---

## 🌟 Key Features

- **Multi-Framework Compatibility**: Works out of the box with **QBCore**, **QBX Core**, **ESX**, and **Standalone**.
- **Universal Fuel System Support**: Native integration with **cdn-fuel**, **LegacyFuel**, **ps-fuel**, **ox_fuel**, **qb-fuel**, **ti_fuel**, **okokGasStation**, and State Bags (prevents fuel depletion and engine breakdowns).
- **Target Support**: Fully compatible with **qb-target**, **ox_target**, or fallback 3D Text & Marker prompts.
- **Modern Vue 3 NUI Interface**: Premium glassmorphism UI with real-time telemetry, trip preferences, and destination selection.
- **Autonomous Driving Modes**:
  - **Smooth & Safe** (Cautious driving, obeys traffic)
  - **Normal** (Standard cruise)
  - **Fast & Aggressive** (Speedy lane changes & overtakes)
  - **Sport & Performance** (High-speed routing)
- **Interactive In-Cabin Experience**:
  - Cabin interior lighting toggle (`[G]` or `/taxiisik`)
  - Power window controls (`[H]` or tablet)
  - 360° Birds-Eye Camera view (`[C]` or `/taxikamera`)
  - Interactive seatback tablet touch mode (`[E]` or `/taxitablet`)
  - AI Voice interaction & smart driver dialogue
- **Trip Customization**: VIP Neon lighting colors, climate control/AC, and music genres.
- **Real-Time Taximeter**: Dynamic fare calculations based on base fee, distance traveled, and trip duration.

---

## 📋 Prerequisites & Dependencies

Make sure your server meets the following requirements:
- FiveM Server Artifact: **Recommended 5848 or higher**
- `fx_version`: **`bodacious`** or **`cerulean`**
- One of the supported frameworks (Optional - can run Standalone):
  - `qb-core` / `qbx_core` / `es_extended`
- Target Resource (Optional):
  - `qb-target` or `ox_target`
- Fuel Script (Optional):
  - `cdn-fuel`, `ps-fuel`, `LegacyFuel`, `ox_fuel`, `qb-fuel`, etc.

---

## 🚀 Installation Guide

### Step 1: Download & Place Resource
1. Extract or place the `DepAITaxi` folder into your server's `resources/` directory (e.g., `resources/[qb]/DepAITaxi` or `resources/[standalone]/DepAITaxi`).

### Step 2: Configure `server.cfg`
Add the resource to your `server.cfg` ensure order:

```cfg
# Ensure dependencies first (Framework, Target, Fuel)
ensure qb-core       # or es_extended / qbx_core
ensure qb-target     # or ox_target
ensure cdn-fuel      # or your preferred fuel resource

# Ensure DepAITaxi
ensure DepAITaxi
```

### Step 3: Configure Settings in `config.lua`
Open `config.lua` and adjust any settings for your server economy, framework, and language:

```lua
Config.Language = 'en'              -- Language: 'en' or 'tr' (check /locales folder)
Config.Framework = 'autodetect'     -- 'autodetect', 'qb', 'qbx', 'esx', or 'standalone'
Config.FuelSystem = 'autodetect'    -- 'autodetect', 'cdn-fuel', 'LegacyFuel', 'ps-fuel', 'ox_fuel', 'qb-fuel', 'standalone'
Config.SetFullFuel = true           -- Keeps taxi vehicle fuel full to prevent stalls and breakdowns

Config.VehicleModel = 'vivanite2'   -- Primary taxi vehicle model name
Config.FallbackModel = 'taxi'       -- Fallback model if custom model is not streamed

Config.BaseFare = 20.0              -- Base initial trip fare
Config.PricePerKM = 12.5            -- Cost per kilometer driven
Config.PaymentAccount = 'cash'      -- 'cash' or 'bank'
```

---

## 🎮 In-Game Controls & Commands

| Command / Key | Description |
| :--- | :--- |
| **`E` (Near Ped)** | Interact with the AI Taxi Dispatcher Ped / Station |
| **`/aitaxi`** | Opens the AI Taxi Booking UI (if `Config.EnableCommand = true`) |
| **`/canceltaxi`** | Cancels active taxi trip and dismisses the taxi |
| **`/taxipos`** | Copies your current coords formatted for `Config.PresetDestinations` to clipboard |
| **`E` (Inside Taxi)** | Open / Close Interactive Cabin Touch Panel |
| **`H` (Inside Taxi)** | Roll cabin windows Up / Down |
| **`G` (Inside Taxi)** | Toggle Cabin Interior Lighting On / Off |
| **`C` (Inside Taxi)** | Toggle 360° Birds-Eye Exterior Camera |
| **`N` (Inside Taxi)** | Push-to-Talk AI Driver Voice Input |

---

## 📍 Adding Custom Preset Destinations

You can easily add new preset locations in `config.lua` under `Config.PresetDestinations`.

1. Go to your desired location in-game.
2. Type `/taxipos` in chat or F8 console. The exact formatted Lua table entry will be copied to your clipboard.
3. Paste it inside `Config.PresetDestinations` in `config.lua`:

```lua
Config.PresetDestinations = {
    {
        id = 'legion',
        name = 'Legion Square (Downtown)',
        desc = 'City center, social gathering area',
        icon = 'building',
        coords = vector3(215.34, -810.12, 30.73)
    },
    -- Add your custom entries here:
    {
        id = 'custom_spot',
        name = 'Custom Destination Name',
        desc = 'Custom description',
        icon = 'map-pin',
        coords = vector3(123.45, -678.90, 25.10)
    }
}
```

---

## 🔧 Troubleshooting & FAQ

#### Q: The taxi is stuttering or says "Out of Fuel"
- Make sure `Config.FuelSystem = 'autodetect'` or `'cdn-fuel'` (if using cdn-fuel) in `config.lua`.
- `Config.SetFullFuel = true` ensures the vehicle is continuously topped up and won't trigger fuel-drain cutoffs.

#### Q: The Dispatcher Ped is not showing target options
- If using `qb-target` or `ox_target`, ensure they are started **before** `DepAITaxi` in your `server.cfg`.
- If you don't use a target script, the station uses a 3D text marker with `[E]` keypress automatically.

#### Q: Vehicle model doesn't spawn or crashes
- If you don't stream the custom `vivanite2` vehicle, the script automatically uses `taxi` as fallback. You can customize `Config.VehicleModel` in `config.lua`.

---

## 📄 License & Credits
- **Author**: Deploy Store
- **Resource**: DepAITaxi (Autonomous AI Taxi System)
