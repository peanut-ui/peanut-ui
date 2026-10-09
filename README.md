# PeanutUI

A declarative, reactive UI framework for Roblox, written in Luau.

Peanut-sized API, production-sized UI.

> **Status:** early development. PeanutUI is not yet published for public use and is unfinished — expect bugs and incomplete features.

## Features

- **Declarative widgets** — compose UI with callable constructors like `Widgets.Frame { ... }`. No manual instance wiring.
- **Reactive by default** — refs, computed values, and reactive tables drive your UI. Changes flow through the Scheduler, not straight to instances.
- **Reactive units** — `Units.Size`, `Units.Position`, and `Units.Unit` replace `UDim2` and `UDim` with per-component scaling and ref-driven updates.
- **Responsive scaling** — declare a reference resolution once and `Scaling` keeps the whole tree proportional on every screen.
- **Animations & transitions** — continuous animations and on-change transitions, with a full library of easing curves and spring physics.
- **Stable API** — the public surface avoids breaking changes where possible; features are deprecated rather than removed.

## Installation

PeanutUI is a library. Where it lives depends on how you install it:

- **Manual install** — `ReplicatedStorage.PeanutUI`
- **Wally install** — `ReplicatedStorage.Packages.PeanutUI`

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Manual install
local PeanutUI = require(ReplicatedStorage.PeanutUI)

-- Wally install
local PeanutUI = require(ReplicatedStorage.Packages.PeanutUI)
```

## Quick start

```luau
local PeanutUI = require(ReplicatedStorage.PeanutUI)

local Component = PeanutUI.Component
local Space = PeanutUI.Space
local Widgets = PeanutUI.Widgets
local Units = PeanutUI.Units

local space = Space.createScreenSpace("Main")

local App = Component.defineComponent(function()
    return Widgets.Frame {
        properties = {
            size = Units.Size(200, 200),
            backgroundColor = Color3.fromRGB(30, 30, 30),
        },
        children = {
            Widgets.TextLabel {
                properties = {
                    text = "Hello, PeanutUI",
                },
            },
        },
    }
end)

local app = App()
app.setParent(space)
```

## Documentation

Full guides and API reference live in the [docs](https://peanutui.dev) site:

- **Guides** — quick start, thinking in PeanutUI, spaces, widgets, components, reactivity, animations, transitions.
- **Reference** — API, space, units, scaling, scheduler, ease curves, widgets, and modifiers.
