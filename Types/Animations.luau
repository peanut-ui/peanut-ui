--!strict

export type Transition = {
    read _typeName: "transition",
    read animate: (obj: Instance, property: string, to: any) -> (),
    read stop: (obj: Instance, property: string) -> (),
    read isRunning: (obj: Instance, property: string) -> boolean,
    read stopAll: (obj: Instance) -> (),
}

return {}