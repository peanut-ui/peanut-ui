--!strict

-- keyof and index worked poorly so I made functions instead...
export type function KeyOf(TableType: type): type
    local keys: { type } = {}
    local seen: { [string]: boolean } = {}

    local function collect(current: type)
        if current:is("table") then
            for key in current:properties() do
                if key:is("singleton") then
                    local name = key:value()
                    if type(name) ~= "string" then
                        continue
                    end

                    if not seen[name] then
                        seen[name] = true
                        table.insert(keys, key)
                    end
                end
            end
        elseif current:is("intersection") then
            for _, comp in current:components() do
                collect(comp)
            end
        end
    end

    collect(TableType)

    local count = #keys
    if count == 0 then
        return types.any
    elseif count == 1 then
        return keys[1]
    end

    return types.unionof(table.unpack(keys))
end

export type function Resolve(TableType: type, KeyType: type): type
    if not KeyType:is("singleton") then
        return types.unknown
    end

    local function findProperty(current: type): type?
        if current:is("table") then
            return current:readproperty(KeyType)
        elseif current:is("intersection") then
            for _, comp in current:components() do
                local prop = findProperty(comp)
                if prop then
                    return prop
                end
            end
        end
        return nil
    end

    return findProperty(TableType) or types.unknown
end

type function makeOptional(t: type): type
    if types.optional then
        return types.optional(t)
    else
        return types.unionof(t, types.singleton(nil))
    end
end

export type function UnionProperties(TableType: type, UnionWith: type): type
    local result = types.newtable()
    local queue = { TableType }
    local seen = {}

    while #queue > 0 do
        local current = table.remove(queue) :: type

        if current:is("table") then
            for key, value in current:properties() do
                local propType = value.read or value.write
                local keyName = if key:is("singleton") then key:value() else nil

                if propType and keyName and not seen[keyName] then
                    seen[keyName] = true

                    local optionalProp = types.unionof(propType, UnionWith)

                    result:setproperty(key, optionalProp)
                end
            end
        elseif current:is("intersection") then
            for _, comp in current:components() do
                table.insert(queue, comp)
            end
        end
    end

    return result
end

export type function Partial(TableType: type): type
    local result = types.newtable()
    local queue = { TableType }
    local seen = {}

    while #queue > 0 do
        local current = table.remove(queue) :: type

        if current:is("table") then
            for key, value in current:properties() do
                local propType = value.read or value.write
                local keyName = if key:is("singleton") then key:value() else nil

                if propType and keyName and not seen[keyName] then
                    seen[keyName] = true

                    local optionalProp = makeOptional(propType)

                    result:setproperty(key, optionalProp)
                end
            end
        elseif current:is("intersection") then
            for _, comp in current:components() do
                table.insert(queue, comp)
            end
        end
    end

    return result
end

export type function Flatten(IntersectionType: type): type
    local result = types.newtable()
    local queue = { IntersectionType }
    local seen = {}

    while #queue > 0 do
        local current = table.remove(queue) :: type

        if current:is("table") then
            for key, value in current:properties() do
                local keyName = if key:is("singleton") then key:value() else nil

                if keyName and not seen[keyName] then
                    seen[keyName] = true

                    if value.read then
                        result:setproperty(key, value.read)
                    elseif value.write then
                        result:setproperty(key, value.write)
                    end
                end
            end
        elseif current:is("intersection") then
            for _, comp in current:components() do
                table.insert(queue, comp)
            end
        end
    end

    return result
end

return {}