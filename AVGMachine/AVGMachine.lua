local Parser = require("AVGMachine.AVGParser")

local AVGMachine = {}

AVGMachine.Parser = Parser

local mt = {__index = AVGMachine}

function AVGMachine.New()
    local o = {}
    setmetatable(o, mt)
    return o
end

function AVGMachine:SetDelegate(delegate)
    self._delegate = delegate
end

function AVGMachine:SetEnv(env)
    setmetatable(env, {__index = _G})
    self._env = env
end

function AVGMachine:SetData(data)
    self._data = data
end

function AVGMachine:LoadString(text)
    self._data = self.Parser.LoadString(text)
end

function AVGMachine:LoadFile(path)
    self._data = self.Parser.LoadFile(path)
end

function AVGMachine:GetCurrentSection()
    return self._currentSection and self._currentSection.name or nil
end

function AVGMachine:GetTriggers()
    assert(self._data, "_data is nil")
    return self._data.triggers;
end

function AVGMachine:SetTrigger(name)
    assert(name, "invalid trigger")
    assert(self._data, "_data is nil")
    assert(not self._currentSection, "is playing")
    local sectionName = string.format("__on_trigger_%s__", name)
    self._currentSection = self._data.sections[sectionName]
    self._currentStep = 0
    self:Resume()
end

function AVGMachine:Play(sectionName)
    assert(self._data, "_data is nil")
    self._currentSection = sectionName and self._data.sections[sectionName] or self._data.sections.main
    self._currentStep = 0
    self._delegate:OnNewScene(self._data.scene.name, {
        options = self._data.scene.options,
        actors = self._data.actors
    })
    self:Resume()
end

function AVGMachine:Resume(choice)
    assert(self._currentSection, "_currentSection is nil")
    local step = self._currentSection.steps[self._currentStep]
    if choice then
        local choices = step.choices
        assert(choices , "choices is nil")
        assert(#choices >= choice , "choice > #choices")
        self._currentStep = self._currentStep + choice
    else
        assert(not step or not step.choices, "need a choice")
        self._currentStep = self._currentStep + 1
    end

    local paused = false
    while true do
        if self._currentStep > #self._currentSection.steps then
            self._currentSection = nil
            self._currentStep = nil
            self._delegate:OnSectionEnd()
            break
        end
        step = self._currentSection.steps[self._currentStep]
        if step.type == "choice" and step.choice_id ~= choice then
            -- skip
        else
            paused = self:Execute(step)
            if paused then
                break
            end
        end
        self._currentStep = self._currentStep + 1
    end
end

function AVGMachine:Execute(step)
    local type = step.type
    if type == "dialogue" then
        self._delegate:OnPause(step)
        return true
    elseif type == "choice" then
        return step.next_step and self:Execute(step.next_step)
    elseif type == "code" then
        setfenv(step.func, self._env or {})
        step.func()
        return false
    elseif type == "condition" then
        setfenv(step.func, self._env or {})
        local value = step.func()
        if value then
            return step.true_step and self:Execute(step.true_step)
        else
            return step.false_step and self:Execute(step.false_step)
        end
    elseif type == "section_jump" then
        self._currentSection = self._data.sections[step.section]
        self._currentStep = 1
        return self:Execute(self._currentSection.steps[1])
    elseif type == "file_jump" then
        local newData = self.Parser.LoadFile(step.file)
        self:SetData(newData)
        self:Play()
        return false
    end
    assert(false, "invalid type: " .. type)
end

return AVGMachine