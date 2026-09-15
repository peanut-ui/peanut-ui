--!strict

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
    read continue: (obj: Instance) -> ()
}

return {}