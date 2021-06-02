local AVGMachine = require "AVGMachine.AVGMachine"

local avg = AVGMachine.New()
avg:LoadFile("stories/story1.avg")

local TestGame = {
    playerState = {
        level = 1,
        hp = 5,
    }
}

function TestGame:OnNewScene(name, extra)
    print("====================")
    print("场景:", name, unpack(extra.options or {}))
    print("登场角色:")
    for name, actor in pairs(extra.actors) do
        print(name, unpack(actor.options or {}))
    end
end

function TestGame:OnPause(step)
    print("====================")
    if step.type == "dialogue" then
        if step.speaker then
            print(step.speaker .. "：" .. step.text)
        else
            print(step.text)
        end
        if step.options then
            for key, value in pairs(step.options) do
                print(key, value)
            end
        end
        if step.choices then
            for i, text in ipairs(step.choices) do
                print(i .. ". " .. text)
            end
        end
    else
        print(step.type)
    end
end

function TestGame:OnSectionEnd(name)
    print("====================")
    print("剧情结束，选择触发新剧情")
    local triggers = avg:GetTriggers()
    for i, name in ipairs(triggers) do
        print(i .. ". " .. name)
    end
end

function TestGame:Exit()
    print("游戏结束")
    os.exit()
end

avg:SetDelegate(TestGame)
avg:SetEnv({playerState = TestGame.playerState, game=TestGame})
avg:Play()

while true do
    local choice = tonumber(io.read())
    if avg:GetCurrentSection() then
        avg:Resume(choice)
    elseif choice then
        local triggers = avg:GetTriggers()
        avg:SetTrigger(triggers[choice])
    end
end

