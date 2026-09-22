--!strict
--!optimize 2
const Component = require(script.Components.Component)
const ControlFlow = require(script.Components.ControlFlow)

local Components = table.freeze({
    define = Component.defineComponent,
    onCreated = Component.onCreated,
    onSetup = Component.onSetup,
    onBeforeDestroyed = Component.onBeforeDestroyed,
    onDestroyed = Component.onDestroyed,
    If = ControlFlow.If,
    makeStory = require(script.Components.Stories).makeStory,
})

return table.freeze({
    Widgets = require(script.Components.Widgets),
    Space = require(script.Classes.Space),

    Component = Components,

    Animations = require(script.Components.Animations),
    Transitions = require(script.Components.Transitions),

    Ref = require(script.Utils.Ref),
    Units = require(script.Utils.Units),
    State = require(script.State),
})