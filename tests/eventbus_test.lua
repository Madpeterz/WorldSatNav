-- core/eventbus.lua: subscriptions, deferred queue, immediate dispatch.
return function(t, env)
    local function load()
        env.reset({ now = 1700000000 })
        local eventbus = env.require("core/eventbus")
        local topics = env.require("core/eventtopics").topics
        return eventbus, topics
    end

    t.test("unknown topics are rejected everywhere", function()
        local eventbus = load()
        t.falsy(eventbus.WatchEvent("no.such.topic", function() end, "test"))
        t.falsy(eventbus.TriggerEvent("no.such.topic"))
        t.falsy(eventbus.TriggerEventImmediate("no.such.topic"))
        t.falsy(eventbus.TriggerEvent(nil))
    end)

    t.test("TriggerEvent queues until ProcessDeferredEvents runs", function()
        local eventbus, topics = load()
        local received = {}
        eventbus.WatchEvent(topics.dev.modeChanged, function(a, b)
            table.insert(received, { a, b })
        end, "test")
        t.truthy(eventbus.TriggerEvent(topics.dev.modeChanged, "x", 2))
        t.eq(#received, 0)
        t.eq(eventbus.ProcessDeferredEvents(), 1)
        t.eq(#received, 1)
        t.eq(received[1][1], "x")
        t.eq(received[1][2], 2)
    end)

    t.test("TriggerEventImmediate dispatches straight away with up to five args", function()
        local eventbus, topics = load()
        local args = nil
        eventbus.WatchEvent(topics.dev.modeChanged, function(...)
            args = { ... }
        end, "test")
        eventbus.TriggerEventImmediate(topics.dev.modeChanged, 1, 2, 3, 4, 5)
        t.deepEq(args, { 1, 2, 3, 4, 5 })
    end)

    t.test("every subscriber to a topic is called, in order", function()
        local eventbus, topics = load()
        local order = {}
        eventbus.WatchEvent(topics.dev.modeChanged, function() table.insert(order, "first") end, "test")
        eventbus.WatchEvent(topics.dev.modeChanged, function() table.insert(order, "second") end, "test")
        eventbus.TriggerEventImmediate(topics.dev.modeChanged)
        t.deepEq(order, { "first", "second" })
    end)

    t.test("a failing subscriber does not stop the others", function()
        local eventbus, topics = load()
        local reached = false
        eventbus.WatchEvent(topics.dev.modeChanged, function() error("boom") end, "test")
        eventbus.WatchEvent(topics.dev.modeChanged, function() reached = true end, "test")
        eventbus.TriggerEventImmediate(topics.dev.modeChanged)
        t.truthy(reached)
    end)

    t.test("only subscribers of the triggered topic are called", function()
        local eventbus, topics = load()
        local called = false
        eventbus.WatchEvent(topics.tracking.stop, function() called = true end, "test")
        eventbus.TriggerEventImmediate(topics.dev.modeChanged)
        t.falsy(called)
    end)

    t.test("events with no subscribers are harmless", function()
        local eventbus, topics = load()
        t.truthy(eventbus.TriggerEvent(topics.dev.modeChanged))
        t.eq(eventbus.ProcessDeferredEvents(), 1)
    end)

    t.test("ProcessDeferredEvents honours the per-tick budget", function()
        local eventbus, topics = load()
        local count = 0
        eventbus.WatchEvent(topics.dev.modeChanged, function() count = count + 1 end, "test")
        for _ = 1, 12 do
            eventbus.TriggerEvent(topics.dev.modeChanged)
        end
        t.eq(eventbus.ProcessDeferredEvents(), 5) -- default budget
        t.eq(count, 5)
        t.eq(eventbus.ProcessDeferredEvents(4), 4)
        t.eq(eventbus.ProcessDeferredEvents(), 3)
        t.eq(count, 12)
        t.eq(eventbus.ProcessDeferredEvents(), 0)
    end)

    t.test("deferred events run in the order they were queued", function()
        local eventbus, topics = load()
        local seen = {}
        eventbus.WatchEvent(topics.dev.modeChanged, function(n) table.insert(seen, n) end, "test")
        for n = 1, 4 do
            eventbus.TriggerEvent(topics.dev.modeChanged, n)
        end
        eventbus.ProcessDeferredEvents()
        t.deepEq(seen, { 1, 2, 3, 4 })
    end)

    t.test("a large backlog drains completely across ticks", function()
        local eventbus, topics = load()
        local count = 0
        eventbus.WatchEvent(topics.dev.modeChanged, function() count = count + 1 end, "test")
        eventbus.SetDeferredBudgetPerTick(50)
        for _ = 1, 400 do
            eventbus.TriggerEvent(topics.dev.modeChanged)
        end
        local ticks = 0
        while eventbus.ProcessDeferredEvents() > 0 do
            ticks = ticks + 1
        end
        t.eq(count, 400)
        t.eq(ticks, 8)
    end)

    t.test("events queued by a subscriber are processed in a later pass", function()
        local eventbus, topics = load()
        local order = {}
        eventbus.WatchEvent(topics.dev.modeChanged, function()
            table.insert(order, "outer")
            eventbus.TriggerEvent(topics.tracking.stop)
        end, "test")
        eventbus.WatchEvent(topics.tracking.stop, function() table.insert(order, "inner") end, "test")
        eventbus.TriggerEvent(topics.dev.modeChanged)
        eventbus.ProcessDeferredEvents(1)
        t.deepEq(order, { "outer" })
        eventbus.ProcessDeferredEvents(1)
        t.deepEq(order, { "outer", "inner" })
    end)

    t.test("SetDeferredBudgetPerTick validates its argument", function()
        local eventbus = load()
        t.falsy(eventbus.SetDeferredBudgetPerTick("10"))
        t.falsy(eventbus.SetDeferredBudgetPerTick(0))
        t.falsy(eventbus.SetDeferredBudgetPerTick(-3))
        t.truthy(eventbus.SetDeferredBudgetPerTick(7.9))
    end)

    t.test("a zero budget processes nothing", function()
        local eventbus, topics = load()
        eventbus.TriggerEvent(topics.dev.modeChanged)
        t.eq(eventbus.ProcessDeferredEvents(0), 0)
        t.eq(eventbus.ProcessDeferredEvents(), 1)
    end)
end
