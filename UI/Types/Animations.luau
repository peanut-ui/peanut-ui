--!strict

export type AnimationBase = {
    read animate: (obj: Instance, property: string, to: any) -> (),
    read stop: (obj: Instance, property: string?) -> (),
    read isRunning: (obj: Instance, property: string) -> boolean
}

export type Transition = AnimationBase & {
    read _typeName: "transition",
}

export type Animation = AnimationBase & {
    read _typeName: "animation",

    read pause: (obj: Instance, property: string?) -> (),
    read continue: (obj: Instance, property: string) -> (),
}

return {}