--!strict

export type AnimationStep = (obj: any, deltaTime: number, state: any) -> ...boolean?

export type Transition = {
    read _typeName: "transition",
    read animate: (obj: Instance, property: string, to: any) -> (),
    read stop: (obj: Instance, property: string?) -> (),
    read isRunning: (obj: Instance, property: string) -> boolean
}

export type Animation = {
    read _typeName: "animation",

    read animate: (obj: Instance) -> (),
    read stop: (obj: Instance) -> (),
    read isRunning: (obj: Instance) -> boolean,
    read pause: (obj: Instance) -> (),
    read continue: (obj: Instance) -> (),
    read properties: {string}
}

-- May change in the future
-- currently only for mapping properties like "backgroundColor" to "BackgroundColor3"
export type UnresolvedAnimation = {
    read _typeName: "unresolvedAnimation",

    read resolve: (propertiesMap: {[string]: string}) -> Animation
}

export type AnimationControl = {
    read _typeName: "animationControl",

    read animate: () -> (),
    read stop: () -> (),
    read isRunning: () -> boolean,
    read pause: () -> (),
    read continue: () -> ()
}

return {}