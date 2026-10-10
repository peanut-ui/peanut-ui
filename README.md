# PeanutUI

![GitHub commit activity](https://img.shields.io/github/commit-activity/m/peanut-ui/peanut-ui?style=for-the-badge&labelColor=%23424242&color=%23B2FF59)
![GitHub repo size](https://img.shields.io/github/repo-size/peanut-ui/peanut-ui?style=for-the-badge&labelColor=%23424242&color=%2384FFFF)
![GitHub Repo stars](https://img.shields.io/github/stars/peanut-ui/peanut-ui?style=for-the-badge&labelColor=%23424242&color=%23B9F6CA)
![GitHub contributors](https://img.shields.io/github/contributors/peanut-ui/peanut-ui?style=for-the-badge&labelColor=%23424242&color=%23FFAB40)
![GitHub License](https://img.shields.io/github/license/peanut-ui/peanut-ui?style=for-the-badge&labelColor=%23424242&color=%23FF9E80)

A declarative, reactive UI framework for Roblox, written in Luau.

> **Status:** early development. PeanutUI is not yet published for public use and is unfinished — expect bugs and incomplete features.

## Why PeanutUI

Most Roblox UI code is imperative: create an instance, set a property, listen for a change, set it again. PeanutUI keeps that power but flips the default — you declare the UI, and reactivity keeps it in sync.

- **Declarative and imperative are the same thing.** `Widgets.Frame { properties = { ... } }` is exactly equivalent to creating the widget and calling `setProperty` for each field. Use whichever reads better.
- **Reactive by default.** Reading a ref subscribes; writing one schedules dependents. You never wire up change listeners by hand.
- **Deferred, not immediate.** Mutations flow through the Scheduler's stages instead of hitting instances synchronously, so updates batch cleanly.
- **Stable by design.** The public API avoids breaking changes; features are deprecated, not removed.

## Features

- **Declarative widgets** — compose UI with callable constructors like `Widgets.Frame { ... }`. No manual instance wiring.
- **Reactive by default** — refs, computed values, and reactive tables drive your UI. Changes flow through the Scheduler, not straight to instances.
- **Reactive units** — `Units.Size`, `Units.Position`, and `Units.Unit` replace `UDim2` and `UDim` with per-component scaling and ref-driven updates.
- **Lazy instance creation** — widgets are created immediately, but their Roblox `Instance` is deferred. An invisible or unparented widget never builds its instance until it becomes visible and attached.
- **Responsive scaling** — declare a reference resolution once and `Scaling` keeps the whole tree proportional on every screen.
- **Animations & transitions** — continuous animations and on-change transitions, with a full library of easing curves and spring physics.
- **Stable API** — the public surface avoids breaking changes where possible; features are deprecated rather than removed.

## Installation

PeanutUI is a library. Where it lives depends on how you install it:

```luau
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const PeanutUI = require(ReplicatedStorage.PeanutUI)  -- Or wherever you put it
```

## Example components

Gray square with "Hello, PeanutUI" text:
```luau
const Component = PeanutUI.Component
const Space = PeanutUI.Space
const Widgets = PeanutUI.Widgets
const Units = PeanutUI.Units

const space = Space.createScreenSpace("Main")

const Square = Component.defineComponent(function()
    return Widgets.Frame {
        properties = {
            size = Units.Size(200, 200),
            backgroundColor = Color3.fromRGB(30, 30, 30),
        },
        children = {
            Widgets.TextLabel {
                properties = {
                    text = "Hello, PeanutUI",
                    textColor = Color3.new(1, 1, 1)
                },
            },
        },
    }
end)

const square = Square()
square.setParent(space)  -- Or space.addChild(square)
```

Counter (as a tradition):
```luau
const Component, Space = PeanutUI.Component, PeanutUI.Space
const Widgets, Units = PeanutUI.Widgets, PeanutUI.Units
const ref, computed = PeanutUI.ref, PeanutUI.computed

const space = Space.createScreenSpace("Main")

const Counter = Component.defineComponent(function(initialValue: number)
    const clickCount = ref(initialValue)

    -- Good looking button :3
    return Widgets.TextButton {
        properties = {
            backgroundColor = Color3.fromHex("#222629"),
            textColor = Color3.fromHex("#e9f1f7"),
            text = computed(function()
                return "Clicks: " .. clickCount.value
            end),
            textSize = 16,
            size = Units.Size(0, 40),
            automaticSize = Enum.AutomaticSize.X
        },
        modifiers = {
            cornerRadius = { all = Units.Unit(6) },
            padding = { all = Units.Unit(3), left = Units.Unit(16), right = Units.Unit(16) }
        },
        events = {
            Activated = function()
                clickCount.value += 1
            end
        }
    }
end)

const counter = Counter(1)
counter.setParent(space)  -- Or space.addChild(square)
```

## Documentation

Full guides and API reference live in the [docs](https://peanutui.dev) site:

- **Guides** — quick start, thinking in PeanutUI, spaces, widgets, components, reactivity, animations, transitions.
- **Reference** — API, space, units, scaling, scheduler, ease curves, widgets, and modifiers.
