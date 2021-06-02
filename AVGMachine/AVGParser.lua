
local function lines(text)
    local n = 0
    local p0 = 0
    local len = #text
    return function ()
        if p0 < len then
            local p1 = string.find(text, "\n", p0 + 1)
            local line = nil
            if not p1 then
                p1 = len
            end
            line = string.sub(text, p0 + 1, p1)
            n = n + 1
            p0 = p1
            return n, line
        end
        return nil, nil
    end
end

local keywords = {

    ["scene"] = function(state, data, option)
        option = assert(option, "invalid format")
        local options = {}
        for op in string.gmatch(option, "%S+") do
            table.insert(options, op)
        end
        data.scene = {
            name = options[1],
        }
        if #options > 1 then
            table.remove(options, 1)
            data.scene.options = options
        end
    end,

    ["actor"] = function(state, data, option)
        option = assert(option, "invalid format")
        local options = {}
        for op in string.gmatch(option, "%S+") do
            table.insert(options, op)
        end
        local actor = {
            name = options[1],
        }
        if #options > 1 then
            table.remove(options, 1)
            actor.options = options
        end
        data.actors[actor.name] = actor
    end,

    ["section"] = function (state, data, option)
        option = assert(option, "invalid format")
        state.newSection = {
            name = string.match(option, "(%S+)"),
            steps = {},
        }
    end,

    ["main"] = function(state, data, option)
        state.newSection = {
            name = "main",
            steps = {},
        }
    end,

    ["trigger"] = function (state, data, option)
        local trigger = string.match(option, "(%S+)")
        state.newSection = {
            name = string.format("__on_trigger_%s__", trigger),
            steps = {},
        }
        table.insert(data.triggers, trigger)
    end,

    ["end"] = function (state, data, option)
        local section = assert(state.newSection, "invalid format")
        assert(not data.sections[section.name], "section duplicate")
        data.sections[section.name] = section
        state = {}
    end
}

local parsestep = nil

local function dialogue(line)
    local p1 = string.find(line, "%[%[")
    if not p1 then
        return nil
    end
    local p2 = string.find(line, "%]%]")

    local text = string.sub(line, p1 + 2, p2 - 1)
    local speaker = string.match(line, "%s*(%S+)%s*:%s*%[%[")

    local options = nil
    for op in string.gmatch(line, "%-%-(%S+)", p2) do
        options = options or {}
        local p = string.find(op, "=")
        if p then
            options[string.sub(op, 1, p-1)] = string.sub(op, p + 1)
        else
            options[op] = true
        end
    end

    return {
        type = "dialogue",
        text = text,
        speaker = speaker,
        options = options,
    }
end

local function choice(lineNo, line, state)
    local choice, text, rest = string.match(line, "%s*<(%d)>%s*%[%[(.+)%]%]%s*%?(.+)")
    if choice and text and rest then
        return {
            type = "choice",
            choice_id = tonumber(choice),
            text = text,
            next_step = parsestep(lineNo, rest, state),
        }
    end
end

local function section_jump(line)
    local section = string.match(line, "%s*%->%s*(%S+)")
    if section then
        return {
            type = "section_jump",
            section = section
        }
    end
end

local function file_jump(line)
    local file = string.match(line, "%s*=>%s*(%S+)")
    if file then
        return {
            type = "file_jump",
            file = file
        }
    end
end

local function code(line)
    local code = string.match(line, "%s*>%s*(.+)\n")
    if code then
        return {
            type = "code",
            func = loadstring(string.format([[
                return function ()
                    %s
                end
            ]], code))()
        }
    end
end

local function condition(lineNo, line, state)
    local exp, rest = string.match(line, "%s*IF%((.+)%)(.+)")
    if exp and rest then
        local step = {
            type = "condition",
            func = loadstring(string.format([[
                return function ()
                    return %s
                end
            ]], exp))()
        }
        local s1, s2 = string.match(rest, "(.+)%s+ELSE%s+(.+)")
        if s1 and s2 then
            step.true_step = parsestep(lineNo, s1, state)
            step.false_step = parsestep(lineNo, s2, state)
        else
            step.true_step = parsestep(lineNo, rest, state)
        end
        return step
    end
end

parsestep = function (lineNo, line, state)
    local step = (
        condition(lineNo, line, state)
        or choice(lineNo, line, state)
        or dialogue(line)
        or section_jump(line)
        or file_jump(line)
        or code(line)
    )
    return step
end

local function parseline(lineNo, line, state, data)

    local keyword = string.match(line, "@(%a+)")
    if keyword then
        local option = string.match(line, "%s+(.+)", #keyword)
        keywords[keyword](state, data, option)
        return
    end

    local step = parsestep(lineNo, line, state)
    if step then
        table.insert(state.newSection.steps, step)
        if step.type == "choice" then
            local id = step.choice_id
            local choices = state.newSection.steps[#state.newSection.steps - id].choices or {}
            table.insert(choices, step.text)
            state.newSection.steps[#state.newSection.steps - id].choices = choices
        end
    end
end

local AVGParser = {}

function AVGParser.LoadString(text)

    local data = {
        scene = nil,
        actors = {},
        sections = {},
        triggers = {},
    }
    local state = {}

    for i, line in lines(text) do
        local ok, err = pcall(parseline, i, line, state, data)
        if not ok then
            error("error: " .. line .. "\n" .. err)
        end
    end

    return data
end

function AVGParser.LoadFile(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*all")
    f:close()
    return AVGParser.LoadString(text)
end

return AVGParser